terraform {
  required_version = ">= 1.12.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
  cloud {
    organization = "s-durrani"
    workspaces {
      project = "DevOps Guide for Beginners"
      name    = "test"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "terraform_guide" {
  name     = "rg-tf-08-dev-uks"
  location = "uksouth"
  tags = {
    environment = "test"
    project     = "DevOps Guide"
  }
}

module "network" {
  source              = "./../modules/network"
  resource_group_name = azurerm_resource_group.terraform_guide.name
  location            = azurerm_resource_group.terraform_guide.location
  vnet_name           = "vnet-tf08"
  address_space       = ["10.40.0.0/16"]
  subnets = {
    snet-app = "10.40.1.0/24"
  }
  tags = azurerm_resource_group.terraform_guide.tags
}

resource "azurerm_network_interface" "ni-vms" {
  name                = "nic-vm"
  location            = azurerm_resource_group.terraform_guide.location
  resource_group_name = azurerm_resource_group.terraform_guide.name
  ip_configuration {
    name                          = "internal"
    subnet_id                     = module.network.subnet_id["snet-app"]
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "vm_1" {
  name                  = "vm-1"
  location              = azurerm_resource_group.terraform_guide.location
  resource_group_name   = azurerm_resource_group.terraform_guide.name
  size                  = "Standard_D2als_v6"
  admin_username        = "devops"
  network_interface_ids = [azurerm_network_interface.ni-vms.id]

  admin_ssh_key {
    username   = "devops"
    public_key = var.admin_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}

resource "azurerm_log_analytics_workspace" "log-analytics" {
  name                = "log-tg08"
  location            = azurerm_resource_group.terraform_guide.location
  resource_group_name = azurerm_resource_group.terraform_guide.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_monitor_action_group" "ops" {
  name                = "ag-tf08-ops"
  resource_group_name = azurerm_resource_group.terraform_guide.name
  short_name          = "tf08-ops"

  email_receiver {
    name          = "CTO"
    email_address = "<your-email>"
  }
}

resource "azurerm_monitor_metric_alert" "cpu-usage" {
  name                = "alert-vm-1-cpu70"
  resource_group_name = azurerm_resource_group.terraform_guide.name
  scopes              = [azurerm_linux_virtual_machine.vm_1.id]
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 60
  }
  action {
    action_group_id = azurerm_monitor_action_group.ops.id
  }
}