#!/usr/bin/env python
########################################################### {COPYRIGHT-TOP} ####
# Licensed Materials - Property of IBM
# IBM WFSS
#
# (C) Copyright IBM Corp. 2019
#
# US Government Users Restricted Rights - Use, duplication, or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
########################################################### {COPYRIGHT-END} ####

#usage : python clone_vms.py -s vcsa3-devops-vvm-wash4.fss.ibm.com  -u xyz@fss.ibm.com.local -source-vm-directory-path "/1414775-WDC04-FCI/vm/TRY/DD/103" -destination-vm-directory-path "/1414775-WDC04-FCI/vm/TRY/DD/103" -p secret -operation clone -vmlist vms.csv 

import sys
import csv
import json
from pyVmomi import vim, vmodl
from pyVim.connect import SmartConnectNoSSL, Disconnect
from pyVim.task import WaitForTask,WaitForTasks
from tools import cli

__author__ = 'IBM wfss SRE'


def setup_args():
    parser = cli.build_arg_parser()
    parser.add_argument('-n', '--property', default='runtime.powerState',
                        help='Name of the property to filter by')
    parser.add_argument('-v', '--value', default='poweredOn',
                        help='Value to filter with')
    parser.add_argument('-source-vm-directory-path', 
                        required=True,
                        action='store',
                        default=None,
                        help='Name of the source directory  VM to')
    parser.add_argument('-destination-vm-directory-path', 
                        required=True,
                        action='store',
                        default=None,
                        help='Name of the destination directory  VM to')
    parser.add_argument('-operation', 
                        required=True,
                        action='store',
                        default=None,
                        help='Operation list/create/clone')
    parser.add_argument('-vmlist', 
                        required=True,
                        action='store',
                        default=None,
                        help='CSV file with VMs list - for now the CSV file must exist in the same folder as this program')
    
    return cli.prompt_for_password(parser.parse_args())


def get_vmFolder(content, vimtype, name):
    """
    Return an object by name, if name is None the
    first found object is returned
    """
    obj = None
    container = content.viewManager.CreateContainerView(
        content.rootFolder, vimtype, True)
    for c in container.view:
        if name:
            if c.name == name:
                obj = c
                break
        else:
            obj = c
            break

    return obj

def get_vmlist(si,vmlist,source_vm_directory):

   f_obj=si.content.searchIndex.FindByInventoryPath(source_vm_directory)
   vm_list=[]

   with open(vmlist, 'r') as f:
        reader = csv.reader(f)
        for row in reader :
          vm_list.append(row[0])
        
    
   vmobject_list=[]
    
   
    
   if isinstance(f_obj, vim.VirtualApp):
       
       for c_obj in f_obj.vm :
          if(c_obj.name in vm_list) :
            vmobject_list.append(c_obj)


   elif not isinstance (f_obj, vim.Datacenter):
        for c_obj in f_obj.childEntity:
        
            if isinstance (c_obj, vim.VirtualMachine):
                if(c_obj.name in vm_list) :
                  vmobject_list.append(c_obj)
            
   else :
        for vm in f_obj.vmFolder.childEntity :
           if(vm.name in vm_list) :
             vmobject_list.append(vm)
    
   
   return vmobject_list

def clone_vms(vmobject_list,destination_vm_directory) :


    tasks=[]
    results=[]
    vm_meta_data={}
    vm_meta_data['meta_vm'] = []
    
    
    for vm in vmobject_list :
                relospec = vim.vm.RelocateSpec()
                relospec.folder=destination_vm_directory
                clonespec = vim.vm.CloneSpec()
                clonespec.powerOn = False
                clonespec.location = relospec
                vm_clone_name=vm.name+"_clone"
                print("cloning VM..."+vm.name)
                vm_dict = {"source_vm_name": vm.name,
                           "dest_vm_name": vm_clone_name,
                           "source_vm_hostname": vm.summary.guest.hostName,
                           "cpu": str(vm.summary.config.numCpu), 
                           "mem": str(vm.summary.config.memorySizeMB), 
                           "disks":str(vm.summary.config.numVirtualDisks)} 
                
                vm_meta_data['meta_vm'].append(vm_dict)
                task = vm.Clone(folder=destination_vm_directory, name=vm_clone_name, spec=clonespec)                  
                tasks.append(task)     
    with open("meta_vms.json", 'w') as outfile:
      json.dump(vm_meta_data,outfile)
    WaitForTasks(tasks,results=results,raiseOnError=False)
    for task in tasks :
         if(task.info.state== "success") :
           print("Cloning is success for "+task.info.entityName)
         else :
           print ("Investigate why cloning failed for "+ task.info.entityName + " Error :: "+ task.info.error.msg  )
 
    

def main():
    args = setup_args()
    si = SmartConnectNoSSL(host=args.host,
                           user=args.user,
                           pwd=args.password,
                           port=args.port)
    
    source_vm_directory=args.source_vm_directory_path
    destination_vm_directory=si.content.searchIndex.FindByInventoryPath(args.destination_vm_directory_path)
    operation=args.operation
    vmobject_list=get_vmlist(si,args.vmlist,source_vm_directory)

    if operation == 'list':

        for vm in vmobject_list :
          print(vm.summary)
          
 
    if operation == 'clone':
        
        clone_vms(vmobject_list,destination_vm_directory)
          

    Disconnect(si)


if __name__ == '__main__':
    main()