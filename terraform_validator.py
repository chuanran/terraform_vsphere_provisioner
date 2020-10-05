from __future__ import print_function
import argparse
import getpass
import json
import urllib

try:
    from pyVmomi import vim
    from pyVim.connect import SmartConnectNoSSL, Disconnect
    from com.vmware.cis.tagging_client import (Category, CategoryModel, Tag, TagAssociation)
    from vmware.vapi.vsphere.client import create_vsphere_client
    import ssl
    import requests
    import urllib3
    import atexit
except ImportError:
    print ("pyVmomi modules does not exist")

MBFACTOR = float(1 << 20)

def get_obj(content, vimtype):
    return [item for item in content.viewManager.CreateContainerView(
        content.rootFolder, [vimtype], recursive=True).view]


def get_smart_connection(host_ip, vsphere_user, vsphere_password):
    try:
        si = SmartConnectNoSSL(host=host_ip,
                           user=vsphere_user,
                           pwd=vsphere_password
                          )
        atexit.register(Disconnect, si)
    except:
        raise SystemExit("Unable to connect to host %s with supplied user %s and password %s" % (host_ip, vsphere_user, vsphere_password))
    return si

def retrieve_dc_list(host_ip, vsphere_user, vsphere_password):
    si = get_smart_connection(host_ip, vsphere_user, vsphere_password)
    # A list comprehension of all the root folder's first tier children...
    try:
        datacenters = [entity for entity in si.content.rootFolder.childEntity if hasattr(entity, 'vmFolder')]
    except:
        raise SystemExit("Unable to list datacenter using host %s, user %s and password %s" % (host_ip, vsphere_user, vsphere_password))
    # Just to prove to ourselves we have that list:
    for dc in datacenters:
        print(urllib.parse.unquote(dc.name))


def get_network_adapters_by_dc(host_ip, vsphere_user, vsphere_password, datacenter_name):
    si = get_smart_connection(host_ip, vsphere_user, vsphere_password)
    try:
        datacenters = [entity for entity in si.content.rootFolder.childEntity if hasattr(entity, 'vmFolder')]
    except:
        raise SystemExit("Unable to list datacenter using host %s, user %s and password %s" % (host_ip, vsphere_user, vsphere_password))
    # Just to prove to ourselves we have that list:
    for dc in datacenters:
        if dc.name == datacenter_name:
            for nic in dc.network:
                print(nic.name)

def get_datastores_by_dc(host_ip, vsphere_user, vsphere_password, datacenter_name):
    si = get_smart_connection(host_ip, vsphere_user, vsphere_password)
    # A list comprehension of all the root folder's first tier children...
    try:
        datacenters = [entity for entity in si.content.rootFolder.childEntity if hasattr(entity, 'vmFolder')]
    except:
        raise SystemExit("Unable to list datacenter using host %s, user %s and password %s" % (host_ip, vsphere_user, vsphere_password))
    # Just to prove to ourselves we have that list:
    for dc in datacenters:
        if dc.name == datacenter_name:
            for ds in dc.datastore:
                print(ds.info.name)


def get_clusters(host_ip, vsphere_user, vsphere_password):
    si = get_smart_connection(host_ip, vsphere_user, vsphere_password)
    for cluster_obj in get_obj(si.content, vim.ComputeResource):
       print(cluster_obj.name)
    
#def get_host_folders_by_dc(host_ip, vsphere_user, vsphere_password, datacenter_name):
#    si = get_smart_connection(host_ip, vsphere_user, vsphere_password)
#    for 


def get_hosts_by_cluster(host_ip, vsphere_user, vsphere_password, cluster_name):
    si = get_smart_connection(host_ip, vsphere_user, vsphere_password)
    for cluster_obj in get_obj(si.content, vim.ComputeResource):
        if cluster_obj.name == cluster_name:
            for host in cluster_obj.host:
                print(host.name)

def check_inventory_path(host_ip, vsphere_user, vsphere_password, datacenter_name, folder_path):
    si = get_smart_connection(host_ip, vsphere_user, vsphere_password)
    try:
        obj = si.content.searchIndex.FindByInventoryPath(datacenter_name + '/vm/' + folder_path)
    except:
        raise SystemExit("Folder %s does NOT exist" %(folder_path))
    print(obj)


