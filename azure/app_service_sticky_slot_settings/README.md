## How to make app settings sticky with ARM and Terraform

App Services and Function Apps in Azure have Slots and App Settings.

When we swap slots, all App Settings are also swapped. This is generally the most common scenario for me.

However there are times when you want to make some app settings "sticky". This means that when you swap slots, these settings remain where they are, they do not travel to the target slot.

So how do you do this?

* Portal clicketty click -- easy!
* Azure CLI -- also easy(ish).
* Terraform? No can do.
* ARM templates? Hmmm, try googling that.
* Raw Azure RM API? Hmmm, good luck there too.

And so, without further faff, here is the solution and _explanation_ what this does.

### ARM Template

Given app service with the name `my-app-service`, the following will make all app settings with specified names sticky _in all slots_.


```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
  },
  "variables": {},
  "resources": [
    {
      "apiVersion": "2019-08-01",
      "name": "my-app-service/slotConfigNames",
      "properties": {
        "appSettingNames": [
          "DurableTaskHubName",
          "MyAppSetting"
        ]
      },
      "type": "Microsoft.Web/sites/config"
    }
  ]
}
```

Crucial things to note here:

* The "stickiness" is a _separate resource_ and so can be applied independenty. The above template is self-sufficient.
* It applies to the _entire app as a whole, for all slots_.
* This template _marks existing app settings as sticky_. The values for these settings are specified as per other usual means.
* The `name` property is what is super-important here. It _must_ be in the form `<app_service_name>/slotConfigNames`.
* If you remove an item from `appSettingNames` array, this will remove stickiness from the removed app setting, but only stickiness.


So here you are.

### Terraform

There is no native support for this in terraform at the moment (June 2021). But there is support for ARM templates there. And so we can do it like this in terraform.


```hcl
locals {
  # We will create a function app with this name, and one slot called deploy.
  app_service_name    = "my-app-service"
  deploy_slot_name    = "deploy"
  location            = "westeurope"
  resource_group_name = "example"
}

# Create function app (can be a regular app service)
# and specify values of app settings as per normal.
resource "azurerm_function_app" "main_app" {
  name                = local.app_service_name
  location            = local.location
  resource_group_name = local.resource_group_name

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"    = "dotnet"
    "ASPNETCORE_DETAILEDERRORS"   = "false"
    "AZURE_FUNCTIONS_ENVIRONMENT" = "Development"

    # NOTE: these settings are made sticky separately at the bottom.
    DurableTaskHubName = "sticky value of DurableTaskHubName in the main slot"
    MyAppSetting       = "sticky value of MyAppSetting in the main slot"
  }
}

# Create a slot named "deploy" or any other name for the function app
# and also specify values of app settings as per normal.
resource "azurerm_function_app_slot" "deploy_slot" {

  function_app_name = local.app_service_name
  name              = local.deploy_slot_name

  location            = local.location
  resource_group_name = local.resource_group_name

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"    = "dotnet"
    "ASPNETCORE_DETAILEDERRORS"   = "false"
    "AZURE_FUNCTIONS_ENVIRONMENT" = "Development"

    # NOTE: these settings are made sticky separately at the bottom.
    DurableTaskHubName = "sticky value of DurableTaskHubName in the deploy slot"
    MyAppSetting       = "sticky value of MyAppSetting in the deploy slot"
  }
}

# Make desired app settings sticky in all slots.
resource "azurerm_resource_group_template_deployment" "sticky_app_settings" {
  # Make sure to specify this dependency as otherwise terraform may start
  # this ARM template deployment before the function app and slot are ready.
  depends_on = [
    azurerm_function_app.main_app,
    azurerm_function_app_slot.deploy_slot,
  ]

  name                = "my-app-service-sticky-app-settings"
  resource_group_name = "example"


  # This must NEVER EVER be set to Complete as it will zap everything in the resource group!
  deployment_mode = "Incremental"


  template_content = <<EOT
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
  },
  "variables": {},
  "resources": [
    {
      "apiVersion": "2019-08-01",
      "name": "${local.app_service_name}/slotConfigNames",
      "properties": {
        "appSettingNames": [
          "DurableTaskHubName",
          "MyAppSetting"
        ]
      },
      "type": "Microsoft.Web/sites/config"
    }
  ]
}
EOT
}

```

And here you are, easy :) 

I might wrap this ARM thing in a module unless terraform adds it natively soon.

----

### Obligatory moaning

Well, it took me _ages_ to figure out this ARM template (hours of frustration). If you google, you will see tons of people have this question, but there are no good answers.

Even when there _are_ answers, they are so cryptic and actually don't explain what this template does, what happens etc.

I could not find any official Microsoft docs on the subject. 

The docs for raw Azure RM API -- lets say they were not helpful for this scenario and I couldn't figure it out from there.

In the end I had to combine existing cryptic half-answers I found in random places with the debug output from Azure CLI to see which Azure RM API calls exactly it's making, and then it clicked.

I whish this specific scenario was documented somewhere in the official docs and surfaced up better. Hopefully one day.

Oh and I wish there was a standard support for this in terraform, so that I don't have to do this ARM-in-Terraform thing as this approach has its own issues.

----

Side note: why to _list_ App Settings we need to do HTTP _POST_ to Azure RM API? This doesn't make any sense to me :) But it may explain why you can't see App Settings if you only have Reader role. I really want this changed as this causes massive headaches. See [List App Settings API Reference].

<img width="1463" alt="image" src="https://user-images.githubusercontent.com/300031/122408513-5beab400-cf7a-11eb-87e8-feb40e465c10.png">


[List App Settings API Reference]: https://docs.microsoft.com/en-us/rest/api/appservice/web-apps/list-application-settings



