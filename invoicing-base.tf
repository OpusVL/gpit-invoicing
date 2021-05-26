# Install AWS Vault  https://github.com/99designs/aws-vault and create a profile
# run with: aws-vault exec [profile name] -- terraform plan
# As we use AWS Landing Zone and have different accounts per environment
# it may make sense to name your profile after the environment name e.g. invoicing-uat

# Configures a backend in AWS to store the state of the terraform managed infrastructure
terraform {  
    backend "s3" {
        bucket  = "invoicing-terraform-backend-store-uat2"
        encrypt = true
        key    = "terraform.tfstate"    
        region = "eu-west-2"
    }
}

# We are deploying to AWS
provider "aws" {
  region         = var.region
}

# Create an Alias record to route traffic to the Application Load Balancer
resource "aws_route53_record" "www" {
  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.gpit-invoicing-alb.dns_name
    zone_id                = aws_lb.gpit-invoicing-alb.zone_id
    evaluate_target_health = false
  }
}

resource "aws_vpc" "invoicing-vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_vpc_dhcp_options" "invoicing-dhcp" {
  domain_name         = "${var.region}.compute.internal"
  domain_name_servers = ["AmazonProvidedDNS"]
  ntp_servers         = []
}

resource "aws_vpc_dhcp_options_association" "vpc-dhcp-association" {
  vpc_id          = aws_vpc.invoicing-vpc.id
  dhcp_options_id = aws_vpc_dhcp_options.invoicing-dhcp.id
}

resource "aws_subnet" "invoicing-public-subnets" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.invoicing-vpc.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = element(var.availability_zones, count.index)  
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "invoicing-public-gw" {
  vpc_id = aws_vpc.invoicing-vpc.id
}

resource "aws_route_table" "invoicing-public-rt" {
  vpc_id = aws_vpc.invoicing-vpc.id
}

resource "aws_route_table_association" "invoicing-public-rta" {
  count          = length(aws_subnet.invoicing-public-subnets.*.id)
  subnet_id      = element(aws_subnet.invoicing-public-subnets.*.id, count.index)
  route_table_id = aws_route_table.invoicing-public-rt.id
}

resource "aws_route" "invoicing-public-route" {
  route_table_id         = aws_route_table.invoicing-public-rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.invoicing-public-gw.id
  depends_on             = [aws_route_table.invoicing-public-rt]
}

resource "aws_subnet" "invoicing-private-subnets" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.invoicing-vpc.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = element(var.availability_zones, count.index)
  map_public_ip_on_launch = false
}

# AWS Managed NAT Gateways
resource "aws_eip" "invoicing-nat-eip" {
  count = length(var.public_subnet_cidrs)
  vpc   = true
}

data "aws_subnet" "invoicing-public-nat" {
  count = length(aws_subnet.invoicing-public-subnets.*.id)
  id    = element(aws_subnet.invoicing-public-subnets.*.id, count.index)
}

resource "aws_nat_gateway" "invoicing-nat-gw" {
  count         = length(var.public_subnet_cidrs)
  subnet_id     = element(data.aws_subnet.invoicing-public-nat.*.id, count.index)
  allocation_id = element(aws_eip.invoicing-nat-eip.*.id, count.index)
}

# Route tables. One per NAT gateway.
resource "aws_route_table" "invoicing-private-rt" {
  count  = length(var.public_subnet_cidrs)
  vpc_id = aws_vpc.invoicing-vpc.id
}

resource "aws_route" "invoicing-private-route" {
  count                     = length(var.public_subnet_cidrs)
  route_table_id            = aws_route_table.invoicing-private-rt[count.index].id
  destination_cidr_block    = "0.0.0.0/0"
  nat_gateway_id            = element(aws_nat_gateway.invoicing-nat-gw.*.id, count.index)
}

resource "aws_route_table_association" "invoicing-private-rta" {
  count          = length(aws_subnet.invoicing-private-subnets.*.id)
  subnet_id      = element(aws_subnet.invoicing-private-subnets.*.id, count.index)
  route_table_id = element(aws_route_table.invoicing-private-rt.*.id, count.index)
}

