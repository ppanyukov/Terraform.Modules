# Azure Active Directory Group Members

This folder contains a Terraform module to manage group membership in Azure Active Directory (AAD).

Motivation for the module:

* Display Terraform Plan which is meaningful.

    The raw resource `azuread_group_member` only shows object IDs
    which makes it impossible to make judgement whether the assignment is correct. See: https://github.com/hashicorp/terraform-provider-azuread/issues/390


* Make it a simple one-stop shop for all group membership operations using familiar names, including:
    * Group members.
    * User members.
    * Managed Identity members.
    * Service Principal members (TODO).


## How to use this module?

This folder defines a Terraform module, which you can use in your code by adding a module configuration and setting its source parameter to URL of this folder: 



```hcl
# Managed identify, we create it here.
resource "azurerm_user_assigned_identity" "my_msi_resource" {
  location            = "westeurope"
  resource_group_name = "example"
  name                = "my-msi-resource"
}

# Managed identify, already existing.
data "azurerm_user_assigned_identity" "my_msi_data" {
  location            = "westeurope"
  resource_group_name = "example"
  name                = "my-msi-data"
}

module "aad_group_members" {
  source = "github.com/ppanyukov/Terraform.Modules//azure/aad_group_members"

  # Specify the name of the group to add members to.
  group_name = "target_group_name"

  # Optional. Specify the list of group names to add as members.
  member_group_names = [
    "member_group_1",
    "member_group_2",
  ]

  # Optional. Specify the list of user names to add as members. These are email addresses as shown in AAD.
  member_user_names = [
    "user1@myorg.com"
    "user2@myorg.com"
  ]

  # Optional. Specify the list of Managed Identities to add as members.
  # You can use values of 'resource.azurerm_user_assigned_identity' or 'data.azurerm_user_assigned_identity' directly here.
  # Or you can specify MSI directly.
  member_msi_names = [
    # reference a resource
    azurerm_user_assigned_identity.my_msi_resource,

    # reference data
    data.azurerm_user_assigned_identity.my_msi_data,

    # or specify directly here
    {
        resource_group_name = "example"
        name                = "my-msi-direct"
    },
  ]
}
```

## Notes

* All objects (groups, users, managed identities, service principals) must already exist. This module does not manage these as a resource, it only manages group membership.

* The user or service principal performing terraform operation with this module must have at least the following permissions in AAD:

    * `Directory readers`: Users in this role can read basic directory information.

    * Must be an **owner** of the target group to which members are added. (probably the best approach)

    * OR. Must have `Groups administrator`. **NOT RECOMMENDED!**

## Sample plan output

Given the above HCL, when you do `terraform plan`, the output will be like follows. Note that now it is easy to see what gets added to which group.

```hcl
# module.aad_group_members.azuread_group_member.group["member_group_1 in target_group_name"]:
resource "azuread_group_member" "group" {
    group_object_id  = "11111111-5687-4682-aa95-9bafae2f2f86"
    id               = "11111111-5687-4682-aa95-9bafae2f2f86/member/11111111-b263-4379-bc84-b17e59de27fa"
    member_object_id = "11111111-b263-4379-bc84-b17e59de27fa"
}

# module.aad_group_members.azuread_group_member.group["member_group_2 in target_group_name"]:
resource "azuread_group_member" "group" {
    group_object_id  = "11111111-5687-4682-aa95-9bafae2f2f86"
    id               = "11111111-5687-4682-aa95-9bafae2f2f86/member/11111111-b263-4379-bc84-b17e59de27fa"
    member_object_id = "11111111-b263-4379-bc84-b17e59de27fa"
}

# module.aad_group_members.azuread_group_member.user["user1@myorg.com in target_group_name"]:
resource "azuread_group_member" "user" {
    group_object_id  = "11111111-5687-4682-aa95-9bafae2f2f86"
    id               = "11111111-5687-4682-aa95-9bafae2f2f86/member/11111111-c18a-404b-8f76-97df7439c2c6"
    member_object_id = "11111111-c18a-404b-8f76-97df7439c2c6"
}

# module.aad_group_members.azuread_group_member.user["user2@myorg.com in target_group_name"]:
resource "azuread_group_member" "user" {
    group_object_id  = "11111111-5687-4682-aa95-9bafae2f2f86"
    id               = "11111111-5687-4682-aa95-9bafae2f2f86/member/11111111-c18a-404b-8f76-97df7439c2c6"
    member_object_id = "11111111-c18a-404b-8f76-97df7439c2c6"
}

# module.aad_group_members.azuread_group_member.msi["my-msi-resource in target_group_name"]:
resource "azuread_group_member" "msi" {
    group_object_id  = "11111111-5687-4682-aa95-9bafae2f2f86"
    id               = "11111111-5687-4682-aa95-9bafae2f2f86/member/11111111-c18a-404b-8f76-97df7439c2c6"
    member_object_id = "11111111-c18a-404b-8f76-97df7439c2c6"
}

# module.aad_group_members.azuread_group_member.msi["my-msi-data in target_group_name"]:
resource "azuread_group_member" "msi" {
    group_object_id  = "11111111-5687-4682-aa95-9bafae2f2f86"
    id               = "11111111-5687-4682-aa95-9bafae2f2f86/member/11111111-c18a-404b-8f76-97df7439c2c6"
    member_object_id = "11111111-c18a-404b-8f76-97df7439c2c6"
}

# module.aad_group_members.azuread_group_member.msi["my-msi-direct in target_group_name"]:
resource "azuread_group_member" "msi" {
    group_object_id  = "11111111-5687-4682-aa95-9bafae2f2f86"
    id               = "11111111-5687-4682-aa95-9bafae2f2f86/member/11111111-c18a-404b-8f76-97df7439c2c6"
    member_object_id = "11111111-c18a-404b-8f76-97df7439c2c6"
}
```



