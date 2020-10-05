#!/bin/bash

function append_to_file () {
    local group_heading="$1"
    local host_config_content="$2"
    local host_file="$3"

    # if file does not exist create file and append a -
    # group heading to the top of file
    if [ ! -f $host_file ]; then
        echo $group_heading >> $host_file
    fi
    echo $host_config_content >> $host_file
}

function increment_ip () {
    local ip="$1"
    local increment=$(( $2 - 1 ))
    
    baseaddr="$(echo $ip | cut -d. -f1-3)"
    octet4="$(echo $ip | cut -d. -f4)"
    new_octet4=$(( $octet4 + $increment ))
    echo $baseaddr.$new_octet4
}

ansible_dir="utilities/Ansible/TFD_Ansible_hosts"

# check if Ansible directory exists
if [ ! -d $ansible_dir ]; then
  mkdir -p $ansible_dir
fi

tf_tfvars_json_file="$1"
# GitHub
properties_file="$2"

product_initials=$(jq -r ".product_initials" $tf_tfvars_json_file)
product_version=$(jq -r ".product_version" $tf_tfvars_json_file)
customer_env_name=$(jq -r ".customer_env_name" $tf_tfvars_json_file)
env_type=$(jq -r ".env_type" $tf_tfvars_json_file)

env_name="${product_initials}-${product_version}-${customer_env_name}-${env_type}"

echo "Generating Ansible host stanza for ${env_name}....."

host_file_name="${ansible_dir}/${env_name}.ansible.hosts"

subfile_ext=".sub.hosts"
env_group_host_file_name="${ansible_dir}/${env_name}group_all${subfile_ext}"
env_group_heading="[${env_name}]"

echo $env_group_heading >> $env_group_host_file_name 

# kubernetes group
kube_group_host_file_name="${ansible_dir}/${env_name}group_kube${subfile_ext}"
kube_group_heading="[${env_name}-kube]"

# wca group
wca_group_host_file_name="${ansible_dir}/${env_name}group_wca${subfile_ext}"
wca_group_heading="[${env_name}-wca]"

# hadoop group
hdp_group_host_file_name="${ansible_dir}/${env_name}group_hdp${subfile_ext}"
hdp_group_heading="[${env_name}-hdp]"

# wsl group
wsl_group_host_file_name="${ansible_dir}/${env_name}group_wsl${subfile_ext}"
wsl_group_heading="[${env_name}-wsl]"