# Create a security group for the Bastion Server
# that allows SSH from anywhere
resource "aws_security_group" "invoicing-bastion-rules" {
  name        = "invoicing-bastion-rules"
  description = "Allow traffic"
  vpc_id      = aws_vpc.invoicing-vpc.id

  ingress {
    description = "SSH  TCP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.support_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create a security group for the Application Load Balancer
# that allows HTTP and HTTPS communication from anywhere
resource "aws_security_group" "invoicing-alb-rules" {
  name        = "invoicing-alb-rules"
  description = "Allow traffic"
  vpc_id      = aws_vpc.invoicing-vpc.id

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

# Create a security group for the app server
# that allows communication from the ALB on ports 8069 and 8070
resource "aws_security_group" "invoicing-app-server-rules" {
  name        = "invoicing-app-server-rules"
  description = "Allow traffic"
  vpc_id      = aws_vpc.invoicing-vpc.id

  ingress {
    description = "SSH  TCP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.invoicing-bastion-rules.id]
  }
  
  ingress {
    description = "ODOO  HTTP"
    from_port   = 8069
    to_port     = 8070
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

# Create a security group for the RDS server
# that allows communication from the app server on port 5432
resource "aws_security_group" "invoicing-rds-rules" {
  name        = "invoicing-rds-rules"
  description = "Allow traffic"
  vpc_id      = aws_vpc.invoicing-vpc.id

  # This ingress block needs to be removed when the bastion host is set up
  ingress {
    description = "PostgreSQL  TCP"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [aws_security_group.invoicing-bastion-rules.id]
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

resource "aws_instance" "invoicing-bastion-server" {
  count         = var.enabled ? 1 : 0
  ami           = var.bastion_ami
  instance_type = "t2.micro"

  #user_data = data.template_file.user_data.rendered

  vpc_security_group_ids = [aws_security_group.invoicing-bastion-rules.id]

  #iam_instance_profile        = var.iam_profile
  associate_public_ip_address = true

  key_name = var.bastion_host_key_name

  subnet_id = aws_subnet.invoicing-public-subnets.*.id[0]
}

# Application Load Balancer definition with security group definition
resource "aws_lb" "gpit-invoicing-alb" {
  name               = "gpit-invoicing-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.invoicing-alb-rules.id] 
  subnets            = aws_subnet.invoicing-public-subnets.*.id
  idle_timeout       = 3600

  enable_deletion_protection = var.global_enable_deletion_protection
}

# HTTP listener for ALB simply redirects to HTTPS
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

# HTTPS listener for ALB forwards normal none long polling traffic to the target group of appservers
resource "aws_lb_listener" "gpit-invoicing-alb-https" {
  load_balancer_arn = aws_lb.gpit-invoicing-alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01" 
  certificate_arn   = var.alb_ssl_cert

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gpit-invoicing-appserver.arn
  }
}

# Listener rule that picks up /longpolling* and forwards to
# the correct port of the app server
resource "aws_lb_listener_rule" "long-polling" {
  listener_arn = aws_lb_listener.gpit-invoicing-alb-https.arn
  priority     = 2

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gpit-appserver-longpolling.arn
  }

  condition {
    path_pattern {
      values = ["/longpolling*"]
    }
  }
}

# Target group sets the properties of how to communicate with the odoo instance
# and health check parameters (don't be overzealous with interval or it will perpetually heal)
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
  vpc_id    = aws_vpc.invoicing-vpc.id
}

# Target group sets the properties of how to communicate with the odoo instance
# for long polling
resource "aws_lb_target_group" "gpit-appserver-longpolling" {
  name      = "gpit-appserver-longpolling"
  port      = 8070
  protocol  = "HTTP"
  health_check {
    interval = 300
    path = "/web/login"
    port = "traffic-port"
    timeout = 30
    matcher = "200-399"
  }
  vpc_id    = aws_vpc.invoicing-vpc.id
}

# File for copying config files and starting odoo, passing in the values for the config file filtering
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
mkdir -p /root/deploy
aws s3 sync s3://"${var.s3_bucket_name}" /srv/container-volumes --delete
watchman watch-project /srv/container-volumes
watchman -j <<-EOT
["trigger", "/srv/container-volumes", {
  "name": "containervolumes",
  "expression": ["match", "**/*", "wholename"],
  "command": ["aws", "s3", "sync", "/srv/container-volumes", "s3://${var.s3_bucket_name}", "--delete"]
}]
EOT
cat << TAC > /root/deploy/start
docker login -u="${var.docker_login}" -p="${var.docker_login_password}" ${var.odoo_image}
mkdir -p /srv/container-deployment/syslog-ng
mkdir -p /srv/container-deployment/invoicing/odoo/etc
mkdir -p /srv/container-volumes/odoo
mkdir -p /srv/logs
gpasswd -a ubuntu docker
apt -y install postgresql-client zsh curl
curl -o /srv/container-deployment/invoicing/odoo/etc/odoo.conf.tpl https://raw.githubusercontent.com/nhsconnect/gpit-invoicing/master/deploy/odoo.conf.tpl
curl -o /srv/container-deployment/invoicing/docker-compose.yml.tpl https://raw.githubusercontent.com/nhsconnect/gpit-invoicing/master/deploy/docker-compose.yml.tpl
curl -o /srv/container-deployment/invoicing/.env https://raw.githubusercontent.com/nhsconnect/gpit-invoicing/master/deploy/.env
curl -o /srv/container-deployment/invoicing/odoo_permissions.sh.tpl https://raw.githubusercontent.com/nhsconnect/gpit-invoicing/master/deploy/odoo_permissions.sh.tpl
curl -o /srv/container-deployment/invoicing/template.sh https://raw.githubusercontent.com/nhsconnect/gpit-invoicing/master/deploy/template.sh
curl -o /etc/ssl/openssl.cnf https://raw.githubusercontent.com/nhsconnect/gpit-invoicing/master/deploy/openssl.cnf
chmod +x /srv/container-deployment/invoicing/*.sh
cd /srv/container-deployment/invoicing/syslog-ng
docker-compose pull
docker-compose up -d
cd /srv/container-deployment/invoicing
echo "ADMIN_PASS=${var.odoo_admin_pass}" > .env
echo "CONTAINER_VOLUME=/srv/container-volumes" >> .env
echo "LIMIT_TIME_CPU=${var.limit_time_cpu}" >> .env
echo "LIMIT_TIME_REAL=${var.limit_time_real}" >> .env
echo "ODOO_CRON_DB=${var.odoo_cron_db}" >> .env
echo "ODOO_IMAGE=${var.odoo_image}" >> .env
echo "ODOO_IMAGE_VERSION=${var.odoo_image_version}" >> .env
echo "ODOO_POSTGRES_PASSWORD=${var.odoo_postgres_password}" >> .env
echo "ODOO_POSTGRES_USER=odoo" >> .env
echo "POSTGRES_PASSWORD=${var.postgres_password}" >> .env
echo "RDS_PASS=${var.rds_password}" >> .env
echo "SMTP_PASSWORD=${var.smtp_password}" >> .env
chmod +x template
./template.sh
docker-compose pull
docker-compose up -d && ./odoo_permissions.sh
TAC
chmod +x /root/deploy/start
/bin/bash /root/deploy/start
--//
EOF
}

# Launch template describes the intial state of an odoo instance based on an AMI
# has the start_odoo template_file sent as user data to run at start up.
# Run using an IAM profile (that needs creating) to allow for CloudWatch logging.
resource "aws_launch_template" "gpit-invoicing-appserver-lt" {
  name                   = "gpit-invoicing-appserver-lt"
  image_id               = var.gpit_invoicing_ami
  instance_type          = var.app_server_instance_type
  vpc_security_group_ids = [aws_security_group.invoicing-app-server-rules.id]
  key_name               = var.app_server_key_name
  user_data              = base64encode(data.template_file.start_odoo.rendered)

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = 30
      encrypted = true
      delete_on_termination = true
    }
  }

  iam_instance_profile {
    arn = var.iam_profile
  }
}

# The autoscaling group will "self heal" the target group based on health check results
# the target group being the standard 443 target and the lonpolling target, both pointing
# at the same instance but on different ports
resource "aws_autoscaling_group" "gpit-invoicing-appservers" {
  name                      = "gpit-invoicing-appservers"
  vpc_zone_identifier       = aws_subnet.invoicing-private-subnets.*.id
  desired_capacity          = 1
  min_size                  = 1
  max_size                  = 1
  health_check_grace_period = 600
  health_check_type         = "ELB"
  target_group_arns         = [aws_lb_target_group.gpit-invoicing-appserver.arn, aws_lb_target_group.gpit-appserver-longpolling.arn]  

  launch_template {
    id      = aws_launch_template.gpit-invoicing-appserver-lt.id
    version = "$Latest"
  }
}

# Module for creating the Postgres database based on an initial snapshot which has the odoo user created
module "db" {
  source = "./terraform-aws-rds"

  identifier = "gpit-invoicing-db"

  engine            = "postgres"
  engine_version    = "12.5"
  instance_class    = "db.m4.xlarge"
  allocated_storage = var.db_size_in_gb
  max_allocated_storage = 100
  storage_encrypted = true
  multi_az = true
  #kms_key_id = var.kms_key_id

  publicly_accessible = var.global_enable_deletion_protection ? false : true

  #name = "odoo"
  #Database user
  username = var.postgres_user
  #Database user password
  password = var.postgres_password
  port     = "5432"

  vpc_security_group_ids = [aws_security_group.invoicing-rds-rules.id]
  option_group_name = "default:postgres-12"
  create_db_option_group = false

  maintenance_window = "Mon:00:00-Mon:03:00"
  backup_window      = "03:00-06:00"

  # disable backups to create DB faster
  backup_retention_period = 35

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  # DB subnet group
  subnet_ids = aws_subnet.invoicing-private-subnets.*.id

  # DB parameter group
  family = "postgres12"

  # DB option group
  major_engine_version = "12"

  # Skip snapshot upon DB deletion
  skip_final_snapshot = true

  # Database Deletion Protection
  deletion_protection = var.global_enable_deletion_protection

  snapshot_identifier = var.rds_snapshot_id
}