@description('Lokacija resursa')
param location string

@description('Ime AKS Klastera')
param clusterName string = 'technova-aks'

@description('DNS prefiks za klaster')
param dnsPrefix string = 'technova-k8s'

resource aks 'Microsoft.ContainerService/managedClusters@2022-01-01' = {
  name: clusterName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: dnsPrefix
    agentPoolProfiles: [
      {
        name: 'agentpool'
        count: 1
        vmSize: 'Standard_B2s' // Ekonomična opcija
        osType: 'Linux'
        mode: 'System'
      }
    ]
  }
}

output aksClusterName string = aks.name
output aksFqdn string = aks.properties.fqdn
