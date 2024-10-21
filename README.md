# Kubernetes-Access-Control-with-RBAC-and-AWS-IAM
Limit external access to Kubernetes clusters, granting only certain permissions based on user roles access via a bastion host.

# Description
This project focuses on securing access to Kubernetes clusters by integrating Role-Based Access Control (RBAC) with AWS IAM. The solution restricts external access to Kubernetes environments, ensuring only authorized users can interact with the cluster. Access is controlled via a bastion host or VPN, limiting cluster operations based on defined user roles.

# Technologies
**Terraform v1.9.5**: For automatic provisioning and management of the required AWS resources.  

**AWS Resources**:  
VPC, Subnets (public and private)  
Internet Gateway, NAT Gateway  
EC2 (Bastion Host)  
EKS (Kubernetes Cluster)  
Security Groups (SG), IAM Roles and Policies  
Elastic IP (EIP), CloudWatch  

**AWS CLI**: To interact with AWS services from the command line (bastion).  

**kubectl CLI v1.30.2**: To manage the Kubernetes cluster via connecting to AWS CLI on the bastion.  

# Instructions  
**Prerequisites**  
1. **Terraform v1.9.5** Ensure that Terraform is installed on your local machine. You can follow the Terraform installation guide for setup.

**Setup Steps**  

2. Clone the Repository.    
```
git clone https://github.com/<your-username>/Kubernetes-Access-Control-with-RBAC-and-AWS-IAM.git
cd Kubernetes-Access-Control-with-RBAC-and-AWS-IAM/terraform_scripts
```

3. The SSH key is used to connect to the AWS bastion securely. Two keys, id_rsa as the private key and id_rsa.pub as the public key are generated. (Note: id_rsa is a default name)  
```
ssh-keygen
ls ~/.ssh
```  
4. Set up Terraform Variables. Edit the terraform.tfvars file (if required) with your AWS region, credentials, desktop IP Address, path to SSH public key pair, and any other customizable variables such as resources' names.  
5. Run the Terraform configuration in the project directory. (Note: ```terraform plan``` allows you to preview the changes that Terraform will apply to your AWS infrastructure.)  
```
terraform init
terraform plan
terraform apply -auto-approve
```
6. Connect to the Bastion Host Once the EC2 bastion host is provisioned, connect to it using SSH. To generate SSH key.(eg: bastion-host-ip: x.x.x.x/32)
   Note: bastion-host-ip is generated at the terraform apply output terminal.  
```   
ssh -i <path-to-your-private-key> ec2-user@<bastion-host-ip>
```

7. Install kubectl CLI and AWS CLI necessary to access the EKS cluster From the bastion host (EC2 instance in the public subnet). (Note: following official docs if following doesn't work as technology keeps on updating.)  
```
curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.30.2/2024-07-12/bin/linux/amd64/kubectl
chmod +x kubectl
sudo mv kubectl /usr/local/bin/kubectl
kubectl version --client
curl https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip 
sudo yum install unzip -y
mv *awscliv2.zip* awscliv2.zip
unzip awscliv2.zip
sudo ./aws/install --update
```

8. Run the following to configure AWS credentials.
```
aws configure
aws eks --region us-west-2 update-kubeconfig --name example-cluster
```

9. Create two IAM users (for example: Kad and Eva) on AWS console, with no IAM permissions assigned to them.  

10. Use the ClusterRole and ClusterRoleBinding to attach RBAC to one of the users (Note: The yaml files are set to Kad user) to test the project.  
```
kubectl apply -f ClusterRole.yaml
kubectl apply -f ClusterRoleBinding.yaml
```

# Future Enhancements
**AWS Lambda:** Automate to revoke cluster roles management tasks with AWS Lambda.  
**CI/CD with Jenkins:** Automate Terraform deployments and management via Jenkins pipelines and Golang.  
**Monitoring and Alerts:** Integrate enhanced monitoring and alerting for security and access logs.  
