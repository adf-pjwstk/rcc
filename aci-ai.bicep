@description('Student or lab identifier suffix (e.g. s10001)')
param studentId string = 's10001'

@description('Azure Container Registry username / registry prefix')
param registryUsername string

@description('Azure Container Registry password')
@secure()
param registryPassword string

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Cognitive Services Kind')
param aiKind string = 'ComputerVision'

@description('Cognitive Services SKU')
param aiSku string = 'S1'

@description('Name of the Azure Container Instance')
param aciName string = 'aci-vision'

@description('Container image repository path')
param imageRepository string = 'rcc/image-recognition'

@description('Container image tag')
param imageTag string = 'latest'

@description('Port exposed by the container')
param aciPort int = 80

@description('Number of vCPUs allocated to the container')
param aciCpu int = 1

@description('RAM in GB allocated to the container')
param aciRam int = 1

// Derived variables
var aiName = 'vision-${studentId}'
var aciDnsNameLabel = 'aci-${aiName}'
var registryServer = '${registryUsername}.azurecr.io'
var fullImageUri = '${registryServer}/${imageRepository}:${imageTag}'


// 1. Azure AI Vision (Cognitive Services) Account
resource visionAccount 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: aiName
  location: location
  kind: aiKind
  sku: {
    name: aiSku
  }
  properties: {
    publicNetworkAccess: 'Enabled'
  }
}

// 2. Azure Container Instance (ACI) Group
resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: aciName
  location: location
  properties: {
    osType: 'Linux'
    restartPolicy: 'Always'
    imageRegistryCredentials: [
      {
        server: registryServer
        username: registryUsername
        password: registryPassword
      }
    ]
    containers: [
      {
        name: aciName
        properties: {
          image: fullImageUri
          resources: {
            requests: {
              cpu: aciCpu
              memoryInGB: aciRam
            }
          }
          ports: [
            {
              port: aciPort
              protocol: 'TCP'
            }
          ]
          environmentVariables: [
            {
              name: 'AZURE_ENDPOINT'
              value: visionAccount.properties.endpoint
            }
            {
              name: 'AZURE_KEY'
              secureValue: visionAccount.listKeys().key1
            }
          ]
        }
      }
    ]
    ipAddress: {
      type: 'Public'
      dnsNameLabel: aciDnsNameLabel
      ports: [
        {
          port: aciPort
          protocol: 'TCP'
        }
      ]
    }
  }
}

// Outputs
output fqdn string = containerGroup.properties.ipAddress.fqdn
output publicIp string = containerGroup.properties.ipAddress.ip
