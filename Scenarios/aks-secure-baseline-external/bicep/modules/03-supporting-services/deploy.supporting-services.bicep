targetScope = 'resourceGroup'

// ------------------
//    PARAMETERS
// ------------------

@description('The name of the workload that is being deployed. Up to 10 characters long.')
@minLength(2)
@maxLength(10)
param workloadName string

@description('The name of the environment (e.g. "dev", "test", "prod", "uat", "dr", "qa"). Up to 8 characters long.')
@maxLength(8)
param environment string

@description('The location where the resources will be created. This needs to be the same region as the spoke.')
param location string = resourceGroup().location

@description('Optional. The tags to be assigned to the created resources.')
param tags object = {}

// Hub
@description('The resource ID of the existing hub virtual network.')
param hubVNetId string

// Spoke
@description('The resource ID of the existing spoke virtual network to which the private endpoint will be connected.')
param spokeVNetId string

@description('The resource ID of the existing spoke subnet to which the db will be connected.')
param spokePostgresSubnetId string

@description('The name of the existing subnet in the spoke virtual to which the private endpoint will be connected.')
param spokePrivateEndpointSubnetName string

@description('Deploy Azure Container Registry')
param deployAcr bool

@description('Deploy Redis cache premium SKU')
param deployRedisCache bool

@description('Deploy (or not) an Azure OpenAI account. ATTENTION: At the time of writing this, OpenAI is in preview and only available in limited regions: look here: https://learn.microsoft.com/azure/ai-services/openai/chatgpt-quickstart#prerequisites')
param deployOpenAi bool

@description('Deploy (or not) a model on the openAI Account. This is used only as a sample to show how to deploy a model on the OpenAI account.')
param deployOpenAiGptModel bool = false

@description('Optional. Resource ID of the diagnostic log analytics workspace. If left empty, no diagnostics settings will be defined.')
param logAnalyticsWorkspaceId string = ''

@description('Optional, default value is true. If true, any resources that support AZ will be deployed in all three AZ. However if the selected region is not supporting AZ, this parameter needs to be set to false.')
param deployZoneRedundantResources bool = true

@description('Deploy Postgres database')
param deployPostgres bool

@description('The username to use for the db.')
param postgresAdminUsername string

@description('The password to use for the db.')
@secure()
param postgresAdminPassword string
// ------------------
// RESOURCES
// ------------------

@description('User-configured naming rules')
module naming '../../../../shared/bicep/naming/naming.module.bicep' = {
  name: take('03-sharedNamingDeployment-${deployment().name}', 64)
  params: {
    uniqueId: uniqueString(resourceGroup().id)
    environment: environment
    workloadName: workloadName
    location: location
  }
}

@description('Azure Container Registry, where all workload images should be pulled from.')
module containerRegistry 'modules/container-registry.module.bicep' = if (deployAcr) {
  name: 'containerRegistry-${uniqueString(resourceGroup().id)}'
  params: {
    containerRegistryName: naming.outputs.resourcesNames.containerRegistry
    location: location
    environment: environment
    tags: tags
    spokeVNetId: spokeVNetId
    hubVNetId: hubVNetId
    spokePrivateEndpointSubnetName: spokePrivateEndpointSubnetName
    containerRegistryPrivateEndpointName: naming.outputs.resourcesNames.containerRegistryPep
    containerRegistryUserAssignedIdentityName: naming.outputs.resourcesNames.containerRegistryUserAssignedIdentity
    diagnosticWorkspaceId: logAnalyticsWorkspaceId
    deployZoneRedundantResources: deployZoneRedundantResources
  }
}

@description('Azure Key Vault used to hold items like TLS certs and application secrets that your workload will need.')
module keyVault 'modules/key-vault.bicep' = {
  name: 'keyVault-${uniqueString(resourceGroup().id)}'
  params: {
    keyVaultName: naming.outputs.resourcesNames.keyVault
    location: location
    tags: tags
    spokeVNetId: spokeVNetId
    hubVNetId: hubVNetId
    spokePrivateEndpointSubnetName: spokePrivateEndpointSubnetName
    keyVaultPrivateEndpointName: naming.outputs.resourcesNames.keyVaultPep
    diagnosticWorkspaceId: logAnalyticsWorkspaceId
  }
}

