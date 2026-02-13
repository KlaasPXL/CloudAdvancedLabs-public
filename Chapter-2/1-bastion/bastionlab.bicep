param location string = resourceGroup().location

@secure() 
param adminPassword string
param adminUsername string = 'azureuser'

// Kali VM
param kaliVmName string = 'kali'
param kaliVmSize string = 'Standard_B2ts_v2'


//Networking
param kaliVnetPrefix string = '192.168.0.0/16'
param kaliSubnetPrefix string = '192.168.10.0/24'
param serversVnetPrefix string = '10.1.0.0/16'
param serversSubnetPrefix string = '10.1.10.0/24'
param serversNetworkName string = 'servers'
param serversSubnetName string ='servers'

// linux VM
param linuxVmName string = 'linux'
param linuxVmSize string = 'Standard_B2ts_v2'


// win VM
param winVmName string = 'win'
param winVmSize string = 'Standard_B2ls_v2'


// ----------------------
// Network Resources
// ----------------------


resource serversVnet 'Microsoft.Network/virtualNetworks@2025-05-01' = {
  name: 'vnet-${serversNetworkName}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [serversVnetPrefix]
    }
    subnets: [
      {
        name: 'subnet-${serversSubnetName}'
        properties: {
          addressPrefix: serversSubnetPrefix
          networkSecurityGroup: {
            id: nsgServers.id
          }
        }
      }
    ]
  }
}

resource nsgServers 'Microsoft.Network/networkSecurityGroups@2025-05-01' = {
  name: 'nsg-${serversNetworkName}'
  location: location
  properties: {
    securityRules: [
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
          destinationAddressPrefix: '*'
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
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowRDP'
        properties: {
          priority: 1020
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// ----------------------
// Kali VM Resources
// ----------------------
resource nsgKali 'Microsoft.Network/networkSecurityGroups@2025-05-01' = {
  name: 'nsg-${kaliVmName}'
  location: location
  properties: {
    securityRules: [
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
          destinationAddressPrefix: '*'
        }
      }      
    ]
  }
}

resource kaliVnet 'Microsoft.Network/virtualNetworks@2025-05-01' = {
  name: 'vnet-${kaliVmName}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [kaliVnetPrefix]
    }
    subnets: [
      {
        name: 'subnet-${kaliVmName}'
        properties: {
          addressPrefix: kaliSubnetPrefix
          networkSecurityGroup: {
            id: nsgKali.id
          }
        }
      }
    ]
  }
}

resource kaliPubIP 'Microsoft.Network/publicIPAddresses@2025-05-01' = {
  name: 'pubip-${kaliVmName}'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource kaliNic 'Microsoft.Network/networkInterfaces@2025-05-01' = {
  name: 'nic-${kaliVmName}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: kaliVnet.properties.subnets[0].id
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: kaliPubIP.id
          }
        }
      }
    ]
  }
}

resource kaliVm 'Microsoft.Compute/virtualMachines@2025-04-01' = {
  name: 'vm-${kaliVmName}'
  location: location

  plan: {
    publisher: 'kali-linux'
    product: 'kali'
    name: 'kali-2025-4'
  }

  properties: {
    hardwareProfile: {
      vmSize: kaliVmSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'kali-linux'
        offer: 'kali'
        sku: 'kali-2025-4'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    osProfile: {
      computerName: kaliVmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      customData: base64('''
#cloud-config
package_upgrade: true
packages:
  - nmap
''')
    }
    networkProfile: {
      networkInterfaces: [
        { id: kaliNic.id }
      ]
    }
  }
}

// ----------------------
// linux VM Resources
// ----------------------

resource linuxPubIP 'Microsoft.Network/publicIPAddresses@2025-05-01' = {
  name: 'pubip-${linuxVmName}'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

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
            id: linuxPubIP.id
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
      customData: base64('''
#cloud-config
package_upgrade: true
 
packages:
  - docker.io
 
runcmd:
  - systemctl start docker
  - systemctl enable docker
  - docker run -d --restart unless-stopped -p 80:80 klaaspxl/ca-staticweb:vm
''')
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


// ----------------------
// win VM Resources
// ----------------------
resource winPubIP 'Microsoft.Network/publicIPAddresses@2025-05-01' = {
  name: 'pubip-${winVmName}'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource winNic 'Microsoft.Network/networkInterfaces@2025-05-01' = {
  name: 'nic-${winVmName}'
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
            id: winPubIP.id
          }
        }
      }
    ]
  }
}

resource winVm 'Microsoft.Compute/virtualMachines@2025-04-01' = {
  name: 'vm-${winVmName}'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: winVmSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2025-datacenter-smalldisk-g2'
        version: 'latest'
      }
    }
    osProfile: {
      computerName: winVmName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: winNic.id
        }
      ]
    }
  }
}
