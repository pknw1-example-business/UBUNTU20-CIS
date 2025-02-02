provider "aws" {
  profile = ""
  region  = var.aws_region
}

// Create a security group with access to port 22

resource "random_id" "server" {
  keepers = {
    # Generate a new id each time we switch to a new AMI id
    ami_id = "${var.ami_id}"
  }

  byte_length = 8
}

resource "aws_security_group" "github_actions" {
  name   = "${var.namespace}-${random_id.server.hex}-SG"
  vpc_id = aws_vpc.Main.id

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
    Environment = "${var.environment}"
    Name        = "${var.namespace}-SG"
  }
}

// instance setup

resource "aws_instance" "testing_vm" {
  ami                         = var.ami_id
  availability_zone           = var.availability_zone
  associate_public_ip_address = true
  key_name                    = var.ami_key_pair_name # This is the key as known in the ec2 key_pairs
  instance_type               = var.instance_type
  tags                        = var.instance_tags
  vpc_security_group_ids      = [aws_security_group.github_actions.id]
  subnet_id                   = aws_subnet.Main.id
  root_block_device {
    delete_on_termination = true
  }
}

// generate inventory file
resource "local_file" "inventory" {
  filename             = "./hosts.yml"
  directory_permission = "0755"
  file_permission      = "0644"
  content              = <<EOF
    # benchmark host
    all:
      hosts:
        ${var.ami_os}:
          ansible_host: ${aws_instance.testing_vm.public_ip}
          ansible_user: ${var.ami_username}
          ubtu20cis_grub_pw: 'grub.pbkdf2.sha512.10000.D268F2334B417C788C859A1104D489BE73205AFB74539DCAB0AC3F4A3B2ADE34D994D6D86A6F665200608F88050BCBC5D161ED07DE78C39D3C2BAE345F22DCEE.730C7E0F06BBDD2A54FF7BE93B710E94E1B1B61FE8E0BF27313E2429AF2C57348BF2EA647E39EF5AB13BE3EF3B1972FA5082EEB62AB9436314EA851D8042F423'
          ubtu20cis_root_pw: '$6$m1u7QuCBzmdHhig3$Ss48R6udPO.sISy8XphR2jlLhGqQiLoKkjdqVVU7zsU108oOq25.Bj0BTeafnljaur7iMnQPYXpRCzgXc6o4U1'
      vars:
        setup_audit: true
        run_audit: true
        system_is_ec2: true
    EOF
}
