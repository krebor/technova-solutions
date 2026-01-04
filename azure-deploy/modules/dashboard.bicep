@description('Lokacija resursa')
param location string

@description('Puni Resource ID VM Scale Seta (ne samo ime!)')
param vmssId string

resource dashboard 'Microsoft.Portal/dashboards@2020-09-01-preview' = {
  name: 'TechNova-Dashboard-${uniqueString(resourceGroup().id)}'
  location: location
  tags: {
    'hidden-title': 'TechNova Monitor' // Lijepi naziv u GUI-u
  }
  properties: {
    lenses: [
      {
        order: 0
        parts: [
          // 1. DIO: Naslov (Markdown) - Korigirano na 'settings'
          {
            position: {
              x: 0
              y: 0
              rowSpan: 2
              colSpan: 6
            }
            metadata: {
              inputs: []
              type: 'Extension/HubsExtension/PartType/MarkdownPart'
              settings: {
                content: {
                  settings: {
                    content: '# TechNova Solutions\n**Status Sustava**'
                    title: 'Dobrodošli'
                    subtitle: 'Pregled infrastrukture'
                  }
                }
              }
            }
          }
          // 2. DIO: CPU Graf (Metrics Chart) - Vaš kod je ovdje bio odličan
          {
            position: {
              x: 0
              y: 2
              rowSpan: 4
              colSpan: 6
            }
            metadata: any({
              inputs: [
                {
                  name: 'resourceType'
                  value: 'Microsoft.Compute/virtualMachineScaleSets'
                }
                {
                  name: 'resourceId'
                  value: vmssId
                }
              ]
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              settings: {
                content: {
                  options: {
                    chart: {
                      metrics: [
                        {
                          resourceMetadata: {
                            id: vmssId
                          }
                          name: 'Percentage CPU'
                          aggregationType: 4
                          namespace: 'microsoft.compute/virtualmachinescalesets'
                          metricVisualization: {
                            displayName: 'VMSS CPU Usage'
                            resourceDisplayName: 'TechNova ScaleSet'
                          }
                        }
                      ]
                      title: 'Prosječno opterećenje procesora'
                      titleKind: 1 
                      visualization: {
                        chartType: 2 // 2 = Line Chart, 1 = Bar Chart
                      }
                    }
                  }
                }
              }
            })
          }
        ]
      }
    ]
    metadata: {
      model: {
        timeRange: {
          value: {
            relative: {
              duration: 24
              timeUnit: 1
            }
          }
          type: 'MsPortalFx.Composition.Configuration.ValueTypes.TimeRange'
        }
      }
    }
  }
}
