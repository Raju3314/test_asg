##test
  test
  # Get default VPC
  data "aws_vpc" "default" {
 filter {
    name   = "tag:Name"
    values = ["nna-ncgt-nonprod-us-west-2-pesh-nws-prod"]
  }
  }
  
  # Get default subnets
  data "aws_subnets" "default" {
    filter {
      name   = "vpc-id"
      values = [data.aws_vpc.default.id]
    }
  }
  
  # Get latest Amazon Linux 2 AMI
  data "aws_ami" "amazon_linux_2" {
    most_recent = true
    owners      = ["amazon"]
  
    filter {
      name   = "name"
      values = ["amzn2-ami-hvm-*-x86_64-gp2"]
    }
  }



  
  # Launch Template
  resource "aws_launch_template" "my_template" {
    name_prefix   = "my-template"
    image_id      = data.aws_ami.amazon_linux_2.id
    instance_type = "t2.micro"

    metadata_options {
    http_endpoint               = "enabled"
    http_tokens                = "required"    # This enforces IMDSv2
    http_put_response_hop_limit = 2
  }
  
    network_interfaces {
      associate_public_ip_address = true
    }
  

  
    user_data = base64encode(<<-EOF
                #!/bin/bash
                yum update -y
                yum install -y httpd
                systemctl start httpd
                systemctl enable httpd
                echo "<h1>Hello from EC2 instancev8</h1>" > /var/www/html/index.html
                EOF
    )
  
    tag_specifications {
      resource_type = "instance"
      tags = {
        Name = "my-asg-instance"
        
      }
    }
  
    # Enable version tracking for instance refresh
    lifecycle {
      create_before_destroy = true
    }
  }

  resource "aws_autoscaling_group" "my_asg" {
    name                = "my-asg"
    desired_capacity    = 1
    max_size           = 2  # Make sure this is set
    min_size           = 1
    vpc_zone_identifier = data.aws_subnets.default.ids
  
    launch_template {
      id      = aws_launch_template.my_template.id
      version = aws_launch_template.my_template.latest_version
    }
  
    # Instance refresh configuration
    instance_refresh {
      strategy = "Rolling"
      preferences {
        min_healthy_percentage = 50
        instance_warmup       = 60
      }
      triggers = ["launch_template"]  # Add this triggers block
    }
  
  
    tag {
      key                 = "Name"
      value               = "my-asg-instance"
      propagate_at_launch = true
    }
  
    lifecycle {
      create_before_destroy = true
    }
  }
  
  
