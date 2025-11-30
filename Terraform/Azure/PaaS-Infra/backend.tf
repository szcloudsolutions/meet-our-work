terraform {
 backend "azurerm" {
    # # Specific values about storage account, container, etc are defined in the pipeline, in the terraform init section
    # # This section can be empty, but must exist
    # subscription_id      = "xxxxxxxxxxxxxxxxxxxxxxxx"
    # resource_group_name  = "xxxxxxxxxxxxxxxxxxxx"
    # storage_account_name = "xxxxxxxxxxxxxxxxxx"
    # container_name       = "xxxxxxxxxx"
    # key                  = "terraform.tfstate"
 }
}