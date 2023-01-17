data "aws_caller_identity" "caller" {}

data "aws_s3_bucket" "foundation" {
  bucket = "ams-${var.group}-${var.subenv}-${var.env}-${var.region}"
}

data "aws_security_group" "foundation" {
  vpc_id = var.vpc_id
  name   = "${var.group}-${var.subenv}-${var.env}"
}

data "aws_ami" "lifecycle" {
  most_recent = true
  owners      = [var.ami_owner]

  filter {
    name   = "name"
    values = [var.ami_name]
  }
}

data "aws_iam_policy" "foundation" {
  name = "${var.group}-${var.subenv}-${var.env}-${var.region}"
}

data "aws_iam_policy_document" "assume" {
  policy_id = "assume-${var.group}-${var.subenv}-${var.env}"

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

data "aws_iam_policy_document" "lifecycle" {
  policy_id = "lifecycle-${var.group}-${var.subenv}-${var.env}"

  statement {
    // TODO we'll want to narrow this down to whatever we need for TF to run against a cluster
    actions   = ["*"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "lifecycle" {
  name        = "lifecycle-${var.group}-${var.subenv}-${var.env}-${var.region}"
  description = "lifecycle policy"
  policy      = data.aws_iam_policy_document.lifecycle.json
}

resource "aws_iam_role" "lifecycle" {
  name = "lifecycle-${var.group}-${var.subenv}-${var.env}"

  assume_role_policy = data.aws_iam_policy_document.assume.json
  managed_policy_arns = [
    data.aws_iam_policy.foundation.arn,
    aws_iam_policy.lifecycle.arn
  ]

  tags = var.tags
}

resource "aws_security_group" "lifecycle" {
  name   = "lifecycle-${var.group}-${var.subenv}-${var.env}"
  vpc_id = var.vpc_id
}

resource "aws_security_group_rule" "ssh" {
  security_group_id = aws_security_group.lifecycle.id
  type              = "ingress"
  from_port         = "22"
  to_port           = "22"
  protocol          = "tcp"
  cidr_blocks       = ["52.38.152.249/32"]
}

resource "aws_security_group_rule" "http_egress" {
  security_group_id = aws_security_group.lifecycle.id
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "https_egress" {
  security_group_id = aws_security_group.lifecycle.id
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "healthcheck" {
  security_group_id = aws_security_group.lifecycle.id
  type              = "egress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}


resource "aws_security_group_rule" "aerospike" {
  security_group_id = aws_security_group.lifecycle.id
  type              = "egress"
  from_port         = 3000
  to_port           = 3000
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_iam_instance_profile" "lifecycle" {
  name = "lifecycle-${var.group}-${var.subenv}-${var.env}"
  role = aws_iam_role.lifecycle.id
}

resource "aws_launch_template" "lifecycle" {
  name          = "lifecycle-${var.group}-${var.subenv}-${var.env}"
  description   = "lifecycle"
  image_id      = data.aws_ami.lifecycle.id
  instance_type = var.instance_type

  iam_instance_profile {
    arn = aws_iam_instance_profile.lifecycle.arn
  }

  vpc_security_group_ids = [
    aws_security_group.lifecycle.id,
    data.aws_security_group.foundation.id,
  ]
}

resource "aws_autoscaling_group" "lifecycle" {
  name                = "lifecycle-${var.group}-${var.subenv}-${var.env}"
  max_size            = 1
  min_size            = 1
  vpc_zone_identifier = var.private_subnets
  health_check_type   = "EC2"

  launch_template {
    id      = aws_launch_template.lifecycle.id
    version = "$Latest"
  }

  dynamic "tag" {
    for_each = merge(
      var.tags,
      {
        "Name" : "lifecycle-${var.group}-${var.subenv}-${var.env}",
        "LaunchTemplateVersion" : aws_launch_template.lifecycle.latest_version,
      }
    )
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      instance_warmup        = 0
      min_healthy_percentage = 0
    }
    triggers = ["tag"]
  }
}
