import argparse
from distutils.dir_util import copy_tree
from os.path import isdir, isfile, join
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

def get_service_versions(config):
    return read_yaml(config)
    
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

def copy_service_version(service, src_path, dst_path):
    src = join(src_path, join(service['name'], service['version']))
    dst = join(dst_path, service['name'])
    copy_tree(src, dst)
    
def main():
    args = parse_args()
    
    config = get_service_versions(args.config)
    for service in config['services']:
        copy_service_version(service, args.src_path, args.dst_path)


if __name__ == '__main__':
    main()