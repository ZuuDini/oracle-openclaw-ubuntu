variable "ad_number" {
  description = "The AD number for your A1 flex instance on Oracle"
  default     = 1
  type        = number
}

variable "cluster_domain_endpoint" {
  default     = ""
  description = "The cluster domain endpoint (empty if you don't have one)."
  type        = string
}

variable "compartment_description" {
  default     = "Default compartment"
  description = "A description of the compartment."
  type        = string
}

variable "compartment_name" {
  default     = "default-compartment"
  description = "The name of the compartment."
  type        = string
}

variable "fingerprint" {
  description = "The oci_fingerprint to auth to Oracle Cloud"
  nullable    = false
  type        = string
}

variable "internet_gateway_display_name" {
  default     = "igw"
  description = "The display name of the internet gateway."
  type        = string
}

variable "kubernetes_version" {
  default     = "1.31"
  description = "The major.minor Kubernetes version for the apt repository (e.g. 1.31)."
  type        = string
}

variable "nat_gateway_display_name" {
  default     = "ngw"
  description = "The display name of the NAT gateway."
  type        = string
}

variable "personal_ip" {
  description = "The personal IP address."
  nullable    = false
  sensitive   = true
  type        = string

  validation {
    condition = (
      var.personal_ip == "" ||
      can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$", var.personal_ip))
    )
    error_message = "The personal IP must be an empty string or a valid IPv4 address (e.g., 203.0.113.10)."
  }
}

variable "private_key" {
  description = "The OCI private key (base64 encoded)."
  nullable    = false
  sensitive   = true
  type        = string
}

variable "private_subnet_name" {
  default     = "private"
  description = "The name of the private subnet."
  type        = string
}

variable "public_subnet_name" {
  default     = "public"
  description = "The name of the public subnet."
  type        = string
}

variable "region" {
  description = "The oci_region to auth to Oracle Cloud"
  nullable    = false
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key for accessing the Ubuntu instances."
  nullable    = false
  type        = string
}

variable "tenancy_ocid" {
  description = "The tenancy to auth to Oracle Cloud"
  nullable    = false
  type        = string
}

variable "ubuntu_version" {
  default     = "24.04"
  description = "The Ubuntu version to use for the OCI marketplace image."
  type        = string
}

variable "user_ocid" {
  description = "The user to auth to Oracle Cloud"
  nullable    = false
  type        = string
}

variable "vcn_name" {
  default     = "vcn"
  description = "The name of the Virtual Cloud Network (VCN)."
  type        = string
}
