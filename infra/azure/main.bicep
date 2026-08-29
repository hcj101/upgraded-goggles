// Deploys into a subscription entirely separate from Safinea. No resource,
// identity or network here is shared with the UNICEF deployment.
//
//   az deployment group create -g rg-sim-dev -f infra/azure/main.bicep \
//      -p namePrefix=sim env=dev pgAdminPassword=<secret>

targetScope = 'resourceGroup'

@description('Short prefix, lowercase alphanumeric.')
param namePrefix string = 'sim'
@allowed(['dev', 'stg', 'prod'])
param env string = 'dev'
param location string = resourceGroup().location
@secure()
param pgAdminPassword string

var suffix = '${namePrefix}${env}'
var isProd = env == 'prod'

resource acr 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: 'acr${suffix}'
  location: location
  sku: { name: 'Basic' }
  properties: { adminUserEnabled: false }   // identity only, no admin creds
}

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-${suffix}'
  location: location
}

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: 'st${suffix}'
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storage
  name: 'default'
}

resource artefacts 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'artefacts'
}

resource uploads 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'user-uploads'
}

resource postgres 'Microsoft.DBforPostgreSQL/flexibleServers@2023-12-01-preview' = {
  name: 'pg-${suffix}'
  location: location
  sku: {
    name: isProd ? 'Standard_D2ds_v5' : 'Standard_B1ms'
    tier: isProd ? 'GeneralPurpose' : 'Burstable'
  }
  properties: {
    version: '16'
    administratorLogin: 'app'
    administratorLoginPassword: pgAdminPassword
    storage: { storageSizeGB: isProd ? 128 : 32 }
    backup: { backupRetentionDays: isProd ? 35 : 7, geoRedundantBackup: 'Disabled' }
    highAvailability: { mode: isProd ? 'ZoneRedundant' : 'Disabled' }
  }
}

resource logs 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'log-${suffix}'
  location: location
  properties: { sku: { name: 'PerGB2018' }, retentionInDays: 30 }
}

resource caEnv 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: 'cae-${suffix}'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logs.properties.customerId
        sharedKey: logs.listKeys().primarySharedKey
      }
    }
  }
}

// Thin REST layer. Internal ingress only: reachable from the interface inside
// the Container Apps environment, never from the internet.
resource apiApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'ca-${suffix}-api'
  location: location
  identity: { type: 'UserAssigned', userAssignedIdentities: { '${identity.id}': {} } }
  properties: {
    managedEnvironmentId: caEnv.id
    configuration: {
      ingress: { external: false, targetPort: 8000, transport: 'auto' }
      registries: [ { server: acr.properties.loginServer, identity: identity.id } ]
    }
    template: {
      containers: [ {
        name: 'api'
        image: '${acr.properties.loginServer}/api:latest'
        resources: { cpu: json('0.5'), memory: '1Gi' }
        probes: [ {
          type: 'Readiness'
          httpGet: { path: '/healthz', port: 8000 }
          initialDelaySeconds: 5
          periodSeconds: 10
        } ]
      } ]
      scale: { minReplicas: 1, maxReplicas: 4 }
    }
  }
}

// Long-lived public service. Talks to the API, never to Postgres.
resource interfaceApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'ca-${suffix}-interface'
  location: location
  identity: { type: 'UserAssigned', userAssignedIdentities: { '${identity.id}': {} } }
  properties: {
    managedEnvironmentId: caEnv.id
    configuration: {
      ingress: { external: true, targetPort: 3000, transport: 'auto' }
      registries: [ { server: acr.properties.loginServer, identity: identity.id } ]
    }
    template: {
      containers: [ {
        name: 'interface'
        image: '${acr.properties.loginServer}/interface:latest'
        resources: { cpu: json('0.5'), memory: '1Gi' }
        env: [
          { name: 'API_BASE_URL', value: 'https://${apiApp.properties.configuration.ingress.fqdn}' }
        ]
      } ]
      scale: { minReplicas: 1, maxReplicas: 4 }
    }
  }
}

// One-shot pipeline runs. Replaces the ACI submission path.
resource pipelineJob 'Microsoft.App/jobs@2024-03-01' = {
  name: 'caj-${suffix}-pipeline'
  location: location
  identity: { type: 'UserAssigned', userAssignedIdentities: { '${identity.id}': {} } }
  properties: {
    environmentId: caEnv.id
    configuration: {
      triggerType: 'Manual'
      replicaTimeout: 7200
      replicaRetryLimit: 1
      manualTriggerConfig: { parallelism: 1, replicaCompletionCount: 1 }
      registries: [ { server: acr.properties.loginServer, identity: identity.id } ]
    }
    template: {
      containers: [ {
        name: 'pipeline'
        image: '${acr.properties.loginServer}/pipeline:latest'
        resources: { cpu: json('2.0'), memory: '4Gi' }
      } ]
    }
  }
}

var acrPull = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
var blobContributor = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')

resource acrPullAssign 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: acr
  name: guid(acr.id, identity.id, 'AcrPull')
  properties: {
    roleDefinitionId: acrPull
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource blobAssign 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storage
  name: guid(storage.id, identity.id, 'BlobContributor')
  properties: {
    roleDefinitionId: blobContributor
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

output acrLoginServer string = acr.properties.loginServer
output storageAccount string = storage.name
output interfaceFqdn string = interfaceApp.properties.configuration.ingress.fqdn
output apiFqdn string = apiApp.properties.configuration.ingress.fqdn
output postgresFqdn string = postgres.properties.fullyQualifiedDomainName
