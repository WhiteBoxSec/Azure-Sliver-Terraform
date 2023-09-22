variable "resource_group_location" {
  type        = string
  description = "Location for all resources."
  default     = "eastus"
}

variable "resource_group_name_prefix" {
  type        = string
  description = "Prefix of the resource group name that's combined with a random ID so name is unique in your Azure subscription."
  default     = "Sliver-Test"
}

variable "my_ip" {
  type        = string
  description = "Your IP for firewall rules"
  # Replace with your IP.
  default     = "7.7.7.7"
}

variable "username" {
  type        = string
  description = "The username for the local account that will be created on the new VM."
  default     = "kali"
}

variable "password" {
  type        = string
  description = "The password to connect to the VM."
  # Please use a different password.
  default     = "nottaC2server1234"
}

variable "hostname" {
  type        = string
  description = "The hostname for the new VM."
  default     = "sliver-azure-lab"
}

variable "dns_name" {
  type        = string
  description = "The external DNS name for the VM. It will be <dns_name>.<resourc_group_location>.cloudapp.azure.com."
  # Probably good opsec to change this.
  default     = "notta-c2-server"
}