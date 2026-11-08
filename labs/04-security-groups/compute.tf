data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

locals {
  instances = {
    app = {
      sg   = aws_security_group.app.id
      port = 8080
    }
    db = {
      sg   = aws_security_group.db.id
      port = 5432
    }
    probe = {
      sg   = aws_security_group.probe.id
      port = null
    }
  }
}

resource "aws_instance" "this" {
  for_each = local.instances

  ami                         = data.aws_ssm_parameter.al2023_ami.value
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.this["private_a"].id
  vpc_security_group_ids      = [each.value.sg]
  associate_public_ip_address = false

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted = true
  }

  user_data_replace_on_change = true
  user_data                   = each.value.port == null ? null : <<-EOT
    #!/bin/bash
    mkdir -p /srv/www
    echo "hello from ${each.key}" > /srv/www/index.html
    systemd-run --unit=lab-listener --uid=nobody \
      python3 -m http.server ${each.value.port} --directory /srv/www
  EOT

  tags = {
    Name = "security-groups-lab-dev-${each.key}"
  }
}
