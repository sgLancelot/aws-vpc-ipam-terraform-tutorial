provider "aws" {
  region = var.region
  # add default tags
  default_tags {
    tags = {
      Terraform = true
    }
  }
}

# note that this is a single account IPAM
# let's follow settings for this link. https://docs.aws.amazon.com/vpc/latest/ipam/tutorials-create-vpc-ipam.html

# service linked role
resource "aws_iam_service_linked_role" "ipam" { # only required for single account IPAM.
  aws_service_name = "ipam.amazonaws.com"
  description      = "Service Linked Role for AWS VPC IP Address Manager"
}

locals {
  deduplicated_region_list = toset(concat([var.region], var.ipam_operating_regions))
}

# create IPAM, default scope is created and can be referenced from
resource "aws_vpc_ipam" "tutorial" {
  description = "my-ipam"
  dynamic "operating_regions" {               # You specify a region using the region_name parameter. You must set your provider block region as an operating_region.
    for_each = local.deduplicated_region_list # this handles duplicate values by removing them.
    content {
      region_name = operating_regions.value
    }
  }
  depends_on = [
    aws_iam_service_linked_role.ipam # THIS ROLE CAN ONLY BE DELETED AFTER IPAM IS DELETED. THIS CREATES A DEPENDENCY TO ALLOW IPAM TO BE DELETED FIRST.
  ]
}

# no need to create scope, default created
# create a top-level pool 
# The ID of the IPAM's private scope. A scope is a top-level container in IPAM. Each scope represents an IP-independent network. 
# Scopes enable you to represent networks where you have overlapping IP space. 
# When you create an IPAM, IPAM automatically creates two scopes: public and private. 
# The private scope is intended for private IP space. The public scope is intended for all internet-routable IP space.
resource "aws_vpc_ipam_pool" "top_level" {
  description    = "top-level-pool"
  address_family = "ipv4"
  ipam_scope_id  = aws_vpc_ipam.tutorial.private_default_scope_id
}

# provision CIDR to the top-level pool
resource "aws_vpc_ipam_pool_cidr" "top_level" {
  ipam_pool_id = aws_vpc_ipam_pool.top_level.id
  cidr         = var.top_level_pool_cidr # "10.0.0.0/8" if following the tutorial
}

# create sub-level pools
resource "aws_vpc_ipam_pool" "regional" {
  for_each            = local.deduplicated_region_list
  description         = "${each.key}-pool"
  address_family      = "ipv4"
  ipam_scope_id       = aws_vpc_ipam.tutorial.private_default_scope_id
  locale              = each.key
  source_ipam_pool_id = aws_vpc_ipam_pool.top_level.id
}

resource "aws_vpc_ipam_pool_cidr" "regional" {
  for_each     = { for index, region in tolist(local.deduplicated_region_list) : region => index } # will be a map of region = it's index, for tutorial, its { us-east-1 = 0, us-west-2 = 1 } etc. # NEED TO CONVERT TO LIST
  ipam_pool_id = aws_vpc_ipam_pool.regional[each.key].id
  cidr         = cidrsubnet(var.top_level_pool_cidr, 8, each.value) # "10.0.0.0/16", "10.0.0.1/16" # NEED ABILITY TO USE NETMASK?
}
# > cidrsubnet("10.0.0.0/8", 8, 1)
# "10.1.0.0/16"
# > cidrsubnet("10.0.0.0/8", 8, 0)
# "10.0.0.0/16"

resource "aws_vpc" "tutorial" {
  ipv4_ipam_pool_id   = aws_vpc_ipam_pool.regional[var.region].id
  ipv4_netmask_length = 24 # demonstrating net mask instead of cidr block. not in tutorial. but achieves the same result
  depends_on = [
    aws_vpc_ipam_pool_cidr.regional
  ]
}
# TOOK VERY LONG TO DESTROY! 17 MINUTES TO DESTROY CIDR. MAY HAVE TO DESTROY A FEW TIMES. THE VPC NOT DELETED QUICK ENOUGH?