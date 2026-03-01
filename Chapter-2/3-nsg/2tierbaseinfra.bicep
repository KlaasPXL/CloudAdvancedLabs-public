param location string = resourceGroup().location

@secure()
param adminPassword string

param adminUsername string = 'azureuser'

// Networking
param vnetName string = 'vnet-subtracker'
param vnetPrefix string = '10.1.0.0/16'
param frontendSubnetName string = 'snet-frontend'
param frontendSubnetPrefix string = '10.1.10.0/24'
param backendSubnetName string = 'snet-backend'
param backendSubnetPrefix string = '10.1.20.0/24'
param loadBalancerPublicIpName string = 'pip-loadb'
param natGatewayPublicIpName string = 'pip-natgw'
param loadBalancerName string = 'lb-subtracker'
param linuxVmSize string = 'Standard_B2ts_v2'

var vmConfigs = [
  {
    name: 'vm-frontend'
		subnetName: frontendSubnetName
		includeInLoadBalancer: true
  }
  {
    name: 'vm-backend'
		subnetName: backendSubnetName
		includeInLoadBalancer: false
  }
]

var cloudInitDocker = '''
#cloud-config
package_update: true
package_upgrade: false
packages:
	- docker.io
'''

resource vnetSubtracker 'Microsoft.Network/virtualNetworks@2025-05-01' = {
	name: vnetName
	location: location
	properties: {
		addressSpace: {
			addressPrefixes: [vnetPrefix]
		}
	}
}

resource publicIpLoadBalancer 'Microsoft.Network/publicIPAddresses@2025-05-01' = {
	name: loadBalancerPublicIpName
	location: location
	sku: {
		name: 'Standard'
	}
	properties: {
		publicIPAllocationMethod: 'Static'
		publicIPAddressVersion: 'IPv4'
	}
}

resource publicIpNatGateway 'Microsoft.Network/publicIPAddresses@2025-05-01' = {
	name: natGatewayPublicIpName
	location: location
	sku: {
		name: 'StandardV2'
	}
	properties: {
		publicIPAllocationMethod: 'Static'
		publicIPAddressVersion: 'IPv4'
	}
}

resource natGatewaySubtracker 'Microsoft.Network/natGateways@2025-05-01' = {
	name: 'natgw-subtracker'
	location: location
	sku: {
		name: 'StandardV2'
	}
	properties: {
		publicIpAddresses: [
			{
				id: publicIpNatGateway.id
			}
		]
	}
}

resource publicLoadBalancer 'Microsoft.Network/loadBalancers@2025-05-01' = {
	name: loadBalancerName
	location: location
	sku: {
		name: 'Standard'
	}
	properties: {
		frontendIPConfigurations: [
			{
				name: 'fe-public'
				properties: {
					publicIPAddress: {
						id: publicIpLoadBalancer.id
					}
				}
			}
		]
		backendAddressPools: [
			{
				name: 'bepool-frontend'
			}
		]
		probes: [
			{
				name: 'probe-http-80'
				properties: {
					protocol: 'Tcp'
					port: 80
					intervalInSeconds: 5
					numberOfProbes: 2
				}
			}
		]
		loadBalancingRules: [
			{
				name: 'lbrule-http-80'
				properties: {
					protocol: 'Tcp'
					frontendPort: 80
					backendPort: 80
					enableFloatingIP: false
					disableOutboundSnat: true
					idleTimeoutInMinutes: 4
					loadDistribution: 'Default'
					frontendIPConfiguration: {
						id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', loadBalancerName, 'fe-public')
					}
					backendAddressPool: {
						id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancerName, 'bepool-frontend')
					}
					probe: {
						id: resourceId('Microsoft.Network/loadBalancers/probes', loadBalancerName, 'probe-http-80')
					}
				}
			}
		]
	}
}

resource subnetFrontend 'Microsoft.Network/virtualNetworks/subnets@2025-05-01' = {
	parent: vnetSubtracker
	name: frontendSubnetName
	properties: {
		addressPrefix: frontendSubnetPrefix
		natGateway: {
			id: natGatewaySubtracker.id
		}
		networkSecurityGroup: {
			id: nsgTrackapp.id
		}
	}
}

resource subnetBackend 'Microsoft.Network/virtualNetworks/subnets@2025-05-01' = {
	parent: vnetSubtracker
	name: backendSubnetName
	properties: {
		addressPrefix: backendSubnetPrefix
		natGateway: {
			id: natGatewaySubtracker.id
		}
		networkSecurityGroup: {
			id: nsgTrackapp.id
		}
	}
}

resource nsgTrackapp 'Microsoft.Network/networkSecurityGroups@2025-05-01' = {
	name: 'nsg-trackapp'
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

resource linuxNics 'Microsoft.Network/networkInterfaces@2025-05-01' = [for vm in vmConfigs: {
	name: 'nic-${vm.name}'
	location: location
	properties: {
		ipConfigurations: [
			{
				name: 'ipconfig1'
				properties: {
					subnet: {
						id: vm.subnetName == frontendSubnetName ? subnetFrontend.id : subnetBackend.id
					}
					privateIPAllocationMethod: 'Dynamic'
					loadBalancerBackendAddressPools: vm.includeInLoadBalancer ? [
						{
							id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancerName, 'bepool-frontend')
						}
					] : []
				}
			}
		]
	}
}]

resource linuxVms 'Microsoft.Compute/virtualMachines@2025-04-01' = [for (vm, i) in vmConfigs: {
	name: vm.name
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
			computerName: vm.name
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
					id: linuxNics[i].id
				}
			]
		}
	}
}]
