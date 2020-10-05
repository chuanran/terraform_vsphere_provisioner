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


## This script is used to launch FCI VMs (kube master, kube worker, hdp vms, etc) via Terraform, and do the customization (disk partition, software installation,etc) on the VMs

#variables statement
cur_dir=$(cd `dirname $0` && pwd)
terraform_factory_dir="${cur_dir}/terraform_factory"
terraform_shared_tfvars="${terraform_factory_dir}/terraform.tfvars.shared.config"
terraform="/usr/local/bin/terraform"
terraform_plugin_work_dir="${cur_dir}/plugin"
terraform_plugin_dir="${cur_dir}/plugin/.terraform"
terraform_tf_vars_name="terraform.tfvars"
build_tf_name="build.tf"
variables_tf_name="variables.tf"
#templates variable statement
tf_config_dir=${cur_dir}/config
tf_json_config_file=${tf_config_dir}/terraform.tfvars.json
custom_properties_file=${tf_config_dir}/custom.properties
tf_shared_templates_dir=${cur_dir}/templates/

#templates files for generating build.tf, variables.tf and terraform.tfvars files
tf_build_tf_template=${tf_shared_templates_dir}/build.tf.template
tf_build_tag_template=${tf_shared_templates_dir}/build.tf.tag.template
build_tf_disk_template=${tf_shared_templates_dir}/build.tf.disk.template
build_tf_internal_network_customization_template=${tf_shared_templates_dir}/build.tf.internal.network.customization.template
build_tf_internal_network_definition_template=${tf_shared_templates_dir}/build.tf.internal.network.definition.template
build_tf_internal_network_data_template=${tf_shared_templates_dir}/build.tf.internal.network.data.template
build_tf_compute_cluster_data_template=${tf_shared_templates_dir}/build.tf.compute.cluster.data.template
build_tf_compute_cluster_resource_pool_id_template=${tf_shared_templates_dir}/build.tf.compute.cluster.resource.pool.id.definition.template
build_tf_compute_cluster_host_system_id_template=${tf_shared_templates_dir}/build.tf.compute.cluster.host.system.id.definition.template
build_tf_compute_cluster_vm_host_rules_resource_template=${tf_shared_templates_dir}/build.tf.compute.cluster.vm.host.rules.resource.template
build_tf_host_data_definition_template=${tf_shared_templates_dir}/build.tf.host.data.template
build_tf_single_host_resource_pool_id_template=${tf_shared_templates_dir}/build.tf.single.host.resource.pool.id.definition.template
build_tf_resource_pool_data_template=${tf_shared_templates_dir}/build.tf.vsphere.resource.pool.data.template
build_tf_connection_template=${tf_shared_templates_dir}/build.tf.connection.template
build_tf_connection_hosts_file_provisioner_template=${tf_shared_templates_dir}/build.tf.connection.hosts.file.provisioner.template
build_tf_connection_hdpa_hosts_prop_file_provisioner_template=${tf_shared_templates_dir}/build.tf.connection.hdpa.hosts.prop.file.provisioner.template
build_tf_connection_km_hosts_prop_file_provisioner_template=${tf_shared_templates_dir}/build.tf.connection.km.hosts.prop.file.provisioner.template
build_tf_connection_hostname_change_provisioner_template=${tf_shared_templates_dir}/build.tf.connection.hostname.change.provisioner.template
build_tf_connection_customization_provisioner_template=${tf_shared_templates_dir}/build.tf.connection.customization.provisioner.template
build_tf_tag_data_template=${tf_shared_templates_dir}/build.tf.data.vm.tag.template
build_tf_tag_resource_template=${tf_shared_templates_dir}/build.tf.resource.vm.tag.template
mgmt_hosts_file_template=${tf_shared_templates_dir}/mgmt.hosts.file.template
mgmt_reverse_hosts_file_template=${tf_shared_templates_dir}/mgmt.reverse.hosts.file.template
haproxy_cfg_file_template=${tf_shared_templates_dir}/haproxy.cfg.template

variables_tf_shared_template=${tf_shared_templates_dir}/variables.tf.template
variables_tf_internal_network_template=${tf_shared_templates_dir}/variables.tf.internal.network.template
variables_tf_compute_cluster_template=${tf_shared_templates_dir}/variable.tf.compute.cluster.template
variables_tf_compute_cluster_vm_host_template=${tf_shared_templates_dir}/variable.tf.compute.cluster.vm.host.template
variables_tf_single_host_template=${tf_shared_templates_dir}/variable.tf.single.host.template

terraform_tfvars_distinct_config_template=${tf_shared_templates_dir}/terraform.tfvars.distinct.config.template
terraform_tfvars_shared_config_template=${tf_shared_templates_dir}/terraform.tfvars.shared.config.template

# definition keywords to be replaced in build.tf and variables.tf template file
disk_definition_keywords_in_build_tf_template="#disks_definition"
kube_internal_nw_definition_keywords_in_build_tf_template="#kube_internal_network_definition"
kube_internal_nw_customization_keywords_in_build_tf_template="#kube_internal_network_customization"
kube_internal_nw_data_keywords_in_build_tf_template="#kube_internal_network_data"
connection_keywords_in_build_tf_template="#connection_definition"
vsphere_compute_cluster_data_keywords_in_build_tf_template="#vsphere_compute_cluster_data_definition"
vsphere_host_data_keywords_in_build_tf_template="#vsphere_host_data_definition"
vsphere_resource_pool_data_keywords_in_build_tf_template="#vsphere_resource_pool_data_definition"
resource_pool_id_keywords_in_build_tf_template="#resource_pool_id_definition"
host_system_id_keywords_in_build_tf_template="#host_system_id_definition"
kube_internal_nw_vars_keywords_in_variables_tf_template="kube_internal_network_variables"
compute_cluster_vm_host_vars_keywords_in_variables_tf_template="compute_cluster_vm_host_variables"
host_file_provisioner_keywords_in_build_tf_connection_template="#hosts_file_provisioner"
km_hosts_properties_file_provisioner_keywords_in_build_tf_connection_template="#km_hosts_prop_file_provisioner"
hdpa_hosts_properties_file_provisioner_keywords_in_build_tf_connection_template="#hdpa_hosts_prop_file_provisioner"
hostname_change_provisioner_keywords_in_build_tf_connection_template="#hostname_change_provisioner"
customization_provisioner_keywords_in_build_tf_connection_template="#customization_provisioner"
tag_vm_resource_data_section_in_build_tf_template="#tag_vm_resource_data_section"
vm_tags_list_section_in_build_tf_template="#vm_tags_list_section"

#files directory, which stores artifacts for remote executing, i.e scripts, packages, etc
terraform_files_dir=${cur_dir}/files
terraform_files_secrets_dir=${cur_dir}/files/fci_keystore
terraform_customization_script_template="$terraform_files_dir/customization.sh.template"
terraform_customization_script_name="customization.sh"
terraform_hdp_customization_script_template="$terraform_files_dir/customization.hdp.sh.template"
terraform_hdp_customization_script_name="customization.hdp.sh"
terraform_customization_kube_platform_script_name="customization.kube.platform.sh"
terraform_customization_dd_script_name="customization.dd.sh"
terraform_customization_insurance_script_name="customization.insurance.sh"
terraform_mgmt_files_dir="${terraform_factory_dir}/mgmt/files"
terraform_mgmt_host_file="${terraform_mgmt_files_dir}/wfss.ibm.com.hosts.template"
terraform_km_files_dir="${terraform_factory_dir}/km/files"
terraform_km_hosts_file="${terraform_km_files_dir}/install.hosts.properties.template"
terraform_hdpa_files_dir="${terraform_factory_dir}/hdpa/files"
terraform_hdpa_hosts_properties_file="${terraform_hdpa_files_dir}/fci-hadoop.prod.hosts.properties"
terraform_haproxy_files_dir="${terraform_factory_dir}/haproxy/files"
terraform_haproxy_cfg_file="${terraform_haproxy_files_dir}/haproxy.cfg.template"
terraform_ms1_files_dir="${terraform_factory_dir}/ms1/files"
terraform_vm_tag_folder="${terraform_factory_dir}/tag"
terraform_vm_tag_terraform_build_file="${terraform_vm_tag_folder}/build.tf"
terraform_vm_tag_terraform_tfvars_file="${terraform_vm_tag_folder}/terraform.tfvars"
terraform_vm_tag_terraform_variables_file="${terraform_vm_tag_folder}/variables.tf"

#json file for vms in a specific datacenter. generated by calling pyvmomi
vms_in_dc_file="${cur_dir}/vms_in_dc.json"


# Usage statement
usage() {
	echo
	echo "This script is used to launch FCI VMs (kube master, kube worker, hdp vms, etc) via Terraform, and do the customization (disk partition, software installation,etc) on the VMs"
	echo
	echo "Usage: $0 [OPTIONS]...[ARGS]"
	echo
	echo "   -a|--all"
	echo "       whether need to launch all VMs defined via Terraform"
	echo
	echo "   -km|--kube_master"
	echo "       whether need to launch kube master via Terraform"
	echo
	echo "   -kw|--kube_worker"
	echo "       whether need to launch kube worker via Terraform"
	echo
	echo "   -db|--database"
	echo "       whether need to launch db via Terraform"
	echo
	echo "   -docreg|--docker_registry"
	echo "       whether need to launch docker registry via Terraform"
	echo
	echo "   -kwdd|--kube_worker_dd"
	echo "       whether need to launch kube worker dd via Terraform"
	echo
	echo "   -mgmt|--management"
	echo "       whether need to launch management vm via Terraform"
	echo
	echo "   -nfs1|--nfs1"
	echo "       whether need to launch nfs1 via Terraform"
	echo
	echo "   -nfs2|--nfs2"
	echo "       whether need to launch nfs2 via Terraform"
	echo
	echo "   -nfs3|--nfs3"
	echo "       whether need to launch nfs3 via Terraform"
	echo
	echo "   -web|--web"
	echo "       whether need to launch web vm via Terraform"
	echo
	echo "   -wexc|--wexc"
	echo "       whether need to launch wexc via Terraform"
	echo
	echo "   -wexfp|--wexfp"
	echo "       whether need to launch wexfp via Terraform"
	echo
	echo "   -hdpa|--hdpa"
	echo "       whether need to launch hadoop ambari via Terraform"
    echo
    echo "   -hdpg|--hdpg"
	echo "       whether need to launch hadoop gateway via Terraform"
    echo
    echo "   -hdpm|--hdpm"
	echo "       whether need to launch hadoop master via Terraform"
    echo
    echo "   -hdps1|--hdps1"
	echo "       whether need to launch hadoop slave1 via Terraform"
    echo
    echo "   -hdps2|--hdps2"
	echo "       whether need to launch hadoop slave2 via Terraform"
    echo
    echo "   -hdpsec|--hdpsec"
	echo "       whether need to launch hadoop security via Terraform"
    echo
    echo "   -ms|--ms"
	echo "       whether need to launch ICP4D ms via Terraform"
    echo
    echo "   -str|--stream"
	echo "       whether need to launch stream vms via Terraform"
    echo
    echo "   -zkp|--zkp"
	echo "       whether need to launch zookeeper vm via Terraform"
    echo
    echo "   -wexm|--wexm"
	echo "       whether need to launch wexm via Terraform"
	echo
    echo "   -api|--api"
	echo "       whether need to launch api server via Terraform"
	echo
    echo "   -st|--storage"
	echo "       whether need to launch storage vm via Terraform"
	echo
    echo "   -worker|--worker"
	echo "       whether need to launch worker vm via Terraform"
	echo
    echo "   -landing|--landing"
	echo "       whether need to launch landing vm via Terraform"
	echo
    echo "   -bigdata|--bigdata"
	echo "       whether need to launch bigdata vm via Terraform"
	echo
    echo "   -haproxy|--haproxy"
	echo "       whether need to launch haproxy vm via Terraform"
	echo
    echo "   -portworx|--portworx"
	echo "       whether need to launch haproxy vm via Terraform"
	echo
    echo "   -disable_validator|--disable_validator"
	echo "       whether need to disable validator or NOT"
	echo
    echo "   -ansible|--ansible"
	echo "       whether need to generate ansible hosts file via Terraform"
	echo
    echo "   -zabbix|--zabbix"
	echo "       whether need to integrate with zabbix via Terraform"
	echo
	echo "   -deploy|--deploy"
	echo "       whether launch terraform deploy or not"
	echo
}

