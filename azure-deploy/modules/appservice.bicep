@description('Lokacija za resurse')
param location string

@description('Prefiks za imena resursa')
param namePrefix string = 'technova-internal'

// 1. App Service Plan (Server Farm)
// Koristimo Standard S1 jer Free/Basic tierovi ne podržavaju Autoscaling
resource appServicePlan 'Microsoft.Web/serverfarms@2021-02-01' = {
  name: '${namePrefix}-plan-${uniqueString(resourceGroup().id)}'
  location: location
  sku: {
    name: 'S1' 
    tier: 'Standard'
    capacity: 1
  }
}

// 2. Web Aplikacija
resource webApp 'Microsoft.Web/sites@2021-02-01' = {
  name: '${namePrefix}-app-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      alwaysOn: true
      // Jednostavna statička stranica za demonstraciju
      appSettings: [
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~14'
        }
      ]
    }
  }
}

// 3. Autoscaling Postavke (Monitor > Autoscale)
resource appServiceAutoScaling 'Microsoft.Insights/autoscalesettings@2015-04-01' = {
  name: '${namePrefix}-autoscale'
  location: location
  properties: {
    name: '${namePrefix}-autoscale'
    targetResourceUri: appServicePlan.id
    enabled: true
    profiles: [
      {
        name: 'AutoCreatedDefaultProfile'
        capacity: {
          minimum: '1'
          maximum: '3'
          default: '1'
        }
        rules: [
          // Pravilo 1: Scale OUT (Povećaj) ako je CPU > 80%
          {
            metricTrigger: {
              metricName: 'CpuPercentage'
              metricResourceUri: appServicePlan.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'GreaterThan'
              threshold: 80
            }
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT5M'
            }
          }
          // Pravilo 2: Scale IN (Smanji) ako je CPU < 30%
          {
            metricTrigger: {
              metricName: 'CpuPercentage'
              metricResourceUri: appServicePlan.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'LessThan'
              threshold: 30
            }
            scaleAction: {
              direction: 'Decrease'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT5M'
            }
          }
        ]
      }
    ]
  }
}

output appServiceUrl string = 'https://${webApp.properties.defaultHostName}'
