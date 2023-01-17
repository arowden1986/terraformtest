data "aws_caller_identity" "caller" {}


data "aws_subnet_ids" "private" {
  vpc_id = var.vpc_id

  tags = {
    Name = "private-${var.group}-${var.subenv}-${var.env}"
  }
}

data "aws_subnet_ids" "public" {
  vpc_id = var.vpc_id

  tags = {
    Name = "public-${var.group}-${var.subenv}-${var.env}"
  }
}

data "aws_subnet_ids" "data" {
  vpc_id = var.vpc_id

  tags = {
    Name = "data-${var.group}-${var.subenv}-${var.env}"
  }
}

data "aws_ami" "proxy" {
  most_recent = true
  owners      = [var.ami_owner]

  filter {
    name   = "name"
    values = [var.ami_name]
  }
}

# --- ASG -------------------------------------------------------------

resource "aws_security_group" "proxy" {
  name   = "proxy-${var.group}-${var.subenv}-${var.env}"
  vpc_id = var.vpc_id
}

resource "aws_security_group_rule" "ssh" {
  security_group_id = aws_security_group.proxy.id
  type              = "ingress"
  from_port         = "22"
  to_port           = "22"
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "http" {
  security_group_id = aws_security_group.proxy.id
  type              = "ingress"
  from_port         = "4000"
  to_port           = "4000"
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "http_egress" {
  security_group_id = aws_security_group.proxy.id
  type              = "egress"
  from_port         = 4000
  to_port           = 4000
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "https_egress" {
  security_group_id = aws_security_group.proxy.id
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "aerospike" {
  security_group_id = aws_security_group.proxy.id
  type              = "egress"
  from_port         = 3000
  to_port           = 3000
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_launch_template" "proxy" {
  name          = "proxy-${var.group}-${var.subenv}-${var.env}"
  description   = "proxy"
  image_id      = data.aws_ami.proxy.id
  instance_type = var.instance_type

  # iam_instance_profile {
  #   arn = aws_iam_instance_profile.proxy.arn
  # }

  vpc_security_group_ids = [
    aws_security_group.proxy.id,
  ]
}

resource "aws_lb_target_group" "nlb" {
  name        = "amspush-nlb-tg-${var.env}"
  port        = 443
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "alb"
}

resource "aws_lb_target_group_attachment" "tg_attachment" {
  target_group_arn = aws_lb_target_group.nlb.arn
  target_id        = aws_lb.amspush.arn
  port             = 443
}

resource "aws_lb_target_group" "pushgw" {
  name                 = "amspush-lb-tg-${var.env}"
  port                 = 4000
  protocol             = "HTTP"
  protocol_version     = "GRPC"
  vpc_id               = var.vpc_id
  deregistration_delay = "30"

  # health_check {
  #   path                = "/"
  #   port                = "traffic-port"
  #   interval            = 30
  #   timeout             = 2
  #   healthy_threshold   = 3
  #   unhealthy_threshold = 3
  #   matcher             = "200"
  # }

  tags = var.tags
}

resource "aws_autoscaling_group" "proxy" {
  name                = "proxy-${var.group}-${var.subenv}-${var.env}"
  max_size            = var.instance_count
  min_size            = var.instance_count
  vpc_zone_identifier = data.aws_subnet_ids.private.ids
  target_group_arns   = [aws_lb_target_group.pushgw.id]
  health_check_type   = "EC2"

  launch_template {
    id      = aws_launch_template.proxy.id
    version = "$Latest"
  }

  dynamic "tag" {
    for_each = merge(
      var.tags,
      {
        "Name" : "${var.group}-${var.subenv}-${var.env}",
        "LaunchTemplateVersion" : aws_launch_template.proxy.latest_version,
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

# --- Certificate -------------------------------------------------------------

data "aws_route53_zone" "public" {
  name = "${var.dns_tld}."
}

resource "aws_acm_certificate" "ams_cert" {
  domain_name               = "${var.env}.ams.${var.dns_tld}"
  subject_alternative_names = ["*.${var.env}.ams.${var.dns_tld}"]
  validation_method         = "DNS"

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "ams_cert" {
  certificate_arn         = aws_acm_certificate.ams_cert.arn
  validation_record_fqdns = [aws_route53_record.ams_cert.fqdn]
}

resource "aws_route53_record" "ams_cert" {
  zone_id         = data.aws_route53_zone.public.zone_id
  allow_overwrite = true #https://github.com/terraform-providers/terraform-provider-aws/issues/7918
  name            = tolist(aws_acm_certificate.ams_cert.domain_validation_options)[0].resource_record_name
  type            = tolist(aws_acm_certificate.ams_cert.domain_validation_options)[0].resource_record_type
  records         = [tolist(aws_acm_certificate.ams_cert.domain_validation_options)[0].resource_record_value]
  ttl             = 60
}


# --- Balancer -------------------------------------------------------------


resource "aws_lb" "nlb" {
  name               = "nlb-${var.env}"
  internal           = false
  load_balancer_type = "network"
  subnets            = data.aws_subnet_ids.public.ids

  tags = var.tags
}

resource "aws_lb_listener" "nlb" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = "443"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb.arn
  }
}

# data "aws_s3_bucket" "logs" {
#   bucket = var.logging_bucket
# }

resource "aws_lb" "amspush" {
  name               = "proxy-lb-${var.env}"
  internal           = false
  load_balancer_type = "application"
  subnets            = data.aws_subnet_ids.public.ids
  security_groups    = [aws_security_group.amspush_lb.id]

  access_logs {
    // TODO data call and accept this as a var
    bucket  = var.logging_bucket
    enabled = true
  }

  tags = var.tags
}

resource "aws_alb_listener" "amspush" {
  load_balancer_arn = aws_lb.amspush.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-Ext-2018-06"
  certificate_arn   = aws_acm_certificate.ams_cert.arn

  dynamic "default_action" {
    for_each = var.create_proxy ? [] : [1]

    content {
      type = "fixed-response"

      fixed_response {
        content_type = "text/plain"
        message_body = "OK"
        status_code  = "200"
      }
    }
  }

  dynamic "default_action" {
    for_each = var.create_proxy ? [1] : []

    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.pushgw.arn
    }
  }

  depends_on = [aws_acm_certificate.ams_cert]
}

resource "random_id" "amspush_lb_sg_bytes" {
  byte_length = 2
}

resource "aws_security_group" "amspush_lb" {
  name        = "${var.group}_${var.env}_${var.subenv}"
  description = "Push Proxy LB"
  vpc_id      = var.vpc_id

  tags = var.tags

  # https://github.com/terraform-providers/terraform-provider-aws/issues/265
  lifecycle { create_before_destroy = true }
}

resource "aws_security_group_rule" "amspush_lb_allow_https_in" {
  security_group_id = aws_security_group.amspush_lb.id
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  # cidr_blocks       = ["52.38.152.249/32"]
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "amspush_lb_allow_http_out" {
  security_group_id = aws_security_group.amspush_lb.id
  type              = "egress"
  from_port         = 4000
  to_port           = 4000
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}
