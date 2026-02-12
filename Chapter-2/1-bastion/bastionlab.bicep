param location string = resourceGroup().location

@secure() 
param adminPassword string
param adminUsername string = 'azureuser'

// Kali VM
param kaliVmName string = 'kali-vm'
param kaliVmSize string = 'Standard_B2ts_v2'
param kaliVnetName string = 'kali-network'
param kaliVnetPrefix string = '192.168.0.0/16'
param kaliSubnetName string = 'kali-subnet'
param kaliSubnetPrefix string = '192.168.10.0/24'
param kaliNSGName string = 'nsg-kali'
param kaliPubIPName string = 'kali-pubip'

// WebSSH VM
param websshVmName string = 'webssh-vm'
param websshVmSize string = 'Standard_B2ts_v2'
param websshVnetName string = 'webssh-network'
param websshVnetPrefix string = '10.2.0.0/16'
param websshSubnetName string = 'webssh-subnet'
param websshSubnetPrefix string = '10.2.1.0/24'
param websshNSGName string = 'nsg-webssh'
param websshPubIPName string = 'webssh-pubip'

// WebBastion VM
param webbastionVmName string = 'webbastion-vm'
param webbastionVmSize string = 'Standard_B2ts_v2'
param webbastionVnetName string = 'webbastion-network'
param webbastionVnetPrefix string = '10.3.0.0/16'
param webbastionSubnetName string = 'webbastion-subnet'
param webbastionSubnetPrefix string = '10.3.1.0/24'
param webbastionNSGName string = 'nsg-webbastion'
param webbastionPubIPName string = 'webbastion-pubip'

// ----------------------
// Kali VM Resources
// ----------------------
resource nsgKali 'Microsoft.Network/networkSecurityGroups@2025-05-01' = {
  name: kaliNSGName
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
  name: kaliVnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [kaliVnetPrefix]
    }
    subnets: [
      {
        name: kaliSubnetName
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
  name: kaliPubIPName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource kaliNic 'Microsoft.Network/networkInterfaces@2025-05-01' = {
  name: '${kaliVmName}-nic'
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
  name: kaliVmName
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
  name: websshNSGName
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
  name: websshVnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [websshVnetPrefix]
    }
    subnets: [
      {
        name: websshSubnetName
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
  name: websshPubIPName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource websshNic 'Microsoft.Network/networkInterfaces@2025-05-01' = {
  name: '${websshVmName}-nic'
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
  name: websshVmName
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
  name: webbastionNSGName
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
  name: webbastionVnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [webbastionVnetPrefix]
    }
    subnets: [
      {
        name: webbastionSubnetName
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
  name: webbastionPubIPName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource webbastionNic 'Microsoft.Network/networkInterfaces@2025-05-01' = {
  name: '${webbastionVmName}-nic'
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
  name: webbastionVmName
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
