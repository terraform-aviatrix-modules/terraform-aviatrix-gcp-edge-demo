# Script to validate if the Edge Gateway is indeed up.

import libvirt, libvirt_qemu
import sys, json, base64, time, re

#########################################################################
# getVM - is a VM running, get config
#########################################################################
def getVM(c, n):
  try:
      d = c.lookupByName(n)
  except libvirt.libvirtError as e:
      return "missing"

  if d.ID() == -1 or not d.isActive():
    return "stopped"
  
  return d

#########################################################################
# guestExec - run command on KVM VM
#########################################################################
def guestExec(d, cmd, *argv):
  vmConnectStatus = False
  requestObj = {
    "execute" :  "guest-exec",
    "arguments" : {
      "path": cmd,
      "arg" : argv,
      "capture-output" : True 
    }
  }
  while vmConnectStatus == False:
    requestResult = json.loads(libvirt_qemu.qemuAgentCommand(d, json.dumps(requestObj), 5, 0))

    requestStatusObj = {
        "execute": "guest-exec-status",
        "arguments": {
            "pid": requestResult['return']['pid']
        }
    }

    cmdFinished=False
    while cmdFinished == False:
      requestStatusResult = json.loads(libvirt_qemu.qemuAgentCommand(d, json.dumps(requestStatusObj), 5, 0))
      cmdFinished = requestStatusResult['return']['exited']
      if cmdFinished == False:
          time.sleep(5)

  base64.b64decode(requestStatusResult['return']['out-data'])

#########################################################################
# Main
#########################################################################
edgeVmName = "avx-mattk-edge-vm-1"
maxLoop = 5

#Connect to Libvirt
try:
    conn = libvirt.open("qemu:///system")
except libvirt.libvirtError as e:
    print('Failed to open connection to KVM.')
    print(repr(e))
    sys.exit(1)

#Get VM status from libvirt
loop = 0
dom = ""
while type(dom) is str or loop == maxLoop:
  dom = getVM(conn, edgeVmName)
  if type(dom) is str:
    time.sleep(30)
    loop = loop + 1

if type(dom) is str:
  print("{} isn't running.".format(edgeVmName))
  sys.exit(1)

# Connect to the VM and get network connectivity status.
vmConnectStatus = False
loop = 0
while vmConnectStatus == False or loop == maxLoop:
  result = guestExec(dom, 'python', "/home/ubuntu/avx-edge/interface.py", "test", "--connect")
  vmConnectStatus = bool(re.search('succeeded', result))
  if vmConnectStatus == False:
    time.sleep(30)
    loop = loop + 1

if vmConnectStatus == False:
  print("{} not reported connected. Check firewall rules, maybe.".format(edgeVmName))
  sys.exit(1)

# Connect to VM and check Conduit connectivity.
# If this succeeds, the Edge is up and connected.
conduitStatus = False
loop = 0
while conduitStatus == False or loop == maxLoop:
  result = guestExec(dom, 'python', "/home/ubuntu/avx-edge/helper.py", "conduit_ping")
  conduitStatus = bool(re.search('succeeded', result))
  if conduitStatus == False:
    time.sleep(30)
    loop = loop + 1
  if loop == maxLoop:
    break