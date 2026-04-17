variable "enabled" {
  type = bool
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "region_short" {
  type = string
}

variable "tags" {
  type = map(string)
}

variable "firewall_private_ip" {
  type = string
}

variable "spoke_vnet_address_space" {
  type = string
}

variable "on_premises_address_space" {
  type = string
}

variable "spoke_workload_subnet_ids" {
  description = "Map of workload/data/app subnet ids to associate with the spoke route table."
  type        = map(string)
}
