terraform {
  required_providers {
    linode = {
      source = "linode/linode"
      version = "1.16.0"
    }
  }
}

provider "linode" {
    token = var.linode_token
}

# resource "linode_instance" "example_instance" {
#     label = "example_instance_label"
#     image = "linode/centos7"
#     region = "eu-central"
#     type = "g6-nanode-1"
#     authorized_keys = var.authorized_keys
#     root_pass = var.root_password
#     private_ip = true
# }