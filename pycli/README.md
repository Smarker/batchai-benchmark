# easycluster

A python cli tool to work with batch ai resources

## install pip packages

```sh
install.sh
```

## usage

Create a fileshare directory to store errors and logs from your cluster.

```sh
pybatchai \
--subscription-id <sub id> \
--aad-client-id <aad client id> \
--aad-secret-key <aad key> \
--aad-tenant-id <aad tenant id> \
--resource-group-name <rg name> \
--location <location> \
storage \
--storage-account-name <storage acct name> \
fileshare \
--fileshare-name <file share name> \
directory \
--directory-name <file share directory> \
create
```

Create a cluster.

```sh
pybatchai \
--subscription-id <sub id> \
--aad-client-id <aad client id> \
--aad-secret-key <aad key> \
--aad-tenant-id <aad tenant id> \
--resource-group-name <rg name> \
--location <location> \
cluster \
create \
--cluster-name \
<cluster name> \
--node-count <node count> \
--vm-size <vm size> \
--admin-username <username> \
--admin-password <password> \
--admin-ssh-public-key <ssh key> \
--workspace steph-ws \
--storage-account-name <storage acct name> \
--fileshare-name <file share name>
```

## hierarchy

```sh
pybatchai
  cluster
    create
    monitor
  storage
    fileshare
      create
      directory
        create
  job
    create
```

## known issues

`Keyring cache token has failed: (1783, 'CredWrite', 'The stub received bad data')`