# Creating kubernetes cluster/s on AWS

# Requirements
Tool required before building the cluster are:
1. kubectl  `brew install kubectl`
command line tool for interacting with Kubernetes cluster
2. kops `brew install kops`
 The Kubernetes Operations (kops) project handles the building and operation of Kubernetes clusters on the cloud (stable support for Google Cloud and AWS)
3. terraform `brew install terraform`
 IaC tool for infrastructure state management and build/deployment
4. awscli `brew install awscli`
 AWS command line tool
5. jq `brew install jq`
 lightweight and flexible command-line JSON processor.
 

# USAGE

## 1. Configure DNS
create_cluster.sh script auto-creates dns subdomain , However before entering ssh-key password (or leave empty) make sure adding your dns ns record into your registar.

for further info you can check [DNS requirements for kops](https://kops.sigs.k8s.io/getting_started/aws/#configure-dns)
## 2. Clone this repository 

 `git clone git@github.com:laithrafid/multicloud_Terraform_kubernetes.git`

## 3. Configure script permissions and set up environment variables
```
$ chmod +x ./create_cluster.sh
$ aws configure 
```

## 4. Run create cluster script

```
$ ./create_cluster.sh $STAGE (dev|stg|prd)
```
to check the deployment run command :
```
$ kops validate cluster
```

## 5. Clean up

In case you want to destroy the cluster deployed and Pre-red run below:
```
$ ./create_cluster.sh rm $STAGE
```

# References 
* https://kops.sigs.k8s.io/gossip/
* https://kops.sigs.k8s.io/getting_started/aws/#customize-cluster-configuration
* https://github.com/dayta-ai/kubernetes-cluster-tutorial