param location string = resourceGroup().location

@secure() 
param adminPassword string
param adminUsername string = 'azureuser'

//Networking

param labVnetPrefix string = '10.1.0.0/16'
param labSubnetPrefix string = '10.1.10.0/24'
param labNetworkName string = 'lab'
param labSubnetName string ='lab'

// linux VM
param linuxVmName string = 'linux'
param linuxVmSize string = 'Standard_B2ts_v2'

var cloudInitDocker = '''
#cloud-config
package_update: true
package_upgrade: false
packages:
  - docker.io
'''

// ----------------------
// Network Resources
// ----------------------

resource serversVnet 'Microsoft.Network/virtualNetworks@2025-05-01' = {
  name: 'vnet-${labNetworkName}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [labVnetPrefix]
    }
    subnets: [
      {
        name: 'subnet-${labSubnetName}'
        properties: {
          addressPrefix: labSubnetPrefix
          networkSecurityGroup: {
            id: nsgServers.id
          }
          defaultOutboundAccess: true
        }
      }
    ]
  }
}

resource nsgServers 'Microsoft.Network/networkSecurityGroups@2025-05-01' = {
  name: 'nsg-${labNetworkName}'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowHTTP'
        properties: {
          priority: 1000
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource linuxPublicIp 'Microsoft.Network/publicIPAddresses@2025-05-01' = {
  name: 'pip-${linuxVmName}'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// ----------------------
// linux VM Resources
// ----------------------

resource linuxNic 'Microsoft.Network/networkInterfaces@2025-05-01' = {
  name: 'nic-${linuxVmName}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: serversVnet.properties.subnets[0].id
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: linuxPublicIp.id
          }
        }
      }
    ]
  }
}

resource linuxVm 'Microsoft.Compute/virtualMachines@2025-04-01' = {
  name: 'vm-${linuxVmName}'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: linuxVmSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
      imageReference: {
        publisher: 'Canonical'
        offer: 'ubuntu-24_04-lts'
        sku: 'server'
        version: 'latest'
      }
    }
    osProfile: {
      computerName: linuxVmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      customData: base64(cloudInitDocker)
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: linuxNic.id
        }
      ]
    }
  }
}