for vm_it in $(jq '.vms_meta | keys | .[]' $tf_tfvars_json_file); do
    vm_type=$(jq -r ".vms_meta[$vm_it].vm_type" $tf_tfvars_json_file)
    vm_sl_private_ip=$(jq -r ".vms_meta[$vm_it].vm_sl_private_ip" $tf_tfvars_json_file)
    vsphere_vm_count=$(jq -r ".vms_meta[$vm_it].vsphere_vm_count" $tf_tfvars_json_file)
    # echo "[${env_name}-${vm_type}]" >> $host_file_name

    # files to be create
    # naming convention - group_
    
    host_config_content="${vm_sl_private_ip} #${env_name}-${vm_type}"
    # add current vm to group_all
    if [ $vsphere_vm_count == null ]; then
        append_to_file "${env_group_heading}" "${host_config_content}" "${env_group_host_file_name}"
    fi

    # append_to_file "group_heading" "text" "file"
    if [ $vm_type == "km" ]; then
        # add to kube
        append_to_file "${kube_group_heading}" "${host_config_content}" "${kube_group_host_file_name}"
        
        # add to km
        km_group_host_file_name="${ansible_dir}/${env_name}group_${vm_type}${subfile_ext}"
        km_group_heading="[${env_name}-${vm_type}]"
        append_to_file "${km_group_heading}" "${host_config_content}" "${km_group_host_file_name}"
    fi

    if [ $vm_type == "kw" ]; then
        
        kw_group_host_file_name="${ansible_dir}/${env_name}group_${vm_type}${subfile_ext}"
        kw_group_heading="[${env_name}-${vm_type}${i}]"
        for ((i=1;i<=$vsphere_vm_count;i++)); do
            kw_vm_sl_private_ip=$( increment_ip "${vm_sl_private_ip}" "${i}" )
            kw_host_config_content="${kw_vm_sl_private_ip} #${env_name}-${vm_type}${i}"

            # add to group_all
            append_to_file "${env_group_heading}" "${kw_host_config_content}" "${env_group_host_file_name}"
            
            # add to kube
            append_to_file "${kube_group_heading}" "${kw_host_config_content}" "${kube_group_host_file_name}"
            
            # add to kw
            append_to_file "${kw_group_heading}" "${kw_host_config_content}" "${kw_group_host_file_name}"

            # add to kw-i
            kwi_group_host_file_name="${ansible_dir}/${env_name}group_${vm_type}${i}${subfile_ext}"
            kwi_group_heading="[${env_name}-${vm_type}${i}]"
            append_to_file "${kwi_group_heading}" "${kw_host_config_content}" "${kwi_group_host_file_name}"
        done
    fi

    if [ $vm_type == "kwdd" ]; then
        kwdd_group_host_file_name="${ansible_dir}/${env_name}group_${vm_type}${subfile_ext}"
        kwdd_group_heading="[${env_name}-${vm_type}]"
        for ((i=1;i<=$vsphere_vm_count;i++)); do
            kwdd_vm_sl_private_ip=$( increment_ip "${vm_sl_private_ip}" "${i}" )
            kwdd_host_config_content="${kwdd_vm_sl_private_ip} #${env_name}-${vm_type}${i}"

            # add to group_all
            append_to_file "${env_group_heading}" "${kwdd_host_config_content}" "${env_group_host_file_name}"
            
            # add to kube
            append_to_file "${kube_group_heading}" "${kwdd_host_config_content}" "${kube_group_host_file_name}"
            
            # add to kwdd
            append_to_file "${kwdd_group_heading}" "${kwdd_host_config_content}" "${kwdd_group_host_file_name}"

            # add to kwdd-i
            kwddi_group_host_file_name="${ansible_dir}/${env_name}group_${vm_type}${i}${subfile_ext}"
            kwddi_group_heading="[${env_name}-${vm_type}${i}]"
            append_to_file "${kwddi_group_heading}" "${kwdd_host_config_content}" "${kwddi_group_host_file_name}"
        done
    fi

    if [ $vm_type == "ms" ]; then
        ms_group_host_file_name="${ansible_dir}/${env_name}group_${vm_type}${subfile_ext}"
        ms_group_heading="[${env_name}-${vm_type}]"
        for ((i=1;i<=$vsphere_vm_count;i++)); do
            ms_vm_sl_private_ip=$( increment_ip "${vm_sl_private_ip}" "${i}" )
            ms_host_config_content="${ms_vm_sl_private_ip} #${env_name}-${vm_type}${i}"

            # add to group_all
            append_to_file "${env_group_heading}" "${ms_host_config_content}" "${env_group_host_file_name}"

            # Add to wsl
            append_to_file "${wsl_group_heading}" "${ms_host_config_content}" "${wsl_group_host_file_name}"
            
            # add to ms
            append_to_file "${ms_group_heading}" "${ms_host_config_content}" "${ms_group_host_file_name}"

            # add to ms-i
            msi_group_host_file_name="${ansible_dir}/${env_name}group_${vm_type}${i}${subfile_ext}"
            msi_group_heading="[${env_name}-${vm_type}${i}]"
            append_to_file "${msi_group_heading}" "${ms_host_config_content}" "${msi_group_host_file_name}"
        done
    fi

    if [ $vm_type == "db" ]; then
        # add to db
        db_group_host_file_name="${ansible_dir}/${env_name}group_${vm_type}${subfile_ext}"
        db_group_heading="[${env_name}-${vm_type}]"
        append_to_file "${db_group_heading}" "${host_config_content}" "${db_group_host_file_name}"
    fi

    if [ $vm_type == "mgmt" ]; then
        # add to mgmt
        mgmt_group_host_file_name="${ansible_dir}/${env_name}group_${vm_type}${subfile_ext}"
        mgmt_group_heading="[${env_name}-${vm_type}]"
        append_to_file "${mgmt_group_heading}" "${host_config_content}" "${mgmt_group_host_file_name}"
    fi

    if [ $vm_type == "nfs1" ]; then
        # add to nfs1
        nfs1_group_host_file_name="${ansible_dir}/${env_name}group_${vm_type}${subfile_ext}"
        nfs1_group_heading="[${env_name}-${vm_type}]"
        append_to_file "${nfs1_group_heading}" "${host_config_content}" "${nfs1_group_host_file_name}"
    fi

    if [ $vm_type == "nfs2" ]; then
        # add to nfs2
        nfs2_group_host_file_name="${ansible_dir}/${env_name}group_${vm_type}${subfile_ext}"
        nfs2_group_heading="[${env_name}-${vm_type}]"
        append_to_file "${nfs2_group_heading}" "${host_config_content}" "${nfs2_group_host_file_name}"
    fi

    if [ $vm_type == "nfs3" ]; then
        # Add to wsl
        append_to_file "${wsl_group_heading}" "${host_config_content}" "${wsl_group_host_file_name}"
        
        # add to nfs3
        nfs3_group_host_file_name="${ansible_dir}/${env_name}group_${vm_type}${subfile_ext}"
        nfs3_group_heading="[${env_name}-${vm_type}]"
        append_to_file "${nfs3_group_heading}" "${host_config_content}" "${nfs3_group_host_file_name}"
    fi

    if [ $vm_type == "wexc" ]; then
        # add to wca
        append_to_file "${wca_group_heading}" "${host_config_content}" "${wca_group_host_file_name}"

        # add to wexc
        wexc_group_host_file_name="${ansible_dir}/${env_name}group_${vm_type}${subfile_ext}"
        wexc_group_heading="[${env_name}-${vm_type}]"
        append_to_file "${wexc_group_heading}" "${host_config_content}" "${wexc_group_host_file_name}"
    fi

    if [ $vm_type == "wexfp" ]; then
        # add to wca
        append_to_file "${wca_group_heading}" "${host_config_content}" "${wca_group_host_file_name}"

        # add to wexfp
        wexfp_group_host_file_name="${ansible_dir}/${env_name}group_${vm_type}${subfile_ext}"
        wexfp_group_heading="[${env_name}-${vm_type}]"
        append_to_file "${wexfp_group_heading}" "${host_config_content}" "${wexfp_group_host_file_name}"
    fi

    if [ $vm_type == "wexm" ]; then
        # add to wca
        append_to_file "${wca_group_heading}" "${host_config_content}" "${wca_group_host_file_name}"

        # add to wexm
        wexm_group_host_file_name="${ansible_dir}/${env_name}group_${vm_type}${subfile_ext}"
        wexm_group_heading="[${env_name}-${vm_type}]"
        append_to_file "${wexm_group_heading}" "${host_config_content}" "${wexm_group_host_file_name}"
    fi

    if [ $vm_type == "web" ]; then
        # Add to web
        web_group_host_file_name="${ansible_dir}/${env_name}group_${vm_type}${subfile_ext}"
        web_group_heading="[${env_name}-${vm_type}]"
        append_to_file "${web_group_heading}" "${host_config_content}" "${web_group_host_file_name}"
    fi

    if [ $vm_type == "hdpg" ]; then
        # Add to hadoop - hdp
        append_to_file "${hdp_group_heading}" "${host_config_content}" "${hdp_group_host_file_name}"

        # Add to hdpg
        hdpg_group_host_file_name="${ansible_dir}/${env_name}group_${vm_type}${subfile_ext}"
        hdpg_group_heading="[${env_name}-${vm_type}]"
        append_to_file "${hdpg_group_heading}" "${host_config_content}" "${hdpg_group_host_file_name}"
    fi

    if [ $vm_type == "hdpm" ]; then
        # Add to hadoop - hdp
        append_to_file "${hdp_group_heading}" "${host_config_content}" "${hdp_group_host_file_name}"

        # Add to hdpm
        hdpm_group_host_file_name="${ansible_dir}/${env_name}group_${vm_type}${subfile_ext}"
        hdpm_group_heading="[${env_name}-${vm_type}]"
        append_to_file "${hdpm_group_heading}" "${host_config_content}" "${hdpm_group_host_file_name}"
    fi

    if [ $vm_type == "hdps1" ]; then
        # Add to hadoop - hdp
        append_to_file "${hdp_group_heading}" "${host_config_content}" "${hdp_group_host_file_name}"

        # Add to hdps1
        hdps1_group_host_file_name="${ansible_dir}/${env_name}group_${vm_type}${subfile_ext}"
        hdps1_group_heading="[${env_name}-${vm_type}]"
        append_to_file "${hdps1_group_heading}" "${host_config_content}" "${hdps1_group_host_file_name}"
    fi

    if [ $vm_type == "hdps2" ]; then
        # Add to hadoop - hdp
        append_to_file "${hdp_group_heading}" "${host_config_content}" "${hdp_group_host_file_name}"

        # Add to hdps2
        hdps2_group_host_file_name="${ansible_dir}/${env_name}group_${vm_type}${subfile_ext}"
        hdps2_group_heading="[${env_name}-${vm_type}]"
        append_to_file "${hdps2_group_heading}" "${host_config_content}" "${hdps2_group_host_file_name}"
    fi

    if [ $vm_type == "hdpsec" ]; then
        # Add to hadoop - hdp
        append_to_file "${hdp_group_heading}" "${host_config_content}" "${hdp_group_host_file_name}"

        # Add to hdpsec
        hdpsec_group_host_file_name="${ansible_dir}/${env_name}group_${vm_type}${subfile_ext}"
        hdpsec_group_heading="[${env_name}-${vm_type}]"
        append_to_file "${hdpsec_group_heading}" "${host_config_content}" "${hdpsec_group_host_file_name}"
    fi

    if [ $vm_type == "hdpa" ]; then
        # Add to hadoop - hdp
        append_to_file "${hdp_group_heading}" "${host_config_content}" "${hdp_group_host_file_name}"

        # Add to hdpa
        hdpa_group_host_file_name="${ansible_dir}/${env_name}group_${vm_type}${subfile_ext}"
        hdpa_group_heading="[${env_name}-${vm_type}]"
        append_to_file "${hdpa_group_heading}" "${host_config_content}" "${hdpa_group_host_file_name}"
    fi

    if [ $vm_type == "landing" ]; then
        # Add to landing
        landing_group_host_file_name="${ansible_dir}/${env_name}group_${vm_type}${subfile_ext}"
        landing_group_heading="[${env_name}-${vm_type}]"
        append_to_file "${landing_group_heading}" "${host_config_content}" "${landing_group_host_file_name}"
    fi

    if [ $vm_type == "bigdata" ]; then
        # Add to bigdata
        bigdata_group_host_file_name="${ansible_dir}/${env_name}group_${vm_type}${subfile_ext}"
        bigdata_group_heading="[${env_name}-${vm_type}]"
        append_to_file "${bigdata_group_heading}" "${host_config_content}" "${bigdata_group_host_file_name}"
    fi

    if [ $vm_type == "zkp" ]; then
        # Add to zkp
        zkp_group_host_file_name="${ansible_dir}/${env_name}group_${vm_type}${subfile_ext}"
        zkp_group_heading="[${env_name}-${vm_type}]"
        append_to_file "${zkp_group_heading}" "${host_config_content}" "${zkp_group_host_file_name}"
    fi

    if [ $vm_type == "st" ]; then
        st_group_host_file_name="${ansible_dir}/${env_name}group_${vm_type}${subfile_ext}"
        st_group_heading="[${env_name}-${vm_type}]"
        for ((i=1;i<=$vsphere_vm_count;i++)); do
            st_vm_sl_private_ip=$( increment_ip "${vm_sl_private_ip}" "${i}" )
            st_host_config_content="${st_vm_sl_private_ip} #${env_name}-${vm_type}${i}"

            # add to group_all
            append_to_file "${env_group_heading}" "${st_host_config_content}" "${env_group_host_file_name}"
            
            # add to st
            append_to_file "${st_group_heading}" "${st_host_config_content}" "${st_group_host_file_name}"

            # add to st-i
            sti_group_host_file_name="${ansible_dir}/${env_name}group_${vm_type}${i}${subfile_ext}"
            sti_group_heading="[${env_name}-${vm_type}${i}]"
            append_to_file "${sti_group_heading}" "${st_host_config_content}" "${sti_group_host_file_name}"
        done
    fi

    if [ $vm_type == "str" ]; then
        str_group_host_file_name="${ansible_dir}/${env_name}group_${vm_type}${subfile_ext}"
        str_group_heading="[${env_name}-${vm_type}]"
        for ((i=1;i<=$vsphere_vm_count;i++)); do
            str_vm_sl_private_ip=$( increment_ip "${vm_sl_private_ip}" "${i}" )
            str_host_config_content="${str_vm_sl_private_ip} #${env_name}-${vm_type}${i}"

            # add to group_all
            append_to_file "${env_group_heading}" "${str_host_config_content}" "${env_group_host_file_name}"
            
            # add to str
            append_to_file "${str_group_heading}" "${str_host_config_content}" "${str_group_host_file_name}"

            # add to str-i
            stri_group_host_file_name="${ansible_dir}/${env_name}group_${vm_type}${i}${subfile_ext}"
            stri_group_heading="[${env_name}-${vm_type}${i}]"
            append_to_file "${stri_group_heading}" "${str_host_config_content}" "${stri_group_host_file_name}"
        done
    fi

    if [ $vm_type == "api" ]; then
        api_group_host_file_name="${ansible_dir}/${env_name}group_${vm_type}${subfile_ext}"
        api_group_heading="[${env_name}-${vm_type}]"
        for ((i=1;i<=$vsphere_vm_count;i++)); do
            api_vm_sl_private_ip=$( increment_ip "${vm_sl_private_ip}" "${i}" )
            api_host_config_content="${api_vm_sl_private_ip} #${env_name}-${vm_type}${i}"

            # add to group_all
            append_to_file "${env_group_heading}" "${api_host_config_content}" "${env_group_host_file_name}"
            
            # add to api
            append_to_file "${api_group_heading}" "${api_host_config_content}" "${api_group_host_file_name}"

            # add to api-i
            api_i_group_host_file_name="${ansible_dir}/${env_name}group_${vm_type}${i}${subfile_ext}"
            api_i_group_heading="[${env_name}-${vm_type}${i}]"
            append_to_file "${api_i_group_heading}" "${api_host_config_content}" "${api_i_group_host_file_name}"
        done
    fi

    if [ $vm_type == "worker" ]; then
        worker_group_host_file_name="${ansible_dir}/${env_name}group_${vm_type}${subfile_ext}"
        worker_group_heading="[${env_name}-${vm_type}]"
        for ((i=1;i<=$vsphere_vm_count;i++)); do
            worker_vm_sl_private_ip=$( increment_ip "${vm_sl_private_ip}" "${i}" )
            worker_host_config_content="${worker_vm_sl_private_ip} #${env_name}-${vm_type}${i}"

            # add to group_all
            append_to_file "${env_group_heading}" "${worker_host_config_content}" "${env_group_host_file_name}"

            # Add to wsl
            append_to_file "${wsl_group_heading}" "${worker_host_config_content}" "${wsl_group_host_file_name}"
            
            # add to worker
            append_to_file "${worker_group_heading}" "${worker_host_config_content}" "${worker_group_host_file_name}"

            # add to worker-i
            workeri_group_host_file_name="${ansible_dir}/${env_name}group_${vm_type}${i}${subfile_ext}"
            workeri_group_heading="[${env_name}-${vm_type}${i}]"
            append_to_file "${workeri_group_heading}" "${worker_host_config_content}" "${workeri_group_host_file_name}"
        done
    fi

    if [ $vm_type == "haproxy" ]; then
        # Add to wsl
        append_to_file "${wsl_group_heading}" "${host_config_content}" "${wsl_group_host_file_name}"

        # Add to haproxy
        haproxy_group_host_file_name="${ansible_dir}/${env_name}group_${vm_type}${subfile_ext}"
        haproxy_group_heading="[${env_name}-${vm_type}]"
        append_to_file "${haproxy_group_heading}" "${host_config_content}" "${haproxy_group_host_file_name}"
    fi

    if [ $vm_type == "portworx" ]; then
        # Add to portworx
        portworx_group_host_file_name="${ansible_dir}/${env_name}group_${vm_type}${subfile_ext}"
        portworx_group_heading="[${env_name}-${vm_type}]"
        append_to_file "${portworx_group_heading}" "${host_config_content}" "${portworx_group_host_file_name}"
    fi
    
