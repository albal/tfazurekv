provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "example" {
  name     = "example-rg"
  location = "West Europe"
}

resource "random_string" "random" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_key_vault" "example" {
  name                       = "mykv-${random_string.random.result}"
  location                   = azurerm_resource_group.example.location
  resource_group_name        = azurerm_resource_group.example.name
  sku_name                   = "standard"
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days = 7

  access_policy {
    tenant_id          = data.azurerm_client_config.current.tenant_id
    object_id          = data.azurerm_client_config.current.object_id
    secret_permissions = ["List", "Set", "Get", "Delete", "Purge"]
  }
}

resource "azurerm_key_vault_secret" "IPs" {
  name         = "IPs"
  value        = file("ips.txt")
  key_vault_id = azurerm_key_vault.example.id
}

locals {
  ips = split(",", azurerm_key_vault_secret.IPs.value)
}

resource "azurerm_network_security_group" "myips" {
  name                = "example"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_network_security_rule" "ns-rule" {
  count                       = length(local.ips)
  name                        = "Rule-${count.index}"
  priority                    = 100 + count.index
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = trimspace(local.ips[count.index])
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.example.name
  network_security_group_name = azurerm_network_security_group.myips.name
}
