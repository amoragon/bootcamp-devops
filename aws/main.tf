terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.3.0"
    }
  }
}

provider "aws" {
  region     = "eu-west-1"
  secret_key = "..."
  access_key = "..."
}

#######
# VPC #
#######

resource "aws_vpc" "rtb_vpc" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"

  tags = {
    Name = "rtb_vpc"
  }

}

##########################################
# Public subnet a with route to internet #
##########################################

resource "aws_subnet" "rtb_public_subnet_a" {
  vpc_id            = aws_vpc.rtb_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-west-1a"
  tags = {
    Name = "rtb_public_subnet_a"
  }
}

resource "aws_route_table" "rtb_rt_public_subnet_a" {
  vpc_id = aws_vpc.rtb_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.rtb_igw.id
  }
  tags = {
    Name = "rtb_rt_public_subnet_a"
  }
}

resource "aws_route_table_association" "rtb_rt_public_subnet_a" {
  subnet_id      = aws_subnet.rtb_public_subnet_a.id
  route_table_id = aws_route_table.rtb_rt_public_subnet_a.id
}

##########################################
# Public subnet b with route to internet #
##########################################

resource "aws_subnet" "rtb_public_subnet_b" {
  vpc_id            = aws_vpc.rtb_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-west-1b"
  tags = {
    Name = "rtb_public_subnet_b"
  }
}

resource "aws_route_table" "rtb_rt_public_subnet_b" {
  vpc_id = aws_vpc.rtb_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.rtb_igw.id
  }
  tags = {
    Name = "rtb_rt_public_subnet_b"
  }
}

resource "aws_route_table_association" "rtb_rt_public_subnet_b" {
  subnet_id      = aws_subnet.rtb_public_subnet_b.id
  route_table_id = aws_route_table.rtb_rt_public_subnet_b.id
}

###################
# Private subnets #
###################

resource "aws_subnet" "rtb_private_subnet_a" {
  vpc_id            = aws_vpc.rtb_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "eu-west-1a"
  tags = {
    Name = "rtb_private_subnet_a"
  }
}

resource "aws_subnet" "rtb_private_subnet_b" {
  vpc_id            = aws_vpc.rtb_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "eu-west-1b"
  tags = {
    Name = "rtb_private_subnet_b"
  }
}

####################
# Internet Gateway #
####################

resource "aws_internet_gateway" "rtb_igw" {
  vpc_id = aws_vpc.rtb_vpc.id
  tags = {
    Name = "rtb_igw"
  }
}

#################
# Load Balancer #
#################

resource "aws_lb" "rtb_lb" {
  name            = "rtb-lb"
  internal        = false
  security_groups = [aws_security_group.rtb_lb_sg.id]
  subnets         = [aws_subnet.rtb_public_subnet_a.id, aws_subnet.rtb_public_subnet_b.id]
}

resource "aws_lb_listener" "rtb_lb_listener" {
  load_balancer_arn = aws_lb.rtb_lb.arn
  protocol          = "HTTP"
  port              = 80

  default_action {
    target_group_arn = aws_lb_target_group.rtb_tg.arn
    type             = "forward"
  }
}

################
# Target Group #
################

resource "aws_lb_target_group" "rtb_tg" {
  name     = "rtb-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.rtb_vpc.id

  health_check {
    port    = 8080
    matcher = "200"
    path    = "/api/utils/healthcheck"
  }

  stickiness {
    type = "lb_cookie"
  }
}

################################
# Load Balancer Security Group #
################################

resource "aws_security_group" "rtb_lb_sg" {
  name        = "rtb_lb_sg"
  vpc_id      = aws_vpc.rtb_vpc.id
  description = "Permitir entrada HTTP y salida a puerto 8080 webapp"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "rtb_lb_sg"
  }
}

############################
# Launch autoscaling group #
############################

resource "aws_autoscaling_group" "rtb_ag" {
  depends_on = [    
    aws_db_instance.rtb_rds_instance
  ]
  name = "rtb_ag"
  launch_template {
    id      = aws_launch_template.rtb_lt.id
    version = "$Latest"
  }
  min_size            = 1
  max_size            = 1
  desired_capacity    = 1
  target_group_arns   = [aws_lb_target_group.rtb_tg.arn]
  vpc_zone_identifier = [aws_subnet.rtb_public_subnet_a.id, aws_subnet.rtb_public_subnet_b.id]

  lifecycle {
    create_before_destroy = true
  }
}

