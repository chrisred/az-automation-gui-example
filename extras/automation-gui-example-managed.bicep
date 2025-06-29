@description('Region for the Static Web App (SWA Managed Function supported regions), other resources will deploy to the same region as the target resource group.')
@allowed(['eastus2','centralus','westus2','westeurope','eastasia'])
param staticWebAppRegion string
@description('Name of the Managed Identity created in the pre-deploy steps.')
param deploymentScriptIdentityName string = 'id-automation-gui-example-deploy'
@description('Name for the App Registration created during deployment.')
param appRegistrationName string = 'automation-gui-example'
@description('Name for the Storage Account resource.')
param storageAccountName string = 'stautoguiexample${substring(uniqueString(resourceGroup().id),0,5)}'
@description('Name for the Automation Account resource.')
param automationAccountName string = 'aa-automation-gui-example'
@description('DO NOT CHANGE. Expiry time (now +1 year) for the Runbook web hooks used by the Static Web App API.')
param runbookWebhookExpiryTime string = dateTimeAdd(utcNow('u'), 'P1Y')
@description('Name for the Static Web App resource.')
param staticWebAppName string = 'stapp-automation-gui-example'
@description('URL for the Github respository used for deployment.')
param githubRepositoryURL string

var appRegistraionNameArgument = '"${appRegistrationName}"'


resource readerRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
}

resource readerAndDataAccessRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'c12c1c16-33a1-487b-954d-41c89c60f349'
}

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'automation-gui-deploy-script'
  location: resourceGroup().location
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities',deploymentScriptIdentityName)}': {}
    }
  }
  properties: {
    forceUpdateTag: '1'
    azPowerShellVersion: '12.5.0'
    scriptContent: 'param([string] $Name); Connect-AzAccount -Identity; $Sp = New-AzADServicePrincipal -DisplayName $Name; $DeploymentScriptOutputs = @{\'PrincipalId\' = $Sp.Id; \'ClientId\' = $Sp.AppId; \'ClientSecret\' = $Sp.PasswordCredentials.SecretText};'
    arguments: '-Name ${appRegistraionNameArgument}'
    timeout: 'PT1H'
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
  }
}

// allow the App Registration (created by the deployment script) to read from the Automation Account
resource deploymentScriptRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  // use the deploymentScript.id for a unique value as the service principal ID is not usable yet
  name: guid(automationAccount.id, deploymentScript.id, readerRoleDefinition.id)
  scope: automationAccount
  properties: {
    roleDefinitionId: readerRoleDefinition.id
    principalId: deploymentScript.properties.outputs.PrincipalId
    principalType: 'ServicePrincipal'
  }
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

resource storageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  name: storageAccountName
  location: resourceGroup().location
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
}

resource automationAccount 'Microsoft.Automation/automationAccounts@2023-11-01' = {
  name: automationAccountName
  location: resourceGroup().location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    sku: {
      name: 'Basic'
    }
  }

  resource hybridRunbookWorkerGroup 'hybridRunbookWorkerGroups' = {
    name: automationAccountName
  }

  resource runbookExample 'runbooks' = {
    name: 'automation-gui-example'
    location: resourceGroup().location
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
    location: resourceGroup().location
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
    location: resourceGroup().location
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

resource staticWebApp 'Microsoft.Web/staticSites@2024-04-01' = {
  name: staticWebAppName
  location: staticWebAppRegion
  sku: {
    name: 'Free'
    tier: 'Free'
  }
  properties: {
    repositoryUrl: githubRepositoryURL
    branch: 'master'
    stagingEnvironmentPolicy: 'Enabled'
    allowConfigFileUpdates: true
    provider: 'GitHub'
    enterpriseGradeCdnStatus: 'Disabled'
  }
  dependsOn: [
    deploymentScript
  ]

  resource staticWebAppSettings 'config' = {
    name: 'appsettings'
    kind: 'string'
    properties: {
      AUTOMATION_ACCOUNT_NAME: automationAccountName
      AUTOMATION_GROUP_NAME: resourceGroup().name
      AZURE_CLIENT_ID: deploymentScript.properties.outputs.ClientId
      AZURE_CLIENT_SECRET: deploymentScript.properties.outputs.ClientSecret
      AZURE_SUBSCRIPTION_ID: subscription().subscriptionId
      AZURE_TENANT_ID: subscription().tenantId
      WEBHOOK_RUNBOOK: reference(automationAccount::runbookExampleWebhook.name).uri
      WEBHOOK_HYBRID: reference(automationAccount::hybridRunbookExampleWebhook.name).uri
      STORAGE_CONNECTION_STRING: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${listKeys(storageAccountName,'2024-01-01').keys[0].value}'
    }
    dependsOn: [
      storageAccount
    ]
  }
}
