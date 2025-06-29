@description('Region for the Static Web App (SWA Managed Function supported regions), other resources will deploy to the same region as the target resource group.')
@allowed(['eastus2','centralus','westus2','westeurope','eastasia'])
param staticWebAppRegion string
@description('Name for the Storage Account resource.')
param storageAccountName string = 'stautoguiexample${substring(uniqueString(resourceGroup().id),0,5)}'
@description('Name for the App Service plan resource.')
param appServicePlanName string = 'asp-automation-gui-example'
@description('Name for the Function App resource.')
param functionAppName string = 'func-automation-gui-example'
@description('Name for the Automation Account resource.')
param automationAccountName string = 'aa-automation-gui-example'
@description('DO NOT CHANGE. Expiry time (now +1 year) for the Runbook web hooks used by the Static Web App API.')
param runbookWebhookExpiryTime string = dateTimeAdd(utcNow('u'), 'P1Y')
@description('Name for the Static Web App resource.')
param staticWebAppName string = 'stapp-automation-gui-example'
@description('URL for the Github respository used for deployment.')
param githubRepositoryURL string
@description('Name for the Managed Identity resource used to deploy the Function App code.')
param managedIdentityName string = 'id-automation-gui-example-deploy'

var location = resourceGroup().location
var uniqueName = substring(uniqueString(resourceGroup().id),0,5)


resource readerRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
}

resource readerAndDataAccessRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'c12c1c16-33a1-487b-954d-41c89c60f349'
}

resource StorageBlobDataOwnerRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
}

resource websiteContributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'de139f84-1756-47ae-9be6-808fbbe84772'
}

