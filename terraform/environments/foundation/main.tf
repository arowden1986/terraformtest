provider "aws" {
  region = local.region
}

locals {
  group                   = var.group
  env                     = var.env
  subenv                  = var.subenv
  region                  = var.region
  dns_tld                 = var.dns_tld
  bastion_ami_owner       = var.bastion_ami_owner
  bastion_ami_name        = var.bastion_ami_name
  bastion_instance_type   = var.bastion_instance_type
  lifecycle_ami_name      = var.lifecycle_ami_name
  lifecycle_instance_type = var.lifecycle_instance_type

  all_tags = {
    "group" : local.group,
    "subenv" : local.subenv,
    "env" : local.env,
    "provisioner" : "terraform",
  }
}

module "vpc" {
  source = "git::https://github.com/aerospike-managed-cloud-services/ams-base-runbooks.git//terraform/modules/aws-vpc?ref=v11.1.0"

  cidr_block         = "10.0.0.0/23"
  availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]
  public_subnets     = ["10.0.0.0/27", "10.0.0.32/27", "10.0.0.64/27"]
  private_subnets    = ["10.0.0.96/27", "10.0.0.128/27", "10.0.0.160/27"]
  data_subnets       = ["10.0.1.0/27", "10.0.1.32/27", "10.0.1.64/27"]

  all_tags            = local.all_tags
  vpc_tags            = { "Name" : "${local.group}-${local.subenv}-${local.env}" }
  public_rtb_tags     = { "Name" : "public-${local.group}-${local.subenv}-${local.env}" }
  public_subnet_tags  = { "Name" : "public-${local.group}-${local.subenv}-${local.env}" }
  private_rtb_tags    = { "Name" : "private-${local.group}-${local.subenv}-${local.env}" }
  private_subnet_tags = { "Name" : "private-${local.group}-${local.subenv}-${local.env}" }
  data_rtb_tags       = { "Name" : "data-${local.group}-${local.subenv}-${local.env}" }
  data_subnet_tags    = { "Name" : "data-${local.group}-${local.subenv}-${local.env}" }
  eip_tags            = { "Name" : "nat-${local.group}-${local.subenv}-${local.env}" }
  igw_tags            = { "Name" : "${local.group}-${local.subenv}-${local.env}" }
}

module "foundation" {
  source = "git::https://github.com/aerospike-managed-cloud-services/ams-internal-infrastructure.git//terraform/modules/aws-ams-core-foundation?ref=90df4f8"

  group             = local.group
  subenv            = local.subenv
  env               = local.env
  region            = local.region
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids

  dns_tld = local.dns_tld

  ami_owner                         = local.bastion_ami_owner
  bastion_ami_name                  = local.bastion_ami_name
  bastion_instance_type             = local.bastion_instance_type
  dynamic_security_group_rules_cidr = null
  tags                              = local.all_tags
}


module "lifecycle" {
  source = "../../../../../../modules/lifecycle"

  group  = local.group
  subenv = local.subenv
  env    = local.env
  region = local.region

  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnet_ids

  ami_name      = local.lifecycle_ami_name
  instance_type = local.lifecycle_instance_type
  tags          = local.all_tags

  depends_on = [module.foundation]
}
