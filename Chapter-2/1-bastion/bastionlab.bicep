param location string = resourceGroup().location

@secure() 
param adminPassword string
param adminUsername string = 'azureuser'

// Kali VM
param kaliVmName string = 'kali'
param kaliVmSize string = 'Standard_B2ts_v2'
param kaliVnetPrefix string = '192.168.0.0/16'
param kaliSubnetPrefix string = '192.168.10.0/24'

// WebSSH VM
param websshVmName string = 'webssh'
param websshVmSize string = 'Standard_B2ts_v2'
param websshVnetPrefix string = '10.2.0.0/16'
param websshSubnetPrefix string = '10.2.1.0/24'

// WebBastion VM
param webbastionVmName string = 'webbast'
param webbastionVmSize string = 'Standard_B2ts_v2'
param webbastionVnetPrefix string = '10.3.0.0/16'
param webbastionSubnetPrefix string = '10.3.1.0/24'

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
        name: 'nsg-${kaliVmName}'
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
// WebSSH VM Resources
// ----------------------
resource nsgWebssh 'Microsoft.Network/networkSecurityGroups@2025-05-01' = {
  name: 'nsg-${websshVmName}'
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
    ]
  }
}

resource websshVnet 'Microsoft.Network/virtualNetworks@2025-05-01' = {
  name: 'vnet-${websshVmName}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [websshVnetPrefix]
    }
    subnets: [
      {
        name: 'subnet-${websshVmName}'
        properties: {
          addressPrefix: websshSubnetPrefix
          networkSecurityGroup: {
            id: nsgWebssh.id
          }
        }
      }
    ]
  }
}

resource websshPubIP 'Microsoft.Network/publicIPAddresses@2025-05-01' = {
  name: 'pubip-${websshVmName}'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource websshNic 'Microsoft.Network/networkInterfaces@2025-05-01' = {
  name: 'nic-${websshVmName}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: websshVnet.properties.subnets[0].id
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: websshPubIP.id
          }
        }
      }
    ]
  }
}

resource websshVm 'Microsoft.Compute/virtualMachines@2025-04-01' = {
  name: 'vm-${websshVmName}'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: websshVmSize
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
      computerName: websshVmName
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
          id: websshNic.id
        }
      ]
    }
  }
}


// ----------------------
// WebBastion VM Resources
// ----------------------
resource nsgWebbastion 'Microsoft.Network/networkSecurityGroups@2025-05-01' = {
  name: 'nsg-${webbastionVmName}'
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

resource webbastionVnet 'Microsoft.Network/virtualNetworks@2025-05-01' = {
  name: 'vnet-${webbastionVmName}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [webbastionVnetPrefix]
    }
    subnets: [
      {
        name: 'subnet-${webbastionVmName}'
        properties: {
          addressPrefix: webbastionSubnetPrefix
          networkSecurityGroup: {
            id: nsgWebbastion.id
          }
        }
      }
    ]
  }
}

resource webbastionPubIP 'Microsoft.Network/publicIPAddresses@2025-05-01' = {
  name: 'pubip-${webbastionVmName}'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource webbastionNic 'Microsoft.Network/networkInterfaces@2025-05-01' = {
  name: 'nic-${webbastionVmName}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: webbastionVnet.properties.subnets[0].id
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: webbastionPubIP.id
          }
        }
      }
    ]
  }
}

resource webbastionVm 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: 'vm-${webbastionVmName}'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: webbastionVmSize
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
      computerName: webbastionVmName
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
          id: webbastionNic.id
        }
      ]
    }
  }
}
