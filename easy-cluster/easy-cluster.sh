#!/bin/bash
# Interactively create a Batch AI cluster
# Author: Bruno Medina (@brusmx)
# Requirements:
# - Azure Cli >= 2.0.26
# - cut
# - SSH client 
# Example of usage: 
# chmod +x easy-cluster.sh
# ./easy-cluster.sh

set -e

readonly MIN_CLI_VERSION=2.0.26
readonly CONFIG_FILE_NAME="cluster-conf.env"
readonly SSH_PUB_LOCATION=~/.ssh/id_rsa.pub
readonly SSH_PRIV_LOCATION=~/.ssh/id_rsa

readonly CHECKS_FILE="checks.env"

# Output terminal colors
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly L_BLUE='\033[1;34m'
readonly YELLOW='\033[0;33m'
readonly GREEN='\033[0;32m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly GRAY='\033[1;37m'

readonly NC='\033[0m'

# =========================================================================
# =================== HELPER FUNCTIONS ====================================
# =========================================================================
function version_gt() { test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"; }

function write_status(){
cat <<EOT > ${CHECKS_FILE}
export SSH_OK=`echo $SSH_OK`
export CLI_OK=`echo $CLI_OK`
export AZURE_SUBSCRIPTION_ID="`echo $AZURE_SUBSCRIPTION_ID`"
export AZURE_SUBSCRIPTION_NAME="`echo $AZURE_SUBSCRIPTION_NAME`"
export PROVIDER_REGISTERED=`echo $PROVIDER_REGISTERED`
EOT
}

function clean_session(){
    export SSH_OK=
    export CLI_OK=
    export AZURE_SUBSCRIPTION_ID=
    export AZURE_SUBSCRIPTION_NAME=
    export PROVIDER_REGISTERED=
    }

function welcome () {
echo -e "${L_BLUE}"
cat << "EOF"
################################################################
#    ____        _       _          _    ___                   #
#   | __ )  __ _| |_ ___| |__      / \  |_ _|                  #
#   |  _ \ / _` | __/ __| '_ \    / _ \  | |                   #
#   | |_) | (_| | || (__| | | |  / ___ \ | |                   #
#   |____/ \__,_|\__\___|_| |_|_/_/   \_\___| _                #
#   | ____|__ _ ___ _   _   / ___| |_   _ ___| |_ ___ _ __     #
#   |  _| / _` / __| | | | | |   | | | | / __| __/ _ \ '__|    #
#   | |__| (_| \__ \ |_| | | |___| | |_| \__ \ ||  __/ |       #
#   |_____\__,_|___/\__, |  \____|_|\__,_|___/\__\___|_|       #
#                   |___/                                      #
#                                                              #
################################################################

Interactive bash script to provision an Azure Batch AI cluster
Author: Bruno Medina (@brusmx)

EOF
echo -e "${NC}"
}


# =========================================================================
# =================== REQUIREMENT CHECKS ==================================
# =========================================================================
function run_general_checks(){
    if [ -z "$SSH_OK" ]; then
        #Check if SSH was ok
        check_ssh
        export SSH_OK=1
        write_status
    fi
    if [ -z "$CLI_OK" ]; then
        #Check if CLI was ok
        check_cli
        export CLI_OK=1
        write_status
    fi
   
}

function run_sub_checks() {
    #Choose a sub
    if [ ! -z "$AZURE_SUBSCRIPTION_ID" ]; then
        #Check if sub was already selected
        local PREV_SUB_ID=$AZURE_SUBSCRIPTION_ID
        local PREV_SUB_NAME=$AZURE_SUBSCRIPTION_NAME
    else
        export PROVIDER_REGISTERED=''
        write_status
        choose_subscription
    fi


    if [ ! -z "$PREV_SUB_ID" ]; then
        echo -e "${YELLOW}- Current Azure subscription: \"${PREV_SUB_NAME}\" - (${PREV_SUB_ID})${NC}"
        local NEW_NAME=$CONFIG_FILE_NAME.BACKUP.${RANDOM:0:5}
        echo -e "  Press [${GREEN}Enter${NC}] to proceed with this subscription"
        echo -e "  ${GRAY} Or press 'n' on your keyboard to change it${NC}" 
        read -n 1 -r 
        if [ ! $REPLY == $'\x0a' ]; then
            choose_subscription
            if [ ! "$PREV_SUB_ID" == "$AZURE_SUBSCRIPTION_ID" ]; then
                export PROVIDER_REGISTERED=''
                write_status
                echo -e "${BLUE}  Saving current file as '${CLUSTER_NAME}-${CONFIG_FILE_NAME}' and starting over${NC}"
                mv $CONFIG_FILE_NAME $CLUSTER_NAME-$CONFIG_FILE_NAME
            fi 
        fi
    fi
    if [ -z "$PROVIDER_REGISTERED" ]; then
        #Check if SSH was ok
        check_providers
        export PROVIDER_REGISTERED=1
        write_status
    fi
}

function check_ssh () {
    echo -e "${YELLOW}- Checking your SSH installation ...${NC}"
    local HAS_SSH=$(which ssh)
    if [ -z "$HAS_SSH" ]; then
        echo -e "${RED}SSH was not found. You need to install SSH and create an SSH Key without passphrase.${NC}"
        exit 1
    else
        export SSH_PUB_KEY="`cat ${SSH_PUB_LOCATION}`"
        if [ -z "$SSH_PUB_KEY" ]; then
            echo -e "${YELLOW}SSH public key was not found. Creating one ...${NC}"
            ssh-keygen -b 4096 -t rsa -q -N "${USER}@$HOSTNAME" -f ~/.ssh/id_rsa
            export SSH_PUB_KEY="`cat ${SSH_PUB_LOCATION}`"
            if [ -z "$SSH_PUB_KEY" ]; then
                echo -e "${RED}ERROR. SSH key couldn't be created. Please make sure you have an SSH key created on ${NC}"
                exit 1
            fi            
        fi
        echo -e "  ${GREEN}Cool :) SSH is installed and your public key "${SSH_PUB_LOCATION}" is accessible.${NC}"
    fi
}

function check_cli () {
    # Check that Azure CLI is installed
    echo -e "${YELLOW}- Making sure you have a  new-ish Azure CLI version...${NC}"
    local AZ_CLI_VERSION=$(az --version | cut -d')' -f1 | cut -d'(' -f2 | head -1| cut -d' ' -f2)
    if [ -z "$AZ_CLI_VERSION" ]; then
        echo -e "${RED}Azure CLI version could not be retrieved. Is it installed correctly?"
        echo -e "Make sure you have latest version of the Azure CLI:"
        echo -e "${BLUE}https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest${NC}"
        exit 1
    else
        # Check Azure CLI version is new-ish
        if version_gt $MIN_CLI_VERSION $AZ_CLI_VERSION; then
            echo -e "${RED}Your version of the Azure CLI is outdated, please upade it:"
            echo -e "${BLUE}https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest${NC}"
            exit 1
        fi
        echo -e "  ${GREEN}Cool :) You have Azure CLI version: ${AZ_CLI_VERSION}${NC}"
    fi
}


function check_providers() {
    # Check that Batch and Batch AI providers are registered
    local PROVIDER1="Microsoft.Batch"
    local PROVIDER2="Microsoft.BatchAI"
    register_provider $PROVIDER1
    register_provider $PROVIDER2  
}


function register_provider(){
    echo -e "${YELLOW}- Checking if provider $1 is registered ...${NC}"
    local REGISTERED=$(az provider show -n $1 -o tsv | cut -f4)
    if [ "$REGISTERED" = "Registered" ]; then
        echo -e "  ${GREEN}${1} is '${REGISTERED}'${NC}"
    else
        echo -e "${BLUE}${1} is '${REGISTERED}'... registering${NC}"
        az provider register -n $1
    fi
}

function choose_subscription () {
    echo -e "${YELLOW}- Obtaining your Azure subsctiptions...${NC}"
    DEFAULT_ACCOUNT=`az account show -o tsv`
    DEFAULT_ACCOUNT_ID=$(printf %s "$DEFAULT_ACCOUNT" | cut -f2)
    # Check Azure is logged in
    if [ -z "$DEFAULT_ACCOUNT_ID" ]; then
        echo -e "${RED}Your subscription couldn't be found, make sure you have logged in before re-running this script.${NC}"
        exit 1
    else
        export DEFAULT_ACCOUNT_NAME=`printf %s "$DEFAULT_ACCOUNT" | cut -f4`
    echo -e "Current subscription (selected): ${BLUE}\"${DEFAULT_ACCOUNT_NAME}\"${NC} - ${GREEN}(${DEFAULT_ACCOUNT_ID})${NC}"
    echo ""
    export ACCOUNT_LIST=`az account list -o tsv`
    export ACCOUNT_LIST_ID=`printf %s "$ACCOUNT_LIST" |  cut -f2`
    export ACCOUNT_LIST_NAMES=`printf %s "$ACCOUNT_LIST" |  cut -f4`
    export ACCOUNT_LIST_SIZE=`echo "$ACCOUNT_LIST" | wc -l`
    # Ask user to select subscription
    echo "Found $ACCOUNT_LIST_SIZE enabled subscription(s) in your Azure Account:"
    echo ""
    export COUNT=1
    IFS=$'\n'
    set -f
    for line in $(printf %s "$ACCOUNT_LIST"); do
        echo -e "${COUNT}) $(printf %s "$line" | cut -f4 ) || ($(echo $line | cut -f2 ))"
        ((COUNT++))
    done
    set +f
    unset IFS
    echo ""
    echo -e "Select a subscription ${YELLOW}(1-`expr ${ACCOUNT_LIST_SIZE}`)${NC} or press [${GREEN}Enter${NC}] to continue with ${BLUE}\"${DEFAULT_ACCOUNT_NAME}\"${NC} subscription:"
    read selection
    if [ -z "$selection" ]; then
        export AZURE_SUBSCRIPTION_ID=$DEFAULT_ACCOUNT_ID
        export AZURE_SUBSCRIPTION_NAME=$DEFAULT_ACCOUNT_NAME
    elif [ "$selection" -gt 0 ] && [ "$selection" -le "${ACCOUNT_LIST_SIZE}" ]; then
        export AZURE_SUBSCRIPTION_ID=$(sed -n ${selection}p <<< "$ACCOUNT_LIST_ID")
        export AZURE_SUBSCRIPTION_NAME=$(sed -n ${selection}p <<< "$ACCOUNT_LIST_NAMES")
    else
        echo "Incorrect selection, Cluster not created"
        exit 1
    fi
        az account set -s ${AZURE_SUBSCRIPTION_ID}
        echo -e "  ${GREEN}Selected ${AZURE_SUBSCRIPTION_NAME} - (${AZURE_SUBSCRIPTION_ID})${NC}"
        


    fi
}


function reset_variables(){
export RG=
export LOC=
export RG_STATUS=
export STO_ACC_NAME=
export STO_ACC_STATUS=
export STO_FILE_SHARE=
export STO_DIR=
export STO_CONN=
export STO_FILE_SHARE_STATUS=
export STO_DIR_STATUS=
export CLUSTER_NAME=
export CLUSTER_SKU=
export CLUSTER_AGENT_COUNT=
export CLUSTER_USERNAME=
export CLUSTER_SSH_KEY=
export CLUSTER_PASSWORD=
export CLUSTER_STATUS=
export CLUSTER_IP=
export CLUSTER_AGENT_PORT=
export CLUSTER_GPU_PER_AGENT_COUNT=
}

function save_cluster_config () {

cat <<EOT > ${CONFIG_FILE_NAME}

# Resource group 
export RG="`echo $RG`"
export LOC=`echo $LOC`
export RG_STATUS="`echo $RG_STATUS`"

# Storage Account 
export STO_ACC_NAME="`echo $STO_ACC_NAME`"
export STO_ACC_STATUS="`echo $STO_ACC_STATUS`"
export STO_FILE_SHARE="`echo $STO_FILE_SHARE`"
export STO_DIR="`echo $STO_DIR`"
export STO_CONN="`echo $STO_CONN`"
export STO_FILE_SHARE_STATUS=$STO_FILE_SHARE_STATUS
export STO_DIR_STATUS=$STO_DIR_STATUS


# Batch AI cluster 
export CLUSTER_NAME="`echo $CLUSTER_NAME`"
export CLUSTER_SKU="`echo $CLUSTER_SKU`"
export CLUSTER_AGENT_COUNT=`echo $CLUSTER_AGENT_COUNT`
export CLUSTER_USERNAME="`echo $CLUSTER_USERNAME`"
export CLUSTER_SSH_KEY="`echo $CLUSTER_SSH_KEY`"
export CLUSTER_PASSWORD="`echo $CLUSTER_PASSWORD`"
export CLUSTER_STATUS="`echo $CLUSTER_STATUS`"
export CLUSTER_IP=`echo $CLUSTER_IP`
export CLUSTER_AGENT_PORT=`echo $CLUSTER_AGENT_PORT`
export CLUSTER_GPU_PER_AGENT_COUNT=`echo $CLUSTER_GPU_PER_AGENT_COUNT`

EOT


}


function create_config_file() {
    reset_variables

    echo -e "${YELLOW}- Choose one of the following VM SKUs for your cluster:${NC}"
    echo
    echo -e "  ${L_BLUE}1) Basic.${NC} Standard NC6 Nodes with standard configuration"
    echo -e "     Each node has 1 x K80 GPU Card (1/2 Physical Card)."
    echo -e "     6 Cores CPU. RAM 56 GB. 380 GB of SSD."
    echo
    echo -e "  ${BLUE}2) Medium.${NC} Standard NC12 Nodes with standard configuration"
    echo -e "     Each node has 2 x K80 GPU Card (1 Physical Card)."
    echo -e "     12 Cores CPU. RAM 112 GB. 680 GB of SSD."
    echo
    echo -e "  ${PURPLE}3) Big.${NC} Standard NC24r Nodes with Infiniband"
    echo -e "     Each node has 4 x K80 GPU Card (2 Physical Cards)."
    echo -e "     24 Cores CPU. RAM 224 GB. 1.44 TB of SSD."
    echo -e "     ${RED}*Note:${NC} ${GRAY}NC24r Batch AI Quota needs to be available on your subscription"
    echo -e "            Dedicated instances are provided through a Support Ticket.${NC}"
    echo 
    echo -e "Select an option ${BLUE}(1-3)${NC} (or press [${GREEN}Enter${NC}] to continue with a ${L_BLUE}\"Basic\"${NC} cluster):"
    read selection
    export CLUSTER_GPU_PER_AGENT_COUNT=1
    local VM_SKU="STANDARD_NC6"
    if [ ! -z "$selection" ]; then
        if [ "$selection" -gt 1 ] && [ "$selection" -le "3" ]; then
            if [ "$selection" -eq "2" ]; then
                local VM_SKU="STANDARD_NC12"
                export CLUSTER_GPU_PER_AGENT_COUNT=2
            elif [ "$selection" -eq "3" ]; then
                local VM_SKU="STANDARD_NC24r"
                export CLUSTER_GPU_PER_AGENT_COUNT=4
            fi
        fi
    fi

    echo -e "How many nodes ${BLUE}(1-50)${NC} (or press [${GREEN}Enter${NC}] to continue with the ${L_BLUE}\"2\"${NC} nodes):"
    read selection
    local NODES_QTY=2
    if [ ! -z "$selection" ]; then
        if [ "$selection" -gt 0 ] && [ "$selection" -le "51" ]; then
            local NODES_QTY=$selection
        fi
    fi
    export RG=batchai-rg-`echo ${RANDOM:0:4}`
    export LOC=eastus
    export STO_ACC_NAME=b4tch`echo ${RANDOM:0:4}`clust3r`echo ${RANDOM:0:5}`
    export STO_FILE_SHARE=external
    export STO_DIR=storagedir
    export CLUSTER_NAME=batchaicluster`echo ${RANDOM:0:4}`
    export CLUSTER_SKU=`echo ${VM_SKU}`
    export CLUSTER_AGENT_COUNT=`echo ${NODES_QTY}`
    export CLUSTER_USERNAME=`echo $USER`
    export CLUSTER_SSH_KEY="`cat ~/.ssh/id_rsa.pub`"
    export CLUSTER_PASSWORD=m1-`echo ${RANDOM:0:3}`-s3cuR3-`echo ${RANDOM:0:2}`-P4ssW0rd!
    save_cluster_config
    print_conf_file 
}


function print_conf_file() {
    reset_variables
    source $CONFIG_FILE_NAME

    echo -e "${BLUE}*****************************************************************${NC}"
    echo -e "${BLUE}**~~--         Your Batch AI cluster configuration         --~~**${NC}"
    echo -e "${BLUE}*****************************************************************${NC}"


    local CLUSTER_STATUS_TEXT="${YELLOW}Not yet provisioned${NC}"
    if [ ! -z $CLUSTER_STATUS ]; then
        local CLUSTER_STATUS_TEXT="${LBLUE}${CLUSTER_STATUS}${NC}"
        if [ "$CLUSTER_STATUS" == "steady" ]; then
            local CLUSTER_STATUS_TEXT="${GREEN}Up and ready to go${NC}"
            if [ ! -z "$CLUSTER_IP" ]; then
                local SSH_CONNECTION="  ${GREEN}ssh $CLUSTER_USERNAME@$CLUSTER_IP -p $CLUSTER_AGENT_PORT -i ${SSH_PRIV_LOCATION}${NC}" 
            fi
        fi
    fi
    echo -e "Full Cluster eployment status: "
    echo -e  $CLUSTER_STATUS_TEXT
    echo 
    echo -e "Cluster '${PURPLE}${CLUSTER_NAME}${NC}'"
    echo -e "  ${YELLOW}${CLUSTER_AGENT_COUNT}${NC} '${CYAN}${CLUSTER_SKU}${NC}' nodes"

    echo -e "VMs username:'${GRAY}${CLUSTER_USERNAME}${NC}'"
    echo -e "Root password:"
    echo -e "'${GREEN}${CLUSTER_PASSWORD}${NC}'"
    echo
    echo -e "Resource Group '${BLUE}${RG}${NC}' located in '${CYAN}${LOC}${NC}'."
    echo -e "Located in '${CYAN}${LOC}${NC}'. $RG_STATUS"
    echo
    echo -e "Storage account: '${BLUE}${STO_ACC_NAME}${NC}'"
    echo $STO_ACC_STATUS

    echo -e "File share: '${CYAN}${STO_FILE_SHARE}${NC}'. $STO_FILE_SHARE_STATUS"
    echo -e 

    echo -e "Storage Directory: '${CYAN}${STO_DIR}${NC}. $STO_DIR_STATUS"
    echo -e 

    if [ ! -f $STO_CONN ]; then
        echo -e "with connection string \"${GRAY}${STO_CONN}${NC}\"" | fold -w 65 
    fi
    echo
    echo -e "SSH public key: '${SSH_PUB_LOCATION}'" | fold -w 65 
    echo 
    echo -e $SSH_CONNECTION
    echo -e "${BLUE}*****************************************************************${NC}"

    echo
}

function check_conf_file() {
    reset_variables
    source $CONFIG_FILE_NAME
    echo -e "${YELLOW}- Checking integrity of config file ...${NC}"
    if [[ -z $RG || -z $LOC || -z $STO_ACC_NAME || -z $STO_FILE_SHARE || -z $STO_DIR || -z $CLUSTER_NAME || -z $CLUSTER_SKU || -z $CLUSTER_AGENT_COUNT || -z $CLUSTER_SSH_KEY  || -z $CLUSTER_USERNAME  || -z $CLUSTER_PASSWORD ]]; then
        echo -e "${RED} One or more variables are undefined${NC}"
        exit 1
    else
        echo -e "${GRAY}This is the last cluster configuration:${NC}"
        echo
        print_conf_file

    fi

}

function configure() {
    # Checking for previous env file
    echo -e "${YELLOW}- Checking for previous configuration file '${CONFIG_FILE_NAME}'. ${NC}"
    if [ -f $CONFIG_FILE_NAME ]; then
        echo -e "${GREEN}Found '${CONFIG_FILE_NAME}'${NC}"
        check_conf_file
        echo -e "${YELLOW}- Would you like to use this configuration to create a new cluster?${NC}"
        local NEW_NAME="${CLUSTER_NAME}-${CONFIG_FILE_NAME}"
        echo -e "  Press [${GREEN}Enter${NC}] to proceed."
        echo -e "  ${GRAY}Or press 'n' to save your current config in '${NEW_NAME}' and start a new one${NC}" 
        read -n 1 -r 
        if [ ! $REPLY == $'\x0a' ]; then
            echo -e "${BLUE}  Saving current file '${NEW_NAME}', and running the configuration tool${NC}"
            mv $CONFIG_FILE_NAME $NEW_NAME
            echo
            create_config_file
        fi
        # Source environment
        clean_session
        source ${CONFIG_FILE_NAME}
    else
        echo "  No previous configuration file found"
        echo
        create_config_file
    fi

}

function deploy() {
    echo
    echo -e "${YELLOW}- We are ready to deploy your cluster. Do you want to continue?${NC}"
    echo -e "  Press [${GREEN}Enter${NC}] to continue. Or to cancel [Ctrl] + [C]."
    read -p "  You can modify ${CONFIG_FILE_NAME} manually and restart the script" -n 1 -r
    echo -e "${NC}"
    source ${CONFIG_FILE_NAME}
    echo
    if [ ! "$RG_STATUS" == "Succeeded" ]; then
        echo -e "${YELLOW}- Creating resource group '${RG}' in '${LOC}'${NC}"
        export RG_STATUS=$(az group create --name $RG --location $LOC --query properties.provisioningState -o tsv)
        if [ -z "$RG_STATUS" ]; then
            echo -e "${RED}Error: Your resource group was not created${NC}"
            exit 1
        else
            echo -e "  ${GREEN}Created.${NC}"
        fi
        save_cluster_config
        echo
    fi
   

    if [ ! "$STO_ACC_STATUS" == "Succeeded" ]; then
        echo -e "${YELLOW}- Creating storage account '${STO_ACC_NAME}'${NC}"
        export STO_ACC_STATUS=$(az storage account create --name $STO_ACC_NAME -g $RG --sku Standard_LRS --query provisioningState -o tsv)
        if [ -z "$STO_ACC_STATUS" ]; then
            echo -e "${RED}Error: Your storage account was not created${NC}"
            exit 1
        else
            echo -e "  ${GREEN}Created.${NC}"

        fi
        save_cluster_config
        echo
    fi

    if [ -z "$STO_CONN" ]; then
        echo -e "${YELLOW}- Obtaining storage account connection string...${NC}"
        export STO_CONN=`az storage account show-connection-string -g $RG -n $STO_ACC_NAME -o tsv`
        save_cluster_config
        echo -e "${GREEN}  Exported storage account connection string to config file${NC}"
        echo
    fi

    if [ -z "$STO_FILE_SHARE_STATUS" ]; then
        echo -e "${YELLOW}- File shared '${STO_FILE_SHARE}' created?${NC}"
        export STO_FILE_SHARE_STATUS=$(az storage share create --account-name $STO_ACC_NAME --name $STO_FILE_SHARE --connection-string $STO_CONN -o tsv)
        save_cluster_config
        echo -e "  ${GREEN}${STO_FILE_SHARE_STATUS}${NC}"
        echo
    fi

    if [ -z "$STO_DIR_STATUS" ]; then
        echo -e "${YELLOW}- Directory '${STO_DIR}' created?${NC}"
        export STO_DIR_STATUS=$(az storage directory create --share-name $STO_FILE_SHARE  --name $STO_DIR --connection-string $STO_CONN -o tsv)
        echo -e "  ${GREEN}${STO_DIR_STATUS}${NC}"
        echo
    fi

    if [ -z "$CLUSTER_STATUS" ]; then
        echo -e "${YELLOW}- Create Batch AI cluster '$CLUSTER_NAME'${NC}"
        export CLUSTER_STATUS=$(az batchai cluster create --name $CLUSTER_NAME --vm-size $CLUSTER_SKU  \
        --image UbuntuLTS --min $CLUSTER_AGENT_COUNT --max $CLUSTER_AGENT_COUNT --storage-account-name $STO_ACC_NAME \
        --afs-name $STO_FILE_SHARE --afs-mount-path $STO_FILE_SHARE \
        --user-name $CLUSTER_USERNAME --ssh-key "$CLUSTER_SSH_KEY" --password $CLUSTER_PASSWORD \
        --resource-group $RG --location $LOC -o tsv | cut -f2)
        if [ "$CLUSTER_STATUS" == "resizing" ]; then
            save_cluster_config
            echo
            echo -e "  ${GREEN}Your cluster is being provisioned and currently is "${CLUSTER_STATUS}". You can re-run this script again in any time${NC}"
        else
            echo -e "${RED}ERROR:${NC} Cluster could not be provisioned"
            az batchai cluster show -n $CLUSTER_NAME -g $RG -o table --query errors
            echo
            echo -e "If you are getting quota errors for NC24r, make sure to create a support ticket in the portal with the amount of dedicated cores needed in your subscription"
            exit
        fi
    fi
}

function check_cluster() {
    echo
    echo -e "${YELLOW}- Waiting for cluster to be up and running ${NC}"
    reset_variables
    source $CONFIG_FILE_NAME
    local CLUSTER_STATUS_PREV=$CLUSTER_STATUS
    export CLUSTER_STATUS=$(az batchai cluster show -n ${CLUSTER_NAME} -g ${RG} -o tsv | cut -f2)
    echo -ne "  ${CLUSTER_STATUS}"
    while [ ! "$CLUSTER_STATUS" == "steady" ]; 
    do
        sleep 5
        echo -ne "."
        export CLUSTER_STATUS=$(az batchai cluster show -n ${CLUSTER_NAME} -g ${RG} -o tsv | cut -f2)
        if [[ ! -z "$CLUSTER_STATUS"  &&  ! "$CLUSTER_STATUS" == "$CLUSTER_STATUS_PREV" ]]; then
            echo
            echo -e "  ${GREEN}Status changed to: ${CLUSTER_STATUS}${NC}"
            save_cluster_config
        fi
    done
    echo
}

function get_connection_strings() {
    echo
    echo -e "${YELLOW}- Retrieving connection settings for a node in your cluster: '$CLUSTER_NAME' ${NC}"
    export CLUSTER_IP=`az batchai cluster list-nodes -g $RG  -n $CLUSTER_NAME --query "[0].ipAddress" -o tsv`
    echo
    echo -e "  Checking Nodes status (If they are still in 'preparing', you might not be able to deploy a job) ..."
    if [ "$CLUSTER_STATUS" == "steady" ]; then
        az batchai cluster show -g $RG  -n $CLUSTER_NAME -o table
        az batchai cluster list-nodes -g $RG  -n $CLUSTER_NAME -o table
        echo
    fi
    if [ ! -z $CLUSTER_IP ]; then
        local CLUSTER_AGENT_PORT_D=`az batchai cluster list-nodes -g $RG  -n $CLUSTER_NAME --query "[0].port" -o tsv`
        export CLUSTER_AGENT_PORT=`echo ${CLUSTER_AGENT_PORT_D%.*}`
        save_cluster_config
        echo -e "  You can connect to your cluster node with the following SSH command:"
        echo -e "  ${GREEN}ssh $CLUSTER_USERNAME@$CLUSTER_IP -p $CLUSTER_AGENT_PORT -i $SSH_PRIV_LOCATION${NC}"
        echo 
        echo -e "  Remember that the folder where the storage is mounted is the following:"
        echo -e "  cd /mnt/batch/tasks/shared/LS_root/mounts/${STO_FILE_SHARE}/${STO_DIR}"
        echo 
        echo -e "  for Azure File Shares, you can also use Azure Storage explorer with the following connection string:"
        echo -e "  "$STO_CONN
        echo
    else
        echo -e "  ${RED}ERROR: Could not retrieve the cluster public Ip${NC}"
        echo
        
    fi
}

function delete_current_resource_group() {
    echo -e "${RED}- Are you sure to delete resource group '${RG}' containing cluster '$CLUSTER_NAME' and storage account '${STO_ACC_NAME}'"
    echo -e "  ${RED}in subscription \"${AZURE_SUBSCRIPTION_NAME} - ${AZURE_SUBSCRIPTION_ID}\"?${NC}"
    read -r -p "  Type 'yes' or 'y' to confirm... " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            az group delete -n $RG -y --no-wait
            rm -rf $CONFIG_FILE_NAME
            echo -e "  ${RED}Deleting...${NC}"
            exit 1
            ;;
        *)
            cluster_options
            ;;
    esac
}



function create_horovod_job() {
    clean_session
    source $CONFIG_FILE_NAME
    #Make sure the cluster has at least one node provisioned idle with the filesystem mounted
    echo -e "${YELLOW}- Getting CIFAR 10 data set and the input scripts into  your cluster '$CLUSTER_NAME'${NC}"

    #Copy the script to download the data into the server (This should be done once per cluster)
    local AFS_DIRECTORY="/mnt/batch/tasks/shared/LS_root/mounts/${STO_FILE_SHARE}/${STO_DIR}"
    echo "scp -i $SSH_PRIV_LOCATION -o StrictHostKeyChecking=no -P $CLUSTER_AGENT_PORT horovod-cifar10-download.sh $CLUSTER_USERNAME@$CLUSTER_IP:$AFS_DIRECTORY "
    scp -i $SSH_PRIV_LOCATION -o StrictHostKeyChecking=no -P $CLUSTER_AGENT_PORT horovod-cifar10-download.sh $CLUSTER_USERNAME@$CLUSTER_IP:$AFS_DIRECTORY 
    echo
    echo -e "   Running script in cluster"
    echo -e "   ssh $CLUSTER_USERNAME@$CLUSTER_IP -p $CLUSTER_AGENT_PORT -i ${SSH_PRIV_LOCATION} \"bash ${AFS_DIRECTORY}/horovod-cifar10-download.sh ${AFS_DIRECTORY}\""
    ssh $CLUSTER_USERNAME@$CLUSTER_IP -p $CLUSTER_AGENT_PORT -i ${SSH_PRIV_LOCATION} "/bin/bash ${AFS_DIRECTORY}/horovod-cifar10-download.sh ${AFS_DIRECTORY}"

    echo 
    #Create the job.json file with the cluster configurations

    write_horovod_job
    run_job
    #Try to forward port or just print the command
}


function write_horovod_job() {
clean_session
source $CONFIG_FILE_NAME

local AFS_DIRECTORY="\$AZ_BATCHAI_MOUNT_ROOT/$STO_FILE_SHARE/$STO_DIR"

cat <<EOT > job.json
{
  "$schema": "https://raw.githubusercontent.com/Azure/BatchAI/master/schemas/2017-09-01-preview/job.json",
  "properties": {
    "nodeCount": 2,
    "environmentVariables": [
      {
        "name": "NUM_NODES", "value": "$CLUSTER_AGENT_COUNT"
      },
      {
        "name": "PROCESSES_PER_NODE", "value": "$CLUSTER_GPU_PER_AGENT_COUNT"
      },
      {
        "name": "HOROVOD_TIMELINE", "value": "\$AZ_BATCHAI_OUTPUT_TIMELINE/timeline.json"
      }
    ],
    "customToolkitSettings": {
      "commandLine": "\$AZ_BATCHAI_INPUT_SCRIPTS/run-cifar10.sh"
    },
    "stdOutErrPathPrefix": "$AFS_DIRECTORY",
    "outputDirectories": [
      {
        "id": "MODEL",
        "pathPrefix": "$AFS_DIRECTORY",
        "pathSuffix": "models"
      },
      {
        "id": "TIMELINE",
        "pathPrefix": "$AFS_DIRECTORY",
        "pathSuffix": "timelines"
      }
    ],
    "inputDirectories": [{
      "id": "DATASET",
      "path": "$AFS_DIRECTORY/horovod/data/cifar-10-batches-py"
    },{
      "id": "SCRIPTS",
      "path": "$AFS_DIRECTORY/horovod"
    }],
    "containerSettings": {
      "imageSourceRegistry": {
        "image": "tensorflow/tensorflow:1.6.0-gpu"
      }
    },
    "jobPreparation": {
      "commandLine": "\$AZ_BATCHAI_INPUT_SCRIPTS/job-prep.sh"
    }
  }
}

EOT
}

function create_sample_job() {
    clean_session
    source $CONFIG_FILE_NAME
    create_job_prep
    echo -e "${YELLOW}- Uploading job-prep.sh file to '$CLUSTER_NAME'${NC}"
    local AFS_DIRECTORY="/mnt/batch/tasks/shared/LS_root/mounts/${STO_FILE_SHARE}/${STO_DIR}"
    echo "scp -i $SSH_PRIV_LOCATION -o StrictHostKeyChecking=no -P $CLUSTER_AGENT_PORT job-prep.sh $CLUSTER_USERNAME@$CLUSTER_IP:$AFS_DIRECTORY "
    scp -i $SSH_PRIV_LOCATION -o StrictHostKeyChecking=no -P $CLUSTER_AGENT_PORT job-prep.sh $CLUSTER_USERNAME@$CLUSTER_IP:$AFS_DIRECTORY 
    echo
    write_job
    run_job
}

function run_job() {
    export JOB_NAME="sample-job-${RANDOM:0:5}"
    echo -e "${YELLOW}- Running job '$JOB_NAME' on '$CLUSTER_NAME'${NC}"
    az batchai job create -n $JOB_NAME --cluster-name $CLUSTER_NAME -c job.json -g $RG -l $LOC -o table
    echo
    echo -e "${GRAY}  You can see the progress of your job in the portal now or run the following command"
    echo -e "  az batchai job show -n sample-job-15935 -g $RG -o table"
    echo 
    echo -e "  Also, to see the STDERR of the job you can run the following command:"
    echo -e "  az batchai job file stream -n $JOB_NAME -g $RG -f stderr-job_prep.txt"
    echo 
    echo -e "  Same thing to see the STDOUT of the job:"
    echo -e "  az batchai job file stream -n $JOB_NAME -g $RG -f stdout-job_prep.txt"
    echo
    echo

}

function create_job_prep(){


cat <<EOT > job-prep.sh

#!/bin/bash
echo "Installing unzip"
apt-get update 
apt-get install -y zip dos2unix
echo "Getting the sample files"
export MOUNT_PATH=/mnt/batch/tasks/shared/LS_root/mounts/$STO_FILE_SHARE/$STO_DIR
wget https://batchaisamples.blob.core.windows.net/samples/BatchAIQuickStart.zip\?st\=2017-09-29T18%3A29%3A00Z\&se\=2099-12-31T08%3A00%3A00Z\&sp\=rl\&sv\=2016-05-31\&sr\=b\&sig\=hrAZfbZC%2BQ%2FKccFQZ7OC4b%2FXSzCF5Myi4Cj%2BW3sVZDo%3D -O BatchAIQuickStart.zip 
echo "Creating cntk_samples folder in \$MOUNT_PATH"
mkdir \$MOUNT_PATH/cntk_samples
echo "Unzip the file"
unzip -o  BatchAIQuickStart.zip -d \$MOUNT_PATH/cntk_samples
echo "Remove the zip file"
rm -rf BatchAIQuickStart.zip

EOT
}

function write_job() {
clean_session
source $CONFIG_FILE_NAME

local AFS_DIRECTORY="\$AZ_BATCHAI_MOUNT_ROOT/$STO_FILE_SHARE/$STO_DIR"

cat <<EOT > job.json

{
    "$schema": "https://raw.githubusercontent.com/Azure/BatchAI/master/schemas/2017-09-01-preview/job.json",
    "properties": {
        "nodeCount": 1,
        "cntkSettings": {
            "pythonScriptFilePath": "\$AZ_BATCHAI_INPUT_SCRIPT/ConvNet_MNIST.py",
            "commandLineArgs": "\$AZ_BATCHAI_INPUT_DATASET \$AZ_BATCHAI_OUTPUT_MODEL"
        },
        "stdOutErrPathPrefix": "$AFS_DIRECTORY",
        "inputDirectories": [{
            "id": "DATASET",
            "path": "$AFS_DIRECTORY/cntk_samples"
        }, {
            "id": "SCRIPT",
            "path": "$AFS_DIRECTORY/cntk_samples"
        }],
        "outputDirectories": [{
            "id": "MODEL",
            "pathPrefix": "$AFS_DIRECTORY",
            "pathSuffix": "Models"
        }],
        "containerSettings": {
            "imageSourceRegistry": {
                "image": "microsoft/cntk:2.1-gpu-python3.5-cuda8.0-cudnn6.0"
            }
        }
    }
}

EOT
}

function cluster_options() {

    echo -e "${YELLOW}*****************************************************************${NC}"
    echo -e "${YELLOW}**~~--               Batch AI Easy Cluster Menu            --~~**${NC}"
    echo -e "${YELLOW}*****************************************************************${NC}"

    echo -e "${YELLOW}- Options for your cluster '$CLUSTER_NAME'${NC}"
    echo
    echo -e "  ${L_BLUE}1)${NC} Print cluster information"
    echo -e "  ${L_BLUE}2)${NC} Obtain status of nodes and refresh SSH connection string"
    echo -e "  ${L_BLUE}3)${NC} Create a sample job"
    echo -e "  ${L_BLUE}4)${NC} Create a new cluster"
    echo -e "  ${L_BLUE}5)${NC} ${RED}Delete${NC} resource group with cluster and storage account"
    echo
    echo -e "Select an option (or type 'q' to exit):"
    read selection
    case $selection in
        1) 
            print_conf_file
            ;;
        2) 
            get_connection_strings
            ;;
        3) 
            job_menu
            ;;
        4) 
            echo -e "-${BLUE}Saving current file '${NEW_NAME}', and running the configuration tool${NC}"
            mv $CONFIG_FILE_NAME $CLUSTER_NAME-$CONFIG_FILE_NAME
            create_new_cluster
            ;;
        5) 
            delete_current_resource_group
            ;;
        *) # anything else
            echo "See you!"
            exit 1
            ;;
    esac

    cluster_options
}

