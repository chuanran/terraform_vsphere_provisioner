#!/usr/bin/env python
"""
Written by Chuan Ran
Find vms metadata by data_center

"""

from __future__ import print_function

import argparse
import getpass
import json
try:
    from pyVmomi import vim
    from pyVim.connect import SmartConnectNoSSL, Disconnect
    import atexit
except ImportError:
    print ("pyVmomi modules does not exist")


data = {}


def getargs():
    """
    Supports the command-line arguments listed below.
    """
    parser = argparse.ArgumentParser(
        description='Process args for retrieving all the Virtual Machines')
    parser.add_argument('-s', '--host', required=True, action='store',
                        help='Remote host to connect to')
    parser.add_argument('-d', '--datacenter', required=True, action='store',
                        help='the datacenter where the source vms are located in')
    parser.add_argument('-o', '--port', type=int, default=443, action='store',
                        help='Port to connect on')
    parser.add_argument('-u', '--user', required=True, action='store',
                        help='User name to use when connecting to host')
    parser.add_argument('-p', '--password', required=False, action='store',
                        help='Password to use when connecting to host')
    parser.add_argument('--json', required=False, action='store_true',
                        help='Write out to json file')
    parser.add_argument('--jsonfile', required=False, action='store',
                        default='vms_in_dc.json',
                        help='Filename and path of json file')
    parser.add_argument('--silent', required=False, action='store_true',
                        help='supress output to screen')
    args = parser.parse_args()
    return args


def vmsummary(summary, datacenter_name, hostname, ip_addr):
    vmsum = {}
    config = summary.config
    vmsum['dc'] = datacenter_name
    vmsum['hostname'] = hostname
    vmsum['ip'] = ip_addr
    vmsum['path'] = config.vmPathName
    vmsum['mem'] = str(config.memorySizeMB)
    vmsum['cpu'] = str(config.numCpu)
    vmsum['diskcnt'] = str(config.numVirtualDisks)
    vmsum['ostype'] = config.guestFullName
    vmsum['state'] = summary.runtime.powerState
    return vmsum


# need to include vm_name, dc_name, mem, disk_number, cpu_num into dictionary
def vm2dict(vm_name, summary):
    # If nested folder path is required, split into a separate function
    vmname = vm_name
    data[vmname]['dc'] = summary['dc']
    data[vmname]['hostname'] = summary['hostname']
    data[vmname]['ip'] = summary['ip']
    data[vmname]['path'] = summary['path']
    data[vmname]['mem'] = summary['mem']
    data[vmname]['cpu'] = summary['cpu']
    data[vmname]['diskcnt'] = summary['diskcnt']
    data[vmname]['ostype'] = summary['ostype']
    data[vmname]['state'] = summary['state']


def data2json(data, args):
    with open(args.jsonfile, 'w') as f:
        json.dump(data, f)


def get_all_objs(content, vimtype, folder=None, recurse=True):
    if not folder:
        folder = content.rootFolder
    obj = {}
    container = content.viewManager.CreateContainerView(folder, vimtype, recurse)
    for managed_object_ref in container.view:
        obj.update({managed_object_ref: managed_object_ref.name})
    return obj


def find_vms_by_dc(content, data_center, recurse=True):
    vms = get_all_objs(content, [vim.VirtualMachine], data_center.hostFolder, recurse=True)
    for vm in vms:
        data[vm.name] = {}
        
        summary = vmsummary(vm.summary, data_center.name, vm.summary.guest.hostName, vm.guest.ipAddress)
        vm2dict(vm.name, summary)
    return None


def main():
    args = getargs()
    outputjson = True if args.json else False
    if args.password:
        password = args.password
    else:
        password = getpass.getpass(prompt='Enter password for host %s and '
                                          'user %s: ' % (args.host, args.user))
    si = SmartConnectNoSSL(host=args.host,
                           user=args.user,
                           pwd=password,
                           port=int(args.port))

    if not si:
        print("Could not connect to the specified host using specified "
              "username and password")
        return -1

    atexit.register(Disconnect, si)
    root_folder = si.content.rootFolder
    for data_center in root_folder.childEntity:
        if data_center.name == args.datacenter:
            find_vms_by_dc(si.content, data_center)

    if not args.silent:
        print(json.dumps(data, sort_keys=True, indent=4))

    if outputjson:
        data2json(data, args)


# Start program
if __name__ == "__main__":
    main()
