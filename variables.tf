variable "instance_name" {
  description = "Value of the Name tag for the EC2 instance"
  type        = string
  default     = "ExampleAppServerInstance"
}
variable "ubuntu" {
  description = "AMI value for the EC2 instance"
  type        = string
  default     = "ami-0862be96e41dcbf74"
}
variable "redhat" {
  description = "AMI value for the EC2 instance"
  type        = string
  default     = "ami-0aa8fc2422063977a"
}
variable "aws_linux" {
  description = "AMI value for the EC2 instance"
  type        = string
  default     = "ami-05c3dc660cb6907f0"
}
variable "ubu_name_list" {
  description = "Name value for each EC2 instance"
  type        = list(any)
  default     = ["ubu-1", "ubu-2", "ubu-3"]
}
variable "redh_resource_group" {
  description = "Name value for each EC2 instance"
  type        = list(any)
  default     = ["redh-1", "redh-2", "redh-3"]
}
variable "awsl_resource_group" {
  description = "Name value for each EC2 instance"
  type        = list(any)
  default     = ["awsl-1", "awsl-2"]
}