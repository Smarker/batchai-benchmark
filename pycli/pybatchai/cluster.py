import notify
import azure.mgmt.batchai.models as models

def create_cluster(context):
    """Create a batchai cluster."""
    parameters = models.ClusterCreateParameters(
        vm_size=context.obj['vm_size'],
        scale_settings=models.ScaleSettings(
            manual=models.ManualScaleSettings(target_node_count=context.obj['node_count'])
        ),
        user_account_settings=models.UserAccountSettings(
            admin_user_name=context.obj['admin_username'],
            admin_user_password=context.obj['admin_password'],
            admin_user_ssh_public_key=context.obj['admin_ssh_public_key'],
        )
    )

    try:
        cluster_status = context.obj['batchai_client'].clusters.create(
            context.obj['resource_group'],
            context.obj['workspace'],
            context.obj['cluster_name'],
            parameters
        ).result()
        print(cluster_status)
    except Exception:
        notify.print_create_failed(context.obj['cluster_name'], Exception)

def monitor_cluster(context):
    """Monitor the status of your batchai cluster."""
    cluster = context.obj['batchai_client'].clusters.get(
        context.obj['resource_group'],
        context.obj['workspace'],
        context.obj['cluster_name'])
    print_cluster_status(cluster)

def print_cluster_status(cluster):
    """Print the status of your batchai cluster."""
    print(
        'Cluster state: {0} Target: {1}; Allocated: {2}; Idle: {3}; '
        'Unusable: {4}; Running: {5}; Preparing: {6}; Leaving: {7}'.format(
            cluster.allocation_state,
            cluster.scale_settings.manual.target_node_count,
            cluster.current_node_count,
            cluster.node_state_counts.idle_node_count,
            cluster.node_state_counts.unusable_node_count,
            cluster.node_state_counts.running_node_count,
            cluster.node_state_counts.preparing_node_count,
            cluster.node_state_counts.leaving_node_count))
    if not cluster.errors:
        return
    for error in cluster.errors:
        print('Cluster error: {0}: {1}'.format(error.code, error.message))
        if error.details:
            print('Details:')
            for detail in error.details:
                print('{0}: {1}'.format(detail.name, detail.value))
