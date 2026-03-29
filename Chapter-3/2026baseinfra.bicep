param location string = resourceGroup().location

@secure()
param adminPassword string
param adminUsername string = 'azureuser'

// Networking
param vnetName string = 'vnet-checkapp'
param vnetPrefix string = '172.16.0.0/16'
param frontendSubnetName string = 'snet-frontend'
param frontendSubnetPrefix string = '172.16.1.0/24'
param frontendPublicIpName string = 'pip-frontend'
param JumpPublicIpName string = 'pip-jumpserver'
param linuxVmSize string = 'Standard_B2ts_v2'

var vmConfigs = [
  {
    name: 'vm-frontend'
		subnetName: frontendSubnetName
		includeInLoadBalancer: true
  }
	{
    name: 'vm-jumpserver'
		subnetName: frontendSubnetName
		includeInLoadBalancer: false
  }
]

var cloudInitDocker = '''
#cloud-config
package_update: true
package_upgrade: false
packages:
  - docker.io
runcmd:
  - docker pull klaaspxl/checkapp-frontend
'''

resource vnetCheckApp 'Microsoft.Network/virtualNetworks@2025-05-01' = {
	name: vnetName
	location: location
	properties: {
		addressSpace: {
			addressPrefixes: [vnetPrefix]
		}
	}
}

resource subnetFrontend 'Microsoft.Network/virtualNetworks/subnets@2025-05-01' = {
	parent: vnetCheckApp
	name: frontendSubnetName
	properties: {
		addressPrefix: frontendSubnetPrefix
		defaultOutboundAccess: true
		networkSecurityGroup: {
			id: nsgFrontEnd.id
		}
	}
}

resource nsgFrontEnd 'Microsoft.Network/networkSecurityGroups@2025-05-01' = {
	name: 'nsg-frontend'
	location: location
	properties: {
		securityRules: [
			{
				name: 'AllowHttp80FromInternet'
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

resource nsgBackend 'Microsoft.Network/networkSecurityGroups@2025-05-01' = {
	name: 'nsg-backend'
	location: location
	properties: {
		securityRules: []
	}
}

resource publicIpFrontEnd 'Microsoft.Network/publicIPAddresses@2025-05-01' = {
	name: frontendPublicIpName
	location: location
	tags: {
		bicepcreated: 'true'
	}
	sku: {
		name: 'Standard'
	}
	properties: {
		publicIPAllocationMethod: 'Static'
		publicIPAddressVersion: 'IPv4'
	}
}

resource publicIpJump 'Microsoft.Network/publicIPAddresses@2025-05-01' = {
	name: JumpPublicIpName
	location: location
	tags: {
		bicepcreated: 'true'
	}
	sku: {
		name: 'Standard'
	}
	properties: {
		publicIPAllocationMethod: 'Static'
		publicIPAddressVersion: 'IPv4'
	}
}

resource linuxNics 'Microsoft.Network/networkInterfaces@2025-05-01' = [for vm in vmConfigs: {
	name: 'nic-${vm.name}'
	location: location
	properties: {
		ipConfigurations: [
			{
				name: 'ipconfig1'
				properties: {
					subnet: {
						id: subnetFrontend.id
					}
					privateIPAllocationMethod: 'Dynamic'
					publicIPAddress: {
						id: vm.name == 'vm-frontend' ? publicIpFrontEnd.id : publicIpJump.id
					}
				}
			}
		]
	}
}]

resource linuxVms 'Microsoft.Compute/virtualMachines@2025-04-01' = [for (vm, i) in vmConfigs: {
	name: vm.name
	location: location
	tags: {
		bicepcreated: 'true'
	}
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
			computerName: vm.name
			adminUsername: adminUsername
			adminPassword: adminPassword
			...(vm.name == 'vm-frontend' ? {
				customData: base64(cloudInitDocker)
			} : {})
			linuxConfiguration: {
				disablePasswordAuthentication: false
			}
		}
		networkProfile: {
			networkInterfaces: [
				{
					id: linuxNics[i].id
				}
			]
		}
	}
}]
