module "label" {
  source     = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.22.1"
  enabled    = var.enabled
  namespace  = var.namespace
  name       = var.name
  stage      = var.stage
  delimiter  = var.delimiter
  attributes = var.attributes
  tags       = var.tags
}

locals {
  enabled = var.enabled == "true"
  prevent_db_destroy = var.prevent_db_destroy
}

resource "aws_db_instance" "default" {
  count                       = local.enabled ? 1 : 0
  identifier                  = module.label.id
  port                        = var.database_port
  instance_class              = var.instance_class
  storage_encrypted           = var.storage_encrypted
  vpc_security_group_ids      = aws_security_group.default.*.id
  db_subnet_group_name        = join("", aws_db_subnet_group.default.*.name)
  multi_az                    = var.multi_az
  storage_type                = var.storage_type
  iops                        = var.iops
  publicly_accessible         = var.publicly_accessible
  allow_major_version_upgrade = var.allow_major_version_upgrade
  auto_minor_version_upgrade  = var.auto_minor_version_upgrade
  apply_immediately           = var.apply_immediately
  maintenance_window          = var.maintenance_window
  skip_final_snapshot         = true
  backup_retention_period     = var.backup_retention_period
  backup_window               = var.backup_window
  tags                        = module.label.tags
  kms_key_id                  = var.kms_key_arn
  monitoring_interval         = var.monitoring_interval
  replicate_source_db         = var.replicate_source_db

  lifecycle {
    create_before_destroy = local.prevent_db_destroy
  }
}

resource "aws_db_subnet_group" "default" {
  count      = local.enabled && var.same_region == "false" ? 1 : 0
  name       = module.label.id
  subnet_ids = var.subnet_ids
  tags       = module.label.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "default" {
  count       = local.enabled ? 1 : 0
  name        = module.label.id
  description = "Allow inbound traffic from the security groups"
  vpc_id      = var.vpc_id

  tags = module.label.tags

  lifecycle {
    create_before_destroy = true
  }
}

locals {
  security_group_id = join("", aws_security_group.default.*.id)
}

resource "aws_security_group_rule" "allow_ingress" {
  count                    = local.enabled ? length(var.security_group_ids) : 0
  security_group_id        = local.security_group_id
  type                     = "ingress"
  from_port                = var.database_port
  to_port                  = var.database_port
  protocol                 = "tcp"
  source_security_group_id = var.security_group_ids[count.index]
}

resource "aws_security_group_rule" "allow_egress" {
  count             = local.enabled ? 1 : 0
  security_group_id = local.security_group_id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

module "dns_host_name" {
  source  = "git::https://github.com/cloudposse/terraform-aws-route53-cluster-hostname.git?ref=tags/0.10.0"
  enabled = local.enabled && length(var.dns_zone_id) > 0 ? "true" : "false"
  name    = var.host_name
  zone_id = var.dns_zone_id
  records = aws_db_instance.default.*.address
}