# validate cluster
def validate_cluster_capacity(host_ip, vsphere_user, vsphere_password, cluster_name, max_percentage):
    try:
        si = get_smart_connection(host_ip, vsphere_user, vsphere_password)
        for cluster_obj in get_obj(si.content, vim.ComputeResource):
            if cluster_obj.name == cluster_name:
                usage = cluster_obj.GetResourceUsage()
                cpuCapacity = usage.cpuCapacityMHz
                cpuUsed = usage.cpuUsedMHz
                memCapacity = usage.memCapacityMB
                memUsed = usage.memUsedMB
                storageCapacity = usage.storageCapacityMB
                storageUsed = usage.storageUsedMB

                usedCPUPercentage = (cpuUsed / cpuCapacity) * 100
                usedMemoryPercentage = (memUsed / memCapacity) * 100
                usedStoragePercentage = (storageUsed / storageCapacity) * 100

                if cluster_obj.summary.overallStatus != 'green':
                    print("Cluster:{} might have a problem. Status - {}".format(cluster_name, cluster_obj.summary.overallStatus))
                    return
                if usedCPUPercentage > max_percentage:
                    print("Cluster:{} CPU has been used more than {}%".format(cluster_name, max_percentage))
                if usedMemoryPercentage > max_percentage:
                    print("Cluster:{} Memory has been used more than {}%".format(cluster_name, max_percentage))
                if usedStoragePercentage > max_percentage:
                    print("Cluster:{} Storage has been used more than {}%".format(cluster_name, max_percentage))
                if usedCPUPercentage < max_percentage and usedMemoryPercentage < max_percentage and usedStoragePercentage < max_percentage:
                    print(True)
                return
        print(False)
    except:
        raise SystemExit("Unable to retreive usage information for {}".format(cluster_name))


# validate host
def validate_host_capacity(host_ip, vsphere_user, vsphere_password, cluster_name, host_name, max_percentage):
    try:
        si = get_smart_connection(host_ip, vsphere_user, vsphere_password)
        for cluster_obj in get_obj(si.content, vim.ComputeResource):
            if cluster_obj.name == cluster_name:
                for host in cluster_obj.host:
                    if host.name == host_name:
                        summary = host.summary
                        stats = summary.quickStats
                        hardware = host.hardware
                        cpuUsage = stats.overallCpuUsage
                        memoryCapacityInMB = hardware.memorySize/MBFACTOR  #convert from bytes to MB
                        memoryUsage = stats.overallMemoryUsage
                        usedMemoryPercentage = (float(memoryUsage) / memoryCapacityInMB) * 100
                        totalCPU = summary.hardware.cpuMhz * hardware.cpuInfo.numCpuCores
                        usedCPUPercentage = (cpuUsage / totalCPU) * 100
                        
                        # total free space in all datastores
                        ds_freeSpace = 0

                        # total storage capacity of all datastores in the host
                        ds_capacity = 0

                        # Datastores - add all
                        for ds in host.datastore:
                            ds_capacity += ds.summary.capacity
                            ds_freeSpace += ds.summary.freeSpace
                        
                        
                        ds_freeSpacePercentage = (ds_freeSpace / ds_capacity) * 100
                        usedStoragePercentage = 100 - ds_freeSpacePercentage
                        
                        if summary.overallStatus != 'green':
                            print("Host:{} might have a problem. Status - {}".format(host_name, summary.overallStatus))
                            return
                        if usedCPUPercentage > max_percentage:
                            print("Host:{} CPU has been used more than {}%".format(host_name, max_percentage))
                        if usedMemoryPercentage > max_percentage:
                            print("Host:{} Memory has been used more than {}%".format(host_name, max_percentage))
                        if usedStoragePercentage > max_percentage:
                            print("Host:{} Storage has been used more than {}%".format(host_name, max_percentage))
                        if usedCPUPercentage < max_percentage and usedMemoryPercentage < max_percentage and usedStoragePercentage < max_percentage:
                            print(True)
                        return
                return
        print(False)
    except:
        raise SystemExit("Unable to retreive usage information for {}".format(host_name))

def get_unverified_session():
    """
    Get a requests session with cert verification disabled.
    Also disable the insecure warnings message.
    Note this is not recommended in production code.
    @return: a requests session with verification disabled.
    """
    session = requests.session()
    session.verify = False
    requests.packages.urllib3.disable_warnings()
    return session
    
def check_if_tag_exists(host_ip, vsphere_user, vsphere_password, tagname):
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
    session = get_unverified_session()
    client = create_vsphere_client(
            server=host_ip,
            username=vsphere_user,
            password=vsphere_password,
            session=session)
    tag_ids = client.tagging.Tag.list()
    for tag_id in tag_ids:
        tag_model = client.tagging.Tag.get(tag_id)
        if tag_model.name == tagname:
            print(True)
            return
    print(False)

