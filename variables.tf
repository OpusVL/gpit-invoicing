variable "region" {
    description = "AWS region"
    default = "eu-west-2"
}

variable "app_server_instance_type" {
    description = "Instance type for Odoo app server"
    default = "t3.xlarge"
}

variable "postgres_user" {
    description = "Root database user"
}

variable "odoo_postgres_password" {
    description = "Odoo database user password"
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

#variable "gpit_invoicing_subnets" {
#    description = "All subnets used by invoicing solution"
#}

variable "alb_ssl_cert" {
    description = "ARN for SSL cert to be terminated on ALB"
}

#variable "gpit_invoicing_vpc" {
#    description = "VPC id for invoicing solution"
#}

variable "gpit_invoicing_ami" {
    description = "AMI ID of the app server for invoicing"
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
    default = 10800
}

variable "limit_time_real"  {
    description = "limit actual seconds per worker"
    default = 10800
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

variable "domain_name" {
    description = "Domain to create alias record for in Route 53"
}

variable global_enable_deletion_protection {
    description = "Must be turned off explicitly thorugh console if enabled before terraform can destroy "
}

variable docker_login {
    description = "username to log in to docker repo"
}

variable docker_login_password {
    description = "password to log in to docker repo"
}

variable availability_zones {
    description = "availablity zones available to the project"
    default = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
}

variable stage {
    description = "name of environment e.g. UAT, Live"
}

variable name {
    description = "name of the project"
}

variable namespace {
    description = "name of project"
}

variable public_subnet_cidrs {
    description = "cidrs for subnet that should be publicly accessible"
    default = ["10.0.0.0/20", "10.0.16.0/20", "10.0.32.0/20"]
}

variable private_subnet_cidrs {
    description = "cidrs of subnets that should not be publicly accessible"
    default = ["10.0.48.0/20", "10.0.64.0/20", "10.0.80.0/20"]
}

variable enabled {
    description = "whether bastion host is enabled or not"
    default = true
}

variable bastion_ami {
    description = "the AMI ID to use for the bastion server"
    default = "ami-0c216d3ab383cc403"
}

variable support_cidr_blocks {
    description = "CIDRs to allow SSH access to bastion host"
    default = ["0.0.0.0/0"]
}

variable kms_key_id {
    description = "ARN of key from KMS to use for encyptions"
}

variable db_size_in_gb {
    description = "size of database in gigabytes"
}

variable s3_bucket_name {
    description = "name of s3 bucket to store odoo files"
}

variable app_server_key_name {
	description = "key name for the app server"
}

variable bastion_host_key_name {
	description = "key name for the bastion host"
}