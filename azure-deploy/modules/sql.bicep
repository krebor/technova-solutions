@description('Lokacija resursa')
param location string

@description('Ime SQL Servera (mora biti globalno jedinstveno)')
param serverName string = 'technova-sql-${uniqueString(resourceGroup().id)}'

@description('Ime SQL Baze')
param dbName string = 'TechNovaDB'

@description('Admin korisničko ime')
param adminUsername string = 'sqladmin'

@description('Admin lozinka')
@secure()
param adminPassword string

resource sqlServer 'Microsoft.Sql/servers@2021-11-01' = {
  name: serverName
  location: location
  properties: {
    administratorLogin: adminUsername
    administratorLoginPassword: adminPassword
  }
}

resource sqlDB 'Microsoft.Sql/servers/databases@2021-11-01' = {
  parent: sqlServer
  name: dbName
  location: location
  sku: {
    name: 'Basic'
    tier: 'Basic'
    capacity: 5
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 1073741824 // 1 GB
  }
}

// Allow Azure Services to access server (Firewall rule)
resource allowAzureServices 'Microsoft.Sql/servers/firewallRules@2021-11-01' = {
  parent: sqlServer
  name: 'AllowAllWindowsAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

output sqlServerName string = sqlServer.name
output sqlDbName string = sqlDB.name
