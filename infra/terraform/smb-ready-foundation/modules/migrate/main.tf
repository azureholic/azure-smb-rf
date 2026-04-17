// Azure Migrate project — via azapi (no azurerm support for this RP).

terraform {
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.0"
    }
  }
}

locals {
  name = "migrate-smbrf-smb-${var.region_short}"
}

resource "azapi_resource" "migrate_project" {
  type      = "Microsoft.Migrate/migrateProjects@2020-05-01"
  name      = local.name
  location  = var.location
  parent_id = var.resource_group_id

  body = {
    properties = {}
  }

  response_export_values = ["id", "name"]
}
