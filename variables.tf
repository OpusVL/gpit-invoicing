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

variable "odoo_password" {
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

variable "gpit_invoicing_elastic_ips" {
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

variable "limit_memory_hard" {
    description = "hard limit for worker memory"
}
variable "limit_memory_soft"  {
    description = "soft limit for worker memory"
}
variable "limit_time_cpu"  {
    description = "limit cpu seconds per worker"
}
variable "limit_time_real"  {
    description = "limit actual seconds per worker"
}
variable "max_cron_threads" {
    description = "max number of cron running threads. Calculation: https://gist.github.com/Guidoom/d5db0a76ce669b139271a528a8a2a27f"
}
variable "smtp_password" {
    description = "password for smtp server"
}
variable "smtp_port" {
    description = "smtp port"
}
variable "smtp_server" {
    description = "smtp server address"
}
variable "num_workers" {
    description = "max number of worker threads. Calculation: https://gist.github.com/Guidoom/d5db0a76ce669b139271a528a8a2a27f"
}