// allow the Automation Account identity to read and write to the Storage Account
resource automationAccountRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, automationAccount.id, readerAndDataAccessRoleDefinition.id)
  scope: storageAccount
  properties: {
    roleDefinitionId: readerAndDataAccessRoleDefinition.id
    principalId: automationAccount.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// allow the Function App identity to read and write to the Storage Account Blob service
resource functionAppStorageRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, functionApp.id, StorageBlobDataOwnerRoleDefinition.id)
  scope: storageAccount
  properties: {
    roleDefinitionId: StorageBlobDataOwnerRoleDefinition.id
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// allow the Function App identity to read from the Automation Account
resource functionAppReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(automationAccount.id, functionApp.id, readerRoleDefinition.id)
  scope: automationAccount
  properties: {
    roleDefinitionId: readerRoleDefinition.id
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// allow the User Assigned Managed Identity to deploy code to the Function App
resource websiteContribuRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(functionApp.id, managedIdentity.id, websiteContributorRoleDefinition.id)
  scope: functionApp
  properties: {
    roleDefinitionId: websiteContributorRoleDefinition.id
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  name: managedIdentityName
  location: location
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'

  resource storageAccountService 'tableServices' = {
    name: 'default'

    resource storageAccountTable 'tables' = {
      name: 'formData'
    }
  }

  resource storageAccountBlob 'blobServices' = {
    name: 'default'

    resource storageAccountContainer 'containers' = {
      name: 'app-package-${functionAppName}-${uniqueName}'
    }
  }
}

resource automationAccount 'Microsoft.Automation/automationAccounts@2023-11-01' = {
  name: automationAccountName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    sku: {
      name: 'Basic'
    }
  }

  resource hybridRunbookWorkerGroup 'hybridRunbookWorkerGroups' = {
    name: 'automation-gui-example'
  }

  resource runbookExample 'runbooks' = {
    name: 'automation-gui-example'
    location: location
    properties: {
      runbookType: 'PowerShell'
      description: ''
      publishContentLink: {
        uri: 'https://raw.githubusercontent.com/chrisred/az-automation-gui-example/master/extras/RunbookExample.ps1'
        version: '1.0.0.0'
      }
    }
  }

  resource runbookExampleWebhook 'webhooks@2015-10-31' = {
    name: 'automation-gui-example-api'
    properties: {
      expiryTime: runbookWebhookExpiryTime 
      isEnabled: true
      parameters: {}
      runbook: {
        name: 'automation-gui-example'
      }
    }
    dependsOn: [
      runbookExample
    ]
  }

  resource hybridRunbookExample 'runbooks' = {
    name: 'automation-gui-example-hybrid'
    location: location
    properties: {
      runbookType: 'PowerShell'
      description: ''
      publishContentLink: {
        uri: 'https://raw.githubusercontent.com/chrisred/az-automation-gui-example/master/extras/HybridExample.ps1'
        version: '1.0.0.0'
      }
    }
  }

  resource hybridRunbookExampleWebhook 'webhooks@2015-10-31' = {
    name: 'automation-gui-example-hybrid-api'
    properties: {
      expiryTime: runbookWebhookExpiryTime 
      isEnabled: true
      parameters: {}
      runbook: {
        name: 'automation-gui-example-hybrid'
      }
      runOn: automationAccountName
    }
    dependsOn: [
      hybridRunbookExample
    ]
  }

  resource hybridRunBookSyncExample 'runbooks' = {
    name: 'automation-gui-example-sync'
    location: location
    properties: {
      runbookType: 'PowerShell'
      description: ''
      publishContentLink: {
        uri: 'https://raw.githubusercontent.com/chrisred/az-automation-gui-example/master/extras/HybridSyncJob.ps1'
        version: '1.0.0.0'
      }
    }
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: 'FC1'
    tier: 'FlexConsumption'
  }
  kind: 'functionapp'
  properties: {
    reserved: true
    zoneRedundant: false
  }
}

resource functionApp 'Microsoft.Web/sites@2024-04-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    functionAppConfig: {
      runtime: {
        name: 'python'
        version: '3.10'
      }
      deployment: {
        storage: {
          type: 'blobContainer'
          // primaryEndpoints.blob has a trailing slash
          value: '${storageAccount.properties.primaryEndpoints.blob}app-package-${functionAppName}-${uniqueName}'
          authentication: {
            type: 'SystemAssignedIdentity'
          }
        }
      }
      scaleAndConcurrency: {
        instanceMemoryMB: 512
        maximumInstanceCount: 100
      }
    }
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage__credential'
          value: 'managedidentity'
        }
        {
          name: 'AzureWebJobsStorage__accountName'
          value: storageAccount.name
        }
        {
          name: 'AzureWebJobsStorage__blobServiceUri'
          value: storageAccount.properties.primaryEndpoints.blob
        }
        {
          name: 'AzureWebJobsStorage__queueServiceUri'
          value: storageAccount.properties.primaryEndpoints.queue
        }
        {
          name: 'AzureWebJobsStorage__tableServiceUri'
          value: storageAccount.properties.primaryEndpoints.table
        }
        {
          name: 'AZURE_SUBSCRIPTION_ID'
          value: subscription().subscriptionId
        }
        {
          name: 'AUTOMATION_ACCOUNT_NAME'
          value: automationAccountName
        }
        {
          name: 'AUTOMATION_GROUP_NAME'
          value: resourceGroup().name
        }
        {
          name: 'WEBHOOK_RUNBOOK'
          value: reference(automationAccount::runbookExampleWebhook.name).uri
        }
        {
          name: 'WEBHOOK_HYBRID'
          value: reference(automationAccount::hybridRunbookExampleWebhook.name).uri
        }
      ]
    }
  }
}

resource staticWebApp 'Microsoft.Web/staticSites@2024-04-01' = {
  name: staticWebAppName
  location: staticWebAppRegion
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  properties: {
    repositoryUrl: githubRepositoryURL
    branch: 'master'
    stagingEnvironmentPolicy: 'Enabled'
    allowConfigFileUpdates: true
    provider: 'GitHub'
    enterpriseGradeCdnStatus: 'Disabled'
  }

  resource linkedBackend 'linkedBackends' = {
    name: 'backend1'
    properties: {
      backendResourceId: functionApp.id
      region: location
    }
  }
}
