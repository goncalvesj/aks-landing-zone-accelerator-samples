targetScope = 'resourceGroup'

// ------------------
//    PARAMETERS
// ------------------

@description('The location where the resources will be created. This needs to be the same region as the Azure Container Apps instances.')
param location string = resourceGroup().location

@description('Optional. The tags to be assigned to the created resources.')
param tags object = {}

@description('Optional. The name of the Container App. If set, it overrides the name generated by the template.')
@minLength(2)
@maxLength(32)
param containerAppName string = 'ca-simple-hello'

@description('Optional. The name of the Container App. If set, it overrides the name generated by the template.')
@minLength(2)
param containerAppImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@description('Optional. If using public images keep empty. The resource ID of the existing user-assigned managed identity to be assigned to the Container App to be able to pull images from the container registry.')
param containerRegistryUserAssignedIdentityId string = ''

@description('The resource ID of the existing Container Apps environment in which the Container App will be deployed.')
param containerAppsEnvironmentId string

var acaIdentity = containerRegistryUserAssignedIdentityId == '' ? {
  type: 'None'
} : {
  type: 'UserAssigned'
  userAssignedIdentities: {
    '${containerRegistryUserAssignedIdentityId}': {}
  }
}

// ------------------
// RESOURCES
// ------------------

@description('The Container App.')
resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: containerAppName
  location: location
  tags: tags
  identity: acaIdentity
  properties: {
    configuration: {
      activeRevisionsMode: 'single'
      ingress: {
        allowInsecure: false
        external: true
        targetPort: 80
        transport: 'auto'
      }
      registries: []
      secrets: []
    }
    environmentId: containerAppsEnvironmentId
    workloadProfileName: 'Consumption'
    template: {
      containers: [
        {
          name: containerAppName
          // Production readiness change
          // All workloads should be pulled from your private container registry and not public registries.
          image: containerAppImage
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 5
      }
      volumes: []
    }
  }
}

// ------------------
// OUTPUTS
// ------------------

@description('The FQDN of the Container App.')
output acaAppFqdn string = containerApp.properties.configuration.ingress.fqdn
