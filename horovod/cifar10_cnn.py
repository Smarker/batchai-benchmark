'''Train a simple deep CNN on the CIFAR10 small images dataset.

It gets to 75% validation accuracy in 25 epochs, and 79% after 50 epochs.
(it's still underfitting at that point, though).
'''
from __future__ import print_function
import argparse
import glob
import math
import numpy as np
import os
import pickle

import horovod.keras as hvd
import keras
from keras import backend as K
from keras.datasets import cifar10
from keras.layers import Dense, Dropout, Activation, Flatten
from keras.layers import Conv2D, MaxPooling2D
from keras.models import Sequential
from keras.preprocessing.image import ImageDataGenerator
import tensorflow as tf

def load_cifar10_data(data_dir):
    print('Loading CIFAR-10 data...')
    cifar10_files = glob.glob(data_dir + '/data_batch_[1-6]*')
    if (len(cifar10_files) > 0):
        print('Found cifar10 in file storage, unpickling files...')
        return unpickle_cifar10_files(data_dir)
    else:
        print('Downloading cifar10 with keras...')
        return cifar10.load_data()

def unpickle_cifar10_files(data_dir):
    print('Found cifar10 files in storage. Unpickling files...')
    '''train_data shape: 50000 x 32 x 32 x 3
        test_data shape:  10000 x 32 x 32 x 3'''
    train_data = None
    train_labels = []

    for i in range(1, 6):
        data_dic = unpickle(data_dir + '/data_batch_{}'.format(i))
        if i == 1:
            train_data = data_dic['data']
        else:
            train_data = np.vstack((train_data, data_dic['data']))
        train_labels += data_dic['labels']

    test_data_dic = unpickle(data_dir + '/test_batch')
    test_data = test_data_dic['data']
    test_labels = test_data_dic['labels']

    train_data = train_data.reshape((len(train_data), 3, 32, 32))
    train_data = np.rollaxis(train_data, 1, 4)
    train_labels = np.array(train_labels)

    test_data = test_data.reshape((len(test_data), 3, 32, 32))
    test_data = np.rollaxis(test_data, 1, 4)
    test_labels = np.array(test_labels)
    return (train_data, train_labels), (test_data, test_labels)

def unpickle(file):
    '''Load byte data from file'''
    if os.path.getsize(file) > 0:
        with open(file, 'rb') as f:
            data = pickle.load(f)
            return data

def create_cnn_model(num_classes, input_shape, learning_rate):
    model = Sequential()
    model.add(Conv2D(32, (3, 3), padding='same',
                    input_shape=input_shape))
    model.add(Activation('relu'))
    model.add(Conv2D(32, (3, 3)))
    model.add(Activation('relu'))
    model.add(MaxPooling2D(pool_size=(2, 2)))
    model.add(Dropout(0.25))

    model.add(Conv2D(64, (3, 3), padding='same'))
    model.add(Activation('relu'))
    model.add(Conv2D(64, (3, 3)))
    model.add(Activation('relu'))
    model.add(MaxPooling2D(pool_size=(2, 2)))
    model.add(Dropout(0.25))

    model.add(Flatten())
    model.add(Dense(512))
    model.add(Activation('relu'))
    model.add(Dropout(0.5))
    model.add(Dense(num_classes))
    model.add(Activation('softmax'))

    # initiate RMSprop optimizer
    opt = keras.optimizers.rmsprop(lr=learning_rate, decay=1e-6)

    # Horovod: add Horovod Distributed Optimizer.
    opt = hvd.DistributedOptimizer(opt)

    # Let's train the model using RMSprop
    model.compile(loss='categorical_crossentropy',
                optimizer=opt,
                metrics=['accuracy'])
    return model

