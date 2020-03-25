---
services: azure-resource-manager, virtual-machines, azure-bastion, azure-monitor, virtual-network
author: paolosalvatori
---

# JMeter Distributed Test Harness #
Apache JMeter distributed testing leverages multiple systems to perform load testing against a target system, typically a web site or REST API. Distributed testing can be used to sping up a large amount of concurrent virtual users and generate traffic aginst websites and server applications. The ARM template can be used to deploy an [Apache JMeter Distributed Test Harness](https://jmeter.apache.org/usermanual/jmeter_distributed_testing_step_by_step.html) composed of Azure virtual machines located in different Azure regions. 

# Architecture #
The following picture shows the architecture and network topology of the JMeter distributed test harness.
<br/>
<br/>
![Architecture](../TestHarness.png)
<br/>
JMeter master and slave nodes expose a Public IP using the [Java Remote Method Invocation](https://en.wikipedia.org/wiki/Java_remote_method_invocation) communication protocol over the public internet. In order to lock down security, [Network Security Groups](https://docs.microsoft.com/en-us/azure/virtual-network/security-overview) are used to allow inbound traffic on the TCP ports used by JMeter on master and slave nodes only from the virtual machines that are part of the topology. 

 The following picture shows the Network Security Group of the master node. 
<br/>
<br/>
![Master NSG](../MasterNSG.png)
<br/> 
At point 1 you can note that the access via RDP is allowed only from a given public IP. You can restrict the RDP access to master and slave nodes by specifing a public IP as value of the **allowedAddress** parameter in the **azuredeploy.parameters.json** file.
At point 2 and 3 you can see that the access to ports **1099** and **4000-4002** used by JMeter on the master node is retricted to the public IPs of the slave nodes.

 The following picture shows the Network Security Group of the slave node. 
<br/>
<br/>
![Slave NSG](../SlaveNSG.png)
<br/> 
At point 1 you can note that the access via RDP is allowed only from a given public IP. You can restrict the RDP access to master and slave nodes by specifing a public IP as value of the **allowedAddress** parameter in the **azuredeploy.parameters.json** file.
At point 2 and 3 you can see that the access to ports **1099** and **4000-4002** used by JMeter on the master node is retricted to the public IPs of the master node.
 
You can connect to master and slave nodes via RDP on port 3389. In addition, you can connect to the JMeter master virtual machine via [Azure Bastion](https://docs.microsoft.com/en-us/azure/bastion/bastion-overview) which provides secure and seamless RDP/SSH connectivity to your virtual machines directly in the Azure portal over SSL. You can customize the ARM template to disable the access to virtual machines via RDP by eliminating the corresponding rule in the Network Security Groups or you can eliminate Azure Bastion if you don't want to use this access type. 
 
A Custom SC

In addition, all the virtual machines in the topology are configured to collect diagnostics logs, Windows Logs, and performance counters to a Log Analytics workspace. The workspace makes use of the following solutions to keep track of the health of the virtual machines:

- [Agent Health](https://docs.microsoft.com/en-us/azure/azure-monitor/insights/solution-agenthealth)
- [Service Map](https://docs.microsoft.com/en-us/azure/azure-monitor/insights/service-map)
- [Infrastructure Insights](https://docs.microsoft.com/en-us/azure/azure-monitor/insights/vminsights-enable-overview)


# Deployment #
The deployment of the topology is fully automated via:

- ARM templates
- Bash script
- Azure DevOps CI/CD pipelines

Make sure to substitute the placeholders in the parameters files and in the **setup.bat** bash script, then run this script to deploy the sample in your Azure subscription.

# Testing #
VPN into the Jumpbox VM using Bastion or the public IP of the virtual machine, and use an internet browser to connect to the private endpoint exposed by the Application Gateway. If you refresh the page, you should see that requests are distributed across the 3 web Apps, each located in a separate zonal ILB App Service Environment.
<br/>
<br/>
![HelloWorld](https://raw.githubusercontent.com/paolosalvatori/multi-az-ase/master/images/helloworld.png)
<br/>
