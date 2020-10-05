function update_terraform(){
    local vm=$1
    local networkID=$2
    local terraform_factory_dir=$3

    # update terraform code with the network Id
    local virtual_machine_network_interface_subresource_file="/opt/go_workspace/src/github.com/terraform-providers/terraform-provider-vsphere/vsphere/internal/virtualdevice/virtual_machine_network_interface_subresource.go"
    grep -q "\"NETWORK-ID\"" ${virtual_machine_network_interface_subresource_file}
    if [ $? -eq 0 ]; then
        sed -i "s/\"NETWORK-ID\"/\"${networkID}\"/g" ${virtual_machine_network_interface_subresource_file}
    else
        echo "An error occurred while updating the terraform plugin. NETWORK-ID not found"
        exit 3
    fi
 
    # rebuild the terraform binary
    (cd /opt/go_workspace/src/github.com/terraform-providers/terraform-provider-vsphere; make build > /dev/null 2>&1)

    # copy new build to the terraform factory VM folder
    `cp /opt/go_workspace/bin/terraform-provider-vsphere ${terraform_factory_dir}/${vm}/.terraform/plugins/linux_amd64/terraform-provider-vsphere_v1.9.1_x4`

    # revert terraform code back to original
    grep -q "\"${networkID}\"" ${virtual_machine_network_interface_subresource_file}
    if [ $? -eq 0 ]; then
        sed -i "s/\"${networkID}\"/\"NETWORK-ID\"/g" ${virtual_machine_network_interface_subresource_file}
    else
        echo "An error occurred while updating the terraform plugin. ${networkID} network id not found"
        exit 3
    fi

    # rebuild again
    (cd /opt/go_workspace/src/github.com/terraform-providers/terraform-provider-vsphere; make build > /dev/null 2>&1)

    # initialize terraform 
    (cd ${terraform_factory_dir}/${vm}; terraform init > /dev/null 2>&1)

}

#terraform factory directory
terraform_factory_dir=$1
vm_folder=$2
# check if it is directory
if [ -d ${terraform_factory_dir}/${vm_folder} ]; then
    (cd ${terraform_factory_dir}/${vm_folder}; terraform init > /dev/null 2>&1)
    create_vm=$(cd ${terraform_factory_dir}/${vm_folder}; terraform plan -out=create_vm)
    network_id=$(echo "${create_vm}" | grep "network_interface.0.network_id" | awk -F ":" '{print $2}' | awk -F "\"" '{print $2}')
    #remove create_vm file
    rm -f ${terraform_factory_dir}/${vm_folder}/create_vm
    if [ -z "$network_id" ]; then
        echo "No Network Id for ${vm_folder}, resolve the issue and try again. Exiting..."
        exit 1
    else
        echo "Updating plugin for ${vm_folder}...."
        update_terraform "${vm_folder}" "${network_id}" "${terraform_factory_dir}"
        echo "Done updating plugin for ${vm_folder}"
        echo ""
    fi
fi