targetScope = 'resourceGroup'

// ------------------
//    PARAMETERS
// ------------------

@description('The location where the resources will be created.')
param location string = resourceGroup().location

@description('The name of the Postres Server.')
param name string = 'pg-hha-dev-neu'

@description('Optional. The tags to be assigned to the created resources.')
param tags object = {}

@description('The username to use for the db.')
param postgresAdminUsername string

@description('The password to use for the db.')
@secure()
param postgresAdminPassword string

@description('The resource ID of the Hub Virtual Network.')
param hubVNetId string = '/subscriptions/5f65d157-b99f-470b-a9bb-e62bd4fee225/resourceGroups/rg-hha-hub-dev-neu/providers/Microsoft.Network/virtualNetworks/vnet-dev-neu-hub'

@description('The resource ID of the VNet to which the private endpoint will be connected.')
param spokeVNetId string = '/subscriptions/5f65d157-b99f-470b-a9bb-e62bd4fee225/resourceGroups/rg-hha-spoke-dev-neu/providers/Microsoft.Network/virtualNetworks/vnet-hha-dev-neu-spoke'

@description('The resource ID of the Subnet to which the Postgres Server will be connected.')
param spokeSubnetId string = 'subscriptions/5f65d157-b99f-470b-a9bb-e62bd4fee225/resourceGroups/rg-hha-spoke-dev-neu/providers/Microsoft.Network/virtualNetworks/vnet-hha-dev-neu-spoke/subnets/snet-postgres'

// ------------------
//    VARIABLES
// ------------------
var azServicePrivateDnsZoneName = '${name}.private.postgres.database.azure.com'
var vnetHubSplitTokens = !empty(hubVNetId) ? split(hubVNetId, '/') : array('')
var privateEndpointSubResourceName = 'postgres'

var spokeVNetIdTokens = split(spokeVNetId, '/')
var spokeVNetName = spokeVNetIdTokens[8]

var spokeVNetLinks = [
  {
    vnetName: spokeVNetName
    vnetId: spokeVNetId
    registrationEnabled: false
  }
]

module privateDNS '../../../../../shared/bicep/network/private-dns-zone.bicep' = {
  scope: resourceGroup(vnetHubSplitTokens[2], vnetHubSplitTokens[4])
  name: 'privateDnsZoneDeployment-${uniqueString(name, privateEndpointSubResourceName)}'
  params: {
    name: azServicePrivateDnsZoneName
    virtualNetworkLinks: spokeVNetLinks   
  }
}

resource postgres 'Microsoft.DBforPostgreSQL/flexibleServers@2023-06-01-preview' = {
  name: name
  location: location
  sku: {
    name: 'Standard_B1ms'
    tier: 'Burstable'
  }
  tags: tags
  properties: {
    administratorLogin: postgresAdminUsername
    administratorLoginPassword: postgresAdminPassword
    createMode: 'Default'
    version: '16'
    authConfig: {
      activeDirectoryAuth: 'Disabled'
      passwordAuth: 'Enabled'
    }
    storage: {
      iops: 120
      tier: 'P4'
      storageSizeGB: 32
      autoGrow: 'Disabled'
    }
    availabilityZone: '1'
    network: {
      publicNetworkAccess: 'Disabled'
      delegatedSubnetResourceId: spokeSubnetId
      privateDnsZoneArmResourceId: privateDNS.outputs.privateDnsZonesId
    }
  }
}
