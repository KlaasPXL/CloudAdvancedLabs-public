param location string = resourceGroup().location

@secure() 
param adminPassword string
param adminUsername string = 'azureuser'

//Networking
param VnetPrefix string = '10.1.0.0/16'
param SubnetPrefix string = '10.1.10.0/24'
param NetworkName string = 'vnet-lab'
param SubnetName string ='snet-lab'
param nsgName string = 'nsg-lab'

// linux VM
param linuxVmBaseName string = 'vm-nginx-'
param linuxVmCount int = 3
param linuxVmSize string = 'Standard_B2ts_v2'

var linuxVmNames = [for i in range(1, linuxVmCount): '${linuxVmBaseName}${i}']

// ----------------------
// Network Resources
// ----------------------

resource serversVnet 'Microsoft.Network/virtualNetworks@2025-05-01' = {
  name: NetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [VnetPrefix]
    }
    subnets: [
      {
        name: SubnetName
        properties: {
          addressPrefix: SubnetPrefix
          networkSecurityGroup: {
            id: nsgServers.id
          }
          defaultOutboundAccess: false
        }
      }
    ]
  }
}

resource nsgServers 'Microsoft.Network/networkSecurityGroups@2025-05-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [

      // Allow SSH for Linux + Windows
      {
        name: 'AllowSSH'
        properties: {
          priority: 1000
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '*'
          destinationApplicationSecurityGroups: [
            {
              id: asgServersLinux.id
            }
          ]
        }
      }
      {
        name: 'AllowHTTP'
        properties: {
          priority: 1010
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationApplicationSecurityGroups: [
            {
              id: asgServersLinux.id
            }
          ]
        }
      }
    ]
  }
}


resource asgServersLinux 'Microsoft.Network/applicationSecurityGroups@2025-05-01' = {
  name: 'servers-linux'
  location: resourceGroup().location
}

// ----------------------
// linux VM Resources
// ----------------------

resource linuxPublicIp 'Microsoft.Network/publicIPAddresses@2025-05-01' = [for (vmName, i) in linuxVmNames: {
  name: 'pip-${vmName}'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}]

resource linuxNic 'Microsoft.Network/networkInterfaces@2025-05-01' = [for (vmName, i) in linuxVmNames: {
  name: 'nic-${vmName}'
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
            id: linuxPublicIp[i].id
          }
          applicationSecurityGroups: [
            {
              id: asgServersLinux.id
            }
          ]
        }
      }
    ]
  }
}]

resource linuxVm 'Microsoft.Compute/virtualMachines@2025-04-01' = [for (vmName, i) in linuxVmNames: {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: linuxVmSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
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
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      customData: base64('''
#cloud-config
packages:
 - nginx
runcmd:
 - systemctl start nginx
 - systemctl enable nginx
 - echo "<html><head><title>Webserver Cloud Advanced</title></head><body><h1>Webserver Cloud Advanced</h1><h2>Hosted from $(hostname)</h2></body></html>" > /var/www/html/index.html
''')
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: linuxNic[i].id
        }
      ]
    }
  }
}]
