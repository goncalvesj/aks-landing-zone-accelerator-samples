param location string
param name string
param aksNodeRg string
param aksIssuerURL string
param spokeResourceGroup string
param albSubnetId string

// resource agw4c 'Microsoft.ServiceNetworking/trafficControllers@2023-11-01' = {
//   name: name
//   location: location
// }

module albUserAssignedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.2.1' = {
  name: take('agw4cidentity-${deployment().name}-deployment', 64)
  scope: resourceGroup(spokeResourceGroup)
  params: {
    name: '${name}-identity'
    location: location
    federatedIdentityCredentials: [
      {
        name: 'azure-alb-identity'
        issuer: aksIssuerURL //aks.outputs.issuerURL
        subject: 'system:serviceaccount:azure-alb-system:alb-controller-sa'
        audiences: [
          'api://AzureADTokenExchange'
        ]
      }
    ]
  }
}

module subnetRoleAssigment 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.0' = {
  name: take('agw4csubnetrole-${deployment().name}-deployment', 64)
  scope: resourceGroup(spokeResourceGroup)
  params: {
    principalId: albUserAssignedIdentity.outputs.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: '4d97b98b-1d4f-4787-a291-c67834d212e7' // Network Contributor
    resourceId: albSubnetId //spokeVnet.outputs.subnetResourceIds[2]
  }
}

// Role Assignment for AKS Node Resource Group
module aksNodeRgRoleAssigment '../../roles.bicep' = {
  name: take('agw4caksrole-${deployment().name}-deployment', 64)
  scope: resourceGroup(aksNodeRg) //aksNodeRg
  params: {
    principalId: albUserAssignedIdentity.outputs.principalId
    roleName: 'fbc52c3f-28ad-4303-a892-8a056630b8f1' // AppGw for Containers Configuration Manager
  }
}
