import notify
from azure.mgmt.resource import ResourceManagementClient
from msrestazure.azure_cloud import AZURE_PUBLIC_CLOUD

def resource_group_exists(context):
    for item in context.obj['resource_client'].resource_groups.list():
        print(item)
    return True

def create_resource_group_if_not_exists(context):
    """Create a new resource group."""
    resource_group_name = context.obj['resource_group']
    try:
        context.obj['resource_client'] = ResourceManagementClient(
            credentials=context.obj['aad_credentials'],
            subscription_id=context.obj['subscription_id'],
            base_url=AZURE_PUBLIC_CLOUD.endpoints.resource_manager) # TODO: add to batchai
    except Exception as e:
        notify.print_create_failed(resource_group_exists, e)

    if not resource_group_exists:
        try:
            context.obj['resource_client'].resource_groups.create_or_update(resource_group_name, {'location': context.obj['location']})
            notify.print_created(resource_group_name)
        except Exception as e:
            notify.print_create_failed(resource_group_name, e)
    else:
        notify.print_already_exists(resource_group_name)