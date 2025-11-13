terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

# Reference existing Docker network
data "docker_network" "devops" {
  name = "devops-network"
}

# Pull ARM-compatible Nagios image
resource "docker_image" "nagios" {
  name         = "manios/nagios:latest"
  keep_locally = false
}

# Create entrypoint wrapper script that adds custom config
resource "local_file" "nagios_entrypoint" {
  filename = "${path.module}/nagios-entrypoint.sh"
  content  = <<-EOT
    #!/bin/bash
    set -e
    
    # Add custom config to nagios.cfg if not already present
    if ! grep -q "cfg_file=/opt/nagios/etc/objects/nodejs-api.cfg" /opt/nagios/etc/nagios.cfg; then
      echo "cfg_file=/opt/nagios/etc/objects/nodejs-api.cfg" >> /opt/nagios/etc/nagios.cfg
      echo "Custom Node.js API config added to Nagios"
    fi
    
    # Verify config before starting
    /opt/nagios/bin/nagios -v /opt/nagios/etc/nagios.cfg
    
    # Start Nagios using original entrypoint
    exec /usr/local/bin/start_nagios
  EOT

  file_permission = "0755"
}

# Deploy Nagios container with auto-mounted config
resource "docker_container" "nagios" {
  name  = "nagios-server"
  image = docker_image.nagios.image_id

  ports {
    internal = 80
    external = 8000
  }

  # Connect to existing devops-network
  networks_advanced {
    name = data.docker_network.devops.name
  }

  # Mount custom config file
  volumes {
    host_path      = abspath("${path.module}/nagios-config/objects/nodejs-api.cfg")
    container_path = "/opt/nagios/etc/objects/nodejs-api.cfg"
    read_only      = true
  }

  # Mount custom entrypoint
  volumes {
    host_path      = abspath("${path.module}/nagios-entrypoint.sh")
    container_path = "/opt/custom-entrypoint.sh"
    read_only      = true
  }

  # Override entrypoint to run our custom script
  entrypoint = ["/bin/sh", "/opt/custom-entrypoint.sh"]

  restart = "unless-stopped"

  depends_on = [local_file.nagios_entrypoint]
}

output "nagios_url" {
  value = "http://localhost:8000"
}

output "nagios_credentials" {
  value = <<-EOT
    Username: nagiosadmin
    Password: nagios
    
    Custom config automatically loaded from: nagios-config/objects/nodejs-api.cfg
    
    To view logs: docker logs nagios-server
    To verify config: docker exec nagios-server /opt/nagios/bin/nagios -v /opt/nagios/etc/nagios.cfg
  EOT
}

output "monitoring_status" {
  value = "Node.js API at port 3000 is now being monitored by Nagios"
}
