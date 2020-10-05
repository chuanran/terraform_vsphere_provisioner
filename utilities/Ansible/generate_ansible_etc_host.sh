#!/bin/bash

function increment_ip () {
    local ip="$1"
    local increment=$(( $2 - 1 ))
    
    baseaddr="$(echo $ip | cut -d. -f1-3)"
    octet4="$(echo $ip | cut -d. -f4)"
    new_octet4=$(( $octet4 + $increment ))
    echo $baseaddr.$new_octet4
}

etc_dir="TFD_etc_hosts"

if [ ! -d $etc_dir ]; then
  mkdir -p $etc_dir
fi

tf_tfvars_json_file="../../config/terraform.tfvars.json"

product_initials=$(jq -r ".product_initials" $tf_tfvars_json_file)
product_version=$(jq -r ".product_version" $tf_tfvars_json_file)
customer_env_name=$(jq -r ".customer_env_name" $tf_tfvars_json_file)
env_type=$(jq -r ".env_type" $tf_tfvars_json_file)

env_name="${product_initials}-${product_version}-${customer_env_name}-${env_type}"
host_file_name="${etc_dir}/${env_name}.ansible.etc.hosts"
echo "" > $host_file_name
for vm_it in $(jq '.vms_meta | keys | .[]' $tf_tfvars_json_file); do
    vm_type=$(jq -r ".vms_meta[$vm_it].vm_type" $tf_tfvars_json_file)
    vm_sl_private_ip=$(jq -r ".vms_meta[$vm_it].vm_sl_private_ip" $tf_tfvars_json_file)
    vsphere_vm_count=$(jq -r ".vms_meta[$vm_it].vsphere_vm_count" $tf_tfvars_json_file)

    if [ $vsphere_vm_count != null ]; then
        for ((i=1;i<=$vsphere_vm_count;i++)); do  
            vm_function_name=$vm_type$i
            private_ip=$( increment_ip "${vm_sl_private_ip}" "${i}" )
            echo "${private_ip} ${env_name}-${vm_function_name}.wfss.ibm.com ${env_name}-${vm_function_name}" >> $host_file_name
        done
    else
        echo "${vm_sl_private_ip} ${env_name}-${vm_type}.wfss.ibm.com ${env_name}-${vm_type}" >> $host_file_name
    fi
done