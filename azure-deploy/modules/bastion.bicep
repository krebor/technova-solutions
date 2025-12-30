@description('Lokacija za resurse')
param location string

@description('ID Bastion Subneta')
param bastionSubnetId string

@description('Ime Bastion resursa')
param bastionHostName string = 'technova-bastion'

// 1. Public IP za Bastion
resource bastionPip 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: '${bastionHostName}-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// 2. Bastion Host
resource bastionHost 'Microsoft.Network/bastionHosts@2021-02-01' = {
  name: bastionHostName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          subnet: {
            id: bastionSubnetId
          }
          publicIPAddress: {
            id: bastionPip.id
          }
        }
      }
    ]
  }
}
