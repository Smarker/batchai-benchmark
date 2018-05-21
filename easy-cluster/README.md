# Provision a Cluster and Run Jobs

`easy-cluster.sh` is an interactive script to help provision Batch AI clusters.

## Provision a Cluster

```sh
./easy-cluster.sh
```

Clusters may be provisioned with:

1. Standard `NC6` Nodes
2. Standard `NC12` Nodes
3. Standard `NC24r` Nodes with `Infiniband`

## Run Jobs

The `easy-cluster.sh` script contains two training examples and will walk you]
through how to easily set them up on your own cluster:

1. `CNTK` with a `ConvNet` model on `MNIST` data
2. `Horovod` with a `CNN` model on `CIFAR-10` data

## Intel MPI

Currently, if you provision `NC24r` nodes, Batch AI will use `Intel MPI`.
You should run your training scripts with Intel's `mpirun` command.
For more information on Intel `mpirun` command, refer to its
[local options](https://software.intel.com/en-us/mpi-developer-reference-linux-local-options)
(`-n`, `-env`) and [global options](https://software.intel.com/en-us/mpi-developer-reference-linux-global-options)
(`-ppn`).