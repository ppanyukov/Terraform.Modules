# Adds members to the specified Azure Active Directory group.
# Displays plan which is easy to verify.
variable "group_name" {
  type        = string
  description = "The name of Azure Active Directory group to add members to."
}

variable "member_group_names" {
  type        = list(string)
  description = "List of group names to add as members of the group."
  default     = []
}

variable "member_user_names" {
  type        = list(string)
  description = "List of user names (email addresses) to add as members of the group."
  default     = []
}

locals {
  # Create the set of group members so that the key
  # is descriptive and shows which member gets added to which group.
  # This is to work around that the plan only shows object IDs which
  # makes it imossible to make judgement whether the assignment is 
  # what we actually want.
  group_members = {
    for member_name in var.member_group_names :
    "${member_name} in ${var.group_name}" => {
      group_name  = var.group_name
      member_name = member_name
    }
  }

  user_members = {
    for member_name in var.member_user_names :
    "${member_name} in ${var.group_name}" => {
      group_name  = var.group_name
      member_name = member_name
    }
  }
}

data "azuread_group" "target_group" {
  display_name = var.group_name
}

data "azuread_group" "group_to_add_as_member" {
  for_each     = local.group_members
  display_name = each.value.member_name
}

data "azuread_user" "user_to_add_as_member" {
  for_each            = local.user_members
  user_principal_name = each.value.member_name
}

resource "azuread_group_member" "group" {
  for_each         = local.group_members
  group_object_id  = data.azuread_group.target_group.id
  member_object_id = data.azuread_group.group_to_add_as_member[each.key].id
}

resource "azuread_group_member" "user" {
  for_each         = local.user_members
  group_object_id  = data.azuread_group.target_group.id
  member_object_id = data.azuread_user.user_to_add_as_member[each.key].id
}


