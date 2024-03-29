#!/bin/bash
#### COLORS
RED='\033[0;31m' 
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'      
CYAN='\033[0;36m'
####RESET###
NC='\033[0;0m'
#####BOLD#####
BRED='\033[1;31m'
BGREEN='\033[1;32m'
BYELLOW='\033[1;33m'
BBLUE='\033[1;34m'
BPURPLE='\033[1;35m'      
BCYAN='\033[1;36m'
BWHITE='\033[1;37m'   
###UNDERLINE####
URED='\033[4;31m' 
UGREEN='\033[4;32m' 
UYELLOW='\033[4;33m'
UBLUE='\033[4;34m' 
UPURPLE='\033[4;35m'
UCYAN='\033[4;36m'
UWHITE='\033[4;37m'
## VARS AND CONST
DNS_ZONE=kops.yeahstah.com
REGION=$(aws configure get region)
CLUSTER_NAME="api.${DNS_ZONE}"
SSH_NAME="kops-${STAGE}ssh"
STAGE="$1"
KOPS_STATE_S3="kops-${STAGE}-unique"

echo -e "${UYELLOW}=== your current directort===$PWD ${NC}"

### Functions 

create_tfvars(){
cd modules/create/
cat << EOF > "$1".tfvars
    access_key_id="$(aws configure get aws_access_key_id)"
    secret_access_key="$(aws configure get aws_secret_access_key)"
    stage="${STAGE}"
    region="${REGION}"
    kops_state="${KOPS_STATE_S3}"
    dns="$DNS_ZONE"
EOF
cd ../../
}

run_create_module(){
  echo -e "${BLUE}==== Applying Pre-requisite Terraform ====${NC}"
  cd modules/create/
  terraform init
  terraform plan --var-file="$1".tfvars
  terraform apply -auto-approve -input=false --var-file="$1".tfvars
  cd ../../
  echo -e "${GREEN}==== Done Deploying Pre-requisite Terraform ====${NC}"
  echo ''
}
create_tfvars2(){
cd modules/create
cat << EOF > ../cluster/"$1".tfvars
    AWS_KOPS_ACCESS_KEY_ID=$(terraform output -json | jq ".id.value")
    AWS_KOPS_SECRET_ACCESS_KEY=$(terraform output -json | jq ".secret.value")
    stage="${STAGE}"
    region="${REGION}"
    kops_state="${KOPS_STATE_S3}"
    dns="$DNS_ZONE"
    nameservers=$(terraform output -json | jq ".name_servers.value")
EOF
cd ../../
}

