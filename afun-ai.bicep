@description('Student identifier suffix (e.g. s10001)')
param studentId string

@description('Azure region for resources')
param location string = resourceGroup().location

var aiName = 'lang-${studentId}'
var appName = 'fn-sentiment-${studentId}'
var storageName = 'st${take(replace(studentId, '-', ''), 14)}fn'
var hostingPlanName = 'asp-${studentId}'

// Azure AI Language Resource (F0 Free or S Standard)
resource languageAccount 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: aiName
  location: location
  kind: 'TextAnalytics'
  sku: {
    name: 'S' 
  }
  properties: {
    publicNetworkAccess: 'Enabled'
  }
}

// Storage Account required by Azure Functions runtime
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

// Consumption (Serverless) Hosting Plan
resource hostingPlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: hostingPlanName
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {
    reserved: true
  }
}

// Linux Function App
resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: appName
  location: location
  kind: 'functionapp,linux'
  properties: {
    serverFarmId: hostingPlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'NODE|20'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'AzureWebJobsFeatureFlags'
          value: 'EnableWorkerIndexing'
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'false'
        }
        {
          name: 'AZURE_LANGUAGE_ENDPOINT'
          value: languageAccount.properties.endpoint
        }
        {
          name: 'AZURE_LANGUAGE_KEY'
          value: languageAccount.listKeys().key1
        }
      ]
    }
  }
}

output functionUrl string = 'https://${functionApp.properties.defaultHostName}'