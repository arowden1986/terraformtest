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
variable "ami_owner" {
  type        = string
  description = "Account ID containing machine images."
  default     = "337314033594"
}
variable "ami_name" {
  type        = string
  description = "Name of the aeropspike machine image to use."
  default     = "aerospike-lifecycle-poc-2022-12-05T18-46-37Z"
}
variable "instance_type" {
  type        = string
  description = "The aeropspike instance type to use."
  default     = "m5d.large"
}
variable "cluster_size" {
  type    = number
  default = 0
}
variable "default_ttl" {
  type    = number
  default = 0
}