// module appConfig 'modules/app-config.bicep' = {
//   name: 'appConfig-${uniqueString(resourceGroup().id)}'
//   params: {
//     appConfigName: naming.outputs.resourcesNames.appConfiguration
//     appConfigPrivateEndpointName: naming.outputs.resourcesNames.appConfigurationPep
//     spokePrivateEndpointSubnetName: spokePrivateEndpointSubnetName
//     spokeVNetId: spokeVNetId
//     hubVNetId: hubVNetId
//     location: location
//     tags: tags
//   }
// }

// module storage 'modules/storage.bicep' = {
//   name: 'storage-${uniqueString(resourceGroup().id)}'
//   params: {
//     storageName: naming.outputs.resourcesNames.storageAccount
//     storagePrivateEndpointName: naming.outputs.resourcesNames.storageAccountPep
//     spokeVNetId: spokeVNetId
//     spokePrivateEndpointSubnetName: spokePrivateEndpointSubnetName
//     hubVNetId: hubVNetId
//     location: location
//     tags: tags
//   }
// }

module postgres 'modules/postgres.bicep' = if (deployPostgres) {
  name: 'postgres-${uniqueString(resourceGroup().id)}'
  params: {
    hubVNetId: hubVNetId
    name: naming.outputs.resourcesNames.postgres
    spokeSubnetId: spokePostgresSubnetId
    spokeVNetId: spokeVNetId
    location: location
    tags: tags
    postgresAdminPassword: postgresAdminPassword
    postgresAdminUsername: postgresAdminUsername
  }
}

module redisCache 'modules/redis-cache.bicep' = if (deployRedisCache) {
  name: 'redisCache-${uniqueString(resourceGroup().id)}'
  params: {
    location: location
    redisName: naming.outputs.resourcesNames.redisCache
    logAnalyticsWsId: logAnalyticsWorkspaceId
    keyVaultName: keyVault.outputs.keyVaultName
    spokeVNetId: spokeVNetId
    hubVNetId: hubVNetId
    spokePrivateEndpointSubnetName: spokePrivateEndpointSubnetName
    redisCachePrivateEndpointName: naming.outputs.resourcesNames.redisCachePep
  }
}

module openAi 'modules/open-ai.module.bicep' = if (deployOpenAi) {
  name: take('openAiModule-Deployment', 64)
  params: {
    name: naming.outputs.resourcesNames.openAiAccount
    deploymentName: naming.outputs.resourcesNames.openAiDeployment
    location: location
    tags: tags
    vnetHubResourceId: hubVNetId
    logAnalyticsWsId: logAnalyticsWorkspaceId
    deployOpenAiGptModel: deployOpenAiGptModel
    spokeVNetId: spokeVNetId
    hubVNetId: hubVNetId
    spokePrivateEndpointSubnetName: spokePrivateEndpointSubnetName
  }
}

// ------------------
// OUTPUTS
// ------------------

@description('The resource ID of the Azure Container Registry.')
output containerRegistryId string = (deployAcr) ? containerRegistry.outputs.containerRegistryId : ''

@description('The name of the Azure Container Registry.')
output containerRegistryName string = (deployAcr) ? containerRegistry.outputs.containerRegistryName : ''

@description('The resource ID of the user-assigned managed identity for the Azure Container Registry to be able to pull images from it.')
output containerRegistryUserAssignedIdentityId string = (deployAcr) ? containerRegistry.outputs.containerRegistryUserAssignedIdentityId : ''

@description('The resource ID of the Azure Key Vault.')
output keyVaultId string = keyVault.outputs.keyVaultId

@description('The name of the Azure Key Vault.')
output keyVaultName string = keyVault.outputs.keyVaultName

@description('The secret name to retrieve the connection string from KeyVault')
output redisCacheSecretKey string = (deployRedisCache) ? redisCache.outputs.redisCacheSecretKey : ''
