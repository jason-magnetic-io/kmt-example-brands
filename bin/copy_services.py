import argparse
from distutils.dir_util import copy_tree
from os.path import isdir, isfile, join
import sys
import yaml

YAML_EXTENSIONS = ['.yml', '.yaml']
DATA_FILE_EXTENSIONS = YAML_EXTENSIONS

def check_extension(file_path, extensions):
    for extension in extensions:
        if file_path.endswith(extension):
            return True
    return False

def is_directory(directory_path):
    return isdir(directory_path)


def is_file(file_path):
    return isfile(file_path)


def is_data_file(file_path):
    return check_extension(file_path, DATA_FILE_EXTENSIONS)


def directory(astring):
    if not is_directory(astring):
        raise argparse.ArgumentTypeError(
            'directory does not exist: `{}`'.format(astring))
    return astring


def file(astring):
    if not is_file(astring):
        raise argparse.ArgumentTypeError(
            'file does not exist: `{}`'.format(astring))
    return astring


def data_file(astring):
    file(astring)
    if not is_data_file(astring):
        raise argparse.ArgumentTypeError(
            'data file must be either in json or yaml format: `{}`'.format(astring))
    return astring

def read_yaml(yaml_file_path):
    with open(yaml_file_path, 'r') as f:
        return yaml.safe_load(f)

def write_yaml(yaml_file_path, data):
    with open(yaml_file_path, 'w') as f:
        yaml.dump(data, f, default_flow_style=False)
    
def read_env_config(config_file):
    return read_yaml(config_file)
    
def write_env_config(config_file, data, updated):
		data['updated'] = updated
		write_yaml(config_file, data)
    
def parse_args():
    parser = argparse.ArgumentParser()

    parser.add_argument(
        '-c', '--config',
        type=data_file,
        help='config')

    parser.add_argument(
        '-s', '--src-path',
        type=directory,
        help='source path')

    parser.add_argument(
        '-d', '--dst-path',
        type=directory,
        help='destination path')

    args = parser.parse_args()

    return args

def copy_service_version(service, src_path, dst_path, version_prefix=""):
    src = join(src_path, join(service['name'], version_prefix + service['version']))
    dst = join(dst_path, service['name'])
    copy_tree(src, dst)
    
def main():
    args = parse_args()
    
    env_config = read_env_config(args.config)
    if env_config['updated']:
        for service in env_config['computed-services']:
            copy_service_version(service, args.src_path, args.dst_path, version_prefix="v")
        write_env_config(args.config, env_config, False)
    else:
        sys.exit(4) # nothing to copy

if __name__ == '__main__':
    main()