done

# create new 
echo "### BEGIN: ${env_name} ###" > ${host_file_name}
# append the content of each sub file to the created
for group_file in "${ansible_dir}/*${subfile_ext}"; do
    `cat ${group_file} >> ${host_file_name}`
    rm ${group_file}
done
echo "### END: ${env_name} ###" >> ${host_file_name}

cat ${properties_file} | grep -qE "^github_url"
if [ $? -eq 0 ]; then
    github_url="`cat ${properties_file} | grep ^github_url | awk -F "=" '{print $2}' | awk '{print $1}'`"
    ansible_hosts_github_url="${github_url}/contents/Ansible/ansible-hosts"
    branch_github_url="${github_url}/git/refs"
    master_branch_github_url="${github_url}/git/refs/heads/master"
    pull_request_github_url="${github_url}/pulls"
else
    ansible_hosts_github_url="https://github.ibm.com/api/v3/repos/fc-cloud-ops/dev-ops-tasks/contents/Ansible/ansible-hosts"
    branch_github_url="https://github.ibm.com/api/v3/repos/fc-cloud-ops/dev-ops-tasks/git/refs"
    master_branch_github_url="https://github.ibm.com/api/v3/repos/fc-cloud-ops/dev-ops-tasks/git/refs/heads/master"
    pull_request_github_url="https://github.ibm.com/api/v3/repos/fc-cloud-ops/dev-ops-tasks/pulls"