if [ $# -lt 1 ]; then
	usage
	exit 1
fi

### PARAMETER ###
is_all=0
is_kube_master=0
is_kube_worker=0
is_db=0
is_docreg=0
is_kwdd=0
is_mgmt=0
is_nfs1=0
is_nfs2=0
is_nfs3=0
is_web=0
is_wexc=0
is_wexfp=0
is_wexm=0
is_hdpa=0
is_hdpg=0
is_hdpm=0
is_hdps1=0
is_hdps2=0
is_hdpsec=0
is_ms=0
is_zkp=0
is_str=0
is_api=0
is_storage=0
is_worker=0
is_landing=0
is_bigdata=0
is_haproxy=0
is_portworx=0
is_ansible=0
disable_validator=0
is_zabbix=0
terraform_deploy=0

while [[ $# > 0 ]]
do
key="$1"
shift
case ${key} in
	-a|--all)
        is_all=1
    ;;
	-km|--kube_master)
        is_kube_master=1
    ;;
    -kw|--kube_worker)
        is_kube_worker=1
    ;;
    -db|--database)
        is_db=1
    ;;
    -docreg|--docker_registry)
        is_docreg=1
    ;;
    -kwdd|--kube_worker_dd)
        is_kwdd=1
    ;;
    -mgmt|--management)
        is_mgmt=1
    ;;
    -nfs1|--nfs1)
        is_nfs1=1
    ;;
	-nfs2|--nfs2)
        is_nfs2=1
    ;;
	-nfs3|--nfs3)
        is_nfs3=1
    ;;
    -web|--web)
        is_web=1
    ;;
    -wexc|--wexc)
        is_wexc=1
    ;;
    -wexfp|--wexfp)
        is_wexfp=1
    ;;
    -wexm|--wexm)
        is_wexm=1
    ;;
    -hdpa|--hdpa)
        is_hdpa=1
    ;;
    -hdpg|--hdpg)
        is_hdpg=1
    ;;
    -hdpm|--hdpm)
        is_hdpm=1
    ;;
    -hdps1|--hdps1)
        is_hdps1=1
    ;;
    -hdps2|--hdps2)
        is_hdps2=1
    ;;
    -hdpsec|--hdpsec)
        is_hdpsec=1
    ;;
    -ms|--ms)
        is_ms=1
    ;;
    -zkp|--zkp)
        is_zkp=1
    ;;
    -str|--stream)
        is_str=1
    ;;
    -api|--api)
        is_api=1
    ;;
    -st|--storage)
        is_storage=1
    ;;
    -worker|--worker)
        is_worker=1
    ;;
    -landing|--landing)
        is_landing=1
    ;;
    -bigdata|--bigdata)
        is_bigdata=1
    ;;
    -haproxy|--haproxy)
        is_haproxy=1
    ;;
    -portworx|--portworx)
        is_portworx=1
    ;;
    -disable_validator|--disable_validator)
        disable_validator=1
    ;;
    -ansible|--ansible)
        is_ansible=1
    ;;
    -zabbix|--zabbix)
        is_zabbix=1
    ;;
	-deploy|--deploy)
        terraform_deploy=1
    ;;

    -h|--help)
        usage
        exit 1
    ;;
	*)
    echo -e "\nUnknow Argument"
	usage
	exit 1
	;;
esac
done

if [ ! -f $terraform ]; then
	echo "$terraform does NOT exist. Please install it first. Exiting..."
	exit 1
fi

if [ $is_all -eq 1 ]; then
	echo "to provision an environment by cloning existing template VMs"
	is_kube_master=1
	is_kube_worker=1
	is_db=1
	is_docreg=1
	is_kwdd=1
	is_mgmt=1
	is_nfs1=1
	is_nfs2=1
	is_nfs3=1
	is_web=1
	is_wexc=1
	is_wexfp=1
	is_wexm=1
    is_hdpa=1
    is_hdpg=1
    is_hdpm=1
    is_hdps1=1
    is_hdps2=1
    is_hdpsec=1
    is_ms=1
    is_zkp=1
    is_str=1
    is_api=1
    is_storage=1
    is_worker=1
    is_landing=1
    is_bigdata=1
    is_haproxy=1
    is_portworx=1
fi

#function to add ip by 1, for example,  for ip 10.0.80.11, after adding by 1, it will be 10.0.80.12
function add_ip_by_one() {
    local original_ip="$1"
    local ip_prefix="`echo ${original_ip} | awk -F "." '{print $1}'`.`echo ${original_ip} | awk -F "." '{print $2}'`.`echo ${original_ip} | awk -F "." '{print $3}'`."
    local ip_start_number=`echo ${original_ip} | awk -F "." '{print $4}'`
    local ip_postfix=""
    ((ip_postfix=ip_start_number+1))
    echo "${ip_prefix}${ip_postfix}"
}

# function to increment ip address by any number
function increment_ip () {
    local ip="$1"
    # subtract one from the counter to give the increment
    local increment=$(( $2 - 1 ))
    
    local baseaddr="$(echo $ip | cut -d. -f1-3)"
    local octet4="$(echo $ip | cut -d. -f4)"
    new_octet4=$(( $octet4 + $increment ))
    echo $baseaddr.$new_octet4
}

#generate shared tfvars file, which can be used for all types of vms
function generate_shared_tfvars(){
    local vm_it=0
    if [ ! -d $terraform_factory_dir ]; then
        mkdir -p $terraform_factory_dir
    fi
    if [ -f ${terraform_shared_tfvars} ]; then
        rm ${terraform_shared_tfvars}
    fi
    local vsphere_vcenter=$(jq -r ".vsphere_vcenter" $tf_json_config_file)
    echo "vsphere_vcenter = \"$vsphere_vcenter\"" > ${terraform_shared_tfvars}
    local vsphere_user=$(jq -r ".vsphere_user" $tf_json_config_file)
    echo "vsphere_user = \"$vsphere_user\"" >> ${terraform_shared_tfvars}
    local vsphere_password=$(jq -r ".vsphere_password" $tf_json_config_file)
    echo "vsphere_password = \"$vsphere_password\"" >> ${terraform_shared_tfvars}
    local vsphere_source_datacenter=$(jq -r ".vsphere_source_datacenter" $tf_json_config_file)
    echo "vsphere_source_datacenter = \"$vsphere_source_datacenter\"" >> ${terraform_shared_tfvars}
    local vsphere_source_vm_folder=$(jq -r ".vsphere_source_vm_folder" $tf_json_config_file)
    echo "vsphere_source_vm_folder = \"$vsphere_source_vm_folder\"" >> ${terraform_shared_tfvars}
    local vsphere_target_datacenter=$(jq -r ".vsphere_target_datacenter" $tf_json_config_file)
    echo "vsphere_target_datacenter = \"$vsphere_target_datacenter\"" >> ${terraform_shared_tfvars}
    local vsphere_compute_cluster=$(jq -r ".vsphere_compute_cluster" $tf_json_config_file)
    if [ ! -z "${vsphere_compute_cluster// }" ] && [ "$vsphere_compute_cluster" != "null" ]; then
        echo "vsphere_compute_cluster = \"$vsphere_compute_cluster\"" >> ${terraform_shared_tfvars}
    fi
    local vsphere_host=$(jq -r ".vsphere_host" $tf_json_config_file)
    if [ ! -z "${vsphere_host// }" ] && [ "$vsphere_host" != "null" ]; then
        echo "vsphere_host = \"$vsphere_host\"" >> ${terraform_shared_tfvars}
    fi
    local vsphere_host_folder=$(jq -r ".vsphere_host_folder" $tf_json_config_file)
    if [ ! -z "${vsphere_host_folder// }" ] && [ "$vsphere_host_folder" != "null" ]; then
        echo "vsphere_host_folder = \"$vsphere_host_folder\"" >> ${terraform_shared_tfvars}
    fi
    local vsphere_target_datastore=$(jq -r ".vsphere_target_datastore" $tf_json_config_file)
    if [ ! -z "${vsphere_target_datastore// }" ] && [ "$vsphere_target_datastore" != "null" ]; then
        echo "vsphere_target_datastore = \"$vsphere_target_datastore\"" >> ${terraform_shared_tfvars}
    fi
    local vsphere_target_vm_folder=$(jq -r ".vsphere_target_vm_folder" $tf_json_config_file)
    echo "vsphere_target_vm_folder = \"$vsphere_target_vm_folder\"" >> ${terraform_shared_tfvars}
    local vsphere_sl_private_network_name=$(jq -r ".vsphere_sl_private_network_name" $tf_json_config_file)
    if [ ! -z "${vsphere_sl_private_network_name// }" ] && [ "$vsphere_sl_private_network_name" != "null" ]; then
        echo "vsphere_sl_private_network_name = \"$vsphere_sl_private_network_name\"" >> ${terraform_shared_tfvars}
    fi
    local vm_sl_private_netmask=$(jq -r ".vm_sl_private_netmask" $tf_json_config_file)
    if [ ! -z "${vm_sl_private_netmask// }" ] && [ "$vm_sl_private_netmask" != "null" ]; then
        echo "vm_sl_private_netmask = \"$vm_sl_private_netmask\"" >> ${terraform_shared_tfvars}
    fi
    local vm_network_gateway=$(jq -r ".vm_network_gateway" $tf_json_config_file)
    if [ ! -z "${vm_network_gateway// }" ] && [ "$vm_network_gateway" != "null" ]; then
        echo "vm_network_gateway = \"$vm_network_gateway\"" >> ${terraform_shared_tfvars}
    fi
    # generate vsphere_dns_servers list in terraform.tfvars. such as: [ "10.0.80.11", "10.0.80.12" ]
    local vsphere_dns_servers=$(jq -r ".vsphere_dns_servers" $tf_json_config_file)
    #if dns server not defined, will use mgmt vm's ip
    local mgmt_sl_private_ip=""
    if [ "$vsphere_dns_servers" == "null" ]; then
        for  vm_it in $(jq '.vms_meta | keys | .[]' $tf_json_config_file); do
            local vm_type=$(jq -r ".vms_meta[$vm_it].vm_type" $tf_json_config_file)
            if [ "$vm_type" == "mgmt" ]; then
                mgmt_sl_private_ip=$(jq -r ".vms_meta[$vm_it].vm_sl_private_ip" $tf_json_config_file)
                break
            fi
        done
        echo "vsphere_dns_servers = [ \"$mgmt_sl_private_ip\" ]" >> ${terraform_shared_tfvars}
    #if dns server defined by "vsphere_dns_servers", will use the corresponding value of it  
    else
        echo "vsphere_dns_servers = $vsphere_dns_servers" >> ${terraform_shared_tfvars}
        dns_servers_num=`echo $vsphere_dns_servers | awk -F "," '{print NF}'`
        for (( j=1; j<=$dns_servers_num; j++ ))
        do
            vsphere_dns_server=`echo $vsphere_dns_servers | awk -F "," "{print $"$j"}" | awk '{print $1}'`
            sed -i "/^vsphere_dns_server/s/\b$vsphere_dns_server\b/\"$vsphere_dns_server\"/g" ${terraform_shared_tfvars}
        done
        vsphere_dns_servers_str=`grep -E "^vsphere_dns_servers" ${terraform_shared_tfvars} | awk -F "vsphere_dns_servers = " '{print $2}'`
        vsphere_dns_servers_new_str="[ $vsphere_dns_servers_str ]"
        sed -i "/^vsphere_dns_server/s/$vsphere_dns_servers_str/$vsphere_dns_servers_new_str/g" ${terraform_shared_tfvars}
    fi
    # generate virtual_machine_search_domain list in terraform.tfvars. such as: [ "wfss.ibm.com", "fss.ibm.com" ]
    local virtual_machine_search_domain=$(jq -r ".virtual_machine_search_domain" $tf_json_config_file)
    echo "virtual_machine_search_domain = $virtual_machine_search_domain" >> ${terraform_shared_tfvars}
    search_domain_num=`echo $virtual_machine_search_domain | awk -F "," '{print NF}'`
    for (( k=1; k<=$search_domain_num; k++ ))
    do
        search_domain=`echo $virtual_machine_search_domain | awk -F "," "{print $"$k"}" | awk '{print $1}'`
        sed -i "/^virtual_machine_search_domain/s/\b$search_domain\b/\"$search_domain\"/g" ${terraform_shared_tfvars}
    done
    virtual_machine_search_domain_str=`grep -E "^virtual_machine_search_domain" ${terraform_shared_tfvars} | awk -F "virtual_machine_search_domain = " '{print $2}'`
    virtual_machine_search_domain_new_str="[ $virtual_machine_search_domain_str ]"
    sed -i "/^virtual_machine_search_domain/s/$virtual_machine_search_domain_str/$virtual_machine_search_domain_new_str/g" ${terraform_shared_tfvars}

    local vsphere_dns_domain=$(jq -r ".vsphere_dns_domain" $tf_json_config_file)
    echo "vsphere_dns_domain = \"$vsphere_dns_domain\"" >> ${terraform_shared_tfvars}        
}

function get_subnet() {
    local netmask="$1"
    local gateway_ip="$2"

    local network_ip=$(increment_ip "${gateway_ip}" "0")
    echo "${network_ip}/${netmask}"
}

function generate_nfs_export_options() {
    local vm_sl_private_netmask=$(jq -r ".vm_sl_private_netmask"  $tf_json_config_file)
    local vm_network_gateway=$(jq -r ".vm_network_gateway"  $tf_json_config_file)
    local first_subnet="$(get_subnet $vm_sl_private_netmask $vm_network_gateway)"
    local nfs_exports_props="$(echo "${first_subnet}(rw,sync,no_root_squash)" )"

    for vm_it in $(jq '.vms_meta | keys | .[]' $tf_json_config_file); do
        local vm_it_private_netmask=$(jq -r ".vms_meta[$vm_it].vm_sl_private_netmask" $tf_json_config_file)
        local vm_it_network_gateway=$(jq -r ".vms_meta[$vm_it].vm_network_gateway" $tf_json_config_file)

        if [ ! -z "${vm_it_private_netmask// }" ] && [ ! -z "${vm_it_network_gateway// }" ] && [ "$vm_it_private_netmask" != "null" ] && [ "$vm_it_network_gateway" != "null" ]; then
            local next_subnet="$(get_subnet $vm_it_private_netmask $vm_it_network_gateway)"
            local next_nfs_exports_props="${next_subnet}(rw,sync,no_root_squash)"
            local nfs_exports_props="$(echo "${nfs_exports_props} ${next_nfs_exports_props}" )"
        fi
    done

    echo "${nfs_exports_props}"
}

full_nfs_export_options="$(generate_nfs_export_options)"

