# Interactive deployment

You can also use our easy cluster script to provision a cluster on Azure Batch AI and run the horovod training model on it.
Just follow these simple steps.

## Use the right tooling

The following script is only supported on bash. This script have been proven to run on Mac OS X, [Ubuntu on Windows](https://docs.microsoft.com/en-us/windows/wsl/install-win10) or [Azure Cloud Shell](https://shell.azure.com/).
If you have a Windows PC that doesn't have or supports ubuntu bash, the recommended way to use the script is through the [Azure Cloud Shell](https://shell.azure.com/).
In addition to bash, you need the [Azure Cli](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest) installed and Open SSH client (`sudo apt install openssh-client`).

Now, let's download the latest version of the script from this repo. I believe most OS have curl out of the box, so you can use the following command or instead you can use wget. Also, if you git cloned this repo, just make sure to go to the `easy-cluster` folder in the repository and give it execution permissions, you dont need to download the file, you already have it.

```bash
#Let's create a folder to work in.
mkdir easy-cluster
cd easy-cluster
#Download the script
curl -o easy-cluster.sh -O  -J -L https://aka.ms/easy-cluster-batchai 
#Giv it execution permissions
chmod +x easy-cluster.sh
```

## Run the script

Now to run the script, make sure you are in the same directory where the script was downloaded.
And run the following command:

```bash
./easy-cluster
```

1. Let the script verify your current environment and choose the subscription where you want your cluster to be deployed.
2. Choose a size for your cluster, remember that to be able to get the NC24 you need to have quota available in your selected subscription. That implies creating a support ticket to the Batch team asking for the amount of dedicated VMs of NC24 that suit your need.
3. 