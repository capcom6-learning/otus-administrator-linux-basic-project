variable "linode_token" {
  description = "Linode API token"
  type        = string
  sensitive   = true
}

variable "root_password" {
  description = "Default root password"
  type        = string
  sensitive   = true
}

variable "authorized_keys" {
  description = "SSH authorized keys"
  type        = list(string)
}