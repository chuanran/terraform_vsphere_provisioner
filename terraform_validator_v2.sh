#!/bin/bash

########################################################### {COPYRIGHT-TOP} ####
# Licensed Materials - Property of IBM
# CloudOE
#
# (C) Copyright IBM Corp. 2019
#
# US Government Users Restricted Rights - Use, duplication, or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
########################################################### {COPYRIGHT-END} ####

## This script is used to validate terraform.tfvars.json, files, environments, etc
cur_dir=$(cd $(dirname "$0") && pwd)
terraform="/usr/local/bin/terraform"
terraform_plugin_work_dir="${cur_dir}/plugin"
terraform_plugin_dir="${cur_dir}/plugin/.terraform"
tf_config_dir=${cur_dir}/config
tf_tfvars_json_file="${cur_dir}/config/terraform.tfvars.json"
vms_in_dc_file="${cur_dir}/vms_in_dc.json"
custom_properties_file="${cur_dir}/config/custom.properties"

## vm's Type array: i.e. km, kw, kwdd, nfs1, etc
declare -a vm_type_arr
vm_type_arr=(km kw kwdd db docreg mgmt nfs1 nfs2 nfs3 wexc wexfp wexm web hdpa hdpg hdpm hdps1 hdps2 hdpsec ms str zkp st landing bigdata worker api haproxy portworx)

## regex statement for product_initials, customer_env_name and env_type
product_initials_regex="dd|fcisi|cfm|ai|fcii|si|fci"
customer_env_name_regex="regions|mizuho|santander|zions|tryandbuy|devops|freedom|bnym|erie|demoa|demob|ers|barclaysbx|statefarm|jpmc|Complidata"
env_type_regex="test|poc|dev|preprod|prod|dr|pov|uat|devops"
default_ansible_hosts_github_url="https://github.ibm.com/api/v3/repos/fc-cloud-ops/dev-ops-tasks/contents/Ansible/ansible-hosts"

# check if ip address or url is pingable
function ping_address() {
	local address="$1"
	ping -n -w 1 -c 1 $address > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		echo "$address is not reachable. Exiting..."
		exit 3
	fi
}

#function for checking if the environment which runs terraform project is ok
function check_tf_env() {
	#check if terraform exists
	if [ ! -f $terraform ]; then
		echo "$terraform does NOT exist. Please install it first. Exiting..."
	    exit 1
    fi
    # check if plugin directory exists and plugin .terraform exist        
	if [ ! -d "$terraform_plugin_dir" ]; then
		mkdir -p $terraform_plugin_work_dir
		echo "terraform plugin $terraform_plugin_dir does not exist under $terraform_plugin_work_dir. Please try to run 'terraform init' (need internet access) to install it. Exiting..."
		exit 1
    fi
	#check if jq is existing in the vm running terraform
	which jq > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		echo "jq is missing on the vm running terraform. Exiting.."
		exit 1
	fi
	#check if python is existing in the vm running terraform
	which python > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		echo "python is missing on the vm running terraform. Exiting.."
		exit 1
	else
		#check if corresponding python modules exist
		python -c "import pyVmomi"
		if [ $? -ne 0 ]; then
			echo "pyVmomi module does not exist. Exiting.."
			exit 2
		fi
		python -c "import pyVim"
		if [ $? -ne 0 ]; then
			echo "pyVim module does not exist. Exiting.."
			exit 2
		fi
		python -c "import atexit"
		if [ $? -ne 0 ]; then
			echo "atexit module does not exist. Exiting.."
			exit 2
		fi
		python -c "import argparse"
		if [ $? -ne 0 ]; then
			echo "argparse module does not exist. Exiting.."
			exit 2
		fi
		python -c "import json"
		if [ $? -ne 0 ]; then
			echo "json module does not exist. Exiting.."
			exit 2
		fi
	fi
}

#function to validate the cpu/memory/storage of a host or cluster
function validate_host_cluster_capacity() {
	local vsphere_compute_cluster="$1"
	local vsphere_host="$2"
	local product_initials=$(jq -r ".product_initials" $tf_tfvars_json_file)
	local vsphere_vcenter=$(jq -r ".vsphere_vcenter" $tf_tfvars_json_file)
	local vsphere_user=$(jq -r ".vsphere_user" $tf_tfvars_json_file)
	local vsphere_password=$(jq -r ".vsphere_password" $tf_tfvars_json_file)
	local vsphere_target_datacenter=$(jq -r ".vsphere_target_datacenter" $tf_tfvars_json_file)
	#local vsphere_compute_cluster=$(jq -r ".vsphere_compute_cluster" $tf_tfvars_json_file)
	#local vsphere_host=$(jq -r ".vsphere_host" $tf_tfvars_json_file)

	# specify maximum capacity in percentage
	local max_percentage=80

	# check if vsphere_host is provided in the terraform.tfvars.json file
	if [ -z "${vsphere_host// }" ] || [ "$vsphere_host" == "null" ]; then
		# validate cluster capacity
		local result=`python -c "import terraform_validator; terraform_validator.validate_cluster_capacity(\"${vsphere_vcenter}\", \"${vsphere_user}\", \"${vsphere_password}\", \"${vsphere_compute_cluster}\", ${max_percentage})"`
		local entity_name=$vsphere_compute_cluster
	else
		# validate host capacity
		local result=`python -c "import terraform_validator; terraform_validator.validate_host_capacity(\"${vsphere_vcenter}\", \"${vsphere_user}\", \"${vsphere_password}\", \"${vsphere_compute_cluster}\", \"${vsphere_host}\", ${max_percentage})"`
		local entity_name=$vsphere_host
	fi

	if [ ! "$result" == "True" ]; then
		echo "$result"
		echo "${entity_name} does not satisfy the specified maximum capacity requirements. Exiting..."
		exit 3
	fi
}

