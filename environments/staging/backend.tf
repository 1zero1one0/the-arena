terraform {
  backend "azurerm" {
    resource_group_name  = "rg-arena-tfstate-centralus-001"
    storage_account_name = "starenatfstate001"
    container_name       = "tfstate"
    key                  = "staging.tfstate"
  }
}
