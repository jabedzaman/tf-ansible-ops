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

# Pull Nagios Docker image
resource "docker_image" "nagios" {
  name         = "jasonrivers/nagios:latest"
  keep_locally = false
}

# Create volumes for Nagios configuration persistence
resource "docker_volume" "nagios_etc" {
  name = "nagios_etc"
}

resource "docker_volume" "nagios_var" {
  name = "nagios_var"
}

# Create custom Nagios configuration directory
resource "null_resource" "nagios_config" {
  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p ./nagios-config/objects
      cat > ./nagios-config/objects/nodejs-api.cfg <<EOF
# Define the Node.js API host
define host {
    use                     linux-server
    host_name               nodejs-api
    alias                   Node.js Hello API
    address                 172.17.0.1
    max_check_attempts      5
    check_period            24x7
    notification_interval   30
    notification_period     24x7
}

# Define HTTP service check for API health endpoint
define service {
    use                     generic-service
    host_name               nodejs-api
    service_description     API Health Check
    check_command           check_http!-p 3000 -u /health
    max_check_attempts      3
    check_interval          1
    retry_interval          1
    notification_interval   30
    notification_period     24x7
}

# Define HTTP service check for API hello endpoint
define service {
    use                     generic-service
    host_name               nodejs-api
    service_description     API Hello Endpoint
    check_command           check_http!-p 3000 -u /api/hello -s "Hello"
    max_check_attempts      3
    check_interval          2
    retry_interval          1
    notification_interval   30
    notification_period     24x7
}
EOF
    EOT
  }
}

# Deploy Nagios container
resource "docker_container" "nagios" {
  name  = "nagios-server"
  image = docker_image.nagios.image_id

  ports {
    internal = 80
    external = 8000
  }

  env = [
    "NAGIOSADMIN_USER=admin",
    "NAGIOSADMIN_PASS=admin123"
  ]

  volumes {
    volume_name    = docker_volume.nagios_etc.name
    container_path = "/opt/nagios/etc"
  }

  volumes {
    volume_name    = docker_volume.nagios_var.name
    container_path = "/opt/nagios/var"
  }

  volumes {
    host_path      = "${path.cwd}/nagios-config/objects"
    container_path = "/opt/Custom-Nagios-Plugins"
    read_only      = true
  }

  restart = "unless-stopped"

  # Use host network to access API on localhost:3000
  network_mode = "bridge"

  depends_on = [null_resource.nagios_config]
}

output "nagios_url" {
  value = "http://localhost:8000/nagios"
}

output "nagios_credentials" {
  value = "Username: admin, Password: admin123"
  sensitive = false
}
