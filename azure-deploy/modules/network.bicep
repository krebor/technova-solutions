@description('Lokacija resursa')
param location string

@description('Ime virtualne mreže')
param vnetName string = 'technova-vnet'

// --- NSG DEFINICIJE ---

resource nsgFrontend 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: 'technova-nsg-frontend'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowHTTPS'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowHTTP_Redirect'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource nsgBackend 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: 'technova-nsg-backend'
  location: location
  properties: {
    securityRules: [
      {
        name: 'DenyInternetInbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource nsgManagement 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: 'technova-nsg-management'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowSSH'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          // U produkciji ovdje ide IP firme ili Azure BastionSubnet
          sourceAddressPrefix: '*' 
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// --- VNET I SUBNETI ---

resource vnet 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'Frontend'
        properties: {
          addressPrefix: '10.0.1.0/24'
          networkSecurityGroup: {
            id: nsgFrontend.id
          }
        }
      }
      {
        name: 'Backend'
        properties: {
          addressPrefix: '10.0.2.0/24'
          networkSecurityGroup: {
            id: nsgBackend.id
          }
        }
      }
      {
        name: 'Management'
        properties: {
          addressPrefix: '10.0.3.0/24'
          networkSecurityGroup: {
            id: nsgManagement.id
          }
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.0.4.0/26'
        }
      }
    ]
  }
}

// --- OUTPUTS ---
output vnetId string = vnet.id
output frontendSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'Frontend')
output backendSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'Backend')
output bastionSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'AzureBastionSubnet')