#function for generating vm customization script:
function generate_vm_customization_script() {
    local vm_hostname="$1"
    local vm_targetname="$2"
    local terraform_customization_file_folder="$3"
    local product_type=$(jq -r ".product_initials" $tf_json_config_file)
    local vmuser=$(jq -r ".vmuser" $tf_json_config_file)
    local nfs_export_options=$(echo $full_nfs_export_options | sed -e 's/[]\/$*.^[]/\\&/g')
    #copy all the script templates file to the corresponding terraform folder, and rename them to the name without ".template" as the postfix
    for file in `ls $terraform_files_dir/*.sh.template`
    do
        file_basename=$(basename -- $file)
        new_file_basename=$(echo "$file_basename" | awk -F ".template" '{print $1}')
        cp $file "${terraform_customization_file_folder}/${new_file_basename}"
        grep -q "{vsphere_vm_hostname}" "${terraform_customization_file_folder}/${new_file_basename}"
        if [ $? -eq 0 ]; then
            sed -i "s/{vsphere_vm_hostname}/$vm_hostname/g" "${terraform_customization_file_folder}/${new_file_basename}"
        fi
        grep -q "{vsphere_target_vm_name}" "${terraform_customization_file_folder}/${new_file_basename}"
        if [ $? -eq 0 ]; then
            sed -i "s/{vsphere_target_vm_name}/$vm_targetname/g" "${terraform_customization_file_folder}/${new_file_basename}"
        fi
        grep -q "{product_type}" "${terraform_customization_file_folder}/${new_file_basename}"
        if [ $? -eq 0 ]; then
            sed -i "s/{product_type}/$product_type/g" "${terraform_customization_file_folder}/${new_file_basename}"
        fi
        grep -q "{full_nfs_export_options}" "${terraform_customization_file_folder}/${new_file_basename}"
        if [ $? -eq 0 ]; then
            sed -i "s/{full_nfs_export_options}/${nfs_export_options}/g" "${terraform_customization_file_folder}/${new_file_basename}"
        fi
    done
    grep -q "{kwdd_vm_count}" "${terraform_customization_file_folder}/${terraform_customization_kube_platform_script_name}"
    if [ $? -eq 0 ]; then
        local kwdd_vm_count=3
        local vm_it=0
        grep -q "\"vm_type\": \"kwdd\"" $tf_json_config_file
        if [ $? -eq 0 ]; then
            for  vm_it in $(jq '.vms_meta | keys | .[]' $tf_json_config_file); do
                local vm_type=$(jq -r ".vms_meta[$vm_it].vm_type" $tf_json_config_file)
                if [ "$vm_type" == "kwdd" ]; then
                    kwdd_vm_count=$(jq -r ".vms_meta[$vm_it].vsphere_vm_count" $tf_json_config_file)
                fi
            done
        else
            kwdd_vm_count=0
        fi
        sed -i "s/{kwdd_vm_count}/$kwdd_vm_count/g" "${terraform_customization_file_folder}/${terraform_customization_kube_platform_script_name}"
    fi
    grep -q "{kw_vm_count}" "${terraform_customization_file_folder}/${terraform_customization_kube_platform_script_name}"
    if [ $? -eq 0 ]; then
        local kw_vm_count=7
        local vm_it=0
        grep -q "\"vm_type\": \"kw\"" $tf_json_config_file
        if [ $? -eq 0 ]; then
            for  vm_it in $(jq '.vms_meta | keys | .[]' $tf_json_config_file); do
                local vm_type=$(jq -r ".vms_meta[$vm_it].vm_type" $tf_json_config_file)
                if [ "$vm_type" == "kw" ]; then
                    kw_vm_count=$(jq -r ".vms_meta[$vm_it].vsphere_vm_count" $tf_json_config_file)
                fi
            done
        else
            kw_vm_count=0
        fi
        sed -i "s/{kw_vm_count}/$kw_vm_count/g" "${terraform_customization_file_folder}/${terraform_customization_kube_platform_script_name}" 
    fi

    #update web session timeout value "JWT_KEY_EXPIRY"
    grep -Eq "^JWT_KEY_EXPIRY=" $custom_properties_file
    if [ $? -ne 0 ]; then
        JWT_KEY_EXPIRY_VALUE="30m"
    else
        JWT_KEY_EXPIRY_VALUE=$(cat ${custom_properties_file} | grep ^JWT_KEY_EXPIRY | awk -F "=" '{print $2}' | awk '{print $1}')
    fi
    grep -q "{jwt_new_expiry}" "${terraform_customization_file_folder}/${terraform_customization_kube_platform_script_name}"
    if [ $? -eq 0 ]; then
        sed -i "s/{jwt_new_expiry}/$JWT_KEY_EXPIRY_VALUE/g" "${terraform_customization_file_folder}/${terraform_customization_kube_platform_script_name}"
    fi
    # update for hadoop vms customization script
    grep -q "{vm_user}" "${terraform_customization_file_folder}/${terraform_hdp_customization_script_name}"
    if [ $? -eq 0 ]; then
        sed -i "s/{vm_user}/$vmuser/g" "${terraform_customization_file_folder}/${terraform_hdp_customization_script_name}"
    fi
    for vm_it in $(jq '.vms_meta | keys | .[]' $tf_json_config_file); do
        local vm_type=$(jq -r ".vms_meta[$vm_it].vm_type" $tf_json_config_file)
        local vmpassword=$(jq -r ".vms_meta[$vm_it].vmpassword" $tf_json_config_file)
        local vm_sl_private_ip=$(jq -r ".vms_meta[$vm_it].vm_sl_private_ip" $tf_json_config_file)
        if [ "$vm_type" == "km" ]; then
            #copy the secrets to km terraform files folder
            cp -r $terraform_files_secrets_dir ${terraform_customization_file_folder}
            #update {km_vm_password} and {km_vm_sl_private_ip}
            grep -q "{km_vm_password}" "${terraform_customization_file_folder}/${terraform_hdp_customization_script_name}"
            if [ $? -eq 0 ]; then
                sed -i "s/{km_vm_password}/$vmpassword/g" "${terraform_customization_file_folder}/${terraform_hdp_customization_script_name}"
            fi
            grep -q "{km_vm_sl_private_ip}" "${terraform_customization_file_folder}/${terraform_hdp_customization_script_name}"
            if [ $? -eq 0 ]; then
                sed -i "s/{km_vm_sl_private_ip}/$vm_sl_private_ip/g" "${terraform_customization_file_folder}/${terraform_hdp_customization_script_name}"
            fi
        fi
        # update kube customization script with with hdpa password and ip
        if [ "$vm_type" == "hdpa" ]; then
            #copy the secrets to km terraform files folder
            cp -r $terraform_files_secrets_dir ${terraform_customization_file_folder}
            #update {hdpa_vm_password} and {hdpa_vm_sl_private_ip}
            grep -q "{hdpa_vm_password}" "${terraform_customization_file_folder}/${terraform_customization_kube_platform_script_name}" 
            if [ $? -eq 0 ]; then
                sed -i "s/{hdpa_vm_password}/$vmpassword/g" "${terraform_customization_file_folder}/${terraform_customization_kube_platform_script_name}" 
            fi
            grep -q "{hdpa_vm_sl_private_ip}" "${terraform_customization_file_folder}/${terraform_customization_kube_platform_script_name}" 
            if [ $? -eq 0 ]; then
                sed -i "s/{hdpa_vm_sl_private_ip}/$vm_sl_private_ip/g" "${terraform_customization_file_folder}/${terraform_customization_kube_platform_script_name}" 
            fi  
        fi
        if [ "$vm_type" == "hdpm" ]; then
            grep -q "{hdpm_vm_password}" "${terraform_customization_file_folder}/${terraform_customization_kube_platform_script_name}" 
            if [ $? -eq 0 ]; then
                sed -i "s/{hdpm_vm_password}/$vmpassword/g" "${terraform_customization_file_folder}/${terraform_customization_kube_platform_script_name}" 
            fi
            grep -q "{hdpm_vm_sl_private_ip}" "${terraform_customization_file_folder}/${terraform_customization_kube_platform_script_name}" 
            if [ $? -eq 0 ]; then
                sed -i "s/{hdpm_vm_sl_private_ip}/$vm_sl_private_ip/g" "${terraform_customization_file_folder}/${terraform_customization_kube_platform_script_name}" 
            fi  
        fi
    done
    #update data source config
    grep -Eq "^DNB_USERNAME=" $custom_properties_file
    if [ $? -eq 0 ]; then
        DNB_USERNAME=$(cat ${custom_properties_file} | grep ^DNB_USERNAME | awk -F "DNB_USERNAME=" '{print $2}' | awk '{print $1}')
        sed -i "s/{new_dnb_user}/$DNB_USERNAME/g" "${terraform_customization_file_folder}/${terraform_customization_dd_script_name}"
    fi
    grep -Eq "^DNB_PASSWORD=" $custom_properties_file
    if [ $? -eq 0 ]; then
        DNB_PASSWORD=$(cat ${custom_properties_file} | grep ^DNB_PASSWORD | awk -F "DNB_PASSWORD=" '{print $2}' | awk '{print $1}')
        sed -i "s/{new_dnb_password}/$DNB_PASSWORD/g" "${terraform_customization_file_folder}/${terraform_customization_dd_script_name}"
    fi
    grep -Eq "^DOWJONES_USERNAME=" $custom_properties_file
    if [ $? -eq 0 ]; then
        DOWJONES_USERNAME=$(cat ${custom_properties_file} | grep ^DOWJONES_USERNAME | awk -F "DOWJONES_USERNAME=" '{print $2}' | awk '{print $1}')
        sed -i "s/{new_dj_user}/$DOWJONES_USERNAME/g" "${terraform_customization_file_folder}/${terraform_customization_dd_script_name}"
    fi
    grep -Eq "^DOWJONES_PASSWORD=" $custom_properties_file
    if [ $? -eq 0 ]; then
        DOWJONES_PASSWORD=$(cat ${custom_properties_file} | grep ^DOWJONES_PASSWORD | awk -F "DOWJONES_PASSWORD=" '{print $2}' | awk '{print $1}')
        sed -i "s/{new_dj_password}/$DOWJONES_PASSWORD/g" "${terraform_customization_file_folder}/${terraform_customization_dd_script_name}"
    fi
    grep -Eq "^KYCKR_USERNAME=" $custom_properties_file
    if [ $? -eq 0 ]; then
        KYCKR_USERNAME=$(cat ${custom_properties_file} | grep ^KYCKR_USERNAME | awk -F "KYCKR_USERNAME=" '{print $2}' | awk '{print $1}')
        sed -i "s/{new_kyckr_user}/$KYCKR_USERNAME/g" "${terraform_customization_file_folder}/${terraform_customization_dd_script_name}"
    fi
    grep -Eq "^KYCKR_PASSWORD=" $custom_properties_file
    if [ $? -eq 0 ]; then
        KYCKR_PASSWORD=$(cat ${custom_properties_file} | grep ^KYCKR_PASSWORD | awk -F "KYCKR_PASSWORD=" '{print $2}' | awk '{print $1}')
        sed -i "s/{new_kyckr_password}/$KYCKR_PASSWORD/g" "${terraform_customization_file_folder}/${terraform_customization_dd_script_name}"
    fi
    grep -Eq "^FACTIVA_EID=" $custom_properties_file
    if [ $? -eq 0 ]; then
        FACTIVA_EID=$(cat ${custom_properties_file} | grep ^FACTIVA_EID | awk -F "FACTIVA_EID=" '{print $2}' | awk '{print $1}')
        sed -i "s/{new_factiva_eid}/$FACTIVA_EID/g" "${terraform_customization_file_folder}/${terraform_customization_dd_script_name}"
    fi
    grep -Eq "^FACTIVA_NEWS_ENCRYTED_TOKEN_VALUE=" $custom_properties_file
    if [ $? -eq 0 ]; then
        FACTIVA_NEWS_ENCRYTED_TOKEN_VALUE=$(cat ${custom_properties_file} | grep ^FACTIVA_NEWS_ENCRYTED_TOKEN_VALUE | awk -F "FACTIVA_NEWS_ENCRYTED_TOKEN_VALUE=" '{print $2}' | awk '{print $1}')
        sed -i "s/{new_factiva_token}/$FACTIVA_NEWS_ENCRYTED_TOKEN_VALUE/g" "${terraform_customization_file_folder}/${terraform_customization_dd_script_name}"
    fi
    grep -Eq "^BING_NEWS_SUBSCRIPTION_KEY_V7=" $custom_properties_file
    if [ $? -eq 0 ]; then
        BING_NEWS_SUBSCRIPTION_KEY_V7=$(cat ${custom_properties_file} | grep ^BING_NEWS_SUBSCRIPTION_KEY_V7 | awk -F "BING_NEWS_SUBSCRIPTION_KEY_V7=" '{print $2}' | awk '{print $1}')
        sed -i "s/{new_bing_news_key}/$BING_NEWS_SUBSCRIPTION_KEY_V7/g" "${terraform_customization_file_folder}/${terraform_customization_dd_script_name}"
    fi
    grep -Eq "^BING_WEB_SUBSCRIPTION_KEY_V7=" $custom_properties_file
    if [ $? -eq 0 ]; then
        BING_WEB_SUBSCRIPTION_KEY_V7=$(cat ${custom_properties_file} | grep ^BING_WEB_SUBSCRIPTION_KEY_V7 | awk -F "BING_WEB_SUBSCRIPTION_KEY_V7=" '{print $2}' | awk '{print $1}')
        sed -i "s/{new_bing_web_key}/$BING_WEB_SUBSCRIPTION_KEY_V7/g" "${terraform_customization_file_folder}/${terraform_customization_dd_script_name}"
    fi
}

