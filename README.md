Terraform Deployment Tool (TFD)
=======
This tool can be used to launch a relatively large-scale environment that is managed by vSphere/vcsa

- [Overview](#overview)
- [How to use TFD](#How-to-use-TFD)
  - [Prerequisite](#prerequisites)
  - [Deployment Manifest File](#manifest-file)
  - [Provision](#provision)
  - [ansible](#ansible)
  - [zabbix](#zabbix)
  - [Install FCI platform] (#FCI_platform_install)
  - [Install HDP platform] (#HDP_platform_install)
  - [Install other FCI verticals] (#FCI_verticals_install)
   
   
# Overview
Scripts inside of this project will generate terraform configuration files for different types of virtual Machines, and  launch an environment managed by vsphere/vcsa automatically through cloning predefined template VMs. It supports four scenarios so far:  
1. provision an environment to a compute cluster .  
2. provision an environment to a specific host server managed by a compute cluster .  
3. provision an environment to a single host server . 
4. provision an environment from one datacenter to another different datacenter . 

Basically deployer just needs to manage one deployment manifest file that defined the configuration parameters of the infrastructure, and use this tool to clone template VMs to create new VMs, do the post customization like OS-level customization (ip allocation, dns setup, etc) and other customizations (product deployment manifest changes, product installation etc) after VMs booted up, and finally boot up an environment.

# How to use TFD

Deployer only needs two steps to use this tool:  
1. fill in the infrastructure configuration parameters in deployment manifest file `config/terraform.tfvars.json` .  
2. launch the deployment script `terraform_deploy_v2.sh` to create a new environment based on the configuration file deployer created

## Prerequisites

**Tools** .  
A client server with following software prerequisites installed:  
1. Terraform v0.11.11+ .  
2. python + modules (pyVmomi, pyVim) .  
3. jq . 
4. Notice: `perl` needs to be installed on the source template VMs which will be cloned to create new env

**Configuration** .  
You need make sure following infrastructure level configuration values exists before you use this tool . 
1. vsphere/vcsa that manages the template VMs . 
2. vsphere vcenter/login credentials, vsphere datacenter, compute cluster/host server, vsphere folder, vsphere datastore vsphere network adapter, etc . 
3. static IP addresses for the new VMs, dns domain name, network gateway, network mask, etc

## manifest-file
The deployment manifest file is located under `config/terraform.tfvars.json`, and it defines the infrastructure configuration parameters that end-users or deployers need to fill in before launching the deployment. Following is the manifest template of deploying a FCI DD environment under a specific host server in a compute cluster.

```
{
    "vsphere_vcenter": "<vsphere_vcenter_ip_to_be_replaced>",
    "vsphere_user": "<vsphere_user_to_be_replaced>",
    "vsphere_password": "vsphere_password_to_be_replaced",
    "vsphere_source_datacenter": "1414775-WDC04-FCI",
    "vsphere_source_vm_folder": "folder_path_hosting_source_vms_to_be_replaced",
    "vsphere_target_datacenter": "1414775-WDC04-FCI",
    "vsphere_compute_cluster": "1143(FCDD-Backend)Cluster",
    "vsphere_host": "fcidd-esx8-backend-wash4-1414775.wfss.ibm.com",
    "vsphere_target_datastore": "fcidd_cluster_VSAN_DS",
    "vsphere_target_vm_folder": "target_folder_path_to_hold_vms_to_be_replaced",
    "vsphere_sl_private_network_name": "DPortGroup_mgmt2",
    "vm_sl_private_netmask": "softlayer_private_netmask_number_to_be_replaced",
    "vm_network_gateway": "softlayer_network_gateway_to_be_replaced",
    "virtual_machine_search_domain": "wfss.ibm.com",
    "vsphere_dns_domain": "wfss.ibm.com",
    "vmuser": "root",
    "product_initials": "dd",
    "product_version": "110",
    "customer_env_name": "<customer_name>",
    "env_type": "preprod",
    "vms_meta":[
        {
            "vm_type": "km",
            "description": "terraform distinct configuration for kubernetes master vm",
            "vsphere_vm_template": "template_kube_master_vm_name_to_be_replaced",
            "vmpassword": "kube_master_root_user_password_to_be_replaced",
            "vm_sl_private_ip": "kube_master_softlayer_ip_to_be_replaced"
        },
        {
            "vm_type": "kw",
            "description": "terraform distinct configuration for kubernetes worker vm(s)",
            "vsphere_vm_template": "template_kube_worker_vm_name_may_contain_{i}_to_be_replaced",
            "vsphere_vm_count": "kube_worker_vm_count_to_be_replaced",
            "vmpassword": "kube_worker_root_user_password_to_be_replaced",
            "vm_sl_private_ip": "kube_worker_cluster_first_softlayer_ip_to_be_replaced"
        },
        {
            "vm_type": "kwdd",
            "description": "terraform distinct configuration for kubernetes worker DD vm(s)",
            "vsphere_vm_template": "template_kube_worker_dd_vm_name_may_contain_{i}_to_be_replaced",
            "vsphere_vm_count": "kube_worker_dd_vm_count_to_be_replaced",
            "vmpassword": "kube_worker_dd_root_user_password_to_be_replaced",
            "vm_sl_private_ip": "kube_worker_dd_cluster_first_softlayer_ip_to_be_replaced"
        },
        { 
            "vm_type": "db",
            "description": "terraform distinct configuration for database DD vm",
            "vsphere_vm_template": "template_db_vm_name_to_be_replaced",
            "vmpassword": "db_dd_root_user_password_to_be_replaced",
            "vm_sl_private_ip": "db_dd_softlayer_ip_to_be_replaced"
        },
        { 
            "vm_type": "docreg",
            "description": "terraform distinct configuration for docker registry vm",
            "vsphere_vm_template": "template_docreg_vm_name_to_be_replaced",
            "vmpassword": "docreg_root_user_password_to_be_replaced",
            "vm_sl_private_ip": "docreg_softlayer_ip_to_be_replaced"
        },
        { 
            "vm_type": "mgmt",
            "description": "terraform distinct configuration for management service vm",
            "vsphere_vm_template": "template_mgmt_vm_name_to_be_replaced",
            "vmpassword": "mgmt_root_user_password_to_be_replaced",
            "vm_sl_private_ip": "mgmt_softlayer_ip_to_be_replaced"
        },
        { 
            "vm_type": "nfs1",
            "description": "terraform distinct configuration for nfs1 vm",
            "vsphere_vm_template": "template_nfs1_vm_name_to_be_replaced",
            "vmpassword": "nfs1_root_user_password_to_be_replaced",
            "vm_sl_private_ip": "nfs1_softlayer_ip_to_be_replaced"
        },
        { 
            "vm_type": "nfs2",
            "description": "terraform distinct configuration for nfs2 vm",
            "vsphere_vm_template": "template_nfs2_vm_name_to_be_replaced",
            "vmpassword": "nfs2_root_user_password_to_be_replaced",
            "vm_sl_private_ip": "nfs2_softlayer_ip_to_be_replaced"
        },
        { 
            "vm_type": "wexc",
            "description": "terraform distinct configuration for wexc vm",
            "vsphere_vm_template": "template_wexc_vm_name_to_be_replaced",
            "vmpassword": "wexc_root_user_password_to_be_replaced",
            "vm_sl_private_ip": "wexc_softlayer_ip_to_be_replaced"
        },
        { 
            "vm_type": "wexfp",
            "description": "terraform distinct configuration for wexfp vm",
            "vsphere_vm_template": "template_wexfp_vm_name_to_be_replaced",
            "vmpassword": "wexfp_root_user_password_to_be_replaced",
            "vm_sl_private_ip": "wexfp_softlayer_ip_to_be_replaced"
        },
        { 
            "vm_type": "wexm",
            "description": "terraform distinct configuration for wexm vm",
            "vsphere_vm_template": "template_wexm_vm_name_to_be_replaced",
            "vmpassword": "wexm_root_user_password_to_be_replaced",
            "vm_sl_private_ip": "wexm_softlayer_ip_to_be_replaced"
        },
        { 
            "vm_type": "web",
            "description": "terraform distinct configuration for web vm",
            "vsphere_vm_template": "template_web_vm_name_to_be_replaced",
            "vmpassword": "web_root_user_password_to_be_replaced",
            "vm_sl_private_ip": "web_softlayer_ip_to_be_replaced"
        }
    ]
}
```
There are two kinds of configurations in the manifest file. One is called as `shared configuration` (all the contents excluding `vms_meta`), which can be used and shared by all types of VMs; The other one is called as `distinct configuration` (the content is located at the array of `vms_meta` in configuration json file), which only exists for specific VM itself. 

`shared configuration` includes:  
(1). vsphere_vcenter url(or ip)/authentication:  `vsphere_vcenter`, `vsphere_user` and `vsphere_password`.  

(2). The location of source templates: `vsphere_source_datacenter` and `vsphere_source_vm_folder` define the unique location of the template VMs.  
    (a). Normally all the template VMs are located in the same datacenter, so `vsphere_source_datacenter` is a `shared configuration` defined in the json file;  
    (b). Normally all the template VMs are located in the same folder, so `vsphere_source_vm_folder` can be a `shared configuration` existing in the config json file. However it's also possible that templates are located in different folders, so `vsphere_source_vm_folder` can be put under `distinct configuration` section as well, like for kube master vm `km`, the template vm's folder is defined below in `vsphere_source_vm_folder` section. Notice that `vsphere_source_vm_folder` can co-exist in `shared configuration` and `distinct configuration` sections, in which situation, the value defined in `distinct configuration` section will override the value defined in `shared configuration` section.
```
{
            "vm_type": "km",
            "description": "terraform distinct configuration for kubernetes master vm",
            "vsphere_vm_template": "template_kube_master_vm_name_to_be_replaced",
            "vsphere_source_vm_folder": "source_template_vm_folder_to_be_replaced",
            "vmpassword": "kube_master_root_user_password_to_be_replaced",
            "vm_sl_private_ip": "kube_master_softlayer_ip_to_be_replaced"
}
```

(3). The location of target VMs: `vsphere_target_datacenter` and `vsphere_target_vm_folder` can define the unique location of the newly provisioned vms, where `vsphere_target_datacenter` is the name of the datacenter which hosts the provisioned vms, and `vsphere_target_vm_folder` is the path of the folder where the provisioned vms will be put in.   

(4). The datastore the target VMs use: `vsphere_target_datastore` defines the name of the datastore that target VMs use. Normally it is a `shared configuration`, and all target VMs share the same datastore. However, it's possible that different VMs use different datastore, so `vsphere_target_datastore` can be a `distinct configuration`, and can be put into `vms_meta` array.  

(5). The compute_cluster or specific host where the provisioned VMs will be hosted on. There are three scenarios:  
    (a). clone a vm to a specific host in a compute cluster: `vsphere_compute_cluster` and `vsphere_host` defined in terraform.tfvars  
    (b). clone a vm to any host in a compute cluster: only `vsphere_compute_cluster` defined in `terraform.tfvars.json`
    (c). clone a vm to a single host: `vsphere_host` and `vsphere_host_folder` defined in `terraform.tfvars.json`  
For examples:
If you want to clone/provision a vm to a specific host server in a compute cluster, you can specify following in `terraform.tfvars.json`: 
    
        "vsphere_compute_cluster": "1143(FCDD-Backend)Cluster",
        "vsphere_host": "fcidd-esx8-backend-wash4-1414775.wfss.ibm.com",  
if you want to clone/provision a vm to a single host server (not under any compute clusters), you can specify following in     `terraform.tfvars.json`:
   
        "vsphere_host": "fcidd-esx6-backenddmz-wash4-1414775.wfss.ibm.com",
        "vsphere_host_folder": "bcr02a/1132-FCIDD-TryandBuy",
if you want to clone/provision a vm to any one of the host servers under a specific computer cluster,  you can specify following in `terraform.tfvars.json`: 
        
         "vsphere_compute_cluster": "1143(FCDD-Backend)Cluster",

(6). The network related configuration: `vsphere_sl_private_network_name`, `vm_sl_private_netmask` and `vm_network_gateway`.  `vsphere_sl_private_network_name` is the vsphere network adapter name (such as `DPortGroup_mgmt2`) for softlayer network (please notice that we only have 1 softlayer adapter attached to the FCI VMs), and you can find it in vsphere; `vm_sl_private_netmask` is the SL network mask number, where you can find it in softlayer portal, such as `26`; `vm_network_gateway` is the network gateway ip for SL network, where you can find it in softlayer portal  

(7). The dns domain related configuration: `virtual_machine_search_domain` and `vsphere_dns_domain`. `virtual_machine_search_domain` is the dns search domain you want to configure in `/etc/resolv.conf`, such as `wfss.ibm.com`; `vsphere_dns_domain` is the dns domain name for thee vm, which will be displayed as a postfix in vm's hostname or `hostname -f`

(8). The name convention of inventory name and hostname for the vms. The vm's inventory name follows this convention: `{product_initials}-{product_version}-{customer_env_name}-{env_type}-{vm_type}`, where `product_initials` stands the initials of the product, which could be one of `dd, si, cfm, ai`, etc; `product_version` is the version of product, i.e. 110, etc; `customer_env_name` is the customer name; `env_type` means the type/purpose of the environment, like one of `test, poc, dev, preprod, prod`, etc; `vm_type` (defines in `distinct configuration` part `vms_meta`, and the value is defined in `vm_type`) means the type of the vm, such as one of `km, kw, nfs1, nfs2, wexc, wexm, kwdd`, etc. Please notice that if there are more than 1 vm for a specific type (normally there will be more than 1 kube worker vms and more than 1 kube_worker_dd vms), the name of the vm will be the one appending an index after `vm_type`, for example `kw1,  kw2, kwdd1, kwdd2`, etc. 

For example, for following example, the vm name should be `dd-110-<customer_name>-preprod-km`, and the hostname should be the combination of the vm name and the `vsphere_dns_domain`. for example, if the `vsphere_dns_domain` is `wfss.ibm.com`, then the hostname of the vm will be automatically set to `dd-110-<customer_name>-preprod-km.wfss.ibm.com`

    "product_initials": "dd",
    "product_version": "110",
    "customer_env_name": "<customer_name>",
    "env_type": "preprod",
    "vms_meta":[
        {
            "vm_type": "km",
            "description": "terraform distinct configuration for kubernetes master vm",
            "vsphere_vm_template": "template_kube_master_vm_name_to_be_replaced",
            "vmpassword": "kube_master_root_user_password_to_be_replaced",
            "vm_sl_private_ip": "kube_master_softlayer_ip_to_be_replaced"
        },


(9). The ssh user that terraform uses for post customisation. Terraform can do post installation/customisation after the vm provisioned, and it needs an ssh user `vmuser` to login to the vm. Combining `vmuser` and the `vmpassword` (ssh user's password) defined in distinct configuration part for each vm, terraform can login the corresponding vm with correct authentication to do the post customisation. (Notice: currently it only supports ssh user and password authentication. ssh key auth will be supported in the future)

     "vmuser": "root",


`distinct configurations` defined in `vms_meta` array include:  

(1). `vm_type`: the type of each vm, such as `km`, `kw`, `kwdd`, `db`, `docreg`, `nfs1`, `nfs2`, `wexc`, `wexfp`, `wexm`, `web`, etc. Notice `vm_type` will be combined together with `{product_initials}-{product_version}-{customer_env_name}-{env_type}` defined in `shared configurations` to generate vm's name and hostname.  

(2). `description`:  the short description about the corresponding vm.  

(3). `vsphere_vm_template`: the name of the source vm template that's going to be cloned.  

(4). `vmpassword`:  the ssh user's password for terraform to login the vm(s) to do post customisation.  

(5). `vsphere_vm_count`: the count for the specific vm need to be provisioned. if it's not defined, by default the count is 1. `vsphere_vm_count` is normally set for `kw` and `kwdd`, since normally there will be more than 1 kube worker and more than 1 kw_dd vms need to be provisioned.  

(6). `vm_sl_private_ip`: the softlayer private ip for the specific vm. You can get the pre-allocated ip from the softlayer portal.  


## provision
1. Copy latest TFD code to corresponding deployment folder: The latest TFD code is under js1 vm's `/opt/TFD_v2.1/Terraform/fci_terraform_latest_v21`, and there's always a cron job on js1 to sync the latest TFD code in github to js1 vm's folder `/opt/TFD_v2.1/Terraform/fci_terraform_latest_v21`. 

```
root@js1-devops-vvm-wash4:/opt/TFD_v2.1/Terraform/fci_terraform_latest_v21# ls
README.md     config  getvmsbydc.py  templates               terraform_factory       terraform_validator_v2.sh    tools
clone_vms.py  files   plugin         terraform_deploy_v2.sh  terraform_validator.py  terraform_vsphere_workspace  utilities
root@js1-devops-vvm-wash4:/opt/TFD_v2.1/Terraform/fci_terraform_latest_v21# pwd
/opt/TFD_v2.1/Terraform/fci_terraform_latest_v21
```
Then you can create a folder under `/opt/` (`makdir /opt/<deploy_folder_name>`) which is used to deploy the env, and then copy the TFD code to the `deploy_folder` you created: `cp -r /opt/TFD_v2.1/Terraform/fci_terraform_latest_v21/* /opt/<deploy_folder_name>`
2. Update the deployment manifest file (`/opt/<deploy_folder_name>/config/terraform.tfvars.json`) based on above instructions  
3. Update custom properties file `/opt/<deploy_folder_name>/config/custom.properties`. Follow the comments in the `custom.properties` file to set the values for those properties. Normally for `JWT_KEY_EXPIRY`, `github_url` and `ansible_hosts_github_url`, there's no change needed for them; For `github_email`, `github_access_token`, please uncomment the corresponding line and follow the instructions in the comments to get the value for them; For `datasource config`, it's only needed for  Due Diligence setup, for other verticals, just keep them commented out.
```
root@js1-devops-vvm-wash4:/opt/TFD_v2.1/Terraform/fci_terraform_latest_v21/config# cat custom.properties 
#web session timeout that need to be changed in kube master helm chart
JWT_KEY_EXPIRY=4h


# let's consider using fssops github user account
#section: check in ansible hosts file to github repo
#uncomment the following, and provide your own email address
#github_email=github_email_to_be_replaced

#Generate your personal access token - https://help.github.com/en/articles/creating-a-personal-access-token-for-the-command-line
#uncomment the following to provide your own github access token
#github_access_token=github_access_token_to_be_replaced

#github api url for ansible-hosts file
github_url=https://github.ibm.com/api/v3/repos/fc-cloud-ops/dev-ops-tasks
ansible_hosts_github_url=https://github.ibm.com/api/v3/repos/fc-cloud-ops/dev-ops-tasks/contents/Ansible/ansible-hosts
#end section: check in ansible hosts file to github repo

#datasource config
#DNB_USERNAME={dnb_user}
#DNB_PASSWORD={dnb_password}
#DOWJONES_USERNAME={dowjones_user}
#DOWJONES_PASSWORD={dowjones_password}
#KYCKR_USERNAME={kyckr_user}
#KYCKR_PASSWORD={kyckr_password}
#FACTIVA_EID={factiva_eid}
#FACTIVA_NEWS_ENCRYTED_TOKEN_VALUE={factiva_news_token}
#BING_NEWS_SUBSCRIPTION_KEY_V7={bing_news_sub_key_v7}
#BING_WEB_SUBSCRIPTION_KEY_V7={bing_web_sub_key_v7}
```
4. Once all above is done, the deployer can run the script `terraform_deploy_v2.sh` to launch the deploy. The following is the usage of the script. Recommend to run `terraform_deploy_v2.sh` without `-deploy` option first, to just generate the terraform configuration files/scripts, etc. which will be located  under `/opt/<deploy_folder_name>/terraform_factory` and do a validation to see if those generated files are correct and as expected. Once confirmed everything is OK, then run `terraform_deploy_v2.sh` with `-deploy` option to really launch the deploy. 

(1). If deployer assign `-all` as the parameter of the script, a whole DD env will be launched; deployers can also assign any comibinations of individual vm to just launch some specific type(s) of VMs. For example, if deployers only assign `-km`, then only kube master vm will be provisioned, if deployers assign `-km` and `-kw`, then kube master vm and kube worker vm(s) will be provisioned.   

(2). `-ansible`: if deployer assign `-anisible`, TFD will generate an ansible hosts inventory with group names that cover each VM to be provisioned for that environment and update the [ansible-host](https://github.ibm.com/fc-cloud-ops/dev-ops-tasks/blob/master/Ansible/ansible-hosts) file on Github. This VM grouping is required to enable Ansible easy access to all VMs under the environment.

(3). `-deploy`:  if deployers don't assign `-deploy`, TFD only generates terraform configuration files/scripts under `terraform_factory` folder, and it does  NOT do the actual provision tasks; if deployers assign `-deploy` , TFD not only generates terraform configuration files/scripts, but also does the provision/customisation tasks based on the generated terraform conf and scripts. For instance, `nohup ./terraform_deploy_v2.sh -dd_all -deploy &` will launch a whole DD env's deployment.  

(4). `-zabbix`: if deployer assign `-zabbix`, TFD will call Zabbix APIs to create hosts, host groups, bind with templates, etc. It's better to run `-zabbix` after the env setup done.

(5). If vm(s) failed to be provisioned (due to host/vcsa issue most of time), the failed vm(s) need to be deleted from vcsa if there are any, and then relaunch the script with specific vm type as the parameter to reprovision it. For example, if `km` failed to be provisioned, then you can launch `./terraform_deploy_v2.sh -km` to reprovision it; However, if some vms like `kw2` or `kwdd3` vms failed to be provisioned, then you need go to the `terraform_factory` folder,  change directory to the corresponding vm's terraform folder (i.e. `cd terraform_factory/kw2`), and launch `rm terraform.tfstate; terraform plan -out=create_vm; nohup terraform apply create_vm &`

    ./terraform_deploy_v2.sh --help

    This script is used to launch FCI VMs (kube master, kube worker, hdp vms, etc) via Terraform, and do the customization (disk partition, software installation,etc) on the VMs

    Usage: ./terraform_deploy_v2.sh [OPTIONS]...[ARGS]

       -a|--all
           whether need to launch all VMs defined via Terraform

       -km|--kube_master
           whether need to launch kube master via Terraform

       -kw|--kube_worker
           whether need to launch kube worker via Terraform

       -db|--database
           whether need to launch db via Terraform

       -docreg|--docker_registry
           whether need to launch docker registry via Terraform

       -kwdd|--kube_worker_dd
           whether need to launch kube worker dd via Terraform

       -mgmt|--management
           whether need to launch management vm via Terraform

       -nfs1|--nfs1
           whether need to launch nfs1 via Terraform

       -nfs2|--nfs2
           whether need to launch nfs2 via Terraform

       -web|--web
           whether need to launch web vm via Terraform

       -wexc|--wexc
           whether need to launch wexc via Terraform

       -wexfp|--wexfp
           whether need to launch wexfp via Terraform

       -wexm|--wexm
           whether need to launch wexm via Terraform
           
       -hdpa|--hdpa"
	         whether need to launch hadoop ambari via Terraform"
    
       -hdpg|--hdpg"
	         whether need to launch hadoop gateway via Terraform"
    
       -hdpm|--hdpm"
	         whether need to launch hadoop master via Terraform"
    
       -hdps1|--hdps1"
	         whether need to launch hadoop slave1 via Terraform"
    
       -hdps2|--hdps2"
	         whether need to launch hadoop slave2 via Terraform"
    
       -hdpsec|--hdpsec"
	         whether need to launch hadoop security via Terraform"
    
       -ms|--ms"
	         whether need to launch ICP4D ms via Terraform"
    
       -wexm|--wexm"
	         whether need to launch wexm via Terraform"
	
       -ansible|--ansible"
	         whether need to generate ansible hosts file via Terraform"

       -zabbix|--zabbix"
             whether need to integrate the env with zabbix (host group creation, hosts creation, templates binding, etc)
       -deploy|--deploy
           whether launch terraform deploy or not

## ansible

TFD supports generating ansible hosts file as well, the generated ansible hosts file  will be committed to github in a pull request, once the pull request reviewed and merged by the person who has been assigned as the reviewer by you, the generated ansible hosts will be recorded in: `https://github.ibm.com/fc-cloud-ops/dev-ops-tasks/blob/master/Ansible/ansible-hosts`. Once you have configured `config/terraform.tfvars.json` and `config/custom.properties` correctly:

- change directory to the folder `{tfd_workspace_folder}`, and run `./terraform_deploy_v2.sh -ansible`, which will generate a ansible host file under folder `{tfd_workspace_folder}/utilities/ansible/TFD_Ansible_hosts/`, and will also automatically launch a Pull request to github  

Once you finish the step above, You need to check the pull request and ask someone to review the generated ansible-hosts file, once the reviewer reviewed and merged your code, the ansible-hosts file will be synced to js1 server for the future use to launch an ansible docker container.  

## zabbix

Everytime you use TFD to provision a new environment, you can consider use TFD to integrate the env with zabbix as well. Basically there are mainly 2 steps:

1. Leverage `zabbix_integration.sh` script to create zabbix host group, hosts, and bind templates with corresponding host, append host group to TIP actions for pd integration, etc.  Basically there are 2 ways to run `zabbix_integration.sh`, you can choose any of them:  
   1.1. change directory to the folder `{tfd_workspace_folder}/utilities/zabbix/` (`tfd_workspace_folder` is the folder where you use TFD to provision the environment), and run "./zabbix_integration.sh"  
   1.2. change directory to the folder `{tfd_workspace_folder}`, and run `./terraform_deploy_v2.sh -zabbix`

2. Leverage ansible to run the following 3 ansible-playbooks to deploy monitor scripts to target VMs  
   2.1. password expiry monitoring on all VMs: need to run ansible playbook `Ansible/playbooks/WFSS/wfss-chage-monitor.yml`;  
   
   2.2.kubernetes pods/nodes monitoring: need to run ansible playbook against kubernetes master vm: `Ansible/playbooks/WFSS/wfss-zabbix-k8-podnode-with-cron-job.yml`;  
   
   2.3. ldap check for management server: need to run ansible playbook against management server: `Ansible/playbooks/WFSS/wfss-zabbix-config-mgmt.yml`  
   
   Note: when leverage ansible playbooks to deploy monitor scripts to target VMs, need to follow the following steps:  
   a. Login to js1 server, and launch an ansible docker container by using `"docker run --name <ansible_container_name>  -v /srv/docker/Ansible/:/opt/ansible -it ansible"` (give a unique name for `ansible_container_name`);    
   
   b. add your private ssh key into ssh session: `ssh-add /opt/ansible/keys/<private_key_file>`;    
   
   c. make sure the environment ansible stanza exists in `/etc/ansible/hosts` file, if not exist there, you need either run the ansible script `generate_ansible_stanza.sh` to generate it, or manually create it and put it into `/etc/ansible/hosts`;  
   
   d. run the corresponding ansible playbook such as: `ansible-playbook -vvv --extra-vars "variable_host=<host_group_name>" wfss-chage-monitor.yml`, which will run the password check ansible playbook against all the vms.  

3. Add the corresponding host group into Zabbix Action `TIP.Action.ServiceNow`, `TIP.Action.ServiceNow.PagerDuty`. (Automation is not ready yet, still a little cautious about automating the last Action enablement). Detailed steps as following:   
   3.1. Login to zabbix portal, go to `Configuration -> Actions` tab, and locate the Action `TIP.Action.ServiceNow` and `TIP.Action.ServiceNow.PagerDuty`:  
   

   3.2. Click Action `TIP.Action.ServiceNow`,  `TIP.Action.ServiceNow.PagerDuty` respectively, and create a new `condition`: `"Host group"` `"equals"` the host group you want to add here. Theen click `Add` and `update` to save the changes.
  

4. Add the corresponding host group into the user group `WFSS Cloud Ops - Read Write`, which can make sure the whole team members have access to the corresponding host group. Can login  to zabbix portal and follow the following red rectangle part to add corresponding host group into the user group and then  grant the group `Read Write` permission:

5. Once step 1, 2, 3 and 4 finished, go to zabbix portal, to validate if the zabbix configuration is configured as expected; Pay attention to the alerts that could come from the environment to see if zabbix is really integrated successfully with the env.  

