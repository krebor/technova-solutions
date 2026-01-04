@description('Lokacija za resurse')
param location string

@description('Prefiks imena')
param namePrefix string = 'technova'

@description('Tenant ID (za Access Policies)')
param tenantId string = subscription().tenantId

@description('Admin Password koji spremamo kao tajnu')
@secure()
param adminPassword string

// Generiranje jedinstvenog imena (max 24 znaka)
var kvName = take('${namePrefix}-kv-${uniqueString(resourceGroup().id)}', 24)

resource keyVault 'Microsoft.KeyVault/vaults@2021-06-01-preview' = {
  name: kvName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenantId
    enabledForDeployment: true          // Omoguci VM-ovima da dohvate tajne
    enabledForTemplateDeployment: true  // Omoguci Bicep-u da koristi tajne
    enabledForDiskEncryption: true
    accessPolicies: [
      // Ovdje bi se inace dodale politike za usera koji deploya
      // Ali za demo cemo koristiti RBAC ili pretpostaviti da Owner ima prava
    ]
    enableRbacAuthorization: true       // Koristimo moderni RBAC model
  }
}

// Pohrana Admin Lozinke u Key Vault
resource secretVmPass 'Microsoft.KeyVault/vaults/secrets@2021-06-01-preview' = {
  parent: keyVault
  name: 'VmAdminPassword'
  properties: {
    value: adminPassword
  }
}

// Pohrana SQL Lozinke
resource secretSqlPass 'Microsoft.KeyVault/vaults/secrets@2021-06-01-preview' = {
  parent: keyVault
  name: 'SqlAdminPassword'
  properties: {
    value: adminPassword
  }
}

output keyVaultName string = keyVault.name
output keyVaultId string = keyVault.id
