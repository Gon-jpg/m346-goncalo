provider "aws" {
  region = "us-east-1"
}

# Security Group für MariaDB
resource "aws_security_group" "db_sg" {
  name        = "kn09-db-sg"
  description = "Security Group for MariaDB"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3306
    to_port     = 3306
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
    Name = "KN09-DB-SecurityGroup"
  }
}

# EC2 Instance mit Cloud-Init
resource "aws_instance" "db_server" {
  ami                         = "ami-07ff62358b87c7116"
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.db_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y mariadb105-server
              systemctl start mariadb
              systemctl enable mariadb
              EOF

  tags = {
    Name = "KN09-Terraform-DB"
  }
}

output "public_ip" {
  value = aws_instance.db_server.public_ip
}