# function to validate shared tfvars values
function validate_shared_tfvars() {
    local vcenter_host_ip=$(jq -r ".vsphere_vcenter" $tf_tfvars_json_file)
    if [ -z "${vcenter_host_ip// }" ] || [ "$vcenter_host_ip" == "null" ]; then
        echo "'vsphere_vcenter' definition in $tf_tfvars_json_file is empty or has no contents. Exiting..."
	    exit 1
    fi
    local vsphere_user=$(jq -r ".vsphere_user" $tf_tfvars_json_file)
    if [ -z "${vsphere_user// }" ] || [ "$vsphere_user" == "null" ]; then
        echo "'vsphere_user' definition in $tf_tfvars_json_file is empty or has no contents. Exiting..."
	    exit 1
    fi
    local vsphere_password=$(jq -r ".vsphere_password" $tf_tfvars_json_file)
    if [ -z "${vsphere_password// }" ] || [ "$vsphere_password" == "null" ]; then
        echo "'vsphere_password' definition in $tf_tfvars_json_file is empty or has no contents. Exiting..."
	    exit 1
    fi
    local source_datacenter_name=$(jq -r ".vsphere_source_datacenter" $tf_tfvars_json_file)
    if [ -z "${source_datacenter_name// }" ] || [ "$source_datacenter_name" == "null" ]; then
        echo "'vsphere_source_datacenter' definition in $tf_tfvars_json_file is empty or has no contents. Exiting..."
	    exit 1
    fi
    local target_datacenter_name=$(jq -r ".vsphere_target_datacenter" $tf_tfvars_json_file)
    if [ -z "${target_datacenter_name// }" ] || [ "$target_datacenter_name" == "null" ]; then
        echo "'vsphere_target_datacenter' definition in $tf_tfvars_json_file is empty or has no contents. Exiting..."
	    exit 1
    fi
	local vsphere_source_vm_folder=$(jq -r ".vsphere_source_vm_folder" $tf_tfvars_json_file)
    if [ -z "${vsphere_source_vm_folder// }" ] || [ "$vsphere_source_vm_folder" == "null" ]; then
        echo "'vsphere_source_vm_folder' definition in $tf_tfvars_json_file is empty or has no contents. Will need ensure the each specific role has vsphere_source_vm_folder definition"
	    #exit 1
    else
	    python -c "import terraform_validator; terraform_validator.check_inventory_path(\"${vcenter_host_ip}\", \"${vsphere_user}\", \"${vsphere_password}\", \"${source_datacenter_name}\", \"${vsphere_source_vm_folder}\")" |  grep -q "None"
        if [ $? -eq 0 ]; then
            echo "$vsphere_source_vm_folder defined in 'vsphere_source_vm_folder' in $tf_tfvars_json_file is wrong or cannot be retrieved from pyvmomi. Exiting..."
            exit 2
        fi
	fi
	local vsphere_target_vm_folder=$(jq -r ".vsphere_target_vm_folder" $tf_tfvars_json_file)
    if [ -z "${vsphere_target_vm_folder// }" ] || [ "$vsphere_target_vm_folder" == "null" ]; then
        echo "'vsphere_target_vm_folder' definition in $tf_tfvars_json_file is empty or has no contents. Will Need ensure the each specific role has vsphere_target_vm_folder definition"
    fi
	local vsphere_target_datastore=$(jq -r ".vsphere_target_datastore" $tf_tfvars_json_file)
    if [ -z "${vsphere_target_datastore// }" ] || [ "$vsphere_target_datastore" == "null" ]; then
        echo "'vsphere_target_datastore' definition in $tf_tfvars_json_file is empty or has no contents. Will need ensure the each specific role has vsphere_target_datastore definition"
	    #exit 1
    else
	    python -c "import terraform_validator; terraform_validator.get_datastores_by_dc(\"${vcenter_host_ip}\", \"${vsphere_user}\", \"${vsphere_password}\", \"${target_datacenter_name}\")" |  grep -Ewq "^${vsphere_target_datastore}$"
        if [ $? -ne 0 ]; then
            echo "$vsphere_target_datastore defined in 'vsphere_target_datastore' in $tf_tfvars_json_file is wrong or cannot be retrieved from pyvmomi. Exiting..."
            exit 2
        fi
	fi
	local vsphere_sl_private_network_name=$(jq -r ".vsphere_sl_private_network_name" $tf_tfvars_json_file)
    if [ -z "${vsphere_sl_private_network_name// }" ] || [ "$vsphere_sl_private_network_name" == "null" ]; then
        echo "'vsphere_sl_private_network_name' definition in $tf_tfvars_json_file is empty or has no contents. will need ensure each specific role has vsphere_sl_private_network_name definition"
	else
	    python -c "import terraform_validator; terraform_validator.get_network_adapters_by_dc(\"${vcenter_host_ip}\", \"${vsphere_user}\", \"${vsphere_password}\", \"${target_datacenter_name}\")" | grep -Ewq "^${vsphere_sl_private_network_name}$"
        if [ $? -ne 0 ]; then
            echo "$vsphere_sl_private_network_name defined in 'vsphere_sl_private_network_name' in $tf_tfvars_json_file is wrong or cannot be retrieved from pyvmomi. Exiting..."
            exit 2
        fi
	fi
    
	local vm_sl_private_netmask=$(jq -r ".vm_sl_private_netmask" $tf_tfvars_json_file)
    if [ -z "${vm_sl_private_netmask// }" ] || [ "$vm_sl_private_netmask" == "null" ]; then
        echo "'vm_sl_private_netmask' definition in $tf_tfvars_json_file is empty or has no contents. will need ensure each specific role has vm_sl_private_netmask definition"
    else
	    echo "$vm_sl_private_netmask" | grep -qwE "^[0-9]+$"
	    if [ $? -ne 0 ]; then
	        echo "$vm_sl_private_netmask defined in 'vm_sl_private_netmask' in  $tf_tfvars_json_file is wrong, and it must be an integer. Exiting..."
		    exit 3
	    fi
	fi
	local vm_network_gateway=$(jq -r ".vm_network_gateway" $tf_tfvars_json_file)
    if [ -z "${vm_network_gateway// }" ] || [ "$vm_network_gateway" == "null" ]; then
        echo "'vm_network_gateway' definition in $tf_tfvars_json_file is empty or has no contents. 	will need ensure each specific role has vm_network_gateway definition"
    else
	    echo "$vm_network_gateway" | grep -qwE '10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'
        if [ $? -ne 0 ]; then
    	    echo "$vm_network_gateway defined in 'vm_network_gateway' in $tf_tfvars_json_file must be a '10.*.*.*' ip address. Exiting..."
    	    exit 3
        else
	        #need to ensure network gateway is pingable from the client
	        ping -n -w 1 -c 1 $vm_network_gateway > /dev/null 2>&1
		    if [ $? -ne 0 ]; then
		        echo "$vm_network_gateway defined in 'vm_network_gateway' in $tf_tfvars_json_file is not reachable, please check the network connectivity of specific vlan/subnet"
		        exit 4
		    fi
	    fi
	fi

	#validation of "vm_kube_internal_ip",  "vm_kube_internal_netmask" and vsphere_kube_internal_network_name: they should appear together or disappear together
	local vm_kube_internal_ip=$(jq -r ".vm_kube_internal_ip" $tf_tfvars_json_file)
    local vsphere_kube_internal_network_name=$(jq -r ".vsphere_kube_internal_network_name" $tf_tfvars_json_file)
	local vm_kube_internal_netmask=$(jq -r ".vm_kube_internal_netmask" $tf_tfvars_json_file)
	if [ -z "${vm_kube_internal_ip// }" ] || [ "$vm_kube_internal_ip" == "null" ]; then
        echo "Attention: 'vm_kube_internal_ip' definition in $tf_tfvars_json_file is empty or has no contents. So no kube internal network attached to any vms"
		if [ ! -z "${vm_kube_internal_netmask// }" ] && [ "$vm_kube_internal_netmask" != "null" ]; then
            echo "'vm_kube_internal_netmask' definition in $tf_tfvars_json_file should not exist. Exiting..."
			exit 4
	    else
		    if [ ! -z "${vsphere_kube_internal_network_name// }" ] && [ "$vsphere_kube_internal_network_name" != "null" ]; then
			    echo "'vsphere_kube_internal_network_name' definition in $tf_tfvars_json_file should not exist. Exiting..."
			    exit 4
			fi
		fi
	else
	    echo "$vm_kube_internal_ip" | grep -qwE '192\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'
        if [ $? -ne 0 ]; then
    	    echo "$vm_kube_internal_ip defined in 'vm_kube_internal_ip' in $tf_tfvars_json_file must be a '192.*.*.*' ip address. Exiting..."
    	    exit 3
        fi
		if [ -z "${vm_kube_internal_netmask// }" ] || [ "$vm_kube_internal_netmask" == "null" ]; then
            echo "'vm_kube_internal_netmask' definition in $tf_tfvars_json_file does not exist or has no contents. Exiting..."
			exit 4
	    else
		    echo "$vm_kube_internal_netmask" | grep -qwE "^[0-9]+$"
	        if [ $? -ne 0 ]; then
	            echo "$vm_kube_internal_netmask defined in 'vm_kube_internal_netmask' in  $tf_tfvars_json_file is wrong, and it must be an integer. Exiting..."
		        exit 3
	        fi
			if [ -z "${vsphere_kube_internal_network_name// }" ] || [ "$vsphere_kube_internal_network_name" == "null" ]; then
                echo "'vsphere_kube_internal_network_name' definition in $tf_tfvars_json_file does not exist or has no contents. Exiting..."
			    exit 4
			else
			    python -c "import terraform_validator; terraform_validator.get_network_adapters_by_dc(\"${vcenter_host_ip}\", \"${vsphere_user}\", \"${vsphere_password}\", \"${target_datacenter_name}\")" | grep -Ewq "^${vsphere_kube_internal_network_name}$"
                if [ $? -ne 0 ]; then
                    echo "$vsphere_kube_internal_network_name defined in 'vsphere_kube_internal_network_name' in $tf_tfvars_json_file is wrong or cannot be retrieved from pyvmomi. Exiting..."
                    exit 2
                fi
			fi
		fi
	fi
	local vmuser=$(jq -r ".vmuser" $tf_tfvars_json_file)
    if [ -z "${vmuser// }" ] || [ "$vmuser" == "null" ] || [ "$vmuser" != "root" ]; then
        echo "'vmuser' definition in $tf_tfvars_json_file is empty or has no contents, or is NOT 'root'. Exiting..."
	    exit 1
    fi

    #validation of product_initials, product_version, customer_env_name, and env_type
	local product_initials=$(jq -r ".product_initials" $tf_tfvars_json_file)
    if [ -z "${product_initials// }" ] || [ "$product_initials" == "null" ]; then
        echo "'product_initials' definition in $tf_tfvars_json_file is empty or has no contents. Exiting..."
	    exit 1
    else
	    echo "$product_initials" | tr -d " \t\n\r" |  grep  -wqE "$product_initials_regex"
		if [ $? -ne 0 ]; then
		    echo "'product_initials' definition in $tf_tfvars_json_file must be one of \"$product_initials_regex\". Exiting..."
			exit 3
		fi
	fi
	local product_version=$(jq -r ".product_version" $tf_tfvars_json_file)
	local product_version_count="4"
    if [ -z "${product_version// }" ] || [ "$product_version" == "null" ]; then
        echo "'product_version' definition in $tf_tfvars_json_file is empty or has no contents. Exiting..."
	    exit 1
    else
	    echo "$product_version" | grep -qwE "^[0-9]+$"
		if [ $? -ne 0 ]; then
		    echo "'product_version' definition in $tf_tfvars_json_file must be an integer. Exiting..."
			exit 3
		fi
		if [ "${#product_version}" != "${product_version_count}" ]; then
			echo "'product_version' definition in $tf_tfvars_json_file must be 4 characters long (E.g, '1109'). Exiting..."
			exit 3
		fi
	fi

	local customer_env_name=$(jq -r ".customer_env_name" $tf_tfvars_json_file)
    if [ -z "${customer_env_name// }" ] || [ "$customer_env_name" == "null" ]; then
        echo "'customer_env_name' definition in $tf_tfvars_json_file is empty or has no contents. Exiting..."
	    exit 1
    else
	    echo "$customer_env_name" | tr -d " \t\n\r" |  grep  -wqE "$customer_env_name_regex"
		if [ $? -ne 0 ]; then
		    echo "'customer_env_name' definition in $tf_tfvars_json_file must be one of \"$customer_env_name_regex\". Exiting..."
			exit 3
		fi
	fi
	local env_type=$(jq -r ".env_type" $tf_tfvars_json_file)
	if [ -z "${env_type// }" ] || [ "$env_type" == "null" ]; then
        echo "'env_type' definition in $tf_tfvars_json_file is empty or has no contents. Exiting..."
	    exit 1
    else
	    echo "$env_type" | tr -d " \t\n\r" |  grep  -wqE "$env_type_regex"
		if [ $? -ne 0 ]; then
		    echo "'env_type' definition in $tf_tfvars_json_file must be one of \"$env_type_regex\". Exiting..."
			exit 3
		fi
	fi

	#step 1. check if source_datacenter_name and target_datacenter_name is valid or not
    python -c "import terraform_validator; terraform_validator.retrieve_dc_list(\"${vcenter_host_ip}\", \"${vsphere_user}\", \"${vsphere_password}\")" | grep -Ewq "^${source_datacenter_name}$"
    if [ $? -ne 0 ]; then
        echo "$source_datacenter_name defined in 'vsphere_source_datacenter' in $tf_tfvars_json_file is wrong or cannot be retrieved from pyvmomi. Exiting..."
        exit 2
    else
        #Get the metadata by leveraging pyvmomi, to get info like cpu, mem, disk_count, etc. The info will be put into file "vms_in_dc.json"
        python getvmsbydc.py -s "$vcenter_host_ip" -d "$source_datacenter_name" -u "$vsphere_user" -p "$vsphere_password" --json --silent
    fi
    python -c "import terraform_validator; terraform_validator.retrieve_dc_list(\"${vcenter_host_ip}\", \"${vsphere_user}\", \"${vsphere_password}\")" | grep -Ewq "^${target_datacenter_name}$"
    if [ $? -ne 0 ]; then
        echo "$target_datacenter_name defined in 'target_datacenter_name' in $tf_tfvars_json_file is wrong or cannot be retrieved from pyvmomi. Exiting..."
        exit 2
    fi

	#step 2. check if vsphere_compute_cluster, vsphere_host and vsphere_host_folder and  There are 3 scenarios: 
	# (1) clone a vm to a specific host in a compute cluster: "vsphere_compute_cluster" and "vsphere_host" defined in terraform.tfvars
	# (2) clone a vm to any host in a compute cluster: only "vsphere_compute_cluster" defined in terraform.tfvars
	# (3) clone a vm to a single host: 'vsphere_host' and 'vsphere_host_folder' defined in terraform.tfvars
    local target_vsphere_compute_cluster=$(jq -r ".vsphere_compute_cluster" $tf_tfvars_json_file)
    local target_vsphere_host=$(jq -r ".vsphere_host" $tf_tfvars_json_file)
    local vsphere_host_folder=$(jq -r ".vsphere_host_folder" $tf_tfvars_json_file)
	#validate vsphere_compute_cluster, vsphere_host and vsphere_host_folder
    if [ -z "${target_vsphere_compute_cluster// }" ] || [ "$target_vsphere_compute_cluster" == "null" ]; then
	    echo "There is no valid 'vsphere_compute_cluster' defined in $tf_tfvars_json_file"
		if [ -z "${target_vsphere_host// }" ] || [ "$target_vsphere_host" == "null" ]; then
		    echo "There is neither valid 'vsphere_compute_cluster' nor valid 'vsphere_host' defined in $tf_tfvars_json_file. will need ensure each specific role has vsphere_compute_cluster or  vsphere_host definition "
			#exit 3
		else
			# ping target_vsphere_host address
			ping_address "${target_vsphere_host}"

		    if [ -z "${vsphere_host_folder// }" ] || [ "$vsphere_host_folder" == "null" ]; then
			    echo "There is no 'vsphere_host_folder' defined in shared section of $tf_tfvars_json_file. Exiting..."
				exit 3
			fi
		fi
    else           
	    # get the computer clusters
        python -c "import terraform_validator; terraform_validator.get_clusters(\"${vcenter_host_ip}\", \"${vsphere_user}\", \"${vsphere_password}\")" |  grep -wq "^${target_vsphere_compute_cluster}$"
        if [ $? -ne 0 ]; then
            echo "$target_vsphere_compute_cluster defined in 'vsphere_compute_cluster' in $tf_tfvars_json_file is wrong or cannot be retrieved from pyvmomi. Exiting..."
            exit 2
        fi

		if [ ! -z "${vsphere_host_folder// }" ] && [ "$vsphere_host_folder" != "null" ]; then
		    echo "'vsphere_host_folder' cannot coexist with 'vsphere_compute_cluster' in shared section of $tf_tfvars_json_file"
		    exit 3
		fi

		# get the hosts by cluster name
		if [ ! -z "${target_vsphere_host// }" ] && [ "$target_vsphere_host" != "null" ]; then
            python -c "import terraform_validator; terraform_validator.get_hosts_by_cluster(\"${vcenter_host_ip}\", \"${vsphere_user}\", \"${vsphere_password}\", \"${target_vsphere_compute_cluster}\")" |  grep -Ewq "^${target_vsphere_host}$"
            if [ $? -ne 0 ]; then
                echo "$target_vsphere_host defined in 'vsphere_host' in $tf_tfvars_json_file is wrong or cannot be retrieved from pyvmomi. Exiting..."
                exit 2
		    fi
			# ping target_vsphere_host address
			ping_address "${target_vsphere_host}"
			validate_host_cluster_capacity "$target_vsphere_compute_cluster" "$target_vsphere_host"
		else
		    validate_host_cluster_capacity "$target_vsphere_compute_cluster"
        fi
    fi

	#step 3. check if target folder exist or not
    python -c "import terraform_validator; terraform_validator.check_inventory_path(\"${vcenter_host_ip}\", \"${vsphere_user}\", \"${vsphere_password}\", \"${target_datacenter_name}\", \"${vsphere_target_vm_folder}\")" |  grep -q "None"
    if [ $? -eq 0 ]; then
        echo "$vsphere_target_vm_folder defined in 'vsphere_target_vm_folder' in $tf_tfvars_json_file is wrong or cannot be retrieved from pyvmomi. Exiting..."
        exit 2
    fi	

	#step 4. check validity of vsphere_dns_servers, virtual_machine_search_domain, vsphere_dns_domain
	#step 4.1 handling "vsphere_dns_servers": if vsphere_dns_servers is defined in terraform json file, will use it; otherwise will use mgmt's ip as the dns server
	local vsphere_dns_servers=$(jq -r ".vsphere_dns_servers" $tf_tfvars_json_file)
    if [ -z "${vsphere_dns_servers// }" ] || [ "$vsphere_dns_servers" == "null" ]; then
        echo "'vsphere_dns_servers' definition in $tf_tfvars_json_file is empty or has no contents. Will try to use mgmt vm's ip as dns server"
		grep -q "\"vm_type\": \"mgmt\"" $tf_tfvars_json_file
		if [ $? -ne 0 ]; then
		    echo "No mgmt definition in $tf_tfvars_json_file. So No dns servers can be found. Exiting..."
			exit 3
		else
		    local vm_it=0
		    for  vm_it in $(jq '.vms_meta | keys | .[]' $tf_tfvars_json_file); do
                local vm_type=$(jq -r ".vms_meta[$vm_it].vm_type" $tf_tfvars_json_file)
                if [ "$vm_type" == "mgmt" ]; then
                    local mgmt_sl_private_ip=$(jq -r ".vms_meta[$vm_it].vm_sl_private_ip" $tf_tfvars_json_file)
					echo $mgmt_sl_private_ip | grep -qwE '10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'
					if [ $? -ne 0 ]; then
					    echo "No valid value for 'vm_sl_private_ip' defined in mgmt part in $tf_tfvars_json_file. Exiting..."
						exit 3
					fi
                    break
                fi
            done
		fi
    else
	    #vsphere_dns_servers must be separated by comma if there are multiple values, and each value must be a valid "10.*.*.*" ip address
	    local orig_ifs="$IFS"
	    echo  "$vsphere_dns_servers" | awk -F ","  '{for (i = 0; ++i <= NF;) print $i}' | while IFS="\n" read -r dns_server;
		do
		    local dns_servers_num=`echo "$dns_server" |  grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' |  wc -l`
			if [ $dns_servers_num -ne 1 ]; then
			    echo "$dns_server defined in 'vsphere_dns_servers' in $tf_tfvars_json_file is invalid, it must have valid ip addresses, and must be split with ',' if there are more than 1 ip address. Exiting..."
				IFS="$orig_ifs"
				exit 3
			else
			    local dns_servers_real_num=`echo "$dns_server" | awk '{print $1}' | grep -Eo '^10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$' |  wc -l`
				if [ $dns_servers_real_num -ne 1 ]; then
				    echo "$dns_server defined in 'vsphere_dns_servers' in $tf_tfvars_json_file is invalid, it must have valid ip addresses, and must be split with ',' if there are more than 1 ip address. Exiting..."
				    IFS="$orig_ifs"
					exit 3
				fi
			fi
		done
        [[ $? != 0 ]] && exit $?
        IFS="$orig_ifs"
	fi
	#step 4.2 handling virtual_machine_search_domain list
    local virtual_machine_search_domain=$(jq -r ".virtual_machine_search_domain" $tf_tfvars_json_file)
	if [ -z "${virtual_machine_search_domain// }" ] || [ "$virtual_machine_search_domain" == "null" ]; then
        echo "'virtual_machine_search_domain' definition in $tf_tfvars_json_file is empty or has no contents. Exiting..."
	    exit 1
    else
	    local orig_ifs="$IFS"
	    echo  "$virtual_machine_search_domain" | awk -F ","  '{for (i = 0; ++i <= NF;) print $i}' | while IFS="\n" read -r search_domain;
		do
		    local search_domain_num=`echo "$search_domain" |  grep -E  '^wfss.ibm.com$' |  wc -l`
			if [ $search_domain_num -ne 1 ]; then
			    echo "$search_domain defined in 'virtual_machine_search_domain' in $tf_tfvars_json_file is invalid, it must be 'wfss.ibm.com', and must be split with ',' if there are more than 1 search domain. Exiting..."
				IFS="$orig_ifs"
				exit 3
			else
			    local real_search_domain_num=`echo "$search_domain" |  grep -E '^wfss.ibm.com$' |  wc -l`
				if [ $real_search_domain_num -ne 1 ]; then
			        echo "$search_domain defined in 'virtual_machine_search_domain' in $tf_tfvars_json_file is invalid, it must be 'wfss.ibm.com', and must be split with ',' if there are more than 1 search domain. Exiting..."
				    IFS="$orig_ifs"
					exit 3
				fi
			fi
		done
		[[ $? != 0 ]] && exit $?
        IFS="$orig_ifs"
	fi
	#step 4.3 handling vsphere_dns_domain
	local vsphere_dns_domain=$(jq -r ".vsphere_dns_domain" $tf_tfvars_json_file)
	if [ -z "${vsphere_dns_domain// }" ] || [ "$vsphere_dns_domain" == "null" ]; then
        echo "'vsphere_dns_domain' definition in $tf_tfvars_json_file is empty or has no contents. Exiting..."
	    exit 1
	else
	    local dns_domain_num=`echo "$vsphere_dns_domain" |  grep -E '^wfss.ibm.com$' |  wc -l`
		if [ $dns_domain_num -ne 1 ]; then
			    echo "$vsphere_dns_domain defined in 'vsphere_dns_domain' in $tf_tfvars_json_file is invalid, it must be 'wfss.ibm.com'. Exiting..."
				exit 3
		else
			local real_dns_domain_num=`echo "$vsphere_dns_domain" |  grep -E '^wfss.ibm.com$' |  wc -l`
			if [ $real_dns_domain_num -ne 1 ]; then
			    echo "$vsphere_dns_domain defined in 'vsphere_dns_domain' in $tf_tfvars_json_file is invalid, it must be 'wfss.ibm.com'. Exiting..."
				exit 3
			fi
		fi
	fi
}
# function to check if an element exists in a bash array
function array_contains() { 
    local array="$1[@]"
    local target_elem=$2
    local exists_flag=1
    for element in "${!array}"; do
        if [[ $element == $target_elem ]]; then
            exists_flag=0
            break
        fi
    done
    echo $exists_flag
}