def main(data_dir, model_dir, batch_size, epochs, learning_rate, data_augmentation, verbose):
    num_classes = 10
    model_name = 'keras_cifar10_trained_model.h5'

    # Horovod: initialize Horovod.
    hvd.init()

    # Horovod: pin GPU to be used to process local rank (one GPU per process)
    config = tf.ConfigProto()
    config.gpu_options.allow_growth = True
    config.gpu_options.visible_device_list = str(hvd.local_rank())
    K.set_session(tf.Session(config=config))

    # The data, split between train and test sets:
    (x_train, y_train), (x_test, y_test) = load_cifar10_data(data_dir)

    print('x_train shape:', x_train.shape)
    print(x_train.shape[0], 'train samples')
    print(x_test.shape[0], 'test samples')

    # Convert class vectors to binary class matrices.
    y_train = keras.utils.to_categorical(y_train, num_classes)
    y_test = keras.utils.to_categorical(y_test, num_classes)

    input_shape = x_train.shape[1:]
    model = create_cnn_model(num_classes, input_shape, learning_rate)

    callbacks = [
        # Horovod: broadcast initial variable states from rank 0 to all other processes.
        # This is necessary to ensure consistent initialization of all workers when
        # training is started with random weights or restored from a checkpoint.
        hvd.callbacks.BroadcastGlobalVariablesCallback(0),
    ]
    x_train = x_train.astype('float32')
    x_test = x_test.astype('float32')
    x_train /= 255
    x_test /= 255

    # Horovod: save checkpoints only on worker 0 to prevent other workers from corrupting them.
    if hvd.rank() == 0:
        callbacks.append(keras.callbacks.ModelCheckpoint(data_dir + '/logs/checkpoint-{epoch}.h5'))
        callbacks.append(keras.callbacks.TensorBoard(data_dir + '/logs'))

    if not data_augmentation:
        print('Not using data augmentation.')
        model.fit(x_train, y_train, # TODO: add fit generator so you don't need all the data
                batch_size=batch_size,
                epochs=epochs,
                validation_data=(x_test, y_test),
                shuffle=True,
                callbacks=callbacks)
    else:
        print('Using real-time data augmentation.')
        # This will do preprocessing and realtime data augmentation:
        datagen = ImageDataGenerator(
            featurewise_center=False,  # set input mean to 0 over the dataset
            samplewise_center=False,  # set each sample mean to 0
            featurewise_std_normalization=False,  # divide inputs by std of the dataset
            samplewise_std_normalization=False,  # divide each input by its std
            zca_whitening=False,  # apply ZCA whitening
            rotation_range=0,  # randomly rotate images in the range (degrees, 0 to 180)
            width_shift_range=0.1,  # randomly shift images horizontally (fraction of total width)
            height_shift_range=0.1,  # randomly shift images vertically (fraction of total height)
            horizontal_flip=True,  # randomly flip images
            vertical_flip=False)  # randomly flip images

        # Compute quantities required for feature-wise normalization
        # (std, mean, and principal components if ZCA whitening is applied).
        datagen.fit(x_train)

        # Fit the model on the batches generated by datagen.flow().
        model.fit_generator(datagen.flow(x_train, y_train,
                                        batch_size=batch_size),
                            epochs=epochs,
                            validation_data=(x_test, y_test),
                            #workers=4,
                            callbacks = callbacks)

    # Save model and weights
    if hvd.rank() == 0:
        if not os.path.isdir(model_dir):
            os.makedirs(model_dir)
        model_path = model_dir + '/' + model_name

        print('Saving trained model at %s ' % model_path)
        model.save(model_path)

        # Score trained model.
        scores = model.evaluate(x_test, y_test, verbose=verbose)

        if verbose:
            print('Test loss:', scores[0])
            print('Test accuracy:', scores[1])

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '--data-dir',
        type=str,
        required=True,
        help='The path to the data directory'
    )
    parser.add_argument(
        '--model-dir',
        type=str,
        required=True,
        help='The path to the model directory'
    )
    parser.add_argument(
        '--batch-size',
        type=int,
        default=32,
        help='The training batch size'
    )
    parser.add_argument(
        '--epochs',
        type=int,
        default=10,
        help='The number of epochs'
    )
    parser.add_argument(
        '--learning-rate',
        type=float,
        default=0.0001,
        help='The learning rate'
    )
    parser.add_argument(
        '--data-augmentation',
        action='store_true',
        help='Use real-time data augmentation'
    )
    parser.add_argument(
        '--verbose',
        default=1,
        help='Verbosity mode (0 = silent, 1 = progress bar, 2 = one line per epoch)'
    )
    data_augmentation = False
    args = parser.parse_args()
    main(**vars(args))