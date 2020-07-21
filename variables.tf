variable "aws_access_key" {
    description = "AWS access key"
}

variable "aws_secret_key" {
    description = "AWS secret key"
}

variable "app_server_instance_type" {
    description = "Instance type for Odoo app server"
}

variable "postgres_user" {
    description = "Root database user"
}

variable "postgres_password" {
    description = "Root database user password"
}

variable "rds_password" {
    description = "Root database user password"
}

variable "rds_snapshot_id" {
    description = "Snapshot to start the RDS database from"
}

variable "alb_security_groups" {
    description = "Allow all security group for ALB"
}

variable "gpit_invoicing_subnets" {
    description = "All subnets used by invoicing solution"
}

variable "alb_ssl_cert" {
    description = "ARN for SSL cert to be terminated on ALB"
}

variable "gpit_invoicing_vpc" {
    description = "VPC id for invoicing solution"
}

variable "gpit_invoicing_ami" {
    description = "AMI ID of the app server for invoicing"
}

variable "gpit_invoicing_ami_snapshot" {
    description = "ID of EBS Snapshot for AMI Root filesystem"
}

variable "appserver_security_groups" {
    description = "Security group only allowing 22 8069 - 8072 plus access from default"
}

variable "rds_security_groups" {
    description = "Security group only allowing 22 5432 plus access from default and appserver"
}

variable "odoo_image" {
    description = "Odoo image to pull"
}

variable "odoo_image_version" {
    description = "Version of the Odoo image to pull"
}

variable "odoo_admin_pass" {
    description = "Odoo master password"
}

variable "limit_time_cpu"  {
    description = "limit cpu seconds per worker"
}

variable "limit_time_real"  {
    description = "limit actual seconds per worker"
}

variable "smtp_password" {
    description = "password for smtp server"
}

variable "hosted_zone_id" {
    description = "ID of hosted zone in route 53 to add alias record to"
}

variable "odoo_cron_db" {
    description = "db to run cron on"
}

variable "iam_profile" {
    description = "arn of the iam profile for this instance for cloudwatch "
}