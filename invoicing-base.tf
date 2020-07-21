provider "aws" {
  region         = "eu-west-2"
}

resource "aws_route53_record" "www" {
  zone_id = var.hosted_zone_id
  name    = "gpiti.uk"
  type    = "A"

  alias {
    name                   = aws_lb.gpit-invoicing-alb.dns_name
    zone_id                = aws_lb.gpit-invoicing-alb.zone_id
    evaluate_target_health = false
  }
}

resource "aws_security_group" "invoicing-alb-rules" {
  name        = "invoicing-alb-rules"
  description = "Allow traffic"
  vpc_id      = var.gpit_invoicing_vpc

  ingress {
    description = "HTTP  TCP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    description = "HTTPS  TCP"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ALL  TCP  SELF"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "invoicing-app-server-rules" {
  name        = "invoicing-app-server-rules"
  description = "Allow traffic"
  vpc_id      = var.gpit_invoicing_vpc

  ingress {
    description = "SSH  TCP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["80.3.136.155/32", "79.76.204.13/32"]
  }
  
  ingress {
    description = "ODOO  HTTP"
    from_port   = 8069
    to_port     = 8072
    protocol    = "tcp"
    security_groups = [aws_security_group.invoicing-alb-rules.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "invoicing-rds-rules" {
  name        = "invoicing-rds-rules"
  description = "Allow traffic"
  vpc_id      = var.gpit_invoicing_vpc

  ingress {
    description = "PostgreSQL  TCP"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["80.3.136.155/32", "79.76.204.13/32"]
  }
  
  ingress {
    description = "PostgreSQL  TCP"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [aws_security_group.invoicing-app-server-rules.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Application Load Balancer definition in default security group terminates SSL
resource "aws_lb" "gpit-invoicing-alb" {
  name               = "gpit-invoicing-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.invoicing-alb-rules.id] #var.alb_security_groups
  subnets            = var.gpit_invoicing_subnets
  idle_timeout       = 3600

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

#HTTPS listener for ALB forwards normal none long polling traffic to the target group of appservers
resource "aws_lb_listener" "gpit-invoicing-alb-https" {
  load_balancer_arn = aws_lb.gpit-invoicing-alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01" #"ELBSecurityPolicy-2016-08"
  certificate_arn   = var.alb_ssl_cert

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gpit-invoicing-appserver.arn
  }
}

resource "aws_lb_listener_rule" "long-polling" {
  listener_arn = aws_lb_listener.gpit-invoicing-alb-https.arn
  priority     = 2

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gpit-appserver-longpolling.arn
  }

  condition {
    path_pattern {
      values = ["/longpolling/poll*"]
    }
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
    matcher = "200-399"
  }
  vpc_id    = var.gpit_invoicing_vpc
}

#Target group sets the properties of how to communicate with the odoo instance
#for long polling
resource "aws_lb_target_group" "gpit-appserver-longpolling" {
  name      = "gpit-appserver-longpolling"
  port      = 8072
  protocol  = "HTTP"
  health_check {
    interval = 300
    path = "/web/login"
    port = 8069
    timeout = 30
    matcher = "200-399"
  }
  vpc_id    = var.gpit_invoicing_vpc
}

#File for copying config files and starting odoo, passing in the values for the config file filtering
data "template_file" "start_odoo" {
  template = <<EOF
    Content-Type: multipart/mixed; boundary="//"
    MIME-Version: 1.0

    --//
    Content-Type: text/cloud-config; charset="us-ascii"
    MIME-Version: 1.0
    Content-Transfer-Encoding: 7bit
    Content-Disposition: attachment; filename="cloud-config.txt"

    #cloud-config
    cloud_final_modules:
    - [scripts-user, always]

    --//
    Content-Type: text/x-shellscript; charset="us-ascii"
    MIME-Version: 1.0
    Content-Transfer-Encoding: 7bit
    Content-Disposition: attachment; filename="userdata.txt"

    #!/bin/bash
    /bin/bash /home/gpitsupport/deploy/start ${module.db.this_db_instance_address} ${var.rds_password} ${var.odoo_admin_pass} ${var.postgres_password} ${var.odoo_image_version} ${var.odoo_image} ${var.limit_time_cpu} ${var.limit_time_real} ${var.smtp_password} ${var.odoo_cron_db} > /home/gpitsupport/deploy.log 2>&1
    --//
  EOF
}

#Launch template describes the intial state of an odoo instance based on an AMI
#has the start_odoo template_file sent as user data.
resource "aws_launch_template" "gpit-invoicing-appserver-lt" {
  name                   = "gpit-invoicing-appserver-lt"
  image_id               = var.gpit_invoicing_ami
  instance_type          = var.app_server_instance_type
  vpc_security_group_ids = [aws_security_group.invoicing-app-server-rules.id] #var.appserver_security_groups
  key_name               = "app-server"
  user_data              = base64encode(data.template_file.start_odoo.rendered)

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size = 12
    }
  }

  iam_instance_profile {
    arn = var.iam_profile
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
  allocated_storage = 50
  storage_encrypted = true
  multi_az = true

  publicly_accessible = true

  # kms_key_id        = "arm:aws:kms:<region>:<account id>:key/<kms key id>"
  name = "odoo"
  #Database user
  username = var.postgres_user
  #Database user password
  password = var.postgres_password
  port     = "5432"

  vpc_security_group_ids = [aws_security_group.invoicing-rds-rules.id] #var.rds_security_groups

  maintenance_window = "Mon:00:00-Mon:03:00"
  backup_window      = "03:00-06:00"

  # disable backups to create DB faster
  backup_retention_period = 7

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