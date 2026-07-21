provider "azuread" {
  use_oidc = true
}

provider "azurerm" {
  features {}

  storage_use_azuread = true
  use_oidc            = true
}
