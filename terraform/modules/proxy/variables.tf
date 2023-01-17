variable "group" {
  description = "Group name"
  type        = string
  default     = "proxy"
}

variable "subenv" {
  description = "Sub-environment name"
  type        = string
  default     = "jwillhite"
}

variable "env" {
  description = "Environment name"
  type        = string
  default     = "perftest"
}

variable "region" {
  description = "Region name"
  type        = string
  default     = "us-west-2"
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

variable "ami_owner" {
  description = "Owner account for the AMI to use"
  type        = string
  default     = "337314033594"
}

variable "instance_type" {
  description = "Type of instance to use"
  type        = string
  default     = "m6a.large"
}

variable "instance_count" {
  description = "numner of instance to use"
  type        = number
  default     = 3
}

variable "ami_name" {
  description = "Name of the AMI to use"
  type        = string
  default     = "proxy-2022-12-29T17-57-33Z"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
  default     = "vpc-0056943ed656edcd1"
}

variable "dns_tld" {
  description = "domain"
  type        = string
  default     = "amstest.cloud"
}

variable "create_proxy" {
  description = "domain"
  type        = bool
  default     = true
}

variable "logging_bucket" {
  description = "Logging bucket name"
  type        = string
  default     = "ams-logging-core-prod-us-west-2"
}
