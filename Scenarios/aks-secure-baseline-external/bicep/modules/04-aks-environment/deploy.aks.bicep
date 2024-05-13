param clusterName string
param logworkspaceid string

param aadGroupdIds array
param subnetId string

param kubernetesVersion string
param location string
param availabilityZones array
param enableAutoScaling bool
param autoScalingProfile object

@allowed([
  'azure'
  'kubenet'
])
param networkPlugin string

param useRouteTable bool
param enablePrivateCluster bool

var networkProfile = (useRouteTable)
  ? {
      networkPlugin: networkPlugin
      outboundType: 'userDefinedRouting'
      dnsServiceIP: '192.168.100.10'
      serviceCidr: '192.168.100.0/24'
    }
  : {
      networkPlugin: networkPlugin
      dnsServiceIP: '192.168.100.10'
      serviceCidr: '192.168.100.0/24'
    }

var apiServerAccessProfile = (!enablePrivateCluster)
  ? {
      enablePrivateCluster: false
      authorizedIPRanges: [
        '4.210.69.107'
      ]
    }
  : {
      //TODO: Add support for private cluster API Server VNET integration
      enablePrivateCluster: true
      enablePrivateClusterPublicFQDN: false
      privateDNSZone: 'system'
    }

// Create an Azure User Managed Identity
resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' = {
  name: '${clusterName}-identity'
  location: location
}

// TODO: Add support subnet separation for control plane and node pools

resource aksCluster 'Microsoft.ContainerService/managedClusters@2024-01-01' = {
  name: clusterName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identity.id}': {}
    }
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    azureMonitorProfile: {
      metrics: {
        enabled: true             
      }
    }
    autoUpgradeProfile: {
      upgradeChannel: 'patch'
      nodeOSUpgradeChannel: 'NodeImage'
    }
    securityProfile: {
      imageCleaner: {
        enabled: true
        intervalHours: 24
      }
      workloadIdentity: {
        enabled: true
      }
    }
    oidcIssuerProfile: {
      enabled: true
    }
    nodeResourceGroup: '${clusterName}-aksInfraRG'
    dnsPrefix: '${clusterName}aks'
    agentPoolProfiles: [
      {
        enableAutoScaling: enableAutoScaling
        name: 'agentpool'
        availabilityZones: !empty(availabilityZones) ? availabilityZones : null
        mode: 'System'
        // enableEncryptionAtHost: true
        count: 3
        minCount: enableAutoScaling ? 1 : null
        maxCount: enableAutoScaling ? 3 : null
        vmSize: 'Standard_B4ms'
        // osDiskSizeGB: 0
        type: 'VirtualMachineScaleSets'
        vnetSubnetID: subnetId
        osSKU: 'AzureLinux'
        // maxPods: 110
      }
    ]
    autoScalerProfile: enableAutoScaling ? autoScalingProfile : null
    networkProfile: networkProfile
    apiServerAccessProfile: apiServerAccessProfile
    enableRBAC: true
    disableLocalAccounts: true
    aadProfile: {
      adminGroupObjectIDs: aadGroupdIds
      enableAzureRBAC: true
      managed: true
      tenantID: subscription().tenantId
    }
    serviceMeshProfile: {
      istio: {
        components: {
          ingressGateways: [
            {
              enabled: false
              mode: 'External'
            }
          ]
        }
        revisions: [
          'asm-1-20'
        ]
      }
      mode: 'Istio'
    }
    storageProfile: {
      blobCSIDriver: {
        enabled: false
      }
      diskCSIDriver: {
        enabled: false
      }
      fileCSIDriver: {
        enabled: true
      }
      snapshotController: {
        enabled: false
      }
    }
    addonProfiles: {
      omsagent: {
        config: {
          logAnalyticsWorkspaceResourceID: logworkspaceid
        }
        enabled: true
      }
      azurepolicy: {
        enabled: true
      }
      azureKeyvaultSecretsProvider: {
        enabled: true
      }
    }
  }
}

// var ag4cRoleDefinitionId = resourceId('Microsoft.Authorization/roleDefinitions', 'fbc52c3f-28ad-4303-a892-8a056630b8f1')
// module ra '../../../../shared/bicep/role-assignments/role-assignment.bicep' = {
//   name: take('aksRoleAssignment-${deployment().name}-deployment', 64)
//   scope: resourceGroup('${clusterName}-aksInfraRG')
//   params: {
//     name: 'aksRoleAssignment'
//     resourceId: ''
//     principalId: ''
//     roleDefinitionId: ag4cRoleDefinitionId
//     principalType: 'ServicePrincipal'
//   }
// }

// resource userAssignedIdentity_roleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
//   name: guid(userAssignedIdentity.id, roleAssignment.principalId, roleAssignment.roleDefinitionIdOrName)
//   properties: {
//     roleDefinitionId: contains(builtInRoleNames, roleAssignment.roleDefinitionIdOrName) ? builtInRoleNames[roleAssignment.roleDefinitionIdOrName] : contains(roleAssignment.roleDefinitionIdOrName, '/providers/Microsoft.Authorization/roleDefinitions/') ? roleAssignment.roleDefinitionIdOrName : subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleAssignment.roleDefinitionIdOrName)
//     principalId: roleAssignment.principalId
//     description: roleAssignment.?description
//     principalType: roleAssignment.?principalType
//     condition: roleAssignment.?condition
//     conditionVersion: !empty(roleAssignment.?condition) ? (roleAssignment.?conditionVersion ?? '2.0') : null // Must only be set if condtion is set
//     delegatedManagedIdentityResourceId: roleAssignment.?delegatedManagedIdentityResourceId
//   }
//   scope: identity
// }]

// Flux v2 Extension
resource fluxAddon 'Microsoft.KubernetesConfiguration/extensions@2023-05-01' = {
  name: 'flux'
  scope: aksCluster
  properties: {
    extensionType: 'microsoft.flux'
    autoUpgradeMinorVersion: true
    releaseTrain: 'Stable'
    scope: {
      cluster: {
        releaseNamespace: 'flux-system'
      }
    }
    configurationProtectedSettings: {}
  }
}

output aksId string = aksCluster.id
output kubeletIdentity string = aksCluster.properties.identityProfile.kubeletidentity.objectId
output aksManagedRG string = aksCluster.properties.nodeResourceGroup
output aksUMIId string = identity.id
output aksUMIPrincipalId string = identity.properties.principalId
// output ingressIdentity string = aksCluster.properties.addonProfiles.ingressApplicationGateway.identity.objectId
output keyvaultaddonIdentity string = aksCluster.properties.addonProfiles.azureKeyvaultSecretsProvider.identity.objectId
