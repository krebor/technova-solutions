@description('Lokacija resursa')
param location string

@description('ID Frontend Subneta')
param subnetId string

@description('Admin korisničko ime za VM')
param adminUsername string = 'azureuser'

@description('SSH javni ključ za VM pristup')
@secure()
param adminPasswordOrKey string

@description('ID Log Analytics Workspace-a za monitoring')
param logAnalyticsWorkspaceId string

// --- LOAD BALANCER ---

resource publicIP 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: 'technova-lb-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: 'technova-app-${uniqueString(resourceGroup().id)}'
    }
  }
}

resource lb 'Microsoft.Network/loadBalancers@2021-02-01' = {
  name: 'technova-lb'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'LoadBalancerFrontEnd'
        properties: {
          publicIPAddress: {
            id: publicIP.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'BackendPool1'
      }
    ]
    loadBalancingRules: [
      {
        name: 'LBRule'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', 'technova-lb', 'LoadBalancerFrontEnd')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'technova-lb', 'BackendPool1')
          }
          protocol: 'Tcp'
          frontendPort: 80
          backendPort: 80
          enableFloatingIP: false
          idleTimeoutInMinutes: 5
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', 'technova-lb', 'HealthProbe')
          }
        }
      }
    ]
    probes: [
      {
        name: 'HealthProbe'
        properties: {
          protocol: 'Tcp'
          port: 80
          intervalInSeconds: 15
          numberOfProbes: 2
        }
      }
    ]
  }
}

// --- VM SCALE SET ---

resource vmss 'Microsoft.Compute/virtualMachineScaleSets@2021-03-01' = {
  name: 'technova-vmss'
  location: location
  sku: {
    name: 'Standard_B1s' // Jeftiniji SKU za studente
    tier: 'Standard'
    capacity: 2
  }
  properties: {
    overprovision: true
    upgradePolicy: {
      mode: 'Manual'
    }
    virtualMachineProfile: {
      storageProfile: {
        osDisk: {
          createOption: 'FromImage'
          caching: 'ReadWrite'
        }
        imageReference: {
          publisher: 'Canonical'
          offer: '0001-com-ubuntu-server-jammy'
          sku: '22_04-lts'
          version: 'latest'
        }
      }
      osProfile: {
        computerNamePrefix: 'vm'
        adminUsername: adminUsername
        adminPassword: adminPasswordOrKey
        customData: base64('''#cloud-config
package_upgrade: true
packages:
  - nginx
write_files:
  - owner: www-data:www-data
  - path: /var/www/html/index.html
    content: |
      <!DOCTYPE html>
      <html>
      <head>
          <title>TechNova Solutions</title>
          <style>
              body { font-family: sans-serif; text-align: center; padding: 50px; background-color: #f0f2f5; }
              h1 { color: #0078d4; }
              p { color: #555; }
          </style>
      </head>
      <body>
          <h1>TechNova Solutions - Azure Cloud App</h1>
          <p>Aplikacija uspjesno radi na Azure VM Scale Set-u.</p>
          <p>Server: Nginx na Ubuntu 22.04</p>
      </body>
      </html>
runcmd:
  - systemctl enable nginx
  - systemctl start nginx
''')
      }
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            name: 'nic'
            properties: {
              primary: true
              ipConfigurations: [
                {
                  name: 'ipconfig'
                  properties: {
                    subnet: {
                      id: subnetId
                    }
                    loadBalancerBackendAddressPools: [
                      {
                        id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'technova-lb', 'BackendPool1')
                      }
                    ]
                  }
                }
              ]
            }
          }
        ]
      }
    }
  }
  dependsOn: [
    lb
  ]
}

// --- DIAGNOSTICS SETTINGS ---
resource vmssDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: vmss
  name: 'vmss-diagnostics'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

output appUrl string = 'http://${publicIP.properties.dnsSettings.fqdn}'
