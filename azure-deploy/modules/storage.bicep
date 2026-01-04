@description('Lokacija za resurse')
param location string

@description('Ime Storage Account-a (mora biti jedinstveno na razini Azure-a)')
param storageAccountName string = 'tnovadata${uniqueString(resourceGroup().id)}'

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
  }
}

// File Services (za File Share)
resource fileServices 'Microsoft.Storage/storageAccounts/fileServices@2021-04-01' = {
  parent: storageAccount
  name: 'default'
}

// File Share (Dijeljeni mrežni disk)
resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-04-01' = {
  parent: fileServices
  name: 'technova-fileshare'
  properties: {
    accessTier: 'TransactionOptimized'
    shareQuota: 5 // 5 GB kvota
  }
}

output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name

// Lifecycle Policy: Automatski prebaci u Cool tier nakon 30 dana
resource storageLifecycle 'Microsoft.Storage/storageAccounts/managementPolicies@2021-04-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    policy: {
      rules: [
        {
          enabled: true
          name: 'MoveToCoolTier'
          type: 'Lifecycle'
          definition: {
            actions: {
              baseBlob: {
                tierToCool: {
                  daysAfterModificationGreaterThan: 30
                }
              }
            }
            filters: {
              blobTypes: [
                'blockBlob'
              ]
            }
          }
        }
      ]
    }
  }
}
