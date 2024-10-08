from aws_cdk import (
    App, Stack, Duration, RemovalPolicy, CfnOutput, aws_ec2 as ec2,
    aws_iam as iam, aws_ecs as ecs, aws_ecs_patterns as ecs_patterns,
    aws_rds as rds, aws_lambda as _lambda, aws_cloudwatch as cloudwatch,
    aws_events as events, aws_events_targets as targets, aws_amplify as amplify,
    aws_codepipeline as codepipeline, aws_codepipeline_actions as pipeline_actions,
    aws_codebuild as codebuild, aws_s3 as s3, aws_s3_deployment as s3_deployment,
    aws_budgets as budgets, aws_ecr as ecr
)
from constructs import Construct


class ScalableWebAppStack(Stack):

    def __init__(self, scope: Construct, id: str, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        # VPC
        vpc = ec2.Vpc(self, "VPC", max_azs=2)

        # Fargate Cluster
        cluster = ecs.Cluster(self, "Cluster", vpc=vpc)

        # IAM Role for Fargate Task Execution
        execution_role = iam.Role(
            self, "ExecutionRole",
            assumed_by=iam.ServicePrincipal("ecs-tasks.amazonaws.com"),
            managed_policies=[
                iam.ManagedPolicy.from_aws_managed_policy_name("service-role/AmazonECSTaskExecutionRolePolicy")
            ]
        )

        # Define the Fargate Task with Django
        task_definition = ecs.FargateTaskDefinition(
            self, "TaskDef",
            execution_role=execution_role
        )

        container = task_definition.add_container(
            "DjangoContainer",
            image=ecs.ContainerImage.from_registry("your-django-app-image"),  # Replace with your Docker image
            logging=ecs.LogDrivers.aws_logs(stream_prefix="DjangoApp")
        )

        container.add_port_mappings(
            ecs.PortMapping(container_port=8000)
        )

        # Fargate Service
        fargate_service = ecs_patterns.ApplicationLoadBalancedFargateService(
            self, "FargateService",
            cluster=cluster,
            task_definition=task_definition,
            public_load_balancer=True,
        )

        # Aurora Serverless Database with Auto-Pause
        db_cluster = rds.ServerlessCluster(
            self, "AuroraServerless",
            engine=rds.DatabaseClusterEngine.aurora_mysql(version=rds.AuroraMysqlEngineVersion.VER_2_10_0),
            vpc=vpc,
            credentials=rds.Credentials.from_generated_secret("dbadmin"),
            scaling=rds.ServerlessScalingOptions(
                auto_pause=Duration.minutes(5),  # Auto-pause after 5 minutes of inactivity
                min_capacity=rds.AuroraCapacityUnit.ACU_2,
                max_capacity=rds.AuroraCapacityUnit.ACU_8,
            ),
            enable_data_api=True
        )

        # CloudWatch Metric for Monitoring Idle Time
        http_requests_metric = cloudwatch.Metric(
            namespace="AWS/ApplicationELB",
            metric_name="RequestCount",
            dimensions_map={
                "LoadBalancer": fargate_service.load_balancer.load_balancer_full_name
            },
            period=Duration.minutes(1),
            statistic="Sum"
        )

        # CloudWatch Alarm to Trigger Stop Lambda Function
        idle_alarm = cloudwatch.Alarm(
            self, "IdleAlarm",
            metric=http_requests_metric,
            threshold=0,
            evaluation_periods=2,
            datapoints_to_alarm=2,
            actions_enabled=True,
            alarm_description="Trigger when idle for 2 minutes"
        )

        # Lambda Function to Stop Fargate Service
        stop_fargate_lambda = _lambda.Function(
            self, "StopFargateLambda",
            runtime=_lambda.Runtime.PYTHON_3_8,
            handler="stop_fargate.handler",
            code=_lambda.Code.from_inline(
                f"""
                import boto3
                
                def handler(event, context):
                    ecs_client = boto3.client('ecs')
                    response = ecs_client.update_service(
                        cluster='{cluster.cluster_name}',  # Dynamically retrieve cluster name
                        service='{fargate_service.service.service_name}',  # Dynamically retrieve service name
                        desired_count=0
                    )
                    print("Fargate service stopped:", response)
                """
            ),
            timeout=Duration.seconds(60)
        )

        # Trigger Stop Lambda on Alarm
        idle_alarm.add_alarm_action(targets.LambdaFunction(stop_fargate_lambda))

        # Lambda Function to Start Fargate Service
        start_fargate_lambda = _lambda.Function(
            self, "StartFargateLambda",
            runtime=_lambda.Runtime.PYTHON_3_8,
            handler="start_fargate.handler",
            code=_lambda.Code.from_inline(
                f"""
                import boto3
                
                def handler(event, context):
                    ecs_client = boto3.client('ecs')
                    response = ecs_client.update_service(
                        cluster='{cluster.cluster_name}',  # Dynamically retrieve cluster name
                        service='{fargate_service.service.service_name}',  # Dynamically retrieve service name
                        desired_count=1
                    )
                    print("Fargate service started:", response)
                """
            ),
            timeout=Duration.seconds(60)
        )

        # EventBridge Rule to Trigger Start Lambda on Schedule
        start_rule = events.Rule(
            self, "StartFargateRule",
            schedule=events.Schedule.cron(minute="*/5"),  # Runs every 5 minutes
        )
        start_rule.add_target(targets.LambdaFunction(start_fargate_lambda))

        # CloudWatch Alarm to Trigger Start Lambda on Traffic
        start_alarm = cloudwatch.Alarm(
            self, "StartAlarm",
            metric=http_requests_metric,
            threshold=1,
            evaluation_periods=1,
            datapoints_to_alarm=1,
            actions_enabled=True,
            alarm_description="Trigger to start Fargate service on traffic"
        )
        start_alarm.add_alarm_action(targets.LambdaFunction(start_fargate_lambda))

        # Create ECR Repository
        ecr_repo = ecr.Repository(
            self, "DjangoECRRepo",
            repository_name="your-django-app"
        )

        # AWS Amplify for React Frontend
        amplify_app = amplify.CfnApp(
            self, "AmplifyApp",
            name="AmplifyAppName",
            repository="https://github.com/your-github-username/your-repository-name",  # Replace with your GitHub repo URL
            oauth_token=iam.SecretValue.secrets_manager("github-token").to_string()
        )

        amplify_branch = amplify.CfnBranch(
            self, "AmplifyBranch",
            app_id=amplify_app.ref,
            branch_name="main",
        )

        # S3 Bucket for Django Artifacts
        artifact_bucket = s3.Bucket(self, "ArtifactBucket")

        # CodeBuild Project for Django
        build_project = codebuild.Project(
            self, "DjangoBuild",
            source=codebuild.Source.s3(bucket=artifact_bucket, path="django-app.zip"),
            environment=codebuild.BuildEnvironment(
                build_image=codebuild.LinuxBuildImage.STANDARD_5_0
            ),
            build_spec=codebuild.BuildSpec.from_object({
                "version": "0.2",
                "phases": {
                    "install": {
                        "commands": [
                            "pip install -r requirements.txt"
                        ]
                    },
                    "build": {
                        "commands": [
                            "python manage.py migrate",
                            "python manage.py collectstatic --noinput",
                            "docker build -t your-django-app-image ."
                        ]
                    },
                    "post_build": {
                        "commands": [
                            f"$(aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin {ecr_repo.repository_uri})",
                            f"docker tag your-django-app-image:latest {ecr_repo.repository_uri}:latest",
                            f"docker push {ecr_repo.repository_uri}:latest"
                        ]
                    }
                }
            })
        )

        # CodePipeline for Django
        pipeline = codepipeline.Pipeline(self, "Pipeline",
            pipeline_name="DjangoPipeline",
            artifact_bucket=artifact_bucket
        )

        source_output = codepipeline.Artifact()
        build_output = codepipeline.Artifact()

        pipeline.add_stage(
            stage_name="Source",
            actions=[
                pipeline_actions.S3SourceAction(
                    action_name="S3Source",
                    bucket=artifact_bucket,
                    bucket_key="django-app.zip",
                    output=source_output
                )
            ]
        )

        pipeline.add_stage(
            stage_name="Build",
            actions=[
                pipeline_actions.CodeBuildAction(
                    action_name="CodeBuild",
                    project=build_project,
                    input=source_output,
                    outputs=[build_output]
                )
            ]
        )

        # AWS Budget to Monitor Costs
        budget = budgets.CfnBudget(
            self, "MonthlyBudget",
            budget={
                "budgetName": "MonthlyCostBudget",
                "budgetLimit": {
                    "amount": 100,
                    "unit": "USD"
                },
                "budgetType": "COST",
                "timeUnit": "MONTHLY",
            },
            notifications_with_subscribers=[{
                "notification": {
                    "comparisonOperator": "GREATER_THAN",
                    "threshold": 90,
                    "thresholdType": "PERCENTAGE",
                    "notificationType": "ACTUAL"
                },
                "subscribers": [{
                    "subscriptionType": "EMAIL",
                    "address": "your-email@example.com"
                }]
            }]
        )

        # Outputs
        CfnOutput(self, "LoadBalancerDNS", value=fargate_service.load_balancer.load_balancer_dns_name)
        CfnOutput(self, "AmplifyAppURL", value=amplify_branch.attr_branch_url)
        CfnOutput(self, "PipelineURL", value=pipeline.pipeline_arn)
        CfnOutput(self, "ECRRepoURI", value=ecr_repo.repository_uri)


app = App()
ScalableWebAppStack(app, "ScalableWebAppStack")
app.synth()
