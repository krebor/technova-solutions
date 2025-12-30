@description('Lokacija resursa')
param location string

@description('Ime Recovery Services Vaulta')
param vaultName string = 'technova-rsv'

@description('Ime Backup Politike')
param policyName string = 'DailyBackupPolicy'

resource recoveryVault 'Microsoft.RecoveryServices/vaults@2022-01-01' = {
  name: vaultName
  location: location
  sku: {
    name: 'RS0'
    tier: 'Standard'
  }
  properties: {}
}

resource backupPolicy 'Microsoft.RecoveryServices/vaults/backupPolicies@2022-01-01' = {
  parent: recoveryVault
  name: policyName
  properties: {
    backupManagementType: 'AzureIaasVM'
    instantRpRetentionRangeInDays: 2
    schedulePolicy: {
      schedulePolicyType: 'SimpleSchedulePolicy'
      scheduleRunFrequency: 'Daily'
      scheduleRunTimes: [
        '2023-01-01T22:00:00Z'
      ]
      scheduleWeeklyFrequency: 0
    }
    retentionPolicy: {
      retentionPolicyType: 'LongTermRetentionPolicy'
      dailySchedule: {
        retentionTimes: [
          '2023-01-01T22:00:00Z'
        ]
        retentionDuration: {
          count: 7
          durationType: 'Days'
        }
      }
    }
    timeZone: 'Central European Standard Time'
  }
}

output vaultName string = recoveryVault.name
