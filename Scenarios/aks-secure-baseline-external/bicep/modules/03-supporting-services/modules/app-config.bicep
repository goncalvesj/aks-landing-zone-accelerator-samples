targetScope = 'resourceGroup'

// ------------------
//    PARAMETERS
// ------------------

@description('The location where the resources will be created.')
param location string = resourceGroup().location

@description('The name of the Key Vault.')
param appConfigName string

@description('Optional. The tags to be assigned to the created resources.')
param tags object = {}

@description('The resource ID of the VNet to which the private endpoint will be connected.')
param spokeVNetId string

@description('The name of the subnet in the VNet to which the private endpoint will be connected.')
param spokePrivateEndpointSubnetName string

@description('The name of the private endpoint to be created.')
param appConfigPrivateEndpointName string

@description('The resource ID of the Hub Virtual Network.')
param hubVNetId string

// ------------------
// VARIABLES
// ------------------

var privateDnsZoneNames = 'privatelink.azconfig.io'
var resourceName = 'configurationStores'

var hubVNetIdTokens = split(hubVNetId, '/')
var hubVNetName = hubVNetIdTokens[8]

var spokeVNetIdTokens = split(spokeVNetId, '/')
var spokeSubscriptionId = spokeVNetIdTokens[2]
var spokeResourceGroupName = spokeVNetIdTokens[4]
var spokeVNetName = spokeVNetIdTokens[8]

var spokeVNetLinks = [
  {
    vnetName: spokeVNetName
    vnetId: spokeVNetId
    registrationEnabled: false
  }
  {
    vnetName: hubVNetName
    vnetId: hubVNetId
    registrationEnabled: false
  }
]
// ------------------
// RESOURCES
// ------------------

resource vnetSpoke 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  scope: resourceGroup(spokeSubscriptionId, spokeResourceGroupName)  
  name: spokeVNetName

}
resource spokePrivateEndpointSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' existing = {
  parent: vnetSpoke
  name: spokePrivateEndpointSubnetName
}

resource appConfig 'Microsoft.AppConfiguration/configurationStores@2023-03-01' = {
  name: appConfigName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
}

module appConfigNetwork '../../../../../shared/bicep/network/private-networking.bicep' = {
  name: 'keyVaultNetwork-${uniqueString(appConfig.id)}'
  params: {
    location: location
    azServicePrivateDnsZoneName: privateDnsZoneNames
    azServiceId: appConfig.id
    privateEndpointName: appConfigPrivateEndpointName
    privateEndpointSubResourceName: resourceName
    virtualNetworkLinks: spokeVNetLinks
    subnetId: spokePrivateEndpointSubnet.id
    vnetHubResourceId: hubVNetId
  }
}
