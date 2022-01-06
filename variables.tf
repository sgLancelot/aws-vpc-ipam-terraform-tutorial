variable "region" {
  type        = string
  description = "The AWS Region that the resources will be created in. Will also be included as part of the IPAM operating region"
  default     = "us-east-1"
}

variable "ipam_operating_regions" {
  type        = list(string)
  description = "Additional AWS VPC IPAM operating regions. You can only create VPCs from a pool whose locale matches this variable. Duplicate values will be removed."
  default     = ["us-west-2"]
}

variable "top_level_pool_cidr" {
  type        = string
  description = "The top level IPAM pool CIDR. Currently only supports a single CIDR."
  default     = "10.0.0.0/8"
}