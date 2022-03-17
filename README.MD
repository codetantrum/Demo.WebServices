# Current Environment
- 1 Linux virtual machine serving default Apache installation to the public
- 1 bastion host for troubleshooting

# Tools Used
- OS: Mac OS X v12.2.1
- IDE: PyCharm (Community Edition)
- IaC: Azure-CLI, Terraform CLI 1.1.6, Hashicorp Cloud-init
- Remote State: Terraform Cloud

# Setup Procedure
Performing the following should be sufficient for getting
everything running. 

### Code Base Setup
`git clone git@github.com:codetantrum/Demo.WebServices.git`

### Azure Setup
1. Sign up for an Azure free trial
2. `az login`
3. `az account set --subscription [subscription id]`
4. `az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/[subscription id]`
   (save these values for next step)

### Terraform Cloud 
1. Create an organization and/or workspace ("demo" workspace used here)
2. Add environment variables in Terraform Cloud workspace for the Azure provider created above
```
ARM_CLIENT_ID="<APPID_VALUE>"
ARM_CLIENT_SECRET="<PASSWORD_VALUE>"
ARM_SUBSCRIPTION_ID="<SUBSCRIPTION_ID>"
ARM_TENANT_ID="<TENANT_VALUE>"
```
3. In main.tf, change `cloud.organization` to the correct value

### Terraform CLI Setup
1. Create an ssh keypair without a passphrase named `tf-cloud-init`
(https://github.com/hashicorp/terraform/issues/24898)
`ssh-keygen -t rsa -C ""`
2. Copy the public key to `admin_ssh_key.publickey` in main.tf
3. Copy the private key to `/terraform` and follow the instructions for setting up cloud-init
   (https://learn.hashicorp.com/tutorials/terraform/cloud-init)

# To Do
- Deploy load balancer with SSL cert in front of web server
- Add web server to scale set
- Use Packer to create custom image for use by vmss
- store pki in tf cloud
- move count to variables.tf

# current changes
added 2 backend pools (1 for each vm) *required* 
   added, but check if needed
added http load balancing rule *required* (depends on pools)
   added but may need to re-specify backend pool
added nsg and associated to snet-demo *required* 
   added, but check if failures.. not able to add subnet. only nics
created NSG any any rule for port 80 inbound *required* added