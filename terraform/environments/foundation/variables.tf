variable "group" {
  type        = string
  description = "The customer ID"
  default     = "customerID"
}
variable "env" {
  type        = string
  description = "The dataplane ID"
  default     = "dataplaneID"
}
variable "subenv" {
  type        = string
  description = "The database ID"
  default     = "databaseID"
}
variable "region" {
  type        = string
  description = "The cloud region."
  default     = "us-west-2"
}
variable "dns_tld" {
  type        = string
  description = "Route53 DNS zone to use when setting records."
  default     = "amstest.cloud"
}
variable "bastion_ami_owner" {
  type        = string
  description = "Account ID containing machine images."
  default     = "337314033594"
}
variable "bastion_ami_name" {
  type        = string
  description = "Name of the bastion machine image to use."
  default     = "ams-aws-v11_0_1-base-final-2763421647"
}
variable "bastion_instance_type" {
  type        = string
  description = "The bastion instance type to use."
  default     = "t3.small"
}
variable "lifecycle_ami_name" {
  type        = string
  description = "Name of the lifecycle machine image to use."
  default     = "lifecycle-poc-2022-12-05T19-11-34Z"
}
variable "lifecycle_instance_type" {
  type        = string
  description = "The lifecycle instance type to use."
  default     = "t3.micro"
}

variable "proxy_ami_name" {
  type        = string
  description = "Name of the proxy machine image to use."
  default     = "proxy-2022-12-29T17-57-33Z"
}

variable "proxy_instance_type" {
  type        = string
  description = "The proxy instance type to use."
  default     = "m6a.large"
}