# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

# Configure the Microsoft Azure Provider
# provider "azurerm" {
#   skip_provider_registration = true # This is only required when the User, Service Principal, or Identity running Terraform lacks the permissions to register Azure Resource Providers.
#   features {}
# }

# Create a resource group
resource "azurerm_resource_group" "PaaSInfraRG" {
  name     = "PaaSInfraRG"
  location = "East US"
}

#Create a Key Vault within the resource group
resource "azurerm_key_vault" "PaaSInfraKV" {
  name                = "PaaSInfraKV"
  location            = azurerm_resource_group.PaaSInfraRG.location
  resource_group_name = azurerm_resource_group.PaaSInfraRG.name
  tenant_id           = azurerm_resource_group.PaaSInfraRG.tenant_id
  sku_name            = "standard"
}

# resource "azurerm_key_vault_access_policy" "PaaSInfraKV" {
#   key_vault_id = azurerm_key_vault.PaaSInfraKV.id
#   tenant_id    = data.azurerm_client_config.current.tenant_id
#   object_id    = data.azurerm_client_config.current.object_id

#   key_permissions = [
#     "Get",
#   ]

#   secret_permissions = [
#     "Get",
#   ]
# }

# Create a virtual network within the resource group
resource "azurerm_virtual_network" "PaaSInfraVNT" {
  name                = "PaaSInfraVNT"
  resource_group_name = azurerm_resource_group.PaaSInfraRG.name
  location            = azurerm_resource_group.PaaSInfraRG.location
  address_space       = ["10.0.0.0/24"]
}
# Create subnets within the resource group
resource "azurerm_subnet" "PaaSInfraSBN1" {
  name                 = "PaaSInfraSBN1"
  resource_group_name  = azurerm_resource_group.PaaSInfraRG.name
  virtual_network_name = azurerm_virtual_network.PaaSInfraVNT.name
  address_prefixes     = ["10.0.0.0/27"]
  enforce_private_link_service_network_policies = true
}

resource "azurerm_subnet" "PaaSInfraSBN2" {
  name                 = "PaaSInfraSBN2"
  resource_group_name  = azurerm_resource_group.PaaSInfraRG.name
  virtual_network_name = azurerm_virtual_network.PaaSInfraVNT.name
  address_prefixes     = ["10.0.0.32/27"]
  enforce_private_link_service_network_policies = true
}

resource "azurerm_subnet" "PaaSInfraSBN3" {
  name                 = "PaaSInfraSBN3"
  resource_group_name  = azurerm_resource_group.PaaSInfraRG.name
  virtual_network_name = azurerm_virtual_network.PaaSInfraVNT.name
  address_prefixes     = ["10.0.0.64/27"]
}

# Create a Log Analytics Workspace within the resource group

resource "azurerm_log_analytics_workspace" "PaasInfraOMS" {
  name                = "PaasInfraOMS"
  location            = azurerm_resource_group.PaaSInfraRG.location
  resource_group_name = azurerm_resource_group.PaaSInfraRG.name
  sku                 = "Free"
  retention_in_days   = 30
}

# Create a storage within the resource group

resource "azurerm_storage_account" "paasinfrastg" {
  name                     = "paasinfrastg"
  resource_group_name      = azurerm_resource_group.PaaSInfraRG.name
  location                 = azurerm_resource_group.PaaSInfraRG.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  tags = {
    environment = "testing"
  }
}

# Create a SQL Server within the resource group

resource "azurerm_mssql_server" "example" {
  name                         = "mssqlserver"
  resource_group_name          = azurerm_resource_group.example.name
  location                     = azurerm_resource_group.example.location
  version                      = "12.0"
  administrator_login          = "missadministrator"
  administrator_login_password = "thisIsKat11"
  minimum_tls_version          = "1.2"

  azuread_administrator {
    login_username = "AzureAD Admin"
    object_id      = "00000000-0000-0000-0000-000000000000"
  }

  tags = {
    environment = "production"
  }
}

# Create a SQL Database within the resource group

resource "azurerm_mssql_database" "example" {
  name           = "example-db"
  server_id      = azurerm_mssql_server.example.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  max_size_gb    = 4
  read_scale     = true
  sku_name       = "S0"
  zone_redundant = true
  enclave_type   = "VBS"

  tags = {
    foo = "bar"
  }

  # prevent the possibility of accidental data loss
  lifecycle {
    prevent_destroy = true
  }
}

# Create a Cosmos Db within the resource group

data "azurerm_cosmosdb_account" "paasinfracdbaccount" {
  name                = "paasinfracdbaccount"
  resource_group_name = "PaaSInfraRG"
}

resource "azurerm_cosmosdb_mongo_database" "paasinfracdb" {
  name                = "paasinfracdb"
  resource_group_name = data.azurerm_cosmosdb_account.paasinfracdbaccount.PaaSInfraRG_name
  account_name        = data.azurerm_cosmosdb_account.paasinfracdbaccount.name
  throughput          = 400
}

# Create Private Endpoints within the resource group



# Create an Application Insights within the resource group

resource "azurerm_application_insights" "paasinfraaai" {
  name                = "paasinfraaai"
  location            = azurerm_resource_group.PaaSInfraRG.location
  resource_group_name = azurerm_resource_group.PaaSInfraRG.name
  application_type    = "web"
}

# Create an App Service Plan within the resource group

resource "azurerm_app_service_plan" "example" {
  name                = "example-appserviceplan"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  sku {
    tier = "Standard"
    size = "S1"
  }
}

# Create a Webapp with Node.js within the resource group

resource "azurerm_app_service" "example" {
  name                = "example-app-service"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  app_service_plan_id = azurerm_app_service_plan.example.id

  site_config {
    dotnet_framework_version = "v4.0"
    scm_type                 = "LocalGit"
  }

  app_settings = {
    "SOME_KEY" = "some-value"
  }

# Create a Static Web App within the resource group

resource "azurerm_static_web_app" "example" {
  name                = "example"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
}

# Create an Application Gateway within the resource group

resource "azurerm_public_ip" "example" {
  name                = "example-pip"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  allocation_method   = "Dynamic"
}

# since these variables are re-used - a locals block makes this more maintainable
locals {
  backend_address_pool_name      = "${azurerm_virtual_network.example.name}-beap"
  frontend_port_name             = "${azurerm_virtual_network.example.name}-feport"
  frontend_ip_configuration_name = "${azurerm_virtual_network.example.name}-feip"
  http_setting_name              = "${azurerm_virtual_network.example.name}-be-htst"
  listener_name                  = "${azurerm_virtual_network.example.name}-httplstn"
  request_routing_rule_name      = "${azurerm_virtual_network.example.name}-rqrt"
  redirect_configuration_name    = "${azurerm_virtual_network.example.name}-rdrcfg"
}

resource "azurerm_application_gateway" "network" {
  name                = "example-appgateway"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "my-gateway-ip-configuration"
    subnet_id = azurerm_subnet.example.id
  }

  frontend_port {
    name = local.frontend_port_name
    port = 80
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.example.id
  }

  backend_address_pool {
    name = local.backend_address_pool_name
  }

  backend_http_settings {
    name                  = local.http_setting_name
    cookie_based_affinity = "Disabled"
    path                  = "/path1/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  http_listener {
    name                           = local.listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = local.request_routing_rule_name
    priority                   = 9
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
  }
}

# Create a WAF within the resource group

