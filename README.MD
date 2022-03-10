# Current Environment
- 1 Linux virtual machine serving default Apache installation to the public
- 1 bastion host for troubleshooting

# Tools Used
- OS: Mac OS X v12.2.1
- IDE: PyCharm (Community Edition)
- IaC: Azure-CLI, Terraform CLI 1.1.6
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
1. Create an ssh keypair without a passphrase
(https://github.com/hashicorp/terraform/issues/24898)
`ssh-keygen -t rsa -C ""`
2. Copy the public key to `admin_ssh_key.publickey` in main.tf
3. Copy the private key to `/terraform` and update path in main.tf 
(https://github.com/hashicorp/terraform/issues/29342)

# To Do
- Deploy load balancer with SSL cert in front of web server
- Add web server to scale set
- Break out resources into seperate configs 
- Use Packer to create custom image for use in vmss
- Deploy Jenkins node 
- Leverage variables file