#function for generating install.hosts.properties under /root/fci-install-kit/helm on km vm
function generate_install_hosts_properties() {
    local tfvars_file="$1"
    local vm_sl_private_ip=`grep -E  "^vm_sl_private_ip" $tfvars_file |  awk -F "=" '{print $2}' |  awk -F '"' '{print $2}'`
    local vsphere_vm_hostname=`grep -E  "^vsphere_vm_hostname" $tfvars_file |  awk -F "=" '{print $2}' |  awk -F '"' '{print $2}'`
    local vsphere_dns_domain=`grep -E  "^vsphere_dns_domain" $tfvars_file |  awk -F "=" '{print $2}' |  awk -F '"' '{print $2}'`
    local vmpassword=`grep -E  "^vmpassword" $tfvars_file |  awk -F "=" '{print $2}' |  awk -F '"' '{print $2}'`
    #for kube master
    echo "$vsphere_vm_hostname" | grep -q "\-km"
    if [ $? -eq 0 ]; then
        echo "master.ip=$vm_sl_private_ip" >> $terraform_km_hosts_file
        echo "master.fqdn=${vsphere_vm_hostname}.${vsphere_dns_domain}" >> $terraform_km_hosts_file
        echo "master.root_password=$vmpassword" >> $terraform_km_hosts_file
    fi
    # for kube worker
    echo  "$vsphere_vm_hostname" | grep -Eq "\-kw[0-9]+$"
    if [ $? -eq 0 ]; then
        local worker_index=$(echo  "$vsphere_vm_hostname" | grep -E "\-kw[0-9]+$" | awk -F "-kw" '{print $2}' |  awk '{print $1}')
        echo "worker.$worker_index.ip=$vm_sl_private_ip" >> $terraform_km_hosts_file
        echo "worker.$worker_index.fqdn=${vsphere_vm_hostname}.${vsphere_dns_domain}" >> $terraform_km_hosts_file
        echo "worker.$worker_index.root_password=$vmpassword" >> $terraform_km_hosts_file
    fi

    # for kube worker dd
    echo  "$vsphere_vm_hostname" | grep -Eq "\-kwdd[0-9]+$"
    if [ $? -eq 0 ]; then
        local worker_dd_index=$(echo  "$vsphere_vm_hostname" | grep -E "\-kwdd[0-9]+$" | awk -F "-kwdd" '{print $2}' |  awk '{print $1}')
        local kw_vm_count=0
        local vm_it=0
        for  vm_it in $(jq '.vms_meta | keys | .[]' $tf_json_config_file); do
            local vm_type=$(jq -r ".vms_meta[$vm_it].vm_type" $tf_json_config_file)
            if [ "$vm_type" == "kw" ]; then
                kw_vm_count=$(jq -r ".vms_meta[$vm_it].vsphere_vm_count" $tf_json_config_file)
            fi
        done
        local worker_index=0
        ((worker_index=worker_dd_index+kw_vm_count))
        echo "worker.$worker_index.ip=$vm_sl_private_ip" >> $terraform_km_hosts_file
        echo "worker.$worker_index.fqdn=${vsphere_vm_hostname}.${vsphere_dns_domain}" >> $terraform_km_hosts_file
        echo "worker.$worker_index.root_password=$vmpassword" >> $terraform_km_hosts_file
    fi
    # for nfs2 server
    echo  "$vsphere_vm_hostname" | grep -Eq "\-nfs2"
    if [ $? -eq 0 ]; then
        echo "nfs.ip=$vm_sl_private_ip" >> $terraform_km_hosts_file
        echo "nfs.fqdn=${vsphere_vm_hostname}.${vsphere_dns_domain}" >> $terraform_km_hosts_file
        echo "nfs.root_password=$vmpassword" >> $terraform_km_hosts_file
    fi
}

function generate_fci_hadoop_hosts_properties() {
    local product_initials=$(jq -r ".product_initials" $tf_json_config_file)
    local product_version=$(jq -r ".product_version" $tf_json_config_file)
    local customer_env_name=$(jq -r ".customer_env_name" $tf_json_config_file)
    local env_type=$(jq -r ".env_type" $tf_json_config_file)
    local vsphere_dns_domain=$(jq -r ".vsphere_dns_domain" $tf_json_config_file)

    local env_name="${product_initials}-${product_version}-${customer_env_name}-${env_type}"
    
    echo "" > $terraform_hdpa_hosts_properties_file
    for vm_it in $(jq '.vms_meta | keys | .[]' $tf_json_config_file); do
        local vm_type=$(jq -r ".vms_meta[$vm_it].vm_type" $tf_json_config_file)
        local vm_sl_private_ip=$(jq -r ".vms_meta[$vm_it].vm_sl_private_ip" $tf_json_config_file)
        local vmpassword=$(jq -r ".vms_meta[$vm_it].vmpassword" $tf_json_config_file)

        local hostname="${env_name}-${vm_type}.${vsphere_dns_domain}"
        if [ "$vm_type" == "hdpa" ]; then
            echo "ambari                  ${vm_sl_private_ip}        ${hostname}         ${vmpassword}" >> $terraform_hdpa_hosts_properties_file
        fi
        if [ "$vm_type" == "hdpg" ]; then
            echo "hadoop.gateway          ${vm_sl_private_ip}        ${hostname}         ${vmpassword}" >> $terraform_hdpa_hosts_properties_file
        fi
        if [ "$vm_type" == "hdpm" ]; then
            echo "hadoop.master           ${vm_sl_private_ip}        ${hostname}         ${vmpassword}" >> $terraform_hdpa_hosts_properties_file
        fi
        if [ "$vm_type" == "hdpsec" ]; then
            echo "hadoop.secondary        ${vm_sl_private_ip}        ${hostname}         ${vmpassword}" >> $terraform_hdpa_hosts_properties_file
        fi
        if [ "$vm_type" == "hdps1" ]; then
            echo "hadoop.slave            ${vm_sl_private_ip}        ${hostname}         ${vmpassword}" >> $terraform_hdpa_hosts_properties_file
        fi
        if [ "$vm_type" == "hdps2" ]; then
            echo "hadoop.slave            ${vm_sl_private_ip}        ${hostname}         ${vmpassword}" >> $terraform_hdpa_hosts_properties_file
        fi

    done
}

#function for generating mgmt host file based on terraform.tfvars file for each role
function generate_mgmt_host_file() {
    local tfvars_file="$1"
    local vm_type="$2"
    local vm_sl_private_ip=`grep -E  "^vm_sl_private_ip" $tfvars_file |  awk -F "=" '{print $2}' |  awk -F '"' '{print $2}'`
    local vsphere_vm_hostname=`grep -E  "^vsphere_vm_hostname" $tfvars_file |  awk -F "=" '{print $2}' |  awk -F '"' '{print $2}'`
    local vsphere_dns_domain=`grep -E  "^vsphere_dns_domain" $tfvars_file |  awk -F "=" '{print $2}' |  awk -F '"' '{print $2}'`
    if [ "$vm_type" == "kw" ] || [ "$vm_type" == "kwdd" ]; then
        grep -Eq  "^vm_kube_internal_ip" $tfvars_file
        if [ $? -eq 0 ]; then
            local vm_kube_internal_ip=`grep -E  "^vm_kube_internal_ip" $tfvars_file |  awk -F "=" '{print $2}' |  awk -F '"' '{print $2}'`
            echo "${vsphere_vm_hostname}.${vsphere_dns_domain}.                     IN     A      ${vm_kube_internal_ip}" >> ${terraform_mgmt_host_file}
            local vm_sl_hostname=`echo ${vsphere_vm_hostname}.${vsphere_dns_domain} | sed -e 's/ikw/kw/g'`
            echo "${vm_sl_hostname}.                     IN     A      ${vm_sl_private_ip}" >> ${terraform_mgmt_host_file}
        else
            echo "${vsphere_vm_hostname}.${vsphere_dns_domain}.                     IN     A      ${vm_sl_private_ip}" >> ${terraform_mgmt_host_file}
        fi
    elif [ "$vm_type" == "km" ]; then
            grep -Eq "^vm_kube_internal_ip" $tfvars_file
            if [ $? -eq 0 ]; then
                local vm_kube_internal_ip=`grep -E  "^vm_kube_internal_ip" $tfvars_file |  awk -F "=" '{print $2}' |  awk -F '"' '{print $2}'`
                echo "${vsphere_vm_hostname}.${vsphere_dns_domain}.                     IN     A      ${vm_kube_internal_ip}" >> ${terraform_mgmt_host_file}
                local vm_sl_hostname=`echo ${vsphere_vm_hostname}.${vsphere_dns_domain} | sed -e 's/ikm/km/g'`
                echo "${vm_sl_hostname}.                     IN     A      ${vm_sl_private_ip}" >> ${terraform_mgmt_host_file}
            else
                echo "${vsphere_vm_hostname}.${vsphere_dns_domain}.                     IN     A      ${vm_sl_private_ip}" >> ${terraform_mgmt_host_file}
            fi
    else
        echo "${vsphere_vm_hostname}.${vsphere_dns_domain}.                     IN     A      ${vm_sl_private_ip}" >> ${terraform_mgmt_host_file}
        if [ "$vm_type" == "mgmt" ]; then
            sed -i "s/{mgmt_hostname}/${vsphere_vm_hostname}.${vsphere_dns_domain}/g" ${terraform_mgmt_host_file}
        fi
        #workaround to point those hardcoded tb2 hostname for wca and db vms to their new hostnames
        if [ "$vm_type" == "nfs2" ]; then
            echo "fci-nfs2-tb2.wfss.ibm.com.                        IN     CNAME    ${vsphere_vm_hostname}.${vsphere_dns_domain}." >> ${terraform_mgmt_host_file}
        fi
        if [ "$vm_type" == "db" ]; then
            echo "fci-db-tb2.wfss.ibm.com.                        IN     CNAME    ${vsphere_vm_hostname}.${vsphere_dns_domain}." >> ${terraform_mgmt_host_file}
        fi
        if [ "$vm_type" == "wexc" ]; then
            echo "fci-wexc1-tb2.wfss.ibm.com.                        IN     CNAME    ${vsphere_vm_hostname}.${vsphere_dns_domain}." >> ${terraform_mgmt_host_file}
        fi
        if [ "$vm_type" == "wexfp" ]; then
            echo "fci-wexfp1-tb2.wfss.ibm.com.                        IN     CNAME    ${vsphere_vm_hostname}.${vsphere_dns_domain}." >> ${terraform_mgmt_host_file}
        fi
        if [ "$vm_type" == "wexm" ]; then
            echo "fci-wexm-tb2.wfss.ibm.com.                        IN     CNAME    ${vsphere_vm_hostname}.${vsphere_dns_domain}." >> ${terraform_mgmt_host_file}
        fi
    fi
}

#function for generating mgmt db reverse lookup host file based on terraform.tfvars file for each role
function generate_mgmt_reverse_host_file() {
    if [[ ! -d "${terraform_mgmt_files_dir}/db" ]]; then
        mkdir "${terraform_mgmt_files_dir}/db"
    fi
    # remove any previously generate db reverse lookup file
    local db_file_cnt=$(ls $terraform_mgmt_files_dir/db/db.* 2> /dev/null | wc -l)
    if [ $db_file_cnt -gt 0 ]; then
        for generated_db_file in `ls $terraform_mgmt_files_dir/db/db.*`; do
            rm ${generated_db_file}
        done
    fi

    db_template_file="${mgmt_reverse_hosts_file_template}"

    local product_initials=$(jq -r ".product_initials" $tf_json_config_file)
    local product_version=$(jq -r ".product_version" $tf_json_config_file)
    local customer_env_name=$(jq -r ".customer_env_name" $tf_json_config_file)
    local env_type=$(jq -r ".env_type" $tf_json_config_file)

    local env_name="${product_initials}-${product_version}-${customer_env_name}-${env_type}"

    for vm_it in $(jq '.vms_meta | keys | .[]' $tf_json_config_file); do
        local vm_type=$(jq -r ".vms_meta[$vm_it].vm_type" $tf_json_config_file)
        local vm_sl_private_ip=$(jq -r ".vms_meta[$vm_it].vm_sl_private_ip" $tf_json_config_file)
        local vsphere_vm_count=$(jq -r ".vms_meta[$vm_it].vsphere_vm_count" $tf_json_config_file)

        local baseaddr="$(echo $vm_sl_private_ip | cut -d. -f1-3)"
        local reverse_baseaddr=`echo ${baseaddr} | awk -F. '{print $3"." $2"."$1}'`
        
        local db_file="${terraform_mgmt_files_dir}/db/db.${baseaddr}"
        
        if [[ ! -f ${db_file} ]]; then
            cat "${db_template_file}" > ${db_file}
            sed -i "s/{mgmt_hostname}/${env_name}-mgmt.wfss.ibm.com/g" ${db_file}
        fi

        if [[ $vsphere_vm_count != null && $vsphere_vm_count -gt 1 ]]; then
            for ((i=1;i<=$vsphere_vm_count;i++)); do  
                local vm_function_name=$vm_type$i
                local private_ip=$( increment_ip "${vm_sl_private_ip}" "${i}" )
                local reverse_ip=`echo ${private_ip} | awk -F. '{print $4"."$3"." $2"."$1}'`

                local entry="${reverse_ip}.in-addr.arpa.      IN      PTR      ${env_name}-${vm_type}${i}.wfss.ibm.com."
                echo "${entry}" >> ${db_file}
            done
        else
            local reverse_ip=`echo ${vm_sl_private_ip} | awk -F. '{print $4"."$3"." $2"."$1}'`
            local entry="${reverse_ip}.in-addr.arpa.      IN      PTR      ${env_name}-${vm_type}.wfss.ibm.com."
            echo "${entry}" >> ${db_file}
        fi
    done
}