fi

github_email="`cat ${properties_file} | grep ^github_email | awk -F "=" '{print $2}' | awk '{print $1}'`"
github_access_token="`cat ${properties_file} | grep ^github_access_token | awk -F "=" '{print $2}' | awk '{print $1}'`"

github_ansible_hosts_response=`curl -s --user "$github_email:$github_access_token" $ansible_hosts_github_url`

github_ansible_hosts_content=`echo ${github_ansible_hosts_response} | jq -r '.content'`
github_ansible_hosts_sha=`echo ${github_ansible_hosts_response} | jq -r '.sha'`

if [[ $github_ansible_hosts_content == null ]];then
    echo "Failed to retreived the ansible-host file content. Exiting....."
    exit 1
fi

temp_hosts_file="ansible-hosts"

# convert ansible-hosts file content in github from base64 to readable text and put in a temporary ansible-hosts file
echo $github_ansible_hosts_content | base64 -di > ${temp_hosts_file}

temp_hosts_file_contents=`sed "/### BEGIN: ${env_name} ###/,/### END: ${env_name} ###/d" ${temp_hosts_file}`

echo "${temp_hosts_file_contents}" > ${temp_hosts_file}

# add contents of environment host file to temporary ansible host file
echo -e '\n ' >> ${temp_hosts_file}
`cat ${host_file_name} >> ${temp_hosts_file}`