# function to generate vms_in_dc.json
function generate_vms_in_dc_json() {
	local vcenter_host_ip=$(jq -r ".vsphere_vcenter" $tf_tfvars_json_file)
    local source_datacenter_name=$(jq -r ".vsphere_source_datacenter" $tf_tfvars_json_file)
    local vsphere_user=$(jq -r ".vsphere_user" $tf_tfvars_json_file)
    local vsphere_password=$(jq -r ".vsphere_password" $tf_tfvars_json_file)
    #Get the metadata by leveraging pyvmomi, to get info like cpu, mem, disk_count, etc. The info will be put into file "vms_in_dc.json"
    python getvmsbydc.py -s "$vcenter_host_ip" -d "$source_datacenter_name" -u "$vsphere_user" -p "$vsphere_password" --json --silent
}

#function to check if vsphere_vm_template and vsphere_vm_hostname exists in vms_in_dc.json
function vm_config_exists() {
	local seeking_value="$1"
	local existing_flag=1
	if [ ! -s "$vms_in_dc_file" ] || [ `jq '.|length' "$vms_in_dc_file"` -eq 0 ]; then
	    generate_vms_in_dc_json
	fi
	grep -wq "$seeking_value" $vms_in_dc_file
	if [ $? -eq 0 ]; then
	    existing_flag=0
	else
	    generate_vms_in_dc_json
		grep -wq "$seeking_value" $vms_in_dc_file
		if [ $? -eq 0 ]; then
		    existing_flag=0
		fi
	fi
	echo "$existing_flag"
}

