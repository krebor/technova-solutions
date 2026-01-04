@description('Lokacija za resurse')
param location string

@description('Prefiks za imena resursa')
param namePrefix string = 'technova'

// 1. Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: '${namePrefix}-log-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// 2. Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${namePrefix}-insights-${uniqueString(resourceGroup().id)}'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}

output workspaceId string = logAnalyticsWorkspace.id
output appInsightsKey string = appInsights.properties.InstrumentationKey
output appInsightsConnectionString string = appInsights.properties.ConnectionString

// 3. Action Group (Za slanje email upozorenja)
resource actionGroup 'Microsoft.Insights/actionGroups@2021-09-01' = {
  name: 'TechNova-Admins'
  location: 'global'
  properties: {
    groupShortName: 'tn-admins'
    enabled: true
    emailReceivers: [
      {
        name: 'AdminEmail'
        emailAddress: 'admin@technova.com'
        useCommonAlertSchema: true
      }
    ]
  }
}
