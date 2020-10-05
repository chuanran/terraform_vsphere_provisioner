#! /bin/bash
tf_config_json="../../config/terraform.tfvars.json"
zabbix_server="<Replace_me_with_zabbix_server_ip>"
api_token="<<Replace_me_with_zabbix_api_token>>"
user_group_name="TIP.Group"
#permission id set to 3, means "ReadWrite"
permission_id=3
#templates' names
#declare -a mgmt_templates_array
#mgmt_templates_array=("WFS Operations" "WFS OS Linux")
#declare -a km_templates_array
#km_templates_array=("WFS Kubenetes" "WFS OS Linux - Kubernetes")
operations_template="WFS Operations"
kubernetes_template="WFS Kubenetes"
kubernetes_linux_os_template="WFS OS Linux - Kubernetes"
linux_os_template="WFS OS Linux"

#function to get the host group name
function generate_zabbix_host_group_name() {
    local product_initials=$(jq -r ".product_initials" $tf_config_json)
    local product_version=$(jq -r ".product_version" $tf_config_json)
    local customer_env_name=$(jq -r ".customer_env_name" $tf_config_json)
    local env_type=$(jq -r ".env_type" $tf_config_json)
    echo "$product_initials-$product_version-$customer_env_name-$env_type"
}

#function for increament of ip address
function increment_ip () {
    local ip="$1"
    local increment=$(( $2 - 1 ))
    
    local baseaddr="$(echo $ip | cut -d. -f1-3)"
    local octet4="$(echo $ip | cut -d. -f4)"
    new_octet4=$(( $octet4 + $increment ))
    echo $baseaddr.$new_octet4
}

