# Trace-WireSharkSelectedNICs.ps1
Use this script to start Wireshark tracing on all cluster nodes until we get event 1135 on each node.

Read more about it on [PlusOnTech.com](https://plusontech.com/2018/09/25/powershell-script-trace-wiresharkselectednics-ps1-collect-wireshark-traces-from-multiple-network-adapters/ "PlusOnTech.com post about Trace-WireSharkSelectedNICs script").
## Examples
* Trace and save to C:\WireSharkTrace folder on each of the nodes.
```PowerShell
.\Trace-WiresharkCluster.ps1 -TracePath C:\WireSharkTrace
```

* Trace all NICs on a remote cluster and save to C:\WireSharkTrace folder.
```PowerShell
.\Trace-WiresharkCluster.ps1 -TracePath C:\WireSharkTrace -ClusterName ExampleCluster.domain.com
```
    
* Trace only traffic on port 8080
```PowerShell
.\Trace-WiresharkCluster.ps1 -TracePath C:\WireSharkTrace -CaptureFilter "Port 8080"
```
* Trace and save log to "C:\WireSharkClusterTrace.log"
```PowerShell
.\Trace-WiresharkCluster.ps1 -TracePath C:\WireSharkTrace -LogPath "C:\WireSharkClusterTrace.log"
```