create_ssh_key(){
  echo -e "${BLUE}==== Creating Keypair ====${NC}"
  cd modules/create/
  ssh-keygen -t rsa -C ${SSH_NAME} -f ${SSH_NAME}.pem
  PUBKEY="${SSH_NAME}".pem.pub
  aws ec2 import-key-pair --key-name "${SSH_NAME}" --public-key-material fileb://"${PUBKEY}"
  mv "${PUBKEY}" ../cluster/"${PUBKEY}"
  cd ../../
  echo -e "${GREEN}==== Done Creating Keypair ====${NC}"
  echo ''
}
create_terraform_manifest()(
  echo -e "${BLUE}==== Creating Cluster Terraform ====${NC}"
  cd modules/cluster/
  if [ ! -d data/ ]; then 
    echo -e "${BLUE}==== running kops cluster creation ====${NC}"
    kops create cluster --cloud aws --state=s3://${KOPS_STATE_S3} --node-count 3 \
    --zones ${REGION}a,${REGION}b,${REGION}d \
    --master-zones ${REGION}a,${REGION}b,${REGION}d \
    --dns-zone ${DNS_ZONE} --node-size t3.medium \
    --master-size t3.medium --topology private \
    --networking calico --ssh-public-key=${PUBKEY} \
    --bastion --authorization RBAC --out=cluster --target=terraform ${CLUSTER_NAME} 
  else 
    echo -e "${BLUE}==== running kops cluster updating ====${NC}"
    kops update cluster ${CLUSTER_NAME} --yes --state=s3://${KOPS_STATE_S3}
  fi 
  mv cluster/* . && rm -rf cluster/
  while true; do
    if [ ! -f kubernetes.tf ]; then
      echo -e "${RED} ====kubernetes.tf doesn't exist. Sleeping for 6 seconds... till it get created ${NC}"
      sleep 6
    else
      echo -e "${GREEN} ====kubernetes.tf exists. complete, starting Stage 2... ${NC}"
      cat kubernetes.tf | awk '/terraform/,/^}/{next}1' > kubernetes-terraform.tf
      break
    fi
  done
  while true; do
    if [ ! -f kubernetes-terraform.tf ]; then
      echo -e "${RED} ====kubernetes-terraform.tf doesn't exist. Sleeping for 6 seconds... till it get created ${NC}"
      sleep 6
    else
      echo -e "${GREEN} ====kubernetes-terraform.tf exists. Stage 2 complete, starting Stage 3... ${NC}"
      cat kubernetes-terraform.tf | awk '/provider/,/^}/{next}1' > kubernetes-providerless.tf
      break
    fi
  done
  while true; do
    if [ ! -f kubernetes-providerless.tf ]; then
      echo -e "${RED} ====kubernetes-providerless.tf doesn't exist. Sleeping for 6 seconds... till it get created ${NC}"
      sleep 6
    else
      echo -e "${GREEN} ====kubernetes-providerless.tf exists. Stage 3 complete, starting Stage 4... ${NC}"
      rm -rf kubernetes.tf kubernetes-terraform.tf 
      mv kubernetes-providerless.tf kubernetes.tf
      break
    fi
  done
  cd ../../
  echo -e "${GREEN}==== Done Creating Cluster Terraform ====${NC}"
  echo ''
)
deploying_cluster_to_aws(){
  echo -e "${BLUE}==== Deploying Cluster Terraform ====${NC}"
  cd modules/cluster/
  terraform init
  terraform plan --var-file="$1".tfvars 
  terraform apply -auto-approve -input=false  --var-file="$1".tfvars
  cd ../../
  echo -e "${GREEN}==== Done Deploying Cluster Terraform ====${NC}"
}
clean_up(){
  echo -e "${RED}==== Destroying Kubernetes Cluster ====${NC}"
  cd modules/cluster/ 
  terraform destroy -auto-approve --var-file="$2".tfvars
  rm -rf .terraform* "$2".tfvars ${SSH_NAME}.pem.pub Kubernetes.tf data/
  echo -e "${YELLOW}==== Done Destroying Kubernetes Cluster ====${NC}"
  cd ../create
  echo -e "${RED}==== Destroying Pre-requisite Terraform Cluster ====${NC}"
  terraform destroy -auto-approve --var-file="$2".tfvars
  rm -rf "$2".tfvars .terraform* ${SSH_NAME}.pem
  aws ec2 delete-key-pair --key-name "${SSH_NAME}"
  cd ../../
  echo -e "${YELLOW}==== Done Destroying Pre-requisite Terraform Cluster ====${NC}"
}

# Logic
case $STAGE in
  dev)
    create_tfvars $STAGE
    run_create_module $STAGE
    create_tfvars2 $STAGE
    create_ssh_key
    create_terraform_manifest
    deploying_cluster_to_aws $STAGE
    ;;
  stg)
    create_tfvars $STAGE
    run_create_module $STAGE
    create_tfvars2 $STAGE
    create_ssh_key
    create_terraform_manifest
    deploying_cluster_to_aws $STAGE
    ;;
  prd)
    create_tfvars $STAGE
    run_create_module $STAGE
    create_tfvars2 $STAGE
    create_ssh_key
    create_terraform_manifest
    deploying_cluster_to_aws $STAGE
    ;;
  rm)
    clean_up $STAGE $2
    ;;
  *)
    echo "Usage: $0 {dev|stg|prd|rm {dev|stg|prd} }"
    exit 
esac