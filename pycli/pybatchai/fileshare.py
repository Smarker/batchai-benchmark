import notify
from azure.storage.file import FileService

def set_fileshare_service(context):
    context.obj['fileshare_service'] = FileService(context.obj['storage_account_name'], context.obj['storage_account_key'])

def created_fileshare(context):
    shares = list(context.obj['fileshare_service'].list_shares(include_snapshots=True))
    return any(context.obj['fileshare_name'] == share.name for share in shares)

def create_file_share_if_not_exists(context):
    fileshare_name = context.obj['fileshare_name']
    if not created_fileshare(context):
        try:
            context.obj['fileshare_service'].create_share(fileshare_name, fail_on_exist=False)
            notify.print_created(fileshare_name)
        except Exception as e:
            notify.print_create_failed(fileshare_name, e)
            return
    else:
        notify.print_already_exists(fileshare_name)

def created_directory(context):
    directories_and_files = context.obj['fileshare_service'].list_directories_and_files(context.obj['fileshare_name'])
    return any(context.obj['fileshare_directory'] == dir_or_file.name for dir_or_file in directories_and_files)

def create_directory_if_not_exists(context):
    fileshare_directory = context.obj['fileshare_directory']
    if not created_directory(context):
        try:
            context.obj['fileshare_service'].create_directory(context.obj['fileshare_name'], fileshare_directory, fail_on_exist=False)
            notify.print_created(fileshare_directory)
        except Exception as e:
            notify.print_create_failed(fileshare_directory, e)
    else:
        notify.print_already_exists(fileshare_directory)
