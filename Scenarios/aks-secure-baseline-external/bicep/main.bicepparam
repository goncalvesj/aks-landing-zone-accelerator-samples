using './main.bicep'

param workloadName = readEnvironmentVariable('AZURE_ENV_NAME', 'DEFAULT')
param environment = 'dev'
param tags = {}
param hubResourceGroupName = ''
param spokeResourceGroupName = ''
param vnetAddressPrefixes = [
  '10.0.0.0/24'
]

// Hub Params
param gatewaySubnetAddressPrefix = '10.0.0.0/27'
param azureFirewallSubnetAddressPrefix = '10.0.0.64/26'
param azureFirewallSubnetManagementAddressPrefix = '10.0.0.128/26'
param bastionSubnetAddressPrefix = '10.0.0.192/26'
param deployFirewall = false

// Firewall Rules
// Source Addresses are the IP range of the Infra subnet
param applicationRuleCollections = [
  {
    name: 'Helper-tools'
    properties: {
      priority: 101
      action: {
        type: 'Allow'
      }
      rules: [
        {
          name: 'Allow-ifconfig'
          protocols: [
            {
              port: 80
              protocolType: 'Http'
            }
            {
              port: 443
              protocolType: 'Https'
            }
          ]
          targetFqdns: [
            'ifconfig.co'
            'api.snapcraft.io'
            'jsonip.com'
            'kubernaut.io'
            'motd.ubuntu.com'
          ]
          sourceAddresses: [
            '10.1.0.0/24'
          ]
        }
      ]
    }
  }
  {
    name: 'AKS-egress-application'
    properties: {
      priority: 102
      action: {
        type: 'Allow'
      }
      rules: [
        {
          name: 'Egress'
          protocols: [
            {
              port: 443
              protocolType: 'Https'
            }
          ]
          targetFqdns: [
            '*.azmk8s.io'
            'aksrepos.azurecr.io'
            '*.blob.core.windows.net'
            '*.cdn.mscr.io'
            '*.opinsights.azure.com'
            '*.monitoring.azure.com'
            '*.dp.kubernetesconfiguration.azure.com'
          ]
          sourceAddresses: [
            '10.1.0.0/24'
          ]
        }
        {
          name: 'Registries'
          protocols: [
            {
              port: 443
              protocolType: 'Https'
            }
          ]
          targetFqdns: [
            '*.azurecr.io'
            '*.gcr.io'
            'pkg-containers.githubusercontent.com'
            '*.docker.io'
            'registry-1.docker.io'
            'quay.io'
            '*.quay.io'
            '*.cloudfront.net'
            'production.cloudflare.docker.com'
            'mcr.microsoft.com'
            '*.data.mcr.microsoft.com'
          ]
          sourceAddresses: [
            '10.1.0.0/24'
          ]
        }
        {
          name: 'Data-Services'
          protocols: [
            {
              port: 443
              protocolType: 'Https'
            }
          ]
          targetFqdns: [            
            '*.redis.cache.windows.net'
          ]
          sourceAddresses: [
            '10.1.0.0/24'
          ]
        }
        {
          name: 'Additional-Usefull-Address'
          protocols: [
            {
              port: 443
              protocolType: 'Https'
            }
          ]
          targetFqdns: [
            'grafana.net'
            'grafana.com'
            'stats.grafana.org'
            'github.com'
            'charts.bitnami.com'
            'raw.githubusercontent.com'
            '*.letsencrypt.org'
            'usage.projectcalico.org'
            'vortex.data.microsoft.com'            
          ]
          sourceAddresses: [
            '10.1.0.0/24'
          ]
        }
        {
          name: 'AKS-FQDN-TAG'
          protocols: [
            {
              port: 80
              protocolType: 'Http'
            }
            {
              port: 443
              protocolType: 'Https'
            }
          ]
          fqdnTags: [
            'AzureKubernetesService'
          ]
          sourceAddresses: [
            '10.1.0.0/24'
          ]
        }
      ]
    }
  }
]
param networkRuleCollections = [
  {
    name: 'AKS-egress'
    properties: {
      priority: 200
      action: {
        type: 'Allow'
      }
      rules: [
        {
          name: 'NTP'
          protocols: [
            'UDP'
          ]
          sourceAddresses: [
            '10.1.0.0/24'
          ]
          destinationAddresses: [
            '*'
          ]
          destinationPorts: [
            '123'
          ]
        }
        {
          name: 'APITCP'
          protocols: [
            'TCP'
          ]
          sourceAddresses: [
            '10.1.0.0/24'
          ]
          destinationAddresses: [
            '*'
          ]
          destinationPorts: [
            '9000'
          ]
        }
        {
          name: 'HTTPS'
          protocols: [
            'TCP'
          ]
          sourceAddresses: [
            '10.1.0.0/24'
          ]
          destinationAddresses: [
            '*'
          ]
          destinationPorts: [
            '443'
          ]
        }
        {
          name: 'APIUDP'
          protocols: [
            'UDP'
          ]
          sourceAddresses: [
            '10.1.0.0/24'
          ]
          destinationAddresses: [
            '*'
          ]
          destinationPorts: [
            '1194'
          ]
        }
      ]
    }
  }
]
param natRuleCollections = []

// Jumpbox Params
// Bastion dev tier doesnt support peering so we need to deploy it manually in the the spoke vnet
// To switch to the standard tier, change the environment to 'prod'
param enableBastion = false
param vmSize = 'Standard_B2ms'
param vmAdminUsername = 'azureuser'
param vmAdminPassword = 'Password123'
param vmLinuxSshAuthorizedKeys = 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDpNpoh248rsraL3uejAwKlla+pHaDLbp4DM7bKFoc3Rt1DeXPs0XTutJcNtq4iRq+ooRQ1T7WaK42MfQQxt3qkXwjyv8lPJ4v7aElWkAbxZIRYVYmQVxxwfw+zyB1rFdaCQD/kISg/zXxCWw+gdds4rEy7eq23/bXFM0l7pNvbAULIB6ZY7MRpC304lIAJusuZC59iwvjT3dWsDNWifA1SJtgr39yaxB9Fb01UdacwJNuvfGC35GNYH0VJ56c+iCFeAnMXIT00cYuHf0FCRTP0WvTKl+PQmeD1pwxefdFvKCVpidU2hOARb4ooapT0SDM1SODqjaZ/qwWP18y/qQ/v imported-openssh-key'
param vmJumpboxOSType = 'linux'
param vmJumpBoxSubnetAddressPrefix = '10.1.2.32/27'

// Spoke Params
param spokeVNetAddressPrefixes = [
  '10.1.0.0/16'
]
param spokeInfraSubnetAddressPrefix = '10.1.0.0/24'
param spokePrivateEndpointsSubnetAddressPrefix = '10.1.2.0/27'
param spokeApplicationGatewaySubnetAddressPrefix = ''//'10.1.3.0/24'
param spokeAG4CSubnetAddressPrefix = '10.1.1.0/24'

// Support Services Params
param deployAcr = false
param deployRedisCache = false
param deployAzurePolicies = false
param deployZoneRedundantResources = false
param enableApplicationInsights = true

// AKS Params
param kubernetesVersion = '1.27.9'
param aadGroupdIds = [
  '50debbd0-977b-4740-b181-8c9c4607b4d2'
]
