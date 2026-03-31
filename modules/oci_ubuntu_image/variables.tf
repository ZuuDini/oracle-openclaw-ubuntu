variable "compartment_id" {
  description = "The compartment id"
  type        = string
}

variable "ubuntu_version" {
  description = "Ubuntu version to use (e.g. 24.04, 22.04)"
  default     = "24.04"
  type        = string
}
