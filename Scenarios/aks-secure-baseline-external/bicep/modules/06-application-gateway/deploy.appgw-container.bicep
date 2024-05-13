param location string
param name string

resource agw4c 'Microsoft.ServiceNetworking/trafficControllers@2023-11-01' = {
  name: name
  location: location
  properties: {}
}
