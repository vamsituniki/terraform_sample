# VPC 
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr_block
  tags = {
      Name = "React-VPC"
  }
}

# Public Subnet1
resource "aws_subnet" "public-subnet-1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.public_subnet_cidr1

  tags = {
    Name = "public-subnet-1"
  }
}

# Public Subnet2
resource "aws_subnet" "public-subnet-2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.public_subnet_cidr2

  tags = {
    Name = "public-subnet-2"
  }
}

# Private Subnet
resource "aws_subnet" "private-subnet" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.private_subnet_cidr

  tags = {
    Name = "private-subnet" 
  }
}

# IGW
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "my-igw"
  }
}
# Route table & association
resource "aws_route_table" "public-route1" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
    route {
      ipv6_cidr_block = "::/0"
      gateway_id = aws_internet_gateway.igw.id
    }
    tags = {
      Name = "my_public_route1"
     }
}

resource "aws_route_table_association" "public_route1_association" {
  subnet_id      = aws_subnet.public-subnet-1.id
  route_table_id = aws_route_table.public-route1.id
}

resource "aws_route_table" "public-route2" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
    route {
      ipv6_cidr_block = "::/0"
      gateway_id = aws_internet_gateway.igw.id
    }
    tags = {
      Name = "my_public_route2"
     }
}
resource "aws_route_table_association" "public_route2_association" {
  subnet_id      = aws_subnet.public-subnet-2.id
  route_table_id = aws_route_table.public-route2.id
}

#NetworkInterface 
resource "aws_network_interface" "nw-interface" {
  subnet_id       = aws_subnet.public-subnet-1.id
  security_groups = [aws_security_group.allow_http_traffic.id]

}
# EIP
resource "aws_eip" "eip" {
  vpc      = true
  network_interface = aws_network_interface.nw-interface.id
  depends_on = [aws_internet_gateway.igw]
}


# Security group
resource "aws_security_group" "allow_http_traffic" {
  name        = "allow_http_traffic"
  description = "To alloe http traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp" 
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
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
    Name = "allow_http_traffic"
  }
}


#Launch configuration 
resource "aws_launch_configuration" "server" {
  name_prefix = "server"
  image_id = var.image_id
  instance_type = var.instance_type
  security_groups = [aws_security_group.allow_http_traffic.id]
  key_name = "web-app"
  associate_public_ip_address = true


  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c "echo Hello World > /var/www/html/index.html"
              EOF
 
/*
  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install nodejs
              sudo apt install npm
              npx create-react-app my-app
			        cd my-app
			        npm start
              EOF  
*/
 lifecycle {
    create_before_destroy = true
  }
}


#Security group for ELB
resource "aws_security_group" "elb_http" {
  name        = "elb_http"
  description = "Allow http traffic to instances through ELB"
  vpc_id      = aws_vpc.main.id

ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
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
    Name = "allow http through ELB"
  }
}

#Load balancer
resource "aws_lb" "my-elb" {
  name     = "my-web-elb"
  internal = false
  security_groups = [aws_security_group.elb_http.id]
  subnets = [aws_subnet.public-subnet-1.id,aws_subnet.public-subnet-2.id]

  tags = {
    Name = "my-website-elb"
  }
}
#Target group and attachment
resource "aws_lb_target_group" "my-elb-tg" {
  health_check {
    interval            = 10
    path                = "/index.html"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }

  name        = "my-tg"
  depends_on = [aws_vpc.main]
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.main.id
}

resource "aws_lb_listener" "my-elb-listner" {
  depends_on = [aws_lb.my-elb,aws_lb_target_group.my-elb-tg ]
  load_balancer_arn = aws_lb.my-elb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my-elb-tg.arn
  }
}
#Autoscaling group
resource "aws_autoscaling_group" "auto_sg" {
  launch_configuration = aws_launch_configuration.server.id
  vpc_zone_identifier  = [aws_subnet.public-subnet-1.id,aws_subnet.public-subnet-2.id]
  target_group_arns = [ aws_lb_target_group.my-elb-tg.arn ]
  health_check_type    = "ELB"
  min_size = 2
  max_size = 4
  desired_capacity = 2

  tag {
    key                 = "Name"
    value               = "auto_sg"
    propagate_at_launch = true
  }
}

