variable "group" {
  description = "Group name"
  type        = string
}

variable "subenv" {
  description = "Sub-environment name"
  type        = string
}

variable "env" {
  description = "Environment name"
  type        = string
}

variable "region" {
  description = "Region name"
  type        = string
}

variable "vpc_id" {
  description = "The VPC to deploy into"
  type        = string
}

variable "private_subnets" {
  description = "The private subnets"
  type        = list(any)
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

variable "ami_owner" {
  description = "Owner account for the AMI to use"
  type        = string
  default     = "271036156099"
}

variable "instance_type" {
  description = "Type of instance to use"
  type        = string
  default     = "t3.micro"
}

variable "ami_name" {
  description = "Name of the AMI to use"
  type        = string
}