#check if the hostgroup exists or not by the given hostgroup name
hostgroup_name=$(generate_zabbix_host_group_name)
HostGroupId=$(curl -s -H "Content-Type: application/json-rpc" -X POST  http://${zabbix_server}/zabbix/api_jsonrpc.php -d "{\"jsonrpc\":\"2.0\",\"method\":\"hostgroup.get\",\"params\":{\"output\":\"groupid\",\"filter\":{\"name\":[\"${hostgroup_name}\"]}},\"auth\":\"${api_token}\",\"id\":1}" | jq .result[0].groupid | awk -F "\"" '{print $2}')
echo "$HostGroupId" | grep -qwE "^[0-9]+$"
if [ $? -ne 0 ]; then
    HostGroupId=$(curl -s -H "Content-Type: application/json-rpc" -X POST  http://${zabbix_server}/zabbix/api_jsonrpc.php -d "{\"jsonrpc\":\"2.0\",\"method\":\"hostgroup.create\",\"params\":{\"name\": \"$hostgroup_name\" },\"auth\": \"$api_token\",\"id\": 1}" | jq .result.groupids[0] | awk -F "\"" '{print $2}')
    echo "$HostGroupId" | grep -qwE "^[0-9]+$"
    if [ $? -ne 0 ]; then
        echo "Host group $hostgroup_name failed to be created. Exiting..."
        exit 2
    fi
fi

#get the template ids for the given templates
wfs_operation_template_id=$(curl -s -H "Content-Type: application/json-rpc" -X POST  http://${zabbix_server}/zabbix/api_jsonrpc.php -d "{\"jsonrpc\":\"2.0\",\"method\":\"template.get\",\"params\":{\"output\":\"extend\",\"filter\":{\"host\":[\"$operations_template\"]}},\"auth\":\"${api_token}\",\"id\":1}" | jq ".result[0].templateid" | awk -F "\"" '{print $2}')
echo "$wfs_operation_template_id" |  grep -qwE "^[0-9]+$"
if [ $? -ne 0 ]; then
    echo "$operations_template cannot be found via API Call"
fi
kubernetes_template_id=$(curl -s -H "Content-Type: application/json-rpc" -X POST  http://${zabbix_server}/zabbix/api_jsonrpc.php -d "{\"jsonrpc\":\"2.0\",\"method\":\"template.get\",\"params\":{\"output\":\"extend\",\"filter\":{\"host\":[\"$kubernetes_template\"]}},\"auth\":\"${api_token}\",\"id\":1}" | jq ".result[0].templateid" | awk -F "\"" '{print $2}')
echo "$kubernetes_template_id" |  grep -qwE "^[0-9]+$"
if [ $? -ne 0 ]; then
    echo "$kubernetes_template cannot be found via API Call"
fi
kubernetes_linux_os_template_id=$(curl -s -H "Content-Type: application/json-rpc" -X POST  http://${zabbix_server}/zabbix/api_jsonrpc.php -d "{\"jsonrpc\":\"2.0\",\"method\":\"template.get\",\"params\":{\"output\":\"extend\",\"filter\":{\"host\":[\"$kubernetes_linux_os_template\"]}},\"auth\":\"${api_token}\",\"id\":1}" | jq ".result[0].templateid" | awk -F "\"" '{print $2}')
echo "$kubernetes_linux_os_template_id" |  grep -qwE "^[0-9]+$"
if [ $? -ne 0 ]; then
    echo "$kubernetes_linux_os_template cannot be found via API Call"
fi
linux_os_template_id=$(curl -s -H "Content-Type: application/json-rpc" -X POST  http://${zabbix_server}/zabbix/api_jsonrpc.php -d "{\"jsonrpc\":\"2.0\",\"method\":\"template.get\",\"params\":{\"output\":\"extend\",\"filter\":{\"host\":[\"$linux_os_template\"]}},\"auth\":\"${api_token}\",\"id\":1}" | jq ".result[0].templateid" | awk -F "\"" '{print $2}')
echo "$linux_os_template_id" |  grep -qwE "^[0-9]+$"
if [ $? -ne 0 ]; then
    echo "$linux_os_template cannot be found via API Call"
fi
#loop all the ips add hosts into the host group
for  vm_it in $(jq '.vms_meta | keys | .[]' $tf_config_json); do
    vm_type=$(jq -r ".vms_meta[$vm_it].vm_type" $tf_config_json)
    vm_sl_private_ip=$(jq -r ".vms_meta[$vm_it].vm_sl_private_ip" $tf_config_json)
    vsphere_vm_count=$(jq -r ".vms_meta[$vm_it].vsphere_vm_count" $tf_config_json)

    if [ "$vm_type" == "kw" ] || [ "$vm_type" == "kwdd" ] || [ "$vm_type" == "ms" ]; then
        template_pattern="{\"templateid\": \"$kubernetes_linux_os_template_id\"}"
    elif [ "$vm_type" == "mgmt" ]; then
        template_pattern="{\"templateid\": \"$wfs_operation_template_id\"}, {\"templateid\": \"$linux_os_template_id\"}"
    elif [ "$vm_type" == "km" ]; then
        template_pattern="{\"templateid\": \"$kubernetes_template_id\"}, {\"templateid\": \"$kubernetes_linux_os_template_id\"}"
    else
        template_pattern="{\"templateid\": \"$linux_os_template_id\"}"
    fi
    if [[ $vsphere_vm_count != null && $vsphere_vm_count -gt 1 ]]; then
        for ((i=1;i<=$vsphere_vm_count;i++)); do
            host_name="${hostgroup_name}-${vm_type}$i"
            private_ip=$( increment_ip "${vm_sl_private_ip}" "${i}" )
            
            #check if the host exists or not, if exists, then do an update; if does NOT exist, will create the host
            host_id=$(curl -s -H "Content-Type: application/json-rpc" -X POST http://${zabbix_server}/zabbix/api_jsonrpc.php -d "{\"jsonrpc\":\"2.0\",\"method\":\"host.get\",\"params\":{\"filter\":{\"host\":\"$host_name\"}},\"auth\":\"${api_token}\",\"id\":1}" | jq '.result[0].hostid' | awk -F "\"" '{print $2}')
            echo "$host_id" | grep -qwE "^[0-9]+$"
            if [ $? -eq 0 ]; then
                #the host already exists, so just do an update
                curl -s -H "Content-Type: application/json-rpc" -X POST  http://${zabbix_server}/zabbix/api_jsonrpc.php -d "{\"jsonrpc\":\"2.0\",\"method\":\"host.update\",\"params\":{\"host\":\"$host_name\",\"hostid\":\"$host_id\",\"interfaces\":[{\"type\":1,\"main\":1,\"useip\":1,\"ip\":\"$private_ip\",\"dns\":\"\",\"port\":\"10050\"}],\"groups\":[{\"groupid\":\"$HostGroupId\"}],\"templates\":[$template_pattern]},\"auth\":\"${api_token}\",\"id\":1}" | jq '.result.hostids[0]' | awk -F "\"" '{print $2}' | grep -qwE "^[0-9]+$"
                if [ $? -ne 0 ]; then
                    echo "Failed to update host $host_name. Need to have a check"
                fi
            else
                #the host does not exist, need do a creation
                curl -s -H "Content-Type: application/json-rpc" -X POST  http://${zabbix_server}/zabbix/api_jsonrpc.php -d "{\"jsonrpc\":\"2.0\",\"method\":\"host.create\",\"params\":{\"host\":\"$host_name\",\"interfaces\":[{\"type\":1,\"main\":1,\"useip\":1,\"ip\":\"$private_ip\",\"dns\":\"\",\"port\":\"10050\"}],\"groups\":[{\"groupid\":\"$HostGroupId\"}],\"templates\":[$template_pattern]},\"auth\":\"${api_token}\",\"id\":1}" | jq '.result.hostids[0]' | awk -F "\"" '{print $2}' | grep -qwE "^[0-9]+$"
                if [ $? -ne 0 ]; then
                    echo "Failed to create host $host_name. Need to have a check"
                fi
            fi 
        done
    else
        host_name="${hostgroup_name}-${vm_type}"
        host_id=$(curl -s -H "Content-Type: application/json-rpc" -X POST http://${zabbix_server}/zabbix/api_jsonrpc.php -d "{\"jsonrpc\":\"2.0\",\"method\":\"host.get\",\"params\":{\"filter\":{\"host\":\"$host_name\"}},\"auth\":\"${api_token}\",\"id\":1}" | jq '.result[0].hostid' | awk -F "\"" '{print $2}')
        echo "$host_id" | grep -qwE "^[0-9]+$"
        if [ $? -eq 0 ]; then
            #the host already exists, so just do an update
            curl -s -H "Content-Type: application/json-rpc" -X POST  http://${zabbix_server}/zabbix/api_jsonrpc.php -d "{\"jsonrpc\":\"2.0\",\"method\":\"host.update\",\"params\":{\"host\":\"$host_name\",\"hostid\":\"$host_id\",\"interfaces\":[{\"type\":1,\"main\":1,\"useip\":1,\"ip\":\"$vm_sl_private_ip\",\"dns\":\"\",\"port\":\"10050\"}],\"groups\":[{\"groupid\":\"$HostGroupId\"}],\"templates\":[$template_pattern]},\"auth\":\"${api_token}\",\"id\":1}" | jq '.result.hostids[0]' | awk -F "\"" '{print $2}' | grep -qwE "^[0-9]+$"
            if [ $? -ne 0 ]; then
                echo "Failed to update host $host_name. Need to have a check"
            fi
        else
            #the host does not exist, need do a creation
            curl -s -H "Content-Type: application/json-rpc" -X POST  http://${zabbix_server}/zabbix/api_jsonrpc.php -d "{\"jsonrpc\":\"2.0\",\"method\":\"host.create\",\"params\":{\"host\":\"$host_name\",\"interfaces\":[{\"type\":1,\"main\":1,\"useip\":1,\"ip\":\"$vm_sl_private_ip\",\"dns\":\"\",\"port\":\"10050\"}],\"groups\":[{\"groupid\":\"$HostGroupId\"}],\"templates\":[$template_pattern]},\"auth\":\"${api_token}\",\"id\":1}" | jq '.result.hostids[0]' | awk -F "\"" '{print $2}' | grep -qwE "^[0-9]+$"
            if [ $? -ne 0 ]; then
                echo "Failed to create host $host_name. Need to have a check"
            fi
        fi
    fi
done
    
Rights=$(curl -s -H "Content-Type: application/json-rpc" -X POST  http://${zabbix_server}/zabbix/api_jsonrpc.php -d "{\"jsonrpc\":\"2.0\",\"method\":\"usergroup.get\",\"params\":{\"filter\":{\"name\":[\"$user_group_name\"]},\"output\":[\"name\"],\"selectRights\":[\"permission\",\"id\"]},\"auth\":\"$api_token\",\"id\":1}")
user_group_id=$(echo $Rights | jq ".result[].usrgrpid" | awk -F "\"" '{print $2}')
if [[ $Rights == *'"rights"'* ]]; then 
    #getting the rights Object
    Rights=$(echo $Rights | jq ".result[] | .rights" | tr -d \[ | tr -d \] | tr -d ' '| tr -d '\n')
    #check if the group already exists in the right array
    echo "$Rights" |  grep -q "\"id\":\"$HostGroupId\""
    if [ $? -ne 0 ]; then
        #Checking if any previous rights exist. if exists, will append the new right to existing one. permission '3' stands for "Read-Write"
        if [ "$Rights" != "" ]; then
            Rights="{\"permission\":\"$permission_id\",\"id\":\"$HostGroupId\"},"$Rights
        elif [ "$Rights" == "" ]; then
            Rights="{\"permission\":\"$permission_id\",\"id\":\"$HostGroupId\"}"
        fi
        Update=$(curl -s -H "Content-Type: application/json-rpc" -X POST  http://${zabbix_server}/zabbix/api_jsonrpc.php -d "{\"jsonrpc\":\"2.0\",\"method\":\"usergroup.update\",\"params\":{\"usrgrpid\":\"$user_group_id\",\"rights\":[$Rights]},\"auth\":\"${api_token}\",\"id\":1}")
        if [[ $Update == *'"result":{"usrgrpids"'* ]]; then
            printf "\e[1;32m Access to HostGroup {$2} added \033[0m \n"  
        else
            printf "\033[1;31mError\033[0m, $Update\n"
        fi
    else
        echo "host group $hostgroup_name already exists in the user group $user_group_name"
    fi
    
elif [[ $Rights == *"Invalid params"* || $Rights == *"error"* ]]; then 
    printf "\033[1;31m API Failed,\033[0m Response: $Rights\n"
else 
    printf "\033[1;31mError\033[0m, $Rights\n"       
fi