ansible_hosts_new_content=`cat ${temp_hosts_file} | base64`

# remove carriage returns from ansible_hosts_new_content
formatted_ansible_hosts_new_content=`echo "$ansible_hosts_new_content" | tr -d '\n'`

# remove temporary ansible-hosts file
rm ${temp_hosts_file}

# get master branch sha1 value
master_branch_github_response_sha=`curl -s --user "$github_email:$github_access_token" $master_branch_github_url | jq -r '.object.sha'`

# check if master branch is retreived
if [[ $master_branch_github_response_sha == null ]]; then
    echo "Failed to retreive the master branch sha1 value. Exiting....."
    exit 1
fi

current_date=$(date '+%d%b%y-%H%M')
new_github_branch_name="Ansible-Stanza-${env_name}-${current_date}"
new_github_branch_data="{ \"ref\": \"refs/heads/${new_github_branch_name}\", \"sha\": \"${master_branch_github_response_sha}\" }"

# create new branch
create_branch=`curl -s --write-out '%{http_code}' \
                --user "$github_email:$github_access_token" -X POST \
                -H "Accept: application/json" \
                -d "${new_github_branch_data}" \
                $branch_github_url`

create_branch_http_code=`echo $create_branch | awk '{print $NF}'`
if [[ $create_branch_http_code -ne "201" ]]; then
    echo "Failed to create branch: ${new_github_branch_name}. Http Result: ${create_branch_http_code}. Exiting....."
    exit 1
