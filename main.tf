data "aws_ami" "ecs_ami" {
  most_recent = true

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn-ami-${var.ami_version}-amazon-ecs-optimized"]
  }
}

data "template_file" "user_data" {
  template = "${file("${path.module}/templates/user_data.tpl")}"

  vars {
    additional_user_data_script = "${var.additional_user_data_script}"
    cluster_name                = "${aws_ecs_cluster.cluster.name}"
    docker_storage_size         = "${var.docker_storage_size}"
    dockerhub_token             = "${var.dockerhub_token}"
    dockerhub_email             = "${var.dockerhub_email}"
  }
}

data "aws_vpc" "vpc" {
  id = "${var.vpc_id}"
}


locals {
  docker_container_storage = [{
    device_name           = "/dev/xvdcz"
    volume_size           = "${var.docker_storage_size}"
    volume_type           = "${var.docker_storage_type}"
    delete_on_termination = true
  }]
}

resource "aws_launch_configuration" "ecs" {
  name_prefix                 = "${coalesce(var.name_prefix, "ecs-${var.name}-")}"
  image_id                    = "${var.ami == "" ? format("%s", data.aws_ami.ecs_ami.id) : var.ami}"   # Workaround until 0.9.6
  instance_type               = "${var.instance_type}"
  iam_instance_profile        = "${aws_iam_instance_profile.ecs_profile.name}"
  security_groups             = ["${concat(list(aws_security_group.ecs.id), var.security_group_ids)}"]
  associate_public_ip_address = "${var.associate_public_ip_address}"

  root_block_device {
    volume_size           = "${var.root_volume_size}"
    volume_type           = "${var.root_volume_type}"
    delete_on_termination = true
  }

  ebs_block_device = "${concat(local.docker_container_storage, var.ebs_block_devices)}"

  user_data = "${coalesce(var.user_data, data.template_file.user_data.rendered)}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "ecs" {
  name_prefix               = "${coalesce(var.name_prefix, "asg-${aws_launch_configuration.ecs.name}-")}"
  vpc_zone_identifier       = ["${var.subnet_id}"]
  launch_configuration      = "${aws_launch_configuration.ecs.name}"
  min_size                  = "${var.min_servers}"
  max_size                  = "${var.max_servers}"
  desired_capacity          = "${var.servers}"
  wait_for_capacity_timeout = "${var.wait_for_capacity_timeout}"
  load_balancers            = ["${var.load_balancers}"]

  termination_policies = [
    "OldestLaunchConfiguration",
    "ClosestToNextInstanceHour",
    "Default",
  ]

  tags = [
    {
      key                 = "Name"
      value               = "${var.name} ${var.tagName}"
      propagate_at_launch = true
    },
    {
      key                 = "Terraform"
      value               = "yes"
      propagate_at_launch = true
    },
  ]

  tags = ["${var.extra_tags}"]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "ecs" {
  name_prefix = "${coalesce(var.name_prefix, "ecs-sg-${var.name}-")}"
  description = "Container Instance Allowed Ports"
  vpc_id      = "${data.aws_vpc.vpc.id}"

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = "${var.allowed_cidr_blocks}"
  }

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "udp"
    cidr_blocks = "${var.allowed_cidr_blocks}"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name      = "ecs-sg-${var.name}"
    Terraform = "yes"
  }
}

# Make this a var that an get passed in?
resource "aws_ecs_cluster" "cluster" {
  name = "${var.name}"
}
