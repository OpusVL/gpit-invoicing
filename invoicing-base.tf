provider "aws" {
  region         = "eu-west-2"
}

#Application Load Balancer definition in default security group terminates SSL
resource "aws_lb" "gpit-invoicing-alb" {
  name               = "gpit-invoicing-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = var.alb_security_groups
  subnets            = var.gpit_invoicing_subnets

  enable_deletion_protection = false
}

#HTTP listener for ALB simply redirects to HTTPS
resource "aws_lb_listener" "gpit-invoicing-alb-http" {
  load_balancer_arn = aws_lb.gpit-invoicing-alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type            = "redirect"
    redirect {
      port          = "443"
      protocol      = "HTTPS"
      status_code   = "HTTP_301"
    }
  }
}

#HTTPS listener for ALB forwards all traffic to the target group of appservers
resource "aws_lb_listener" "gpit-invoicing-alb-https" {
  load_balancer_arn = aws_lb.gpit-invoicing-alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.alb_ssl_cert

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gpit-invoicing-appserver.arn
  }
}

#Target group sets the properties of how to communicate with the odoo instance
#and health check parameters (don't be overzealous or it will perpetually heal)
resource "aws_lb_target_group" "gpit-invoicing-appserver" {
  name      = "gpit-invoicing-appserver"
  port      = 8069
  protocol  = "HTTP"
  health_check {
    interval = 300
    path = "/web/login"
    port = "traffic-port"
    timeout = 30
    matcher = "200-299"
  }
  vpc_id    = var.gpit_invoicing_vpc
}

#File for copying config files and starting odoo, passing in the values for the config file filtering
data "template_file" "start_odoo" {
  template = <<EOF
    bash /home/gpitsupport/deploy/start ${module.db.this_db_instance_address} ${var.odoo_password} ${var.odoo_admin_pass} ${var.postgres_password} ${var.odoo_image_version} ${var.odoo_image}
  EOF
}

#Launch template describes the intial state of an odoo instance based on an AMI
#has the start_odoo template_file sent as user data.
resource "aws_launch_template" "gpit-invoicing-appserver-lt" {
  name                   = "gpit-invoicing-appserver-lt"
  image_id               = var.gpit_invoicing_ami
  instance_type          = var.app_server_instance_type
  vpc_security_group_ids = var.appserver_security_groups
  key_name               = "app-server"
  user_data              = base64encode(data.template_file.start_odoo.rendered)

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size = 12
    }
  }
}

#The autoscaling group will "self heal" the target group based on health check results
resource "aws_autoscaling_group" "gpit-invoicing-appservers" {
  name                      = "gpit-invoicing-appservers"
  availability_zones        = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
  desired_capacity          = 1
  min_size                  = 1
  max_size                  = 1
  health_check_grace_period = 600
  health_check_type         = "ELB"
  target_group_arns         = [aws_lb_target_group.gpit-invoicing-appserver.arn]  

  launch_template {
    id      = aws_launch_template.gpit-invoicing-appserver-lt.id
    version = "$Latest"
  }
}

#Module for creating the Postgres database based on an initial snapshot which has the odoo user created
module "db" {
  source = "./terraform-aws-rds"

  identifier = "gpit-invoicing-db"

  engine            = "postgres"
  engine_version    = "12.2"
  instance_class    = "db.m4.xlarge"
  allocated_storage = 20
  storage_encrypted = true

  publicly_accessible = false

  # kms_key_id        = "arm:aws:kms:<region>:<account id>:key/<kms key id>"
  name = "odoo"
  #Database user
  username = var.postgres_user
  #Database user password
  password = var.postgres_password
  port     = "5432"

  vpc_security_group_ids = var.rds_security_groups

  maintenance_window = "Mon:00:00-Mon:03:00"
  backup_window      = "03:00-06:00"

  # disable backups to create DB faster
  backup_retention_period = 5

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  # DB subnet group
  subnet_ids = var.gpit_invoicing_subnets

  # DB parameter group
  family = "postgres12"

  # DB option group
  major_engine_version = "12"

  # Snapshot name upon DB deletion
  final_snapshot_identifier = "odoo"

  # Database Deletion Protection
  deletion_protection = false

  snapshot_identifier = var.rds_snapshot_id
}