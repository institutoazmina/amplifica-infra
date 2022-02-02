resource "aws_ssm_document" "cloud_init_wait" {
  name            = "cloud-init-wait"
  document_type   = "Command"
  document_format = "YAML"
  content         = <<-DOC
    schemaVersion: '2.2'
    description: Wait for cloud init to finish
    mainSteps:
    - action: aws:runShellScript
      name: StopOnLinux
      precondition:
        StringEquals:
        - platformType
        - Linux
      inputs:
        runCommand:
        - cloud-init status --wait
    DOC
}

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

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]

    command = <<-EOF
    set -Ee -o pipefail
    export AWS_DEFAULT_REGION="us-east-2"

    IID=$(aws lightsail get-instance --instance-name ${self.id} --query "instance.supportCode" --output text | sed 's!.*/i-/i-/g')
    command_id=$(aws ssm send-command --document-name ${aws_ssm_document.cloud_init_wait.arn} --instance-ids $IID --output text --query "Command.CommandId")
    if ! aws ssm wait command-executed --command-id $command_id --instance-id $IID; then
      echo "Failed to start services on instance ${self.id}!";
      echo "stdout:";
      aws ssm get-command-invocation --command-id $command_id --instance-id $IID --query StandardOutputContent;
      echo "stderr:";
      aws ssm get-command-invocation --command-id $command_id --instance-id $IID --query StandardErrorContent;
      exit 1;
    fi;
    echo "Services started successfully on the new instance with id $IID (${self.id})!"

    EOF
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
