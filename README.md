# Training a CNN with Distributed Tensorflow on CIFAR-10 Data with BatchAI

The training script uses `Horovod` to distribute `Tensorflow` and `Keras`
 to simplify model creation.

## Provisioning a Cluster and Running Jobs

```sh
./easy-cluster.sh
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