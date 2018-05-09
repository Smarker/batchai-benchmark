# Disable AVX/FMA CPU optimization warning as code is optimized for GPU
#export TF_CPP_MIN_LOG_LEVEL=2

NUM_PROCESSES=`expr $NUM_NODES \* $PROCESSES_PER_NODE`

mpirun -np $NUM_PROCESSES \
  --hostfile $AZ_BATCHAI_MPI_HOST_FILE \
  python $AZ_BATCHAI_INPUT_SCRIPTS/cifar10_cnn.py \
    --data-dir $AZ_BATCHAI_INPUT_DATASET \
    --model-dir $AZ_BATCHAI_OUTPUT_MODEL \
    --batch-size 64 \
    --epochs 5 \
    --verbose 1

#oversubscribe? - see medium