output "public_ip_dns_name" {
  description = "fqdn to connect to the first vm provisioned."
  value       = "${azurerm_public_ip.pubip.fqdn}"
}