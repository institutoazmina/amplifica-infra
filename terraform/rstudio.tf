resource "aws_lightsail_instance" "amplifica" {
  name              = "amplifica_server"
  availability_zone = "us-east-2a"
  blueprint_id      = "ubuntu_20_04"
  bundle_id         = "micro_2_0"
  # key_pair_name   = "diego.rabatone"
  user_data = file("./scripts/bootstrap.sh")
  tags = {
    project = "amplifica"
  }
}

resource "aws_lightsail_instance_public_ports" "amplifica" {
  instance_name = aws_lightsail_instance.amplifica.name

  port_info {
    protocol  = "tcp"
    from_port = 22
    to_port   = 22
  }

  port_info {
    protocol  = "tcp"
    from_port = 443
    to_port   = 443
  }

  port_info {
    protocol  = "tcp"
    from_port = 8787
    to_port   = 8787
  }

  port_info {
    protocol  = "tcp"
    from_port = 3838
    to_port   = 3838
  }
}

resource "aws_lightsail_static_ip" "amplifica" {
  name = "amplifica"
}

resource "aws_lightsail_static_ip_attachment" "amplifica" {
  static_ip_name = aws_lightsail_static_ip.amplifica.id
  instance_name  = aws_lightsail_instance.amplifica.id
}

## DNS - Cloudflare
# Add a record to the domain
resource "cloudflare_record" "amplifica" {
  zone_id = "443c8dceafd3fe5639718bd25d0c8d04"
  name    = "amplifica"
  value   = aws_lightsail_static_ip.amplifica.ip_address
  type    = "A"
  ttl     = 3600
}