#function to check if the vm's hostname/template name/target vm name has the keywords related to vm's type. 
#For kw and kwdd, vm names must contain {i}; for km, kw and kwdd, the hostname must contains "ikm" (for km), "ikw"(for kw), and "ikwdd" (for kwdd) 
function validate_vm_name_convention() {
	local vm_type="$1"
	local vm_name="$2"
	echo "$vm_name" | grep -q "${vm_type}"
	if [ $? -ne 0 ]; then
		echo "Warning: For $vm_type, \"$vm_name\" does NOT contain keywords \"${vm_type}\"."
	fi
}

#function to get property value in vms_in_dc.json
function get_value_in_vms_json() {
	local vm_name="$1"
	local key_name="$2"
	if [ ! -s "$vms_in_dc_file" ] || [ `jq '.|length' "$vms_in_dc_file"` -eq 0 ]; then
	    generate_vms_in_dc_json
	fi
	local value=`jq -r ".\"${vm_name}\".\"${key_name}\"" "$vms_in_dc_file"`
	if [ "$value" != "null" ]; then
	    echo "$value"
	else
	    echo "property ${key_name} of $vm_name cannot be found in $vms_in_dc_file. Exiting..."
		exit 1
	fi
}

# function to validate distinct tfvars values
function validate_distinct_tfvars() {
	local vm_it=0
	local counter_tfvars_validation=0
	local counter_sl_ip_addr=0
	local counter_hostname_validation=0
	local sl_ip_addr=""
	declare -a sl_ip_addr_arr
	sl_ip_addr_arr=()
    
	#get some shared vsphere config for later validation
	local vcenter_host_ip=$(jq -r ".vsphere_vcenter" $tf_tfvars_json_file)
	local vsphere_user=$(jq -r ".vsphere_user" $tf_tfvars_json_file)
    local vsphere_password=$(jq -r ".vsphere_password" $tf_tfvars_json_file)
    local source_datacenter_name=$(jq -r ".vsphere_source_datacenter" $tf_tfvars_json_file)
	local target_datacenter_name=$(jq -r ".vsphere_target_datacenter" $tf_tfvars_json_file)
	local product_initials=$(jq -r ".product_initials" $tf_tfvars_json_file)
	local product_version=$(jq -r ".product_version" $tf_tfvars_json_file)
	local customer_env_name=$(jq -r ".customer_env_name" $tf_tfvars_json_file)
    local env_type=$(jq -r ".env_type" $tf_tfvars_json_file)
    
	#step 1. validate if vms_meta exists and have arrays number for than 1
	local vms_meta_num=$(jq '.vms_meta | length' $tf_tfvars_json_file)
	if [ $vms_meta_num -eq 0 ]; then
	    echo "Json Array 'vms_meta' does NOT exists. Exiting..."
		exit 1
	fi
	for  vm_it in $(jq '.vms_meta | keys | .[]' $tf_tfvars_json_file); do
	    #step 2.vm_type: must be one of the defined array: vm_type_arr
	    local vm_type=$(jq -r ".vms_meta[$vm_it].vm_type" $tf_tfvars_json_file)
		if [ -z "${vm_type// }" ] || [ "$vm_type" == "null" ]; then
            echo "'vm_type' definition in 'vms_meta' array in $tf_tfvars_json_file is empty or has no contents. Exiting..."
	        exit 1
		else
		    local vm_type_exists=$(array_contains vm_type_arr "$vm_type")
			if [ $vm_type_exists -ne 0 ]; then
			    echo "'vm_type' $vm_type is NOT valid in $tf_tfvars_json_file. 'vm_type' must be one of \"${vm_type_arr[@]}\""
				exit 1
			fi
		fi

		#step 3. vsphere_vm_count: for kw and kwdd, we must have vsphere_vm_count definition; for other types of vms, vsphere_vm_count it's not needed. vsphere_vm_count must be an integer
        local vm_count=$(jq -r ".vms_meta[$vm_it].vsphere_vm_count" $tf_tfvars_json_file)
	    if [ "$vm_count" == "null" ]; then
		    if [ "$vm_type" == "kw" ] || [ "$vm_type" == "kwdd" ]; then
                echo "'vsphere_vm_count' definition for $vm_type in $tf_tfvars_json_file is empty or has no contents. Exiting..."
	            exit 1
			else
			    vm_count=1
			fi
		else
		    echo "$vm_count" | grep -qwE "^[0-9]+$"
			if [ $? -ne 0 ]; then
				echo "'vsphere_vm_count' definition for $vm_type in $tf_tfvars_json_file is invalid. It must be an integer. Exiting..."
	            exit 3
			fi
		fi

		#step 4. vsphere_vm_template: must be in vms_in_dc.json output. there are 2 situations:
		# vsphere_vm_template contains {i}; 
		# vsphere_vm_template does NOT contain {i}
		local vsphere_vm_template=$(jq -r ".vms_meta[$vm_it].vsphere_vm_template" $tf_tfvars_json_file)
		if [ -z "${vsphere_vm_template// }" ] || [ "$vsphere_vm_template" == "null" ]; then
            echo "'vsphere_vm_template' definition for $vm_type in $tf_tfvars_json_file is empty or has no contents. Exiting..."
	        exit 1
		else
		    validate_vm_name_convention "$vm_type" "$vsphere_vm_template"
		    echo "$vsphere_vm_template" | grep -q "{i}"
			if [ $? -eq 0 ]; then
			    for (( counter_tfvars_validation=1; counter_tfvars_validation<=$vm_count; counter_tfvars_validation++ ))
				do
					local real_vm_template_name=`echo "$vsphere_vm_template" | sed "s/{i}/$counter_tfvars_validation/g"`
					local vm_template_exist=$(vm_config_exists "$real_vm_template_name")
					if [ $vm_template_exist -ne 0 ]; then
						echo "vm template $real_vm_template_name for $vm_type does NOT exist. Exiting..."
						exit 3
					fi
				done
			else
			    local vm_template_exist=$(vm_config_exists "$vsphere_vm_template")
				if [ $vm_template_exist -ne 0 ]; then
					echo "vm template $vsphere_vm_template for $vm_type does NOT exist. Exiting..."
					exit 3
				fi
			fi
		fi

		#step 5. validate vmpassword
		local vmpassword=$(jq -r ".vms_meta[$vm_it].vmpassword" $tf_tfvars_json_file)
		if [ -z "${vmpassword// }" ] || [ "$vmpassword" == "null" ]; then
		    echo "For $vm_type vm, since hostname contains '.', 'vmpassword' has to been provided in $tf_tfvars_json_file. Exiting..."
			exit 1
		fi

		#step 6. vm_sl_private_ip: must be a solid ip starting with "10.", and should be no conflicts especially since kw and kwdd could use several ips
		#also check if the ip is used by other vm(s) to avoid duplicate IPs
		local vm_sl_private_ip=$(jq -r ".vms_meta[$vm_it].vm_sl_private_ip" $tf_tfvars_json_file)
		local vm_sl_private_ip_start_number=`echo ${vm_sl_private_ip} | awk -F "." '{print $4}'`
		local vm_inventory_name="${product_initials}-${product_version}-${customer_env_name}-${env_type}-${vm_type}"
		
		if [ -z "${vm_sl_private_ip// }" ] || [ "$vm_sl_private_ip" == "null" ]; then
            echo "'vm_sl_private_ip' definition for $vm_type in $tf_tfvars_json_file is empty or has no contents. Exiting..."
	        exit 1
		else
		    echo "$vm_sl_private_ip" | grep -qwE '10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'
			if [ $? -ne 0 ]; then
			    echo "'vm_sl_private_ip' definition for $vm_type in $tf_tfvars_json_file is NOT Valid. It must be a 10.*.*.* IP Address. Exiting..."
	            exit 1
			else
			    if [ ! -s "$vms_in_dc_file" ] || [ `jq '.|length' "$vms_in_dc_file"` -eq 0 ]; then
	                generate_vms_in_dc_json
	            fi
				if [ $vm_count -eq 1 ]; then
					#if the ip exists but there's no inventory name, that means the ip has been used by the other vm
					grep -wq "$vm_sl_private_ip" $vms_in_dc_file
					if [ $? -eq 0 ]; then
					    grep -wq "$vm_inventory_name" $vms_in_dc_file
						if [ $? -ne 0 ]; then
						    echo "for $vm_inventory_name, there is duplicate IP $vm_sl_private_ip. Please double check and use a new IP if needed"
							exit 1
						fi
					fi
				    sl_ip_addr_arr=("${sl_ip_addr_arr[@]}" "$vm_sl_private_ip")
				else
				    if [ $vm_count -gt 1 ]; then
				        for (( counter_sl_ip_addr=1; counter_sl_ip_addr<=$vm_count; counter_sl_ip_addr++ ))
                        do
				            local vm_sl_private_ip_prefix="`echo ${vm_sl_private_ip} | awk -F "." '{print $1}'`.`echo ${vm_sl_private_ip} | awk -F "." '{print $2}'`.`echo ${vm_sl_private_ip} | awk -F "." '{print $3}'`."
                            local vm_sl_private_ip_postfix=""
                            ((vm_sl_private_ip_postfix=vm_sl_private_ip_start_number+counter_sl_ip_addr-1))
							vm_sl_private_ip=${vm_sl_private_ip_prefix}${vm_sl_private_ip_postfix}
							vm_inventory_name="${product_initials}-${product_version}-${customer_env_name}-${env_type}-${vm_type}${counter_sl_ip_addr}"
							#if the ip exists but there's no inventory name, that means the ip has been used by the other vm
							grep -wq "$vm_sl_private_ip" $vms_in_dc_file
					        if [ $? -eq 0 ]; then
					            grep -wq "$vm_inventory_name" $vms_in_dc_file
						        if [ $? -ne 0 ]; then
						            echo "for $vm_inventory_name, there is duplicate IP $vm_sl_private_ip. Please double check and use a new IP if needed"
							        exit 1
						        fi
					        fi
                            sl_ip_addr_arr=("${sl_ip_addr_arr[@]}" "${vm_sl_private_ip_prefix}${vm_sl_private_ip_postfix}")
					    done
					fi
				fi
			fi
		fi

		#step 7. validate "vsphere_source_vm_folder" and "vsphere_target_vm_folder" in distinct role area:  here we only need to make sure either shared section or distinct vm role's section contains 'vsphere_source_vm_folder' or 'vsphere_target_vm_folder', and the vm folder exists there
	    # terraform can validate if the vm exists or not in the folder, so TFD validator does not need to consider it
	    local vsphere_source_vm_folder=$(jq -r ".vms_meta[$vm_it].vsphere_source_vm_folder" $tf_tfvars_json_file)
	    if [ -z "${vsphere_source_vm_folder// }" ] || [ "$vsphere_source_vm_folder" == "null" ]; then
	        local vsphere_source_vm_folder_shared=$(jq -r ".vsphere_source_vm_folder" $tf_tfvars_json_file)
            if [ -z "${vsphere_source_vm_folder_shared// }" ] || [ "$vsphere_source_vm_folder_shared" == "null" ]; then
                echo "There are no 'vsphere_source_vm_folder' definition in $tf_tfvars_json_file for $vm_type. 'vsphere_source_vm_folder' definition must either exist in shared section or in $vm_type section of $tf_tfvars_json_file"
	            exit 3
		    fi
	    else
	        python -c "import terraform_validator; terraform_validator.check_inventory_path(\"${vcenter_host_ip}\", \"${vsphere_user}\", \"${vsphere_password}\", \"${source_datacenter_name}\", \"${vsphere_source_vm_folder}\")" |  grep -q "None"
            if [ $? -eq 0 ]; then
                echo "$vsphere_source_vm_folder defined in 'vsphere_source_vm_folder' in $tf_tfvars_json_file for $vm_type is wrong or cannot be retrieved from pyvmomi. Exiting..."
                exit 2
            fi
	    fi

		local vsphere_target_vm_folder=$(jq -r ".vms_meta[$vm_it].vsphere_target_vm_folder" $tf_tfvars_json_file)
	    if [ -z "${vsphere_target_vm_folder// }" ] || [ "$vsphere_target_vm_folder" == "null" ]; then
	        local vsphere_target_vm_folder_shared=$(jq -r ".vsphere_target_vm_folder" $tf_tfvars_json_file)
            if [ -z "${vsphere_target_vm_folder_shared// }" ] || [ "$vsphere_target_vm_folder_shared" == "null" ]; then
                echo "There are no 'vsphere_target_vm_folder' definition in $tf_tfvars_json_file for $vm_type. 'vsphere_target_vm_folder' definition must either exist in shared section or in $vm_type section of $tf_tfvars_json_file"
	            exit 3
		    fi
	    else
	        python -c "import terraform_validator; terraform_validator.check_inventory_path(\"${vcenter_host_ip}\", \"${vsphere_user}\", \"${vsphere_password}\", \"${target_datacenter_name}\", \"${vsphere_target_vm_folder}\")" |  grep -q "None"
            if [ $? -eq 0 ]; then
                echo "$vsphere_target_vm_folder defined in 'vsphere_target_vm_folder' in $tf_tfvars_json_file for $vm_type is wrong or cannot be retrieved from pyvmomi. Exiting..."
                exit 2
            fi
	    fi

		#step 8. validate "vsphere_target_datastore" in distinct role area:  here we only need to make sure either shared section or distinct vm role's section contains 'vsphere_target_datastore', and the target datastore exists there
	    local vsphere_target_datastore=$(jq -r ".vms_meta[$vm_it].vsphere_target_datastore" $tf_tfvars_json_file)
	    if [ -z "${vsphere_target_datastore// }" ] || [ "$vsphere_target_datastore" == "null" ]; then
	        local vsphere_target_datastore_shared=$(jq -r ".vsphere_target_datastore" $tf_tfvars_json_file)
            if [ -z "${vsphere_target_datastore_shared// }" ] || [ "$vsphere_target_datastore_shared" == "null" ]; then
                echo "There are no 'vsphere_target_datastore' definition in $tf_tfvars_json_file for $vm_type. 'vsphere_target_datastore' definition must either exist in shared section or in $vm_type section of $tf_tfvars_json_file"
	            exit 3
		    fi
	    else
	        python -c "import terraform_validator; terraform_validator.get_datastores_by_dc(\"${vcenter_host_ip}\", \"${vsphere_user}\", \"${vsphere_password}\", \"${target_datacenter_name}\")" |  grep -wq "$vsphere_target_datastore"
            if [ $? -ne 0 ]; then
                echo "$vsphere_target_datastore defined in 'vsphere_target_datastore' in $tf_tfvars_json_file for $vm_type is wrong or cannot be retrieved from pyvmomi. Exiting..."
                exit 2
            fi
	    fi

		#step 9. validate "vsphere_sl_private_network_name" in distinct role area:  here we only need to make sure either shared section or distinct vm role's section contains 'vsphere_sl_private_network_name', and the vsphere_sl_private_network_name exists there
	    local vsphere_sl_private_network_name=$(jq -r ".vms_meta[$vm_it].vsphere_sl_private_network_name" $tf_tfvars_json_file)
	    if [ -z "${vsphere_sl_private_network_name// }" ] || [ "$vsphere_sl_private_network_name" == "null" ]; then
	        local vsphere_sl_private_network_name_shared=$(jq -r ".vsphere_sl_private_network_name" $tf_tfvars_json_file)
            if [ -z "${vsphere_sl_private_network_name_shared// }" ] || [ "$vsphere_sl_private_network_name_shared" == "null" ]; then
                echo "There are no 'vsphere_sl_private_network_name' definition in $tf_tfvars_json_file for $vm_type. 'vsphere_sl_private_network_name_shared' definition must either exist in shared section or in $vm_type section of $tf_tfvars_json_file"
	            exit 3
		    fi
	    else
	        python -c "import terraform_validator; terraform_validator.get_network_adapters_by_dc(\"${vcenter_host_ip}\", \"${vsphere_user}\", \"${vsphere_password}\", \"${target_datacenter_name}\")" | grep -wq "$vsphere_sl_private_network_name"
            if [ $? -ne 0 ]; then
                echo "$vsphere_sl_private_network_name defined in 'vsphere_sl_private_network_name' in $tf_tfvars_json_file for $vm_type is wrong or cannot be retrieved from pyvmomi. Exiting..."
                exit 2
            fi
	    fi

        #step 10. validate "vm_sl_private_netmask" in distinct role area:  here we only need to make sure either shared section or distinct vm role's section contains 'vm_sl_private_netmask'
		local vm_sl_private_netmask=$(jq -r ".vms_meta[$vm_it].vm_sl_private_netmask" $tf_tfvars_json_file)
        if [ -z "${vm_sl_private_netmask// }" ] || [ "$vm_sl_private_netmask" == "null" ]; then
            local vm_sl_private_netmask_shared=$(jq -r ".vm_sl_private_netmask" $tf_tfvars_json_file)
            if [ -z "${vm_sl_private_netmask_shared// }" ] || [ "$vm_sl_private_netmask_shared" == "null" ]; then
                echo "There are no 'vm_sl_private_netmask' definition in $tf_tfvars_json_file for $vm_type. 'vm_sl_private_netmask' definition must either exist in shared section or in $vm_type section of $tf_tfvars_json_file"
	            exit 3
		    fi
        else
	        echo "$vm_sl_private_netmask" | grep -qwE "^[0-9]+$"
	        if [ $? -ne 0 ]; then
	            echo "$vm_sl_private_netmask defined in 'vm_sl_private_netmask' in  $tf_tfvars_json_file for $vm_type is wrong, and it must be an integer. Exiting..."
		        exit 3
	        fi
	    fi

		#step 11. validate "vm_network_gateway" in distinct role area:  here we only need to make sure either shared section or distinct vm role's section contains 'vm_network_gateway'
		local vm_network_gateway=$(jq -r ".vms_meta[$vm_it].vm_network_gateway" $tf_tfvars_json_file)
        if [ -z "${vm_network_gateway// }" ] || [ "$vm_network_gateway" == "null" ]; then
            local vm_network_gateway_shared=$(jq -r ".vm_network_gateway" $tf_tfvars_json_file)
            if [ -z "${vm_network_gateway_shared// }" ] || [ "$vm_network_gateway_shared" == "null" ]; then
                echo "There are no 'vm_network_gateway' definition in $tf_tfvars_json_file for $vm_type. 'vm_network_gateway' definition must either exist in shared section or in $vm_type section of $tf_tfvars_json_file"
	            exit 3
		    fi
        else
	        echo "$vm_network_gateway" | grep -qwE '10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'
            if [ $? -ne 0 ]; then
    	        echo "$vm_network_gateway defined in 'vm_network_gateway' in $tf_tfvars_json_file for $vm_type must be a '10.*.*.*' ip address. Exiting..."
    	        exit 3
            else
	            #need to ensure network gateway is pingable from the client
	            ping -n -w 1 -c 1 $vm_network_gateway > /dev/null 2>&1
		        if [ $? -ne 0 ]; then
		            echo "$vm_network_gateway defined in 'vm_network_gateway' in $tf_tfvars_json_file for $vm_type is not reachable, please check the network connectivity of specific vlan/subnet"
		            exit 4
		        fi
	        fi
	    fi

		#step 12. validate "vsphere_compute_cluster", "vsphere_host" and "vsphere_host_folder"
		local vsphere_compute_cluster=$(jq -r ".vms_meta[$vm_it].vsphere_compute_cluster" $tf_tfvars_json_file)
		local vsphere_host=$(jq -r ".vms_meta[$vm_it].vsphere_host" $tf_tfvars_json_file)
		local vsphere_host_folder=$(jq -r ".vms_meta[$vm_it].vsphere_host_folder" $tf_tfvars_json_file)
		local shared_vsphere_compute_cluster=$(jq -r ".vsphere_compute_cluster" $tf_tfvars_json_file)
        local shared_vsphere_host=$(jq -r ".vsphere_host" $tf_tfvars_json_file)

		if [ -z "${vsphere_compute_cluster// }" ] || [ "$vsphere_compute_cluster" == "null" ]; then
		    if [ ! -z "${vsphere_host// }" ] && [ "$vsphere_host" != "null" ]; then
			    if [ -z "${shared_vsphere_compute_cluster// }" ] || [ "$shared_vsphere_compute_cluster" == "null" ]; then
				    if [ -z "${vsphere_host_folder// }" ] || [ "$vsphere_host_folder" == "null" ]; then
					    echo "'vsphere_host_folder' does not exist in distinct section of $tf_tfvars_json_file for $vm_type. Exiting..."
						exit 3
					fi
				else
				    #check if the host under the specific cluster exist or not
				    if [ -z "${vsphere_host_folder// }" ] || [ "$vsphere_host_folder" == "null" ]; then
				        python -c "import terraform_validator; terraform_validator.get_hosts_by_cluster(\"${vcenter_host_ip}\", \"${vsphere_user}\", \"${vsphere_password}\", \"${shared_vsphere_compute_cluster}\")" |  grep -wq "$vsphere_host"
                        if [ $? -ne 0 ]; then
                            echo "$vsphere_host defined in 'vsphere_host' in distinct section of $tf_tfvars_json_file for $vm_type is wrong or cannot be retrieved from pyvmomi. Exiting..."
                            exit 2
						fi
						#check the capacity of the host
						validate_host_cluster_capacity "$shared_vsphere_compute_cluster" "$vsphere_host"
					fi
				fi
			else
			    if [ ! -z "${vsphere_host_folder// }" ] && [ "$vsphere_host_folder" != "null" ]; then
				    if [ ! -z "${shared_vsphere_compute_cluster// }" ] && [ "$shared_vsphere_compute_cluster" != "null" ]; then
					    echo "$shared_vsphere_compute_cluster defined in shared section of $tf_tfvars_json_file cannot exist there. Exiting..."
						exit 3
					else
					    if [ -z "${shared_vsphere_host// }" ] || [ "$shared_vsphere_host" == "null" ]; then
						    echo "There is no 'vsphere_host' set in shared section of $tf_tfvars_json_file. Exiting..."
							exit 3
						fi
					fi
				fi
			fi
		else
		    if [ ! -z "${vsphere_host_folder// }" ] && [ "$vsphere_host_folder" != "null" ]; then
		        echo "'vsphere_host_folder' cannot coexist with 'vsphere_compute_cluster' in distinct section of $tf_tfvars_json_file for $vm_type. Exiting..."
		        exit 3
			fi

			if [ ! -z "${vsphere_host// }" ] && [ "$vsphere_host" != "null" ]; then
			    python -c "import terraform_validator; terraform_validator.get_hosts_by_cluster(\"${vcenter_host_ip}\", \"${vsphere_user}\", \"${vsphere_password}\", \"${vsphere_compute_cluster}\")" |  grep -wq "$vsphere_host"
                if [ $? -ne 0 ]; then
                    echo "$vsphere_host defined in 'vsphere_host' in distinct section of $tf_tfvars_json_file for $vm_type is wrong or cannot be retrieved from pyvmomi. Exiting..."
                    exit 2
		        fi
				#validate the host server's capacity
				validate_host_cluster_capacity "$vsphere_compute_cluster" "$vsphere_host"
			else
			    #validate the compute cluster's capacity
				python -c "import terraform_validator; terraform_validator.get_clusters(\"${vcenter_host_ip}\", \"${vsphere_user}\", \"${vsphere_password}\")" |  grep -wq "$vsphere_compute_cluster"
                if [ $? -ne 0 ]; then
                    echo "$vsphere_compute_cluster defined in 'vsphere_compute_cluster' in distinct section of $tf_tfvars_json_file for $vm_type is wrong or cannot be retrieved from pyvmomi. Exiting..."
                    exit 2
                fi
			    validate_host_cluster_capacity "$vsphere_compute_cluster"
			fi
		fi
	done

	#step 12. check if there are any duplicate IP Addresses in the array 'sl_ip_addr_arr', and if the IP Address are not in use
	local iterator_i=0
	local iterator_j=1
	for sl_ip_addr in "${sl_ip_addr_arr[@]}"
	do
	    #step 12.1 
	    for (( iterator_i=iterator_j; iterator_i<${#sl_ip_addr_arr[@]}; iterator_i=iterator_i+1 ))
		do
		    if [ "$sl_ip_addr" == "${sl_ip_addr_arr[iterator_i]}" ]; then
			    echo "softlayer ip addr $sl_ip_addr is a duplicate one defined in $tf_tfvars_json_file which needs to be fixed. Exiting..."
				exit 3
			fi
		done 
		((iterator_j=iterator_j+1))

    done
}


# function to validate ansible-hosts github propereties and connection
function validate_ansible_hosts_custom_properties() {

	# validate github url
	cat ${custom_properties_file} | grep -qE "^ansible_hosts_github_url="
	if [ $? -eq 0 ]; then
		local ansible_hosts_github_url="`cat ${custom_properties_file} | grep ^ansible_hosts_github_url | awk -F "=" '{print $2}' | awk '{print $1}'`"

		# check if ansible-hosts file github url is valid
		local url_regex='(https|http)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]'
		if [[ ! $ansible_hosts_github_url =~ $url_regex ]]; then 
			echo "The ansible_hosts_github_url in the custom.properties file is not a valid url"
			exit 3
		fi
	else
		local ansible_hosts_github_url="${default_ansible_hosts_github_url}"
	fi

	# validate github email
	cat ${custom_properties_file} | grep -qE "^github_email="
	if [ $? -eq 0 ]; then
		local github_email="`cat ${custom_properties_file} | grep ^github_email | awk -F "=" '{print $2}' | awk '{print $1}'`"

		# check if email is valid
		local email_regex="^[a-z0-9!#\$%&'*+/=?^_\`{|}~-]+(\.[a-z0-9!#$%&'*+/=?^_\`{|}~-]+)*@([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z0-9]([a-z0-9-]*[a-z0-9])?\$"
		if [[ ! $github_email =~ $email_regex ]]; then 
			echo "The github_email property in the custom.properties file is not a valid email"
			exit 3
		fi
	else
		echo "Please provide email or uncomment the github_email property in the custom.properties file"
		exit 3
	fi

	# validate github access token
	cat ${custom_properties_file} | grep -qE "^github_access_token="
	if [ $? -eq 0 ]; then
		local github_access_token="`cat ${custom_properties_file} | grep ^github_access_token | awk -F "=" '{print $2}' | awk '{print $1}'`"
	else
		echo "Please provide a github access token or uncomment the github_access_token property in the custom.properties file"
		exit 3
	fi

	# validate github connection to ansible-hosts file
	local github_ansible_hosts_content=`curl -s --user "$github_email:$github_access_token" $ansible_hosts_github_url | jq -r '.content'`

	# exit code if content is null
	if [[ $github_ansible_hosts_content == "null" ]]; then
		echo "Could not get the content of the ansible-hosts file from github $ansible_hosts_github_url. Please check your github email: $github_email, github access token: $github_access_token"
		exit 3
	fi
}

#function to validate JWT_KEY_EXPIRY defined in custom.properties file
function validate_web_session_timeout_custom_properties() {
	grep -qE "^JWT_KEY_EXPIRY=" ${custom_properties_file}
	if [ $? -eq 0 ]; then
	    grep "^JWT_KEY_EXPIRY" ${custom_properties_file} | awk -F "=" '{print $2}' | awk '{print $1}' | grep -qE "^[1-9][0-9]*[mh]$"
		if [ $? -ne 0 ]; then
		    echo "JWT_KEY_EXPIRY defined in ${custom_properties_file} must be in format like:  for 30 mins should be '30m', for 24 hours, should be '24h'. Exiting..."
			exit 3
		fi
    fi
}

#function to validate all the properties defined in custom.properties file
function validate_custom_properties() {
	#validate ansible hosts related github information, including: ansible_hosts_github_url, github_email and github_access_token
	validate_ansible_hosts_custom_properties
	#validate JWT_KEY_EXPIRY
	validate_web_session_timeout_custom_properties
}

#main function

#step 0. check if the prerequisites for terraform environment are ready

check_tf_env

#step 1. validate if the json file terraform.tfvars.json has contents and  in a correct format
if [ -s "$tf_tfvars_json_file" ]; then
    python -m json.tool $tf_tfvars_json_file > /dev/null 2>&1 
    if [ $? -ne 0 ]; then
        echo "$tf_tfvars_json_file does NOT have a correct json format. Exiting..."
        exit 2
    fi
else
    echo "$tf_tfvars_json_file does NOT exist or has no contents"
    exit 1
fi
#step 2. parse terraform.tfvars.json file, leveraging pyvmomi to do the validation on the parameters

validate_shared_tfvars

#step 3.validate distinct tfvars

validate_distinct_tfvars

#step 4. validate ansible-hosts github config in the custom.properties file
validate_custom_properties
#validate_ansible_hosts_custom_properties
