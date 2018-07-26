from setuptools import setup

setup(
    name="easycluster",
    version='0.1',
    py_modules=['hello'],
    install_requires=[
        'Click',
        'azure',
        'azure-storage',
        'colorama',
        'azure-mgmt-batchai >= 2.0.0',
        'python_version >= 3.6'
    ],
    entry_points='''
        easycluster=easycluster:cli
    '''
)