fi

# update the ansible host file on branch in github
update_data="{ \"message\": \"Update the ansible-hosts with ${env_name}\", \"sha\": \"${github_ansible_hosts_sha}\", \"branch\": \"${new_github_branch_name}\" , \"committer\": { \"name\": \"${github_email}\", \"email\": \"${github_email}\" }, \"content\": \"${formatted_ansible_hosts_new_content}\" }"

update=`curl -s --write-out '%{http_code}' \
        --user "$github_email:$github_access_token" -X PUT \
        -H "Accept: application/json" \
        -d "${update_data}" \
        $ansible_hosts_github_url`

update_http_code=`echo $update | awk '{print $NF}'`
if [[ $update_http_code -ne "200" ]]; then
    echo "Failed to update the ansible-hosts file. Http Result: ${update_http_code}"
    exit 1
fi

# create PR
pull_request_data="{ \"title\": \"Update Ansible Stanza with - ${env_name}\", \"body\": \"Update Ansible Stanza with - ${env_name}\", \"head\": \"${new_github_branch_name}\", \"base\": \"master\" }"

pull_request=`curl -s \
                --user "$github_email:$github_access_token" -X POST \
                -H "Accept: application/json" \
                -d "${pull_request_data}" \
                $pull_request_github_url`

pull_request_html_url=`echo ${pull_request} | jq -r '.html_url'`

if [[ $pull_request_html_url != null ]]; then
    echo "Ansible hosts file has been updated"
    echo "Pull request for ${new_github_branch_name} has been successfully created. Go to the link below to view the PR:"
    echo "${pull_request_html_url}"
    echo " "
    echo "Ansible Stanza genration complete."
    echo "Don't run this ansible stanza generation again. Don't forget to delete the generated branch after merging!"
else
    echo "Failed to create pull request. Http Result: ${pull_request_http_code}"
    exit 1
fi