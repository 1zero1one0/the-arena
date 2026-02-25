variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "vnet_address_space" {
  type = list(string)
}

variable "subnets" {
  type = map(object({
    address_prefixes = list(string)
    delegations      = list(string)
  }))
}

variable "dns_zone_names" {
  description = "Map of key => private DNS zone name to link to this VNet"
  type        = map(string)
  default     = {}
}

variable "dns_zone_resource_group_name" {
  description = "Resource group where private DNS zones live (shared RG)"
  type        = string
  default     = ""
}

variable "peer_vnet_id" {
  description = "VNet ID to peer with (for DR)"
  type        = string
  default     = null
}

variable "peer_vnet_name" {
  description = "Name of the peer VNet"
  type        = string
  default     = null
}