###################
# Launch template #
###################

resource "aws_launch_template" "rtb_lt" {
  name_prefix            = "rtb-as-"
  image_id               = "ami-080af029940804103"
  instance_type          = "t2.micro"
  key_name               = "rtb_key_pair"
  user_data              = filebase64("start-app.sh")
  iam_instance_profile {
    arn = aws_iam_instance_profile.rtb_instance_profile.arn
  }
  network_interfaces {
    associate_public_ip_address = true
    security_groups = [aws_security_group.rtb_webapp_sg.id]
  }
}

############
# Key pair #
############

resource "aws_key_pair" "rtb_key_pair" {
  key_name = "rtb_key_pair"
  public_key = file("rtb_key_pair.pub")
}

##################################
# Web application Security Group #
##################################

resource "aws_security_group" "rtb_webapp_sg" {
  name        = "rtb_webapp_sg"
  vpc_id      = aws_vpc.rtb_vpc.id
  description = "SG que permite conexiones a 8080, salientes a 3306 y resto de internet."
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.rtb_lb_sg.id]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "rtb_webapp_sg"
  }
}

############
# IAM Role #
############

resource "aws_iam_role" "rtb_secret_reader_role" {
  name = "rtb_secret_reader_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Effect = "Allow"
      }
    ]
  })
}

##############
# IAM Policy #
##############

resource "aws_iam_policy" "rtb_secret_reader_policy" {
  name        = "rtb_secret_reader_policy"
  path        = "/"
  description = "Policy to read rtb-db-secret"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
        ]
        Effect   = "Allow"
        Resource = "${aws_secretsmanager_secret.rtb_rds_credentials.arn}"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "rtb_rp_attachment" {
  role       = aws_iam_role.rtb_secret_reader_role.name
  policy_arn = aws_iam_policy.rtb_secret_reader_policy.arn
}

resource "aws_iam_instance_profile" "rtb_instance_profile" {
  name = "rtb_instance_profile"
  role = aws_iam_role.rtb_secret_reader_role.name
}

################
# RDS Instance #
################

resource "aws_db_instance" "rtb_rds_instance" {
  allocated_storage       = 20
  backup_retention_period = 0
  db_name                 = "rtb_db"
  db_subnet_group_name    = "rtb_rds_subnet_group"
  engine                  = "mysql"
  engine_version          = "8.0.27"
  identifier              = "rtb-instance"
  instance_class          = "db.t2.micro"
  username                = "rtb_user"
  password                = random_password.password.result
  monitoring_interval     = 0
  storage_type            = "gp2"
  vpc_security_group_ids  = [aws_security_group.rtb_rds_sg.id]
  skip_final_snapshot     = true
  tags = {
    Name = "rtb_rds_instance"
  }
}

##############################
# Random password for rtb db #
##############################

resource "random_password" "password" {
  length  = 15
  special = false
}

######################
# RDS Security group #
######################

resource "aws_security_group" "rtb_rds_sg" {
  name        = "rtb_rds_sg"
  vpc_id      = aws_vpc.rtb_vpc.id
  description = "Grupo de seguridad para RDS"
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.rtb_webapp_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "rtb_rds_sg"
  }
}

resource "aws_db_subnet_group" "rtb_rds_subnet_group" {
  name        = "rtb_rds_subnet_group"
  description = "Subnet group para MySQL"
  subnet_ids  = [aws_subnet.rtb_private_subnet_a.id, aws_subnet.rtb_private_subnet_b.id]

  tags = {
    Name = "rtb_rds_subnet_group"
  }
}

###################
# Secrets manager #
###################

resource "aws_secretsmanager_secret" "rtb_rds_credentials" {
  name = "rtb-db-secret"
}

resource "aws_secretsmanager_secret_version" "rtb_rds_credentials_sv" {
  secret_id     = aws_secretsmanager_secret.rtb_rds_credentials.id
  secret_string = <<EOF
  {
   "username": "${aws_db_instance.rtb_rds_instance.username}",
   "password": "${random_password.password.result}",
   "host": "${aws_db_instance.rtb_rds_instance.endpoint}",
   "db": "${aws_db_instance.rtb_rds_instance.db_name}"
  }
  EOF
}


