#!/bin/bash

source /opt/intel/compilers_and_libraries_2017.4.196/linux/mpi/intel64/bin/mpivars.sh

# Disable AVX/FMA CPU optimization warning as code is optimized for GPU
export TF_CPP_MIN_LOG_LEVEL=2

mpirun -n 8 -ppn 4 -hosts $AZ_BATCH_HOST_LIST \
  -env I_MPI_FABRICS=dapl \
  -env I_MPI_DAPL_PROVIDER=ofa-v2-ib0 \
  -env I_MPI_DYNAMIC_CONNECTION=0 \
  python $AZ_BATCHAI_INPUT_SCRIPTS/cifar10_cnn.py \
    --data-dir $AZ_BATCHAI_INPUT_DATASET \
    --model-dir $AZ_BATCHAI_OUTPUT_MODEL \
    --batch-size 64 \
    --epochs 5 \
    --verbose 1
