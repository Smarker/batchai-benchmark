# Training a CNN with Horovod on CIFAR-10 Data with BatchAI

The `cifar10_cnn.py` training script uses
[Horovod](https://github.com/uber/horovod) to distribute `Tensorflow`
and `Keras` to simplify model creation.

## Monitor Training Performance

### View Training with Tensorboard

List nodes ips and ports:

```sh
az batchai cluster list-nodes \
  -n <cluster name> \
  -o table
```

SSH into a node:

```sh
ssh <node ip> -p <node port>
```

Monitor training progress by running the below command in your node:

```sh
tensorboard --logdir $AZ_BATCHAI_INPUT_SCRIPTS
```

From your local machine, port forward to view `tensorboard` locally:

```sh
ssh -N -f -L localhost:16006:localhost:6006 <username>@<node ip> -p <node port>
```

View `tensorboard` graphs by navigating to `http://localhost:16006`

### View Horovod Performance with Timeline

1. Download `$AZ_BATCHAI_OUTPUT_TIMELINE/timeline.json`.
2. Open chrome and enter `chrome://tracing/`.
3. Import `timeline.json` to view the timeline