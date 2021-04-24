terraform {
  required_providers {
    linode = {
      source  = "linode/linode"
      version = "1.16.0"
    }
  }
}

provider "linode" {
  token = var.linode_token
}

resource "linode_instance" "frontend" {
  label           = "eu-central-frontend"
  image           = "linode/centos7"
  region          = "eu-central"
  type            = "g6-nanode-1"
  authorized_keys = var.authorized_keys
  root_pass       = var.root_password
  private_ip      = true
  tags            = ["frontend"]
}

resource "linode_instance" "backend_01" {
  label           = "eu-central-backend-01"
  image           = "linode/centos7"
  region          = "eu-central"
  type            = "g6-nanode-1"
  authorized_keys = var.authorized_keys
  root_pass       = var.root_password
  private_ip      = true
  tags            = ["backend"]
}

resource "linode_instance" "backend_02" {
  label           = "eu-central-backend-02"
  image           = "linode/centos7"
  region          = "eu-central"
  type            = "g6-nanode-1"
  authorized_keys = var.authorized_keys
  root_pass       = var.root_password
  private_ip      = true
  tags            = ["backend"]
}

resource "linode_instance" "dbserver" {
  label           = "eu-central-dbserver"
  image           = "linode/centos7"
  region          = "eu-central"
  type            = "g6-nanode-1"
  authorized_keys = var.authorized_keys
  root_pass       = var.root_password
  private_ip      = true
  tags            = ["dbserver"]
}

resource "linode_instance" "dbslave" {
  label           = "eu-central-dbslave"
  image           = "linode/centos7"
  region          = "eu-central"
  type            = "g6-nanode-1"
  authorized_keys = var.authorized_keys
  root_pass       = var.root_password
  private_ip      = true
  tags            = ["dbslave"]
}

resource "linode_instance" "monitoring" {
  label           = "eu-central-monitoring"
  image           = "linode/centos7"
  region          = "eu-central"
  type            = "g6-nanode-1"
  authorized_keys = var.authorized_keys
  root_pass       = var.root_password
  private_ip      = true
  tags            = ["monitoring"]
}
