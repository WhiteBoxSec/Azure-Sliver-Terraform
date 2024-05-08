# Create resource group with random name.
resource "random_pet" "rg_name" {
  prefix = var.resource_group_name_prefix
}

# Resource group location based on variable.
resource "azurerm_resource_group" "rg" {
  name     = random_pet.rg_name.id
  location = var.resource_group_location
}

# Create virtual network.
resource "random_pet" "azurerm_virtual_network_name" {
  prefix = "vnet"
}

# Create vnet super network.
resource "azurerm_virtual_network" "supernet" {
  name                = random_pet.azurerm_virtual_network_name.id
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

}

# Create subnet with random name.
resource "random_pet" "azurerm_subnet_name" {
  prefix = "sub"
}

# Create subnet from super net.
resource "azurerm_subnet" "subnet" {
  name                 = random_pet.azurerm_subnet_name.id
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.supernet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Allocate public IP to network and create DNS record.
resource "azurerm_public_ip" "pubip" {
  name                = "publicIP"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
  domain_name_label = "${var.dns_name}"
}

# Create security group for FW rules.
resource "azurerm_network_security_group" "security-group" {
  resource_group_name   = random_pet.rg_name.id
  location            = azurerm_resource_group.rg.location
  name   = "nsg"
}

# New FW rule to allow all access from my IP.
# IP pulled from variables.
  resource "azurerm_network_security_rule" "Allow-All-rule" {
      name                   = "Allow-My-IP"
      priority               = 100
      direction              = "Inbound"
      access                 = "Allow"
      protocol               = "*"
      source_port_range      = "*"
      destination_port_range = "*"
      source_address_prefix  = var.my_ip
      destination_address_prefix  = "*"
      description            = "Allow-My-IP-All"
      resource_group_name   = random_pet.rg_name.id
      network_security_group_name = azurerm_network_security_group.security-group.name
  }

  # Create 443 deny rule to later enable with target IP range.
  resource "azurerm_network_security_rule" "Target-443-rule" {
      name                   = "Allow-Target-443"
      priority               = 101
      direction              = "Inbound"
      access                 = "Deny"
      protocol               = "Tcp"
      source_port_range      = "*"
      destination_port_range = "443"
      source_address_prefix  = "*"
      destination_address_prefix  = "*"
      description            = "Allow-Target-IP-443"
      resource_group_name   = random_pet.rg_name.id
      network_security_group_name = azurerm_network_security_group.security-group.name
  }

# Create interface for VM.
resource "azurerm_network_interface" "interface" {
  name                = "acctni"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  
  # DHCP for interface.
  ip_configuration {
    name                          = "testConfiguration"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pubip.id
  }
}

# Associate security group with interface.
resource "azurerm_network_interface_security_group_association" "assc-nsg" {
  network_interface_id      = azurerm_network_interface.interface.id
  network_security_group_id = azurerm_network_security_group.security-group.id
}

resource "random_pet" "azurerm_linux_virtual_machine_name" {
  prefix = "vm"
}


# Generate random password. No number and 3 special characters.
# Not working with connection.
resource "random_password" "ssh-password" {
  length           = 16
  numeric          = false
  min_special      = 3 
}

# Creating the virtual machine.
resource "azurerm_linux_virtual_machine" "test-vm" {
  name                  = "${var.resource_group_name_prefix}-vm"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.interface.id]
  # Select VM size
  # B2s = 2 CPUs 4G RAM 
  size                  = "Standard_B2s"

  # Selecting the kali image.
  # Command to find images: az vm image list --offer kali --all --output table
  source_image_reference {
    publisher = "kali-linux"
    offer     = "kali"
    sku       = "kali-2023-3"
    version   = "2023.3.0"
  }

  # plan allows the accepting of the Kali VM usage terms.
  plan {
    # name == sku
    name      = "kali-2023-3"
    # product == offer
    product   = "kali"
    # publisher == publisher
    publisher = "kali-linux"
  }

  # Allow password auth.
  disable_password_authentication = false

  # Creating VM disk. Change disk size with disk_size_gb
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "${var.resource_group_name_prefix}-disk"
    disk_size_gb         = "90"
  }

  # Hostname, user name, and password from variables.
  computer_name  = var.hostname
  admin_username = var.username
  admin_password = var.password
  
  # Trying to generate a random password
  # admin_password = random_password.ssh-password.result

  # Info to connect via ssh to run provisioner 
  connection {
        type = "ssh"
        user = var.username
        host = "${azurerm_public_ip.pubip.fqdn}"
        password = var.password
        timeout = "5m"
        agent = false
    }

 # Download latest Sliver server and client
   provisioner "remote-exec" {
     inline = [
     # Install curl for Sliver download command
     "sudo apt update && sudo apt install curl mingw-w64 binutils-mingw-w64 g++-mingw-w64 -y",
     "mkdir sliver",
     # My dumb oneliner to download the latest sliver client and server. There is probably a better way to do this. 
     "wget -O sliver/sliver-client_linux -q $(curl -s 'https://api.github.com/repos/BishopFox/sliver/releases/latest' | awk -F '\"' '/browser_download_url/{print $4}' | grep sliver-client_linux | grep -iv 'sig')",
     "wget -O sliver/sliver-server_linux -q $(curl -s 'https://api.github.com/repos/BishopFox/sliver/releases/latest' | awk -F '\"' '/browser_download_url/{print $4}' | grep sliver-server_linux | grep -iv 'sig')",
     # Make sliver binaries executable.
     "chmod +x sliver/sliver-*",
     # Start updating server in tmux session. Allows update to run in background and terrafrom to finish. The /user/bin/zsh is to keep the tmux session open after the update.
     "tmux new-session -d -s shell 'sudo apt upgrade -y && /usr/bin/zsh'"
     ]
  }

  tags = {
    environment = "Sliver-lab"
    }
}