# generate haproxy config file
function generate_haproxy_cfg_file() {
    if [[ ! -f ${terraform_haproxy_cfg_file} ]]; then
        touch ${terraform_haproxy_cfg_file}
    fi

    cat "${haproxy_cfg_file_template}" > ${terraform_haproxy_cfg_file}
    
    for vm_it in $(jq '.vms_meta | keys | .[]' $tf_json_config_file); do
        local vm_type=$(jq -r ".vms_meta[$vm_it].vm_type" $tf_json_config_file)
        local vm_sl_private_ip=$(jq -r ".vms_meta[$vm_it].vm_sl_private_ip" $tf_json_config_file)
        local vsphere_vm_count=$(jq -r ".vms_meta[$vm_it].vsphere_vm_count" $tf_json_config_file)
        if [ "$vm_type" == "ms" ]; then
            for ((i=1;i<=$vsphere_vm_count;i++)); do 
                local private_ip=$( increment_ip "${vm_sl_private_ip}" "${i}" )
                local to_be_replaced="{master-${i}-private-ip}"
                grep -q "${to_be_replaced}" "${terraform_haproxy_cfg_file}"
                if [ $? -eq 0 ]; then
                    sed -i "s/${to_be_replaced}/${private_ip}/g" "${terraform_haproxy_cfg_file}"
                fi
            done
        fi
    done
}

# generate wdp.conf file used in WSL install
function generate_wdp_conf_file() {
    local wdp_conf_file="${terraform_ms1_files_dir}/wdp.conf"
    if [[ ! -f ${wdp_conf_file} ]]; then
        touch ${wdp_conf_file}
    fi

    echo "user=root" > ${wdp_conf_file}
    echo "ssh_port=22" >> ${wdp_conf_file}
    echo "suppress_warning=true" >> ${wdp_conf_file}
    
    for vm_it in $(jq '.vms_meta | keys | .[]' $tf_json_config_file); do
        local vm_type=$(jq -r ".vms_meta[$vm_it].vm_type" $tf_json_config_file)
        local vm_sl_private_ip=$(jq -r ".vms_meta[$vm_it].vm_sl_private_ip" $tf_json_config_file)
        local vsphere_vm_count=$(jq -r ".vms_meta[$vm_it].vsphere_vm_count" $tf_json_config_file)
        if [ "$vm_type" == "ms" ]; then
            for ((i=1;i<=$vsphere_vm_count;i++)); do 
                local private_ip=$( increment_ip "${vm_sl_private_ip}" "${i}" )
                echo "master_node_${i}=${private_ip}" >> ${wdp_conf_file}
                echo "master_node_path_${i}=/ibm" >> ${wdp_conf_file}
            done
        fi
        if [ "$vm_type" == "worker" ]; then
            for ((i=1;i<=$vsphere_vm_count;i++)); do 
                local private_ip=$( increment_ip "${vm_sl_private_ip}" "${i}" )
                echo "worker_node_${i}=${private_ip}" >> ${wdp_conf_file}
                echo "worker_node_path_${i}=/ibm" >> ${wdp_conf_file}
            done
        fi
        if [ "$vm_type" == "haproxy" ]; then
            echo "virtual_ip_address_1=${vm_sl_private_ip}" >> ${wdp_conf_file}
            echo "virtual_ip_address_2=${vm_sl_private_ip}" >> ${wdp_conf_file}
        fi
        if [ "$vm_type" == "nfs3" ]; then
            echo "nfs_server=${vm_sl_private_ip}" >> ${wdp_conf_file}
            echo "nfs_dir=/data" >> ${wdp_conf_file}
        fi
    done
}

# function to generate cpu/mem/disk_count meta info into each role's terraform.tfvars file
function generate_meta_terraform_tfvars() {
    local template_vm_name="\"$1\""
	local terraform_tfvars_file="$2"
	if [ ! -s "$vms_in_dc_file" ]; then
	    echo "$vms_in_dc_file empty or does not exist, will exit"
		exit 3
	else
	    cpu_value=`cat $vms_in_dc_file | jq --arg template_vm_name "$template_vm_name" ".[$template_vm_name]|.cpu"`
        mem_value=`cat $vms_in_dc_file | jq --arg template_vm_name "$template_vm_name" ".[$template_vm_name]|.mem"`
        disk_count=`cat $vms_in_dc_file | jq --arg template_vm_name "$template_vm_name" ".[$template_vm_name]|.diskcnt"`
		echo "vsphere_disks_count = $disk_count" >> $terraform_tfvars_file
		echo "vm_cpu = $cpu_value" >> $terraform_tfvars_file
		echo "vm_memory = $mem_value" >> $terraform_tfvars_file
	fi
}

## function for generating variables.tf file under the specific terraform work dir
function generate_variables_tf() {
	local terraform_tfvars_file="$1"
    local work_dir=`dirname $terraform_tfvars_file`
	touch $work_dir/variables.tf
	echo "" > $work_dir/variables.tf
	cp $variables_tf_shared_template $work_dir/variables.tf
	#step 1. add kube internal network variables if needed
	grep -Eq "^vm_kube_internal_ip" $terraform_tfvars_file
	if [ $? -eq 0 ]; then
		sed -i -e "/$kube_internal_nw_vars_keywords_in_variables_tf_template/{r $variables_tf_internal_network_template" -e 'd}' $work_dir/variables.tf
	fi
	#step 2. add compute cluster, or host or host folders variable definition based on the definition in tfvar
	#There are 3 scenarios: 
	# (1) clone a vm to a specific host in a compute cluster: "vsphere_compute_cluster" and "vsphere_host" defined in terraform.tfvars
	# (2) clone a vm to any host in a compute cluster: only "vsphere_compute_cluster" defined in terraform.tfvars
	# (3) clone a vm to a single host: 'vsphere_host' and 'vsphere_host_folder' defined in terraform.tfvars
	
	grep -Eq "^vsphere_compute_cluster" $terraform_tfvars_file
	if [ $? -eq 0 ]; then
	    grep -Eq "^vsphere_host" $terraform_tfvars_file
		if [ $? -eq 0 ]; then
		    sed -i -e "/$compute_cluster_vm_host_vars_keywords_in_variables_tf_template/{r $variables_tf_compute_cluster_vm_host_template" -e 'd}' $work_dir/variables.tf
	    else
		    sed -i -e "/$compute_cluster_vm_host_vars_keywords_in_variables_tf_template/{r $variables_tf_compute_cluster_template" -e 'd}' $work_dir/variables.tf
		fi
	else
	    local host_exist_flag=$(grep -Eq "^vsphere_host =" $terraform_tfvars_file)
		local host_folder_exist_flag=$(grep -Eq "^vsphere_host_folder =" $terraform_tfvars_file)
	    if [[ $host_exist_flag -eq 0 && $host_folder_exist_flag -eq 0 ]]; then
	        sed -i -e "/$compute_cluster_vm_host_vars_keywords_in_variables_tf_template/{r $variables_tf_single_host_template" -e 'd}' $work_dir/variables.tf
		else
		    echo "Illegal compute cluster host definition in $terraform_tfvars_file. It should be either combination of 'vsphere_host' and 'vsphere_compute_cluster', or combination of 'vsphere_host' and 'vsphere_host_folder', or 'vsphere_compute_cluster'"
			exit 3
		fi
	fi
	#step 3. add vm_ssh_user_password part if needed
	# grep -Eq "^vmuser" $terraform_tfvars_file
	# if [ $? -eq 0 ]; then
	#     sed -i 's/#variable "vmuser"/variable "vmuser"/g' $work_dir/variables.tf
	# 	grep -Eq "^vmpassword" $terraform_tfvars_file
	# 	if [ $? -eq 0 ]; then
	# 	    sed -i 's/#variable "vmpassword"/variable "vmpassword"/g' $work_dir/variables.tf
	# 	else
	# 	    echo "vmpassword does not exist in $terraform_tfvars_file. Exiting..."
	# 		exit 3 
	# 	fi
	# fi
}

## function for generating build.tf file under the specific terraform work dir
function generate_build_tf() {
	local terraform_tfvars_file="$1"
    local work_dir=`dirname $terraform_tfvars_file`
	local vm_type="$2"
    local vm_it=0
	touch $work_dir/build.tf
	echo "" > $work_dir/build.tf
	cp $tf_build_tf_template $work_dir/build.tf
	#step 1. fill the disks definition defined in build.tf template file
	#step 1.1 get the disk count from terraform.tfvars file
	grep -Eq "^vsphere_disks_count" $terraform_tfvars_file
	if [ $? -ne 0 ]; then
		echo "variable vsphere_disks_count does NOT exist in $terraform_tfvars_file, will exit..."
		exit 2
	fi
	disks_count=`grep "vsphere_disks_count" $terraform_tfvars_file | grep -Eo '[0-9]{1,4}'`
	if [ ! -z "$disks_count" ] && [ $disks_count -ge 1 ]; then
		disk_definition_content_tmp_file=$work_dir/disk_definition_content_tmp
		touch $disk_definition_content_tmp_file
		echo "" > $disk_definition_content_tmp_file
		#step 1.2 generate disk content based on disks count and disks definition template
		for (( l=0; l<$disks_count; l++ ))
		do
			cat "$build_tf_disk_template" >> $disk_definition_content_tmp_file
			sed -i "s/{i}/$l/g" $disk_definition_content_tmp_file
		done
		#step 1.3 fill in build.tf template with disks definition content
		sed -i -e "/$disk_definition_keywords_in_build_tf_template/{r $disk_definition_content_tmp_file" -e 'd}' $work_dir/build.tf
		#steep 1.4 cleanup
		rm -f $disk_definition_content_tmp_file
	else
		echo "disks_count definition in $terraform_tfvars_file has issues"
		exit 2
	fi

	# step 2. fill compute_cluster_host_folder related definition defined in build.tf template file
	#There are 3 scenarios: 
	# (1) clone a vm to a specific host in a compute cluster: "vsphere_compute_cluster" and "vsphere_host" defined in terraform.tfvars
	# (2) clone a vm to any host in a compute cluster: only "vsphere_compute_cluster" defined in terraform.tfvars
	# (3) clone a vm to a single host: 'vsphere_host' and 'vsphere_host_folder' defined in terraform.tfvars
	grep -Eq "^vsphere_compute_cluster" $terraform_tfvars_file
	if [ $? -eq 0 ]; then
	    grep -Eq "^vsphere_host" $terraform_tfvars_file
		if [ $? -eq 0 ]; then
		    #scenario (1). clone a vm to a specific host in a compute cluster:  computer cluster data definition, resource_pool_id definition, host data definition and cluster_vm_host_rule resource definition needed
		    sed -i -e "/$vsphere_compute_cluster_data_keywords_in_build_tf_template/{r $build_tf_compute_cluster_data_template" -e 'd}' $work_dir/build.tf
			sed -i -e "/$vsphere_host_data_keywords_in_build_tf_template/{r $build_tf_host_data_definition_template" -e 'd}' $work_dir/build.tf
			sed -i -e "/$resource_pool_id_keywords_in_build_tf_template/{r $build_tf_compute_cluster_resource_pool_id_template" -e 'd}' $work_dir/build.tf
            #sed -i -e "/$compute_cluster_vm_host_rule_resource_keywords_in_build_tf_template/{r $build_tf_compute_cluster_vm_host_rules_resource_template" -e 'd}' $work_dir/build.tf
	        sed -i -e "/$host_system_id_keywords_in_build_tf_template/{r $build_tf_compute_cluster_host_system_id_template" -e 'd}' $work_dir/build.tf
		else
		    #scenario (2). clone a vm to any host in a compute cluster: only computer cluster data definition and resource_pool_id definition needed
		    sed -i -e "/$vsphere_compute_cluster_data_keywords_in_build_tf_template/{r $build_tf_compute_cluster_data_template" -e 'd}' $work_dir/build.tf
			sed -i -e "/$resource_pool_id_keywords_in_build_tf_template/{r $build_tf_compute_cluster_resource_pool_id_template" -e 'd}' $work_dir/build.tf
		fi
	else
	    local host_exist_flag=$(grep -Eq "^vsphere_host" $terraform_tfvars_file)
		local host_folder_exist_flag=$(grep -Eq "^vsphere_host_folder" $terraform_tfvars_file)
		#scenario (3). clone a vm to a single host:only resource pool data definition and resource_pool_id definition needed
	    if [[ $host_exist_flag -eq 0 && $host_folder_exist_flag -eq 0 ]]; then
		    sed -i -e "/$vsphere_resource_pool_data_keywords_in_build_tf_template/{r $build_tf_resource_pool_data_template" -e 'd}' $work_dir/build.tf
	        sed -i -e "/$resource_pool_id_keywords_in_build_tf_template/{r $build_tf_single_host_resource_pool_id_template" -e 'd}' $work_dir/build.tf
		else
		    echo "Illegal compute cluster host definition in $terraform_tfvars_file. It should be either combination of 'vsphere_host' and 'vsphere_compute_cluster', or combination of 'vsphere_host' and 'vsphere_host_folder', or 'vsphere_compute_cluster'"
			exit 3
		fi
	fi

	# step 3. fill internal network customization/definition defined in build.tf template file
	grep -Eq "^vm_kube_internal_ip" $terraform_tfvars_file
	if [ $? -eq 0 ]; then
		sed -i -e "/$kube_internal_nw_definition_keywords_in_build_tf_template/{r $build_tf_internal_network_definition_template" -e 'd}' $work_dir/build.tf
		sed -i -e "/$kube_internal_nw_customization_keywords_in_build_tf_template/{r $build_tf_internal_network_customization_template" -e 'd}' $work_dir/build.tf
		sed -i -e "/$kube_internal_nw_data_keywords_in_build_tf_template/{r $build_tf_internal_network_data_template" -e 'd}' $work_dir/build.tf
	fi

	# step 4 fill connection definition defined in build.tf template file. 
    #for mgmt vm, will generate wfss.ibm.com.hosts.template file in connection part
    sed -i -e "/$connection_keywords_in_build_tf_template/{r $build_tf_connection_template" -e 'd}' $work_dir/build.tf
	sed -i -e "/$customization_provisioner_keywords_in_build_tf_connection_template/{r $build_tf_connection_customization_provisioner_template" -e 'd}' $work_dir/build.tf
    if [ "$vm_type" == "mgmt" ]; then
        sed -i -e "/$host_file_provisioner_keywords_in_build_tf_connection_template/{r $build_tf_connection_hosts_file_provisioner_template" -e 'd}' $work_dir/build.tf
    fi
    if [ "$vm_type" == "km" ]; then
        sed -i -e "/$km_hosts_properties_file_provisioner_keywords_in_build_tf_connection_template/{r $build_tf_connection_km_hosts_prop_file_provisioner_template" -e 'd}' $work_dir/build.tf
    fi
    if [ "$vm_type" == "hdpa" ]; then
        sed -i -e "/$hdpa_hosts_properties_file_provisioner_keywords_in_build_tf_connection_template/{r $build_tf_connection_hdpa_hosts_prop_file_provisioner_template" -e 'd}' $work_dir/build.tf
    fi


    if [ "$vm_type" == "mgmt" ]; then
        local vsphere_vcenter=$(jq -r ".vsphere_vcenter" $tf_json_config_file)
        local vsphere_user=$(jq -r ".vsphere_user" $tf_json_config_file)
        local vsphere_password=$(jq -r ".vsphere_password" $tf_json_config_file)
        local product_initials=$(jq -r ".product_initials" $tf_json_config_file)
        local product_version=$(jq -r ".product_version" $tf_json_config_file)
        local customer_env_name=$(jq -r ".customer_env_name" $tf_json_config_file)
        local env_type=$(jq -r ".env_type" $tf_json_config_file)
        local vm_tag_name="${product_initials}-${product_version}-${customer_env_name}-${env_type}-${vm_type}"
        local tag_exist=`python -c "import terraform_validator; terraform_validator.check_if_tag_exists(\"${vsphere_vcenter}\", \"${vsphere_user}\", \"${vsphere_password}\", \"${vm_tag_name}\")"`
        if [ "${tag_exist}" == "True" ]; then
            local tag_section="tags = \[\"\${data\.vsphere_tag\.hostname_tag\.id}\", \"\${data\.vsphere_tag\.allhosts_tag\.id}\"\]"
            sed -i "s/${vm_tags_list_section_in_build_tf_template}/${tag_section}/g" $work_dir/build.tf
            
            sed -i -e "/$tag_vm_resource_data_section_in_build_tf_template/{r $build_tf_tag_data_template" -e 'd}' $work_dir/build.tf
        else
            local tag_section="tags = \[\"\${vsphere_tag\.hostname_tag\.id}\", \"\${data\.vsphere_tag\.allhosts_tag\.id}\"\]"
            sed -i "s/${vm_tags_list_section_in_build_tf_template}/${tag_section}/g" $work_dir/build.tf
            
            sed -i -e "/$tag_vm_resource_data_section_in_build_tf_template/{r $build_tf_tag_resource_template" -e 'd}' $work_dir/build.tf
        fi
    else
        local tag_section="tags = \[\"\${data\.vsphere_tag\.allhosts_tag\.id}\"\]"
        sed -i "s/${vm_tags_list_section_in_build_tf_template}/${tag_section}/g" $work_dir/build.tf
    fi
}

