provider "aws" {
  region = "us-west-2"
}

data "aws_vpc" "vpc" {
  tags = {
    Name = "${var.group}-${var.subenv}-${var.env}"
  }
}

data "aws_subnets" "data" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc.id]
  }

  tags = {
    Name = "data-${var.group}-${var.subenv}-${var.env}"
  }
}

locals {
  ami_owner     = var.ami_owner
  aerospike_ami = var.ami_name
  vpc_id        = data.aws_vpc.vpc.id
  data_subnets  = tolist(data.aws_subnets.data.ids)
  dns_domain    = var.dns_tld

  customer    = var.subenv
  customer_id = "987654321000000" # TODO maybe customer should be the SFID?
  # iam_namespace = var.subenv
  env         = var.env
  ams_version = "v11.0.1"

  ams_version_safe = replace(local.ams_version, ".", "_")

  config_bucket = "ams-${var.group}-${var.subenv}-${var.env}-${var.region}"
}

data "aws_iam_policy" "foundation" {
  name = "${var.group}-${var.subenv}-${var.env}-${var.region}"
}

data "aws_iam_policy_document" "assume" {
  policy_id = "aerospike-${var.group}-${var.subenv}-${var.env}"

  statement {
    sid     = "EC2AssumeRole"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    effect = "Allow"
  }
}

resource "aws_iam_role" "aerospike" {
  name = "aerospike-${var.group}-${var.subenv}-${var.env}"

  assume_role_policy = data.aws_iam_policy_document.assume.json
  managed_policy_arns = [
    data.aws_iam_policy.foundation.arn,
  ]
}

resource "aws_iam_instance_profile" "aerospike" {
  name = "aerospike-${var.group}-${var.subenv}-${var.env}"
  role = aws_iam_role.aerospike.id
}

module "louie" {
  source = "git::https://github.com/aerospike-managed-cloud-services/ams-base-runbooks.git//terraform/modules/aws-aerospike-cluster?ref=v11.1.0"

  vpc_id     = local.vpc_id
  subnet_ids = local.data_subnets

  instance_type             = var.instance_type
  instance_count            = var.cluster_size
  iam_instance_profile_name = aws_iam_instance_profile.aerospike.id
  ami_owner                 = local.ami_owner
  ami_name                  = local.aerospike_ami
  explicit_private_ips      = true
  root_volume_size          = 10

  hostname_prefix = "louie"
  hostname_suffix = "-${local.dns_domain}"

  service_ports  = [3000]
  fabric_port    = 3001
  heartbeat_port = 3002

  client_cidrs = ["10.0.0.0/23"]

  vpc_cidrs = ["10.0.0.0/23", "52.38.152.249/32"]

  hostname_tag_name  = "AmsHostname"
  node_id_tag_name   = "AmsNodeId"
  rack_id_tag_name   = "AmsRackId"
  seed_node_tag_name = "AmsSeedNode"
  zone_id_tag_name   = "AmsZoneId"
  zone_name_tag_name = "AmsZoneName"
  instance_tags = {
    "Name" : "Aerospike Server (louie)",
    "AmsInventoryGroup" : "aerospike_instance"
    "group" : "${var.group}"
    "subenv" : "${var.subenv}"
    "env" : "${var.env}"
    "region" : "${var.region}"
  }

  all_tags = { "AmsCluster" : "louie" }
}

resource "aws_security_group_rule" "outbound" {
  security_group_id = module.louie.vpc_internal_sg_id
  type              = "egress"
  from_port         = "443"
  to_port           = "443"
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "ssh" {
  security_group_id = module.louie.vpc_internal_sg_id
  type              = "ingress"
  from_port         = "22"
  to_port           = "22"
  protocol          = "tcp"
  cidr_blocks       = ["10.0.0.0/16"]
}

resource "aws_security_group_rule" "healthcheck" {
  security_group_id = module.louie.vpc_internal_sg_id
  type              = "ingress"
  from_port         = "8080"
  to_port           = "8080"
  protocol          = "tcp"
  cidr_blocks       = ["10.0.0.0/16"]
}

locals {
  aerospike_conf = templatefile(
    "aerospike.conf.j2.tpl",
    {
      aerospike_ips = module.louie.private_ips
      default_ttl   = var.default_ttl
    }
  )
}

resource "aws_s3_bucket_object" "aerospike_configuration" {
  bucket  = local.config_bucket
  key     = "configuration/aerospike/aerospike.conf.j2"
  content = local.aerospike_conf
  etag    = md5(local.aerospike_conf)
}