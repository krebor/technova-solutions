targetScope = 'subscription'

// --- PARAMETRI (Dolaze iz Master PowerShell skripte) ---
@description('Object ID grupe TechNova-Dev')
param devGroupObjectId string

@description('Object ID grupe TechNova-Sales')
param salesGroupObjectId string

@description('Object ID grupe TechNova-Support')
param supportGroupObjectId string

@description('Lokacija za resurse')
param location string = 'francecentral'

@description('Password for the VM admin user')
@secure()
param adminPassword string

// --- RESURSNA GRUPA ---
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'TechNova-RG'
  location: location
  tags: {
    Project: 'TechNova-PoC'
    Environment: 'Production'
  }
}

// --- 1. MREŽNA INFRASTRUKTURA ---
module network 'modules/network.bicep' = {
  scope: rg
  name: 'deploy-network'
  params: {
    location: location
  }
}

// --- 1.1 MONITORING ---
module monitoring 'modules/monitoring.bicep' = {
  scope: rg
  name: 'deploy-monitoring'
  params: {
    location: location
  }
}

// --- 1.2 BASTION (Opcionalno - Siguran pristup) ---
// Napomena: Bastion je skuplji servis. Može se zakomentirati ako nije potreban.
module bastion 'modules/bastion.bicep' = {
  scope: rg
  name: 'deploy-bastion'
  params: {
    location: location
    bastionSubnetId: network.outputs.bastionSubnetId
  }
}

// --- 1.3 POHRANA PODATAKA (Storage) ---
module storage 'modules/storage.bicep' = {
  scope: rg
  name: 'deploy-storage'
  params: {
    location: location
  }
}

// --- 2. RAČUNALNI RESURSI (Compute) ---
module compute 'modules/compute.bicep' = {
  scope: rg
  name: 'deploy-compute'
  params: {
    location: location
    subnetId: network.outputs.frontendSubnetId
    adminPasswordOrKey: adminPassword
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceId
  }
}

// --- 2.1 KUBERNETES (AKS) ---
// Dodano za zadovoljavanje naprednih zahtjeva (Ishod 3)
module aks 'modules/aks.bicep' = {
  scope: rg
  name: 'deploy-aks'
  params: {
    location: location
  }
}

// --- 2.2 BAZE PODATAKA (SQL) ---
// Dodano za backend pohranu (Ishod 2)
module sql 'modules/sql.bicep' = {
  scope: rg
  name: 'deploy-sql'
  params: {
    location: location
    adminPassword: adminPassword
  }
}

// --- 2.3 BACKUP & RECOVERY ---
// Dodano za sigurnost i pouzdanost
module backup 'modules/backup.bicep' = {
  scope: rg
  name: 'deploy-backup'
  params: {
    location: location
  }
}

// --- 3. UPRAVLJANJE IDENTITETIMA (IAM) ---

// Definicije uloga
var roleVmContributor = '9980e02c-c2be-4d73-94e8-173b1dc7cf3c'
var roleReader = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
var roleMonitoringReader = '43d0d8ad-25c7-4714-9337-8ba259a9fe05'

// Dev Tim -> VM Contributor
module roleAssignDev 'modules/roleAssignment.bicep' = {
  scope: rg
  name: 'deploy-role-dev'
  params: {
    principalId: devGroupObjectId
    roleDefinitionId: roleVmContributor
    principalType: 'Group'
  }
}

// Sales Tim -> Reader
module roleAssignSales 'modules/roleAssignment.bicep' = {
  scope: rg
  name: 'deploy-role-sales'
  params: {
    principalId: salesGroupObjectId
    roleDefinitionId: roleReader
    principalType: 'Group'
  }
}

// Support Tim -> Monitoring Reader
module roleAssignSupport 'modules/roleAssignment.bicep' = {
  scope: rg
  name: 'deploy-role-support'
  params: {
    principalId: supportGroupObjectId
    roleDefinitionId: roleMonitoringReader
    principalType: 'Group'
  }
}

output applicationUrl string = compute.outputs.appUrl
