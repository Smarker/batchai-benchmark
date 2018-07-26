"""For colored message printouts."""
from colorama import Fore

SUCCESS_COLOR = Fore.GREEN
FAIL_COLOR = Fore.RED

# TODO: rename file to print so its print. ----

def print_already_exists(resource_name):
    """Print if resource already exists."""
    print('{}{} already exists.'.format(SUCCESS_COLOR, resource_name))

def print_created(resource_name):
    """Print resource was successfully created."""
    print('{}Created resource {}.'.format(SUCCESS_COLOR, resource_name))

def print_create_failed(resource_name, exception):
    """Print resource was unable to be created."""
    print('{}Failed to create {}. Exception:{}'.format(FAIL_COLOR,
                                                       resource_name,
                                                       exception))
