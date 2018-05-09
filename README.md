# Training a CNN with Distributed Tensorflow on CIFAR-10 Data with BatchAI

The training script uses `Horovod` to distribute `Tensorflow` and `Keras`
 to simplify model creation.

## Download CIFAR-10 and Upload to File Share

Make sure you have `azcopy` installed on your machine. Export environment
 variables. Then, upload `CIFAR-10` data to the file share with:

```sh
upload-cifar10.sh
```

### Installing azcopy

When installing `azcopy`, if you encounter this error:

```sh
libunwind.so.8: cannot open shared object file: No such file or directory
```

Install the missing dependency with:

```sh
sudo apt-get install -y libunwind-dev
```

## Jobs

### Configure Job

In `job.json` set:

| Property  | Description |
| --------- | ----------- |
| nodeCount | Number of nodes to use in your job. |
| NUM_NODES | Use same value as `nodeCount` |
| PROCESSES_PER_NODE | Set to number of GPUs on your node. |

### Set a default resource group and location

```sh
az configure -d group=<resource group>
az configure -d location=eastus
```

### Run Job

```sh
az batchai job create \
  -c job.json \
  -n <job name> \
  -r <cluster name>
```

## Monitoring Training Performance

### View Training with Tensorboard

List nodes ips and ports

```sh
az batchai cluster list-nodes \
  -n <cluster name> \
  -o table
```

SSH into a node

```sh
ssh <node ip> -p <node port>
```

Monitor training progress by running the below command in your node:

```sh
tensorboard --logdir /mnt/batch/tasks/shared/LS_root/mounts/testdir/testdir/dist/horovod/data/logs
```

From your local machine, run this port forwarding command so you can view
tensorboard locally:

```sh
ssh -N -f -L localhost:16006:localhost:6006 $USER@<node ip> -p <node port>
```

View tensorboard graphs by navigating to `http://localhost:16006`

### View Horovod Performance with Timeline

1. Download `$AZ_BATCHAI_OUTPUT_TIMELINE/timeline.json`.
2. Open chrome and enter `chrome://tracing/`.
3. Import `timeline.json` to view the timeline

## Notes

1. Training script to be run with Batch AI: cifar10_cnn.py.
2. Original Keras based training script is: cifar10_cnn.py. Comparining the two give quick overview of what it takes to add Horovod integration.
3. Current script will be downloading data right to the node.
4. TBD: For the baselining with [CTNK training on CIFAR10](https://github.com/Azure/BatchAI/tree/master/recipes/CNTK/CNTK-GPU-Python-Distributed) dataset number of epocs and layers needs to be adjusted
