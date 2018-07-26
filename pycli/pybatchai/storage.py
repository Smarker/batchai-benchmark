import notify
from azure.mgmt.storage.models import (
    StorageAccountCreateParameters,
    Sku,
    SkuName,
    Kind
)
from azure.mgmt.storage import StorageManagementClient

def set_storage_client(context):
    if 'storage_client' not in context.obj:
        context.obj['storage_client'] = StorageManagementClient(
            credentials=context.obj['aad_credentials'],
            subscription_id=context.obj['subscription_id'])

def set_storage_account_key(context):
    storage_keys = context.obj['storage_client'].storage_accounts.list_keys(context.obj['resource_group'], context.obj['storage_account_name'])
    storage_keys = {v.key_name: v.value for v in storage_keys.keys}
    storage_account_key = storage_keys['key1']
    context.obj['storage_account_key'] = storage_account_key

def create_storage_acct_if_not_exists(context):
    availability = context.obj['storage_client'].storage_accounts.check_name_availability(context.obj['storage_account_name'])
    if not availability.name_available:
        if availability.reason.value == 'AlreadyExists':
            notify.print_already_exists('storage account')
        else:
            notify.print_create_failed('storage account', availability.message)
            return False
    else:
        context.obj['storage_client'].storage_accounts.create(
            context.obj['resource_group'],
            context.obj['storage_account_name'],
            StorageAccountCreateParameters(
                sku=Sku(SkuName.standard_ragrs),
                kind=Kind.storage,
                location=context.obj['location']
            )
        )
        notify.print_created(context.obj['storage_account_name'])

    storage_keys = context.obj['storage_client'].storage_accounts.list_keys(context.obj['resource_group'], context.obj['storage_account_name'])
    storage_keys = {v.key_name: v.value for v in storage_keys.keys}
    storage_account_key = storage_keys['key1']
    context.obj['storage_account_key'] = storage_account_key
    return True