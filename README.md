---
services: azure-resource-manager, virtual-machines, azure-bastion, azure-monitor, virtual-network
author: paolosalvatori
---

# JMeter Distributed Test Harness #
Apache JMeter distributed testing leverages multiple systems to perform load testing against a target system, typically a web site or REST API. Distributed testing can be used to sping up a large amount of concurrent virtual users and generate traffic aginst websites and server applications. The ARM template can be used to deploy an [Apache JMeter Distributed Test Harness](https://jmeter.apache.org/usermanual/jmeter_distributed_testing_step_by_step.html) composed of Azure virtual machines located in different Azure regions. 

# Architecture #
The following picture shows the architecture and network topology of the JMeter distributed test harness.

![Architecture](https://raw.githubusercontent.com/paolosalvatori/jmeter-distributed-test-harness/master/images/TestHarness.png)

JMeter master and slave nodes expose a Public IP using the [Java Remote Method Invocation](https://en.wikipedia.org/wiki/Java_remote_method_invocation) communication protocol over the public internet. In order to lock down security, [Network Security Groups](https://docs.microsoft.com/en-us/azure/virtual-network/security-overview) are used to allow inbound traffic on the TCP ports used by JMeter on master and slave nodes only from the virtual machines that are part of the topology. 

 The following picture shows the Network Security Group of the master node. 

![Master NSG](https://raw.githubusercontent.com/paolosalvatori/jmeter-distributed-test-harness/master/images/MasterNSG.png)

At point 1 you can note that the access via RDP is allowed only from a given public IP. You can restrict the RDP access to master and slave nodes by specifing a public IP as value of the **allowedAddress** parameter in the **azuredeploy.parameters.json** file.
At point 2 and 3 you can see that the access to ports **1099** and **4000-4002** used by JMeter on the master node is retricted to the public IPs of the slave nodes.

 The following picture shows the Network Security Group of the slave node. 

![Slave NSG](https://raw.githubusercontent.com/paolosalvatori/jmeter-distributed-test-harness/master/images/SlaveNSG.png)

At point 1 you can note that the access via RDP is allowed only from a given public IP. You can restrict the RDP access to master and slave nodes by specifing a public IP as value of the **allowedAddress** parameter in the **azuredeploy.parameters.json** file.
At point 2 and 3 you can see that the access to ports **1099** and **4000-4002** used by JMeter on the master node is retricted to the public IPs of the master node.
 
You can connect to master and slave nodes via RDP on port 3389. In addition, you can connect to the JMeter master virtual machine via [Azure Bastion](https://docs.microsoft.com/en-us/azure/bastion/bastion-overview) which provides secure and seamless RDP/SSH connectivity to your virtual machines directly in the Azure portal over SSL. You can customize the ARM template to disable the access to virtual machines via RDP by eliminating the corresponding rule in the Network Security Groups or you can eliminate Azure Bastion if you don't want to use this access type. 
 
A [Custom Script Extension for Windows](https://docs.microsoft.com/en-us/azure/virtual-machines/extensions/custom-script-windows) downloads and executes a PowerShell script that performs the following tasks:

- Automatically installs Apache JMeter on both the master and slave nodes via [Chocolatey](https://chocolatey.org/packages/jmeter) .  - Customizes the JMeter properties file to disable RMI over SSL and set 4000 TCP port for client/server communications. 
- Downloads the [JMeter Backend Listener for Application Insights](https://github.com/adrianmo/jmeter-backend-azure) that can be used to send test results to Azure Application Insights.
- Creates inbound rules in the Windows Firewall to allow traffic on ports 1099 and 4000-4002.
- Creates a Windows Task on slave nodes to launch JMeter Server at the startup.
- Automatically starts Jmeter Server on slave nodes.

In addition, all the virtual machines in the topology are configured to collect diagnostics logs, Windows Logs, and performance counters to a Log Analytics workspace. The workspace makes use of the following solutions to keep track of the health of the virtual machines:

- [Agent Health](https://docs.microsoft.com/en-us/azure/azure-monitor/insights/solution-agenthealth)
- [Service Map](https://docs.microsoft.com/en-us/azure/azure-monitor/insights/service-map)
- [Infrastructure Insights](https://docs.microsoft.com/en-us/azure/azure-monitor/insights/vminsights-enable-overview)

# Deployment #
You can use the **azuredeploy.json** ARM template and parameters file included in this repository to deploy the JMeter test harness. Make sure to edit the **azuredeploy.parameters.json** file to customize the installation. In particular, you can customize the list of virtual machines by editing the **virtualMachines** parameter in the parameters file. You can also use the **deploy.sh** Bash script to deploy the ARM template.

# Testing #
You can connect to the JMeter master node with the credentials specified in the ARM template to run tests using the JMeter UI or command-line tool. For more information on how to run tests on remote nodes, see: 

- [Apache JMeter Distributed Testing Step-by-step](https://jmeter.apache.org/usermanual/jmeter_distributed_testing_step_by_step.html)
- [Jmeter Remote Testing](https://jmeter.apache.org/usermanual/remote-test.html)

You can also use the **run.ps1** PowerShell script to run tests on the master node or remote nodes. The script allows to specify the thread number, warmup time, and duration of the test. In order to use this data as parameters, the JMeter test file (.jmx) needs to use define corresponding parameters. As a sample, see the **bing-test.jmx** JMeter test in this repository.

![Slave NSG](https://raw.githubusercontent.com/paolosalvatori/jmeter-distributed-test-harness/master/images/RunScript.png)

This script allows to save JMeter logs, results and dashboard on the local file system.

![Slave NSG](https://raw.githubusercontent.com/paolosalvatori/jmeter-distributed-test-harness/master/images/RunScript.png)

You can use **Windows PowerShell** or **Windows PowerShell ISE** to run commands. For example, the following command:

```powershell
.\run.ps1 -JMeterTest .\bing-test.jmx -Duration 60 -WarmupTime 30 -NumThreads 30 -Remote "191.233.25.31, 40.74.104.255, 52.155.176.185"
```

generates the following JMeter command:

```batch
C:\ProgramData\chocolatey\lib\jmeter\tools\apache-jmeter-5.2.1\bin\jmeter -n -t ".\bing-test.jmx" -l "C:\tests\test_runs\bing-test_1912332531_4074104255_52155176185\test_20200325_052525\results\resultfile.jtl" -e -o "C:\tests\test_runs\bing-test_1912332531_4074104255_52155176185\test_20200325_052525\output" -j "C:\tests\test_runs\bing-test_1912332531_4074104255_52155176185\test_20200325_052525\logs\jmeter.jtl" -Jmode=Stand
ard -Gnum_threads=30 -Gramp_time=30 -Gduration=60 -Djava.rmi.server.hostname=51.124.79.211 -R "191.233.25.31, 40.74.104.255, 52.155.176.185"
```

# Possible Developments #
This solution uses Public IPs to let master and slave nodes to communicate with each other. An alternative solution could be deploying master and slave nodes in different virtual networks located in different regions and use [global virtual network peering](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-network-peering-overview) to connect these virtual networks. Using this approach, the master node could communicate with slave nodes via private IP addresses.

This topology has the following advantages over a topology that uses private IP addresses:

- Reduced complexity 
- Lower total cost of ownership (TCO)
- Extensibility

As an example of extensibility, you can provision slave nodes on other cloud platforms. I personally tested this possibility by provisioning additional slave nodes on AWS.

Last but not least, the ARM template can be easily changed to replace **virtual machines** with **virtual machine scale sets** (VMSS).
