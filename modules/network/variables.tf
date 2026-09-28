variable "resource_group_name" {
  type = string
}
variable "location" {
  type    = string
  default = "uksouth"

}
variable "vnet_name" {
  type = string
}
variable "subnets" {
  type = map(string)
}
variable "tags" {
  type = map(string)
  default = {
    environment = "ladder"
    project     = "terraForm"
  }
}
variable "address_space" {
  type = list(string)

}