# function to generate vms_in_dc.json
function generate_vms_in_dc_json() {
	local vcenter_host_ip=$(jq -r ".vsphere_vcenter" $tf_json_config_file)
    local source_datacenter_name=$(jq -r ".vsphere_source_datacenter" $tf_json_config_file)
    local vsphere_user=$(jq -r ".vsphere_user" $tf_json_config_file)
    local vsphere_password=$(jq -r ".vsphere_password" $tf_json_config_file)
    #Get the metadata by leveraging pyvmomi, to get info like cpu, mem, disk_count, etc. The info will be put into file "vms_in_dc.json"
    python getvmsbydc.py -s "$vcenter_host_ip" -d "$source_datacenter_name" -u "$vsphere_user" -p "$vsphere_password" --json --silent
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

function cross_vlan_terraform_update() {
    local vm_type=$1
    chmod +x utilities/cross_vlan_update.sh
    utilities/cross_vlan_update.sh ${terraform_factory_dir} ${vm_type}
}

#function to genertate terraform artifacts/configuration files for a single virtual machine
function generate_terraform_work_dir_single() {
     #parameter definition
    local vms_meta_iterator_index="$1"
    local terraform_vm_config_folder="$2"
    local vsphere_target_vm_name="$3"
    #shared variables
    local vsphere_dns_domain=$(jq -r ".vsphere_dns_domain" $tf_json_config_file)
    local vmuser=$(jq -r ".vmuser" $tf_json_config_file)  
    #distinct variables
    local vm_type=$(jq -r ".vms_meta[$vms_meta_iterator_index].vm_type" $tf_json_config_file)
    local vsphere_vm_template=$(jq -r ".vms_meta[$vms_meta_iterator_index].vsphere_vm_template" $tf_json_config_file)
    local vsphere_target_datastore=$(jq -r ".vms_meta[$vms_meta_iterator_index].vsphere_target_datastore" $tf_json_config_file)
    local vsphere_target_vm_folder=$(jq -r ".vms_meta[$vms_meta_iterator_index].vsphere_target_vm_folder" $tf_json_config_file)
    local vmpassword=$(jq -r ".vms_meta[$vms_meta_iterator_index].vmpassword" $tf_json_config_file)
    local vsphere_source_vm_folder=$(jq -r ".vms_meta[$vms_meta_iterator_index].vsphere_source_vm_folder" $tf_json_config_file)
    local vsphere_sl_private_network_name=$(jq -r ".vms_meta[$vms_meta_iterator_index].vsphere_sl_private_network_name" $tf_json_config_file)
    local vm_sl_private_netmask=$(jq -r ".vms_meta[$vms_meta_iterator_index].vm_sl_private_netmask" $tf_json_config_file)
    local vm_network_gateway=$(jq -r ".vms_meta[$vms_meta_iterator_index].vm_network_gateway" $tf_json_config_file)
    local vsphere_compute_cluster=$(jq -r ".vms_meta[$vms_meta_iterator_index].vsphere_compute_cluster" $tf_json_config_file)
    local vsphere_host=$(jq -r ".vms_meta[$vms_meta_iterator_index].vsphere_host" $tf_json_config_file)
    local vsphere_host_folder=$(jq -r ".vms_meta[$vms_meta_iterator_index].vsphere_host_folder" $tf_json_config_file)
    #step 0: generate terraform work directory, and copy terraform vsphere plugin to the work directory
    if [ ! -d "$terraform_vm_config_folder" ]; then
        mkdir -p "$terraform_vm_config_folder"
        cp -r "$terraform_plugin_dir" "$terraform_vm_config_folder"
    else
        cp -r "$terraform_plugin_dir" "$terraform_vm_config_folder"
	fi
    #step 1: for generating terraform.tfvars: write shared tfvars to terraform.tfvars file
    local terraform_tfvars_file="$terraform_vm_config_folder/${terraform_tf_vars_name}"
    touch "$terraform_tfvars_file"
    cat "${terraform_shared_tfvars}" > "$terraform_tfvars_file"
    #step 2 for generating terraform.tfvars: generate distinct tfvars and write to terraform.tfvars file
    #step 2.1 generate vm_template, target_vm_name, vm_hostname, vmuser, vmpassword, vm_count
    echo "vsphere_vm_template = \"$vsphere_vm_template\"" >> "$terraform_tfvars_file"
    #need vm ssh user/password to login and remotely customize vm
    echo "vmuser = \"$vmuser\"" >> "$terraform_tfvars_file"
    echo "vmpassword = \"$vmpassword\"" >> "$terraform_tfvars_file"
    local vsphere_vm_hostname="$vsphere_target_vm_name"
    echo "vsphere_target_vm_name = \"$vsphere_target_vm_name\"" >> "$terraform_tfvars_file"
    if [ ! -d "$terraform_vm_config_folder/files" ]; then
        mkdir -p $terraform_vm_config_folder/files
    fi
    #step 2.2 generate vm customization script
    echo "vsphere_vm_hostname = \"$vsphere_vm_hostname\"" >> "$terraform_tfvars_file"
    # generate_vm_customization_script "${vsphere_vm_hostname}.${vsphere_dns_domain}" "$vsphere_target_vm_name" "$terraform_vm_config_folder/files/${terraform_customization_script_name}"
    
    # add allhosts tag name to terraform variables
    local allhosts_vm_tag_name=$(echo "$vsphere_vm_hostname" | cut -d- -f1-4 | sed 's/$/-allhosts/')
    echo "allhosts_vm_tag_name = \"$allhosts_vm_tag_name\"" >> "$terraform_tfvars_file"

    generate_vm_customization_script "${vsphere_vm_hostname}.${vsphere_dns_domain}" "$vsphere_target_vm_name" "$terraform_vm_config_folder/files"
    echo "vsphere_vm_count = \"1\"" >> "$terraform_tfvars_file"

    #step 2.4 generate vsphere_target_datastore, vsphere_source_vm_folder, vsphere_target_vm_folder, vsphere_sl_private_network_name, vm_sl_private_netmask, vm_network_gateway if they exist in the distinct configuration section
    if [ ! -z "${vsphere_target_datastore// }" ] && [ "$vsphere_target_datastore" != "null" ]; then
        grep -q "^vsphere_target_datastore = " ${terraform_tfvars_file}
        if [ $? -eq 0 ]; then
            sed -i "/^vsphere_target_datastore =/c vsphere_target_datastore = \"${vsphere_target_datastore}\"" ${terraform_tfvars_file}
        else
            echo "vsphere_target_datastore = \"$vsphere_target_datastore\"" >> ${terraform_tfvars_file}
        fi
    fi
    if [ ! -z "${vsphere_source_vm_folder// }" ] && [ "$vsphere_source_vm_folder" != "null" ]; then
        grep -q "^vsphere_source_vm_folder = " ${terraform_tfvars_file}
        if [ $? -eq 0 ]; then
            sed -i "/^vsphere_source_vm_folder =/c vsphere_source_vm_folder = \"${vsphere_source_vm_folder}\"" ${terraform_tfvars_file}
        else
            echo "vsphere_source_vm_folder = \"$vsphere_source_vm_folder\"" >> ${terraform_tfvars_file}
        fi
    fi

    if [ ! -z "${vsphere_target_vm_folder// }" ] && [ "$vsphere_target_vm_folder" != "null" ]; then
        grep -q "^vsphere_target_vm_folder = " ${terraform_tfvars_file}
        if [ $? -eq 0 ]; then
            sed -i "/^vsphere_target_vm_folder =/c vsphere_target_vm_folder = \"${vsphere_target_vm_folder}\"" ${terraform_tfvars_file}
        else
            echo "vsphere_target_vm_folder = \"$vsphere_target_vm_folder\"" >> ${terraform_tfvars_file}
        fi
    fi

    if [ ! -z "${vsphere_sl_private_network_name// }" ] && [ "$vsphere_sl_private_network_name" != "null" ]; then
        grep -q "^vsphere_sl_private_network_name = " ${terraform_tfvars_file}
        if [ $? -eq 0 ]; then
            sed -i "/^vsphere_sl_private_network_name =/c vsphere_sl_private_network_name = \"${vsphere_sl_private_network_name}\"" ${terraform_tfvars_file}
        else
            echo "vsphere_sl_private_network_name = \"$vsphere_sl_private_network_name\"" >> ${terraform_tfvars_file}
        fi
    fi
    if [ ! -z "${vm_sl_private_netmask// }" ] && [ "$vm_sl_private_netmask" != "null" ]; then
        grep -q "^vm_sl_private_netmask = " ${terraform_tfvars_file}
        if [ $? -eq 0 ]; then
            sed -i "/^vm_sl_private_netmask =/c vm_sl_private_netmask = \"${vm_sl_private_netmask}\"" ${terraform_tfvars_file}
        else
            echo "vm_sl_private_netmask = \"$vm_sl_private_netmask\"" >> ${terraform_tfvars_file}
        fi
    fi
    if [ ! -z "${vm_network_gateway// }" ] && [ "$vm_network_gateway" != "null" ]; then
        grep -q "^vm_network_gateway = " ${terraform_tfvars_file}
        if [ $? -eq 0 ]; then
            sed -i "/^vm_network_gateway =/c vm_network_gateway = \"${vm_network_gateway}\"" ${terraform_tfvars_file}
        else
            echo "vm_network_gateway = \"$vm_network_gateway\"" >> ${terraform_tfvars_file}
        fi
    fi
    if [ ! -z "${vsphere_compute_cluster// }" ] && [ "$vsphere_compute_cluster" != "null" ]; then
        grep -q "^vsphere_compute_cluster = " ${terraform_tfvars_file}
        if [ $? -eq 0 ]; then
            sed -i "/^vsphere_compute_cluster =/c vsphere_compute_cluster = \"${vsphere_compute_cluster}\"" ${terraform_tfvars_file}
        else
            echo "vsphere_compute_cluster = \"$vsphere_compute_cluster\"" >> ${terraform_tfvars_file}
        fi
    fi
    if [ ! -z "${vsphere_host// }" ] && [ "$vsphere_host" != "null" ]; then
        grep -q "^vsphere_host = " ${terraform_tfvars_file}
        if [ $? -eq 0 ]; then
            sed -i "/^vsphere_host =/c vsphere_host = \"${vsphere_host}\"" ${terraform_tfvars_file}
        else
            echo "vsphere_host = \"$vsphere_host\"" >> ${terraform_tfvars_file}
        fi
    fi
    if [ ! -z "${vsphere_host_folder// }" ] && [ "$vsphere_host_folder" != "null" ]; then
        grep -q "^vsphere_host_folder = " ${terraform_tfvars_file}
        if [ $? -eq 0 ]; then
            sed -i "/^vsphere_host_folder =/c vsphere_host_folder = \"${vsphere_host_folder}\"" ${terraform_tfvars_file}
        else
            echo "vsphere_host_folder = \"$vsphere_host_folder\"" >> ${terraform_tfvars_file}
        fi
        # if vsphere_host_folder, need make sure "vsphere_compute_cluster" is not there
        grep -q "^vsphere_compute_cluster = " ${terraform_tfvars_file}
        if [ $? -eq 0 ]; then
            sed -i '/^vsphere_compute_cluster =/d' ${terraform_tfvars_file}
        fi
    fi

    #step 2.5 generate cpu, mem, disk count from pyvmomi script to terraform.tfvars file
    local vsphere_vm_template_real_name=`grep -E  "^vsphere_vm_template" $terraform_tfvars_file |  awk -F "=" '{print $2}' |  awk -F '"' '{print $2}'`
    generate_meta_terraform_tfvars "$vsphere_vm_template_real_name" "$terraform_tfvars_file"

    #step 3. generate variables.tf
    generate_variables_tf "$terraform_tfvars_file"
    #step 4. generate build.tf
    generate_build_tf "$terraform_tfvars_file" "$vm_type"
}

#function to generate files/dirs under terraform work directory
function generate_tf_work_dir() {
    #get the first kubernetes internal ip
    local vm_it=0
    local vcenter_host_ip=$(jq -r ".vsphere_vcenter" $tf_json_config_file)
    local source_datacenter_name=$(jq -r ".vsphere_source_datacenter" $tf_json_config_file)
    local vsphere_user=$(jq -r ".vsphere_user" $tf_json_config_file)
    local vsphere_password=$(jq -r ".vsphere_password" $tf_json_config_file)
    local product_initials=$(jq -r ".product_initials" $tf_json_config_file)
    local product_version=$(jq -r ".product_version" $tf_json_config_file)
    local customer_env_name=$(jq -r ".customer_env_name" $tf_json_config_file)
    local env_type=$(jq -r ".env_type" $tf_json_config_file)
    local first_kube_internal_ip=$(jq -r ".vm_kube_internal_ip" $tf_json_config_file)
    local vm_kube_internal_ip="$first_kube_internal_ip"
    #Get the metadata by leveraging pyvmomi, to get info like cpu, mem, disk_count, etc. The info will be put into file "vms_in_dc.json"
    python getvmsbydc.py -s "$vcenter_host_ip" -d "$source_datacenter_name" -u "$vsphere_user" -p "$vsphere_password" --json --silent
    #if mgmt server is defined in terraform.tfvars.json, clean up mgmt host file first, and use the template mgmt file to replace it
    grep -q "\"vm_type\": \"mgmt\"" $tf_json_config_file
    local mgmt_exist_flag=$?
    if [ $mgmt_exist_flag -eq 0 ]; then
        if [ ! -d "${terraform_mgmt_files_dir}" ]; then
            mkdir -p ${terraform_mgmt_files_dir}
        fi
        echo "" > ${terraform_mgmt_host_file}
        cp $mgmt_hosts_file_template ${terraform_mgmt_host_file}
    fi
    grep -q "\"vm_type\": \"km\"" $tf_json_config_file
    local km_exist_flag=$?
    if [ $km_exist_flag -eq 0 ]; then
        if [ ! -d "${terraform_km_files_dir}" ]; then
            mkdir -p ${terraform_km_files_dir}
        fi
        echo "" > ${terraform_km_hosts_file}
    fi
    #loop through the vms_meta array to generate terraform configuration files for each vm
    for vm_it in $(jq '.vms_meta | keys | .[]' $tf_json_config_file); do
        local vm_count=$(jq -r ".vms_meta[$vm_it].vsphere_vm_count" $tf_json_config_file)
        if [ -z "${vm_count// }" ] || [ "$vm_count" == "null" ]; then
            vm_count=1
        fi
        local vm_sl_private_ip=$(jq -r ".vms_meta[$vm_it].vm_sl_private_ip" $tf_json_config_file)
        local vm_type=$(jq -r ".vms_meta[$vm_it].vm_type" $tf_json_config_file)
        #if the vm's count is bigger than 1
        if [ $vm_count -gt 1 ]; then
            for (( counter=1; counter<=$vm_count; counter++ ))
            do
                # step 0: initialize terraform "files" folder to store terraform artifacts
                local terraform_vm_config_folder="$terraform_factory_dir/${vm_type}${counter}"
                local terraform_tfvars_file="$terraform_vm_config_folder/${terraform_tf_vars_name}"
                local vsphere_target_vm_name="${product_initials}-${product_version}-${customer_env_name}-${env_type}-${vm_type}${counter}"
                if [ ! -d "$terraform_vm_config_folder/files" ]; then
                    mkdir -p $terraform_vm_config_folder/files
                fi
                # step 1: call terraform configuration generator for specific vm
                generate_terraform_work_dir_single "$vm_it" "$terraform_vm_config_folder" "$vsphere_target_vm_name"
                #generate vm customization script
                sed -i "s/{i}/$counter/g" "$terraform_tfvars_file"
                #step 2: generate softlayer ip
                local vm_sl_private_ip_prefix="`echo ${vm_sl_private_ip} | awk -F "." '{print $1}'`.`echo ${vm_sl_private_ip} | awk -F "." '{print $2}'`.`echo ${vm_sl_private_ip} | awk -F "." '{print $3}'`."
                local vm_sl_private_ip_start_number=`echo ${vm_sl_private_ip} | awk -F "." '{print $4}'`
                local vm_sl_private_ip_postfix=""
                ((vm_sl_private_ip_postfix=vm_sl_private_ip_start_number+counter-1))
                echo "vm_sl_private_ip = \"${vm_sl_private_ip_prefix}${vm_sl_private_ip_postfix}\"" >> "$terraform_tfvars_file"
                #step 3: kube internal network setup: has already been deprecated, and the following code may be disabled soon
                if [ "$vm_type" == "kw" ] || [ "$vm_type" == "kwdd" ]; then
                    if [ ! -z "${vm_kube_internal_ip// }" ] && [ ! "$vm_kube_internal_ip" == "null" ]; then
                        local vm_kube_internal_netmask=$(jq -r ".vm_kube_internal_netmask" $tf_json_config_file)
                        local vsphere_kube_internal_network_name=$(jq -r ".vsphere_kube_internal_network_name" $tf_json_config_file)
                        echo "vm_kube_internal_ip = \"${vm_kube_internal_ip}\"" >> "$terraform_tfvars_file"
                        echo "vm_kube_internal_netmask = \"${vm_kube_internal_netmask}\"" >> "$terraform_tfvars_file"
                        echo "vsphere_kube_internal_network_name = \"${vsphere_kube_internal_network_name}\"" >> "$terraform_tfvars_file"
                        vm_kube_internal_ip=$(add_ip_by_one "${vm_kube_internal_ip}")
                    fi
                fi
                #step 4: generate mgmt host file
                grep -q "\"vm_type\": \"mgmt\"" $tf_json_config_file
                local mgmt_exist_flag=$?
                if [ $mgmt_exist_flag -eq 0 ]; then
                    generate_mgmt_host_file "$terraform_tfvars_file" "$vm_type"
                fi
                #step 5: generate km host properties file
                grep -q "\"vm_type\": \"km\"" $tf_json_config_file
                local km_exist_flag=$?
                if [ $km_exist_flag -eq 0 ]; then
                    generate_install_hosts_properties "$terraform_tfvars_file"
                fi
            done
        #for vms type only has 1 vm
        elif [ $vm_count -eq 1 ]; then
            #step 0: initialize terraform "files" folder to store terraform artifacts
            local terraform_vm_config_folder="$terraform_factory_dir/${vm_type}" 
            local terraform_tfvars_file="$terraform_vm_config_folder/${terraform_tf_vars_name}"
            local vsphere_target_vm_name="${product_initials}-${product_version}-${customer_env_name}-${env_type}-${vm_type}"
            if [ ! -d "$terraform_vm_config_folder/files" ]; then
                mkdir -p $terraform_vm_config_folder/files
            fi
            #step 1: call terraform configuration generator for specific vm
            generate_terraform_work_dir_single "$vm_it" "$terraform_vm_config_folder" "$vsphere_target_vm_name"
            #step 2: generate softlayer ip
            echo "vm_sl_private_ip = \"${vm_sl_private_ip}\"" >> "$terraform_tfvars_file"
            #step 3: kube internal network setup: has already been deprecated, and the following code may be disabled soon
            if [ "$vm_type" == "km" ]; then
                vm_kube_internal_ip="$first_kube_internal_ip"
                if [ ! -z "${vm_kube_internal_ip// }" ] && [ ! "$vm_kube_internal_ip" == "null" ]; then
                     local vm_kube_internal_netmask=$(jq -r ".vm_kube_internal_netmask" $tf_json_config_file)
                     local vsphere_kube_internal_network_name=$(jq -r ".vsphere_kube_internal_network_name" $tf_json_config_file)
                     echo "vm_kube_internal_ip = \"${vm_kube_internal_ip}\"" >> "$terraform_tfvars_file"
                     echo "vm_kube_internal_netmask = \"${vm_kube_internal_netmask}\"" >> "$terraform_tfvars_file"
                     echo "vsphere_kube_internal_network_name = \"${vsphere_kube_internal_network_name}\"" >> "$terraform_tfvars_file"
                     #vm_kube_internal_ip will be added by 1, for later use by kw and kwdd
                     vm_kube_internal_ip=$(add_ip_by_one "${vm_kube_internal_ip}")
                 fi
            fi
            grep -q "\"vm_type\": \"mgmt\"" $tf_json_config_file
            local mgmt_exist_flag=$?
            if [ $mgmt_exist_flag -eq 0 ]; then
                generate_mgmt_host_file "$terraform_tfvars_file" "$vm_type"
            fi
            grep -q "\"vm_type\": \"km\"" $tf_json_config_file
            local km_exist_flag=$?
            if [ $km_exist_flag -eq 0 ]; then
                generate_install_hosts_properties "$terraform_tfvars_file"
            fi
        else
            echo  "for $vm_type, vm count 'vsphere_vm_count' is less than 1, so it will be skipped"
        fi
    done
}

function terraform_apply_serial() {
    local vm_type="$1"
    if [ $terraform_deploy -eq 1 ]; then
        echo "Starting to launch ${vm_type} VM(s) via terraform"
        if [ -d "$terraform_factory_dir/${vm_type}" ]; then
            cd $terraform_factory_dir/${vm_type}
            if [ -f terraform.tfstate ]; then
                mv terraform.tfstate terraform.tfstate.backup
            fi
            $terraform init
	        $terraform plan -out="create_vm"
	        $terraform apply -auto-approve
        fi
    fi
}

function terraform_apply() {
    local vm_type="$1"
    if [ $terraform_deploy -eq 1 ]; then
        echo "Starting to launch ${vm_type} VM(s) via terraform"
        if [ -d "$terraform_factory_dir/${vm_type}" ]; then
            cd $terraform_factory_dir/${vm_type}
            if [ -f terraform.tfstate ]; then
                mv terraform.tfstate terraform.tfstate.backup
            fi
            $terraform init
	        $terraform plan -out="create_vm"
	        nohup $terraform apply -auto-approve &
        fi
    fi
}

#function to provision vms by leveraging terraform
function terraform_provision() {
    local kw_vm_count=0
    local kwdd_vm_count=0
    local ms_vm_count=0
    local stream_vm_count=0
    local worker_vm_ccount=0
    local api_vm_count=0
    local storage_vm_count=0
    local j=0
    local k=0
    local vm_it=0
    for  vm_it in $(jq '.vms_meta | keys | .[]' $tf_json_config_file); do
        local vm_type=$(jq -r ".vms_meta[$vm_it].vm_type" $tf_json_config_file)
        if [ "$vm_type" == "kw" ]; then
            kw_vm_count=$(jq -r ".vms_meta[$vm_it].vsphere_vm_count" $tf_json_config_file)
        fi
        if [ "$vm_type" == "kwdd" ]; then
            kwdd_vm_count=$(jq -r ".vms_meta[$vm_it].vsphere_vm_count" $tf_json_config_file)
        fi
        if [ "$vm_type" == "ms" ]; then
            ms_vm_count=$(jq -r ".vms_meta[$vm_it].vsphere_vm_count" $tf_json_config_file)
        fi
        if [ "$vm_type" == "str" ]; then
            stream_vm_count=$(jq -r ".vms_meta[$vm_it].vsphere_vm_count" $tf_json_config_file)
        fi
        if [ "$vm_type" == "st" ]; then
            storage_vm_count=$(jq -r ".vms_meta[$vm_it].vsphere_vm_count" $tf_json_config_file)
        fi
        if [ "$vm_type" == "api" ]; then
            api_vm_count=$(jq -r ".vms_meta[$vm_it].vsphere_vm_count" $tf_json_config_file)
        fi
        if [ "$vm_type" == "worker" ]; then
            worker_vm_count=$(jq -r ".vms_meta[$vm_it].vsphere_vm_count" $tf_json_config_file)
        fi

    done

    # check if tag folder exists
    if [ -d "${terraform_vm_tag_folder}" ]; then
        terraform_apply_serial "tag"
        if [ $? -ne 0 ]; then
             echo "launching and configuring tag encountered some problems. Need to resolve this before moving forward"
             exit 4
        fi
    fi
    
    #need to provision  VMs in order. For DD, mgmt server need to be started up first, then db2, then nfs1 and nfs2, then the rest of servers can be up in parallel
    # terraform launching management service vm
    if [ $is_mgmt -eq 1 ]; then
         terraform_apply_serial "mgmt"
         if [ $? -ne 0 ]; then
             echo "launching and configuring mgmt server encountered some problems. Need to resolve this before moving forward"
             exit 4
         fi
    fi

    # terraform launching nfs1 vm
    if [ $is_nfs1 -eq 1 ]; then
        terraform_apply_serial "nfs1"
        if [ $? -ne 0 ]; then
             echo "launching and configuring nfs1 server encountered some problems. Need to resolve this before moving forward"
             exit 4
        fi
    fi
    # terraform launching nfs2 vm
    if [ $is_nfs2 -eq 1 ]; then
        terraform_apply_serial "nfs2"
        if [ $? -ne 0 ]; then
             echo "launching and configuring nfs2 server encountered some problems. Need to resolve this before moving forward"
             exit 4
        fi
    fi
    # terraform launching nfs3 vm
    if [ $is_nfs3 -eq 1 ]; then
        terraform_apply_serial "nfs3"
        if [ $? -ne 0 ]; then
             echo "launching and configuring nfs3 server encountered some problems. Need to resolve this before moving forward"
             exit 4
        fi
    fi

    # terraform launching dd database vm
    if [ $is_db -eq 1 ]; then
       terraform_apply_serial "db"
       if [ $? -ne 0 ]; then
             echo "launching and configuring db2 server encountered some problems. Need to resolve this before moving forward"
             exit 4
       fi
    fi
    
	# terraform launching kubernetes master
    if [ $is_kube_master -eq 1 ]; then
        terraform_apply_serial "km"
        if [ $? -ne 0 ]; then
             echo "launching and configuring kube master server encountered some problems. Need to resolve this before moving forward"
             exit 4
        fi
    fi
    # terraform launching kubernetes worker
    if [ $is_kube_worker -eq 1 ]; then
        if [ "$kw_vm_count" != "null" ] && [ ! -z "$kw_vm_count" ]; then
            for (( j=1; j<=$kw_vm_count; j++ ))
            do
                terraform_apply "kw${j}"
            done
        else
            echo "kw vm count does not exist in  $tf_json_config_file or has invalid values. skip terraform applying"
        fi
    fi
    
    # terraform launching docker registry vm
    if [ $is_docreg -eq 1 ]; then
        terraform_apply "docreg"
    fi

    # terraform launching kubernetes worker dd vm
    if [ $is_kwdd -eq 1 ]; then
        if [ "$kwdd_vm_count" != "null" ] && [ ! -z "$kwdd_vm_count" ]; then
            for (( k=1; k<=$kwdd_vm_count; k++ ))
            do
                terraform_apply "kwdd${k}"
            done
        else
            echo "kwdd vm count does not exist in  $tf_json_config_file or has invalid values. skip terraform applying"
        fi
    fi
    
    # terraform launching web vm
    if [ $is_web -eq 1 ]; then
        terraform_apply "web"
    fi
    # terraform launching wexc vm
    if [ $is_wexc -eq 1 ]; then
        terraform_apply "wexc"
    fi
    # terraform launching wexfp vm
    if [ $is_wexfp -eq 1 ]; then
        terraform_apply "wexfp"
    fi
    # terraform launching wexm vm
    if [ $is_wexm -eq 1 ]; then
        terraform_apply "wexm"
    fi
    # terraform launching hdpa vm
    if [ $is_hdpa -eq 1 ]; then
        terraform_apply "hdpa"
    fi
    # terraform launching hdpg vm
    if [ $is_hdpg -eq 1 ]; then
        terraform_apply "hdpg"
    fi
    # terraform launching hdpm vm
    if [ $is_hdpm -eq 1 ]; then
        terraform_apply "hdpm"
    fi
    # terraform launching hdps1 vm
    if [ $is_hdps1 -eq 1 ]; then
        terraform_apply "hdps1"
    fi
    # terraform launching hdps2 vm
    if [ $is_hdps2 -eq 1 ]; then
        terraform_apply "hdps2"
    fi
    # terraform launching hdpsec vm
    if [ $is_hdpsec -eq 1 ]; then
        terraform_apply "hdpsec"
    fi
    # terraform launching icp4d ms vm
    if [ $is_ms -eq 1 ]; then
        if [ "$ms_vm_count" != "null" ] && [ ! -z "$ms_vm_count" ]; then
            for (( j=1; j<=$ms_vm_count; j++ ))
            do
                terraform_apply "ms${j}"
            done
        else
            echo "ms vm count does not exist in  $tf_json_config_file or has invalid values. skip terraform applying"
        fi
    fi

    # terraform launching stream  vms
    if [ $is_str -eq 1 ]; then
        if [ "$stream_vm_count" != "null" ] && [ ! -z "$stream_vm_count" ]; then
            for (( l=1; l<=$stream_vm_count; l++ ))
            do
                terraform_apply "str${l}"
            done
        else
            echo "stream vm count does not exist in  $tf_json_config_file or has invalid values. skip terraform applying"
        fi
    fi

    # terraform launching zookeper vm
    if [ $is_zkp -eq 1 ]; then
        terraform_apply "zkp"
    fi

    # terraform launching landing vm
    if [ $is_landing -eq 1 ]; then
        terraform_apply "landing"
    fi

    # terraform launching bigdata vm
    if [ $is_bigdata -eq 1 ]; then
        terraform_apply "bigdata"
    fi

    # terraform launching haproxy vm
    if [ $is_haproxy -eq 1 ]; then
        terraform_apply "haproxy"
    fi

    # terraform launching portworx vm
    if [ $is_portworx -eq 1 ]; then
        terraform_apply "portworx"
    fi


    # terraform launching storage vm
    if [ $is_storage -eq 1 ]; then
        if [ "$storage_vm_count" != "null" ] && [ ! -z "$storage_vm_count" ]; then
            for (( st_cnt=1; st_cnt<=$storage_vm_count; st_cnt++ ))
            do
                terraform_apply "st${st_cnt}"
            done
        else
            echo "storage vm count does not exist in  $tf_json_config_file or has invalid values. skip terraform applying"
        fi
    fi

    # terraform launching worker vm(s)
    if [ $is_worker -eq 1 ]; then
        if [ "$worker_vm_count" != "null" ] && [ ! -z "$worker_vm_count" ]; then
            for (( worker_cnt=1; worker_cnt<=$worker_vm_count; worker_cnt++ ))
            do
                terraform_apply "worker${worker_cnt}"
            done
        else
            echo "worker vm count does not exist in  $tf_json_config_file or has invalid values. skip terraform applying"
        fi
    fi

    # terraform launching api vm(s)
    if [ $is_api -eq 1 ]; then
        if [ "$api_vm_count" != "null" ] && [ ! -z "$api_vm_count" ]; then
            for (( api_cnt=1; api_cnt<=$api_vm_count; api_cnt++ ))
            do
                terraform_apply "api${api_cnt}"
            done
        else
            echo "api vm count does not exist in  $tf_json_config_file or has invalid values. skip terraform applying"
        fi
    fi
}

function generate_tag_directory() {
    local vsphere_vcenter=$(jq -r ".vsphere_vcenter" $tf_json_config_file)
    local vsphere_user=$(jq -r ".vsphere_user" $tf_json_config_file)
    local vsphere_password=$(jq -r ".vsphere_password" $tf_json_config_file)
    local product_initials=$(jq -r ".product_initials" $tf_json_config_file)
    local product_version=$(jq -r ".product_version" $tf_json_config_file)
    local customer_env_name=$(jq -r ".customer_env_name" $tf_json_config_file)
    local env_type=$(jq -r ".env_type" $tf_json_config_file)
    local env_name="${product_initials}-${product_version}-${customer_env_name}-${env_type}"
    local allhosts_vm_tag_name="${env_name}-allhosts"
    
    # check if allhosts tag exist
    local tag_exist=`python -c "import terraform_validator; terraform_validator.check_if_tag_exists(\"${vsphere_vcenter}\", \"${vsphere_user}\", \"${vsphere_password}\", \"${allhosts_vm_tag_name}\")"`

    if [ "${tag_exist}" == "False" ]; then
        mkdir -p "$terraform_vm_tag_folder"
        cp -r "$terraform_plugin_dir" "$terraform_vm_tag_folder"
        
        # write variables to terraform.tfvars
        echo "vsphere_user = \"${vsphere_user}\"" > $terraform_vm_tag_terraform_tfvars_file
        echo "vsphere_password = \"${vsphere_password}\"" >> $terraform_vm_tag_terraform_tfvars_file
        echo "vsphere_vcenter = \"${vsphere_vcenter}\"" >> $terraform_vm_tag_terraform_tfvars_file
        echo "allhosts_vm_tag_name = \"${allhosts_vm_tag_name}\"" >> $terraform_vm_tag_terraform_tfvars_file

        # write varibales to variables.tf
        echo "variable \"vsphere_user\" {}" > $terraform_vm_tag_terraform_variables_file
        echo "variable \"vsphere_password\" {}" >> $terraform_vm_tag_terraform_variables_file
        echo "variable \"vsphere_vcenter\" {}" >> $terraform_vm_tag_terraform_variables_file
        echo "variable \"allhosts_vm_tag_name\" {}" >> $terraform_vm_tag_terraform_variables_file

        `cat ${tf_build_tag_template} > ${terraform_vm_tag_terraform_build_file}`
    fi
}


#main block
start_time=`date +%s`

# if it's just to integrate with zabbix and generate ansible hosts, we can ignore the validator
if [ $is_zabbix -eq 1 ] || [ $is_ansible -eq 1 ]; then
    disable_validator=1
fi


#step 0. validation which includes: 
#a. terraform environment validation; 
#b. json file validation: json format validation, leveraging pyvmomi to validate the inputed values, etc 

if [ $disable_validator -ne 1 ]; then
    chmod +x ${cur_dir}/terraform_validator_v2.sh
    ${cur_dir}/terraform_validator_v2.sh
    if [ $? -ne 0 ]; then
        echo "$tf_json_config_file validation failed. Exiting..."
        exit 2
    fi
fi


#step 1. initialize: make sure the corresponding directory exists, chmod all scripts  

#step 2. according to datacenter and source_folder info, generate a json file that contains hostName, cpu, mem, disk_count, etc..

#step 3. jq loop to generate tf_work_dir, terraform.tfvars, variables.tf and build.tf
#step 3.1 generate shared configuration which will be used by all roles
generate_shared_tfvars
generate_tag_directory
#step 3.2 generate terraform work directory for each role
generate_tf_work_dir
#step 3.3 generate nslookup reverse lookup db file
grep -q "\"vm_type\": \"mgmt\"" $tf_json_config_file
mgmt_exist_flag=$?
if [ $mgmt_exist_flag -eq 0 ]; then
    generate_mgmt_reverse_host_file
fi
#step 3.4 generate hadoop ambari hosts properties
grep -q "\"vm_type\": \"hdpa\"" $tf_json_config_file
hdpa_exist_flag=$?
if [ $hdpa_exist_flag -eq 0 ]; then
    generate_fci_hadoop_hosts_properties
fi
#step 3.5 generate haproxy config file for WSL
grep -q "\"vm_type\": \"haproxy\"" $tf_json_config_file
haproxy_exist_flag=$?
if [ $haproxy_exist_flag -eq 0 ]; then
    generate_haproxy_cfg_file
fi
#step 3.6 generate wdp config install file for WSL
grep -q "\"vm_type\": \"ms\"" $tf_json_config_file
ms_exist_flag=$?
if [ $ms_exist_flag -eq 0 ]; then
    generate_wdp_conf_file
fi

# generate ansible hosts file
if [ $is_ansible -eq 1 ]; then
    chmod +x utilities/Ansible/generate_ansible_stanza.sh
    utilities/Ansible/generate_ansible_stanza.sh $tf_json_config_file $custom_properties_file
fi

# # cross vlan work aroud for each vm
# if [ $terraform_deploy -eq 0 ]; then
#     echo "Cross vlan workaround..."
#     for vm_folder in ${terraform_factory_dir}/*/; do
#         if [ -d "${vm_folder}" ]; then
#             vm_type=$(echo "${vm_folder}" | awk -F "/" '{print $(NF-1)}')
#             cross_vlan_terraform_update ${vm_type}
#         fi
#     done
# fi

# generate zabbix host group, hosts, Grant Permissions to Tip.Group to access the HostGroup
if [ $is_zabbix -eq 1 ]; then
    chmod +x utilities/zabbix/zabbix_integration.sh
    utilities/zabbix/zabbix_integration.sh
fi

#step 4. if hostname contains 2 or more than 2 ".", terraform cannot handle it, and we have to  remotely executing script to update hostname

#step 5. generate dns_update script based on hostname and ip

#step 6. launch terraform
terraform_provision

wait
end_time=`date +%s`
whole_run_time=$((end_time-start_time))
echo "Total time cost for provisioning via terraform is $whole_run_time seconds"