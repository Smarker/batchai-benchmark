#!/bin/bash

if [ ! -f "cifar-10-python.tar.gz" ]
then
  echo "Downloading cifar10..."
  wget http://www.cs.toronto.edu/~kriz/cifar-10-python.tar.gz
fi

if [ ! -d "cifar-10-batches-py" ]
then
  echo "Found cifar-10-python.tar.gz, untarring..."
  tar xzf cifar-10-python.tar.gz
fi

echo "Uploading cifar10 to storage account $STO_ACC_NAME..."
azcopy --source ./cifar-10-batches-py \
  --destination "https://$STO_ACC_NAME.file.core.windows.net/testfileshare/testdir/dist/horovod/data" \
  --dest-key $STO_ACC_KEY \
  --recursive
