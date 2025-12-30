targetScope = 'resourceGroup'

@description('Object ID korisnika, grupe ili service principala')
param principalId string

@description('Tip principala (User, Group, ServicePrincipal)')
param principalType string = 'Group'

@description('ID definicije uloge (Role Definition ID)')
param roleDefinitionId string

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, principalId, roleDefinitionId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalId: principalId
    principalType: principalType
  }
}

output roleAssignmentId string = roleAssignment.id