function job_menu() {
    echo -e "${YELLOW}*****************************************************************${NC}"
    echo -e "${YELLOW}**~~--               Distributed AI sample jobs            --~~**${NC}"
    echo -e "${YELLOW}*****************************************************************${NC}"

    echo -e "${YELLOW}- Select a job to be deployed in your cluster '$CLUSTER_NAME'${NC}"
    echo
    echo -e "  ${BLUE}1)${NC} ConvNet MNIST - CNTK Sample"
    echo -e "  ${BLUE}2)${NC} Horovod + TF + Keras - CNN with CIFAR-10"
    echo
    echo -e "Select an option (or type 'q' to exit):"
    read selection
    case $selection in
        1) 
            create_sample_job
            ;;
        2) 
            create_horovod_job
            ;;
        *) # anything else
            echo "See you!"
            exit 1
            ;;
    esac

    cluster_options

}

function create_new_cluster() {
    run_sub_checks

    configure 

    deploy 

    check_cluster  

    get_connection_strings 
}

main() {
    clean_session
    #Check if general env file exists
    if [ -f $CHECKS_FILE ]; then
        source $CHECKS_FILE
    fi
    #Check if cluster config file exists
    if [ -f $CONFIG_FILE_NAME ]; then
        source $CONFIG_FILE_NAME
    fi
    welcome 

    run_general_checks 

    #If the cluster has not been deployed, lets configure all the settings
    if [ -z $CLUSTER_STATUS ]; then
        create_new_cluster
    fi

    print_conf_file

    cluster_options
}


# main() program run
main