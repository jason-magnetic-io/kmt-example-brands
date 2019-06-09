import argparse
import copy
import glob
import json
import ntpath
from os import listdir
from os.path import isdir, isfile, join
import yaml

JSON_EXTENSIONS = ['.json']
YAML_EXTENSIONS = ['.yml', '.yaml']
DATA_FILE_EXTENSIONS = JSON_EXTENSIONS + YAML_EXTENSIONS

RELEASE_PLAN_NOT_STARTED = 'not started'
RELEASE_PLAN_STARTED = 'started'
RELEASE_PLAN_FINISHED = 'finished'
RELEASE_PLAN_FAILED = 'failed'
RELEASE_PLAN_ABORTED = 'aborted'
RELEASE_PLAN_SKIPPED = 'skipped'
RELEASE_PLAN_PENDING = 'pending'

CAN_RELEASE = [RELEASE_PLAN_NOT_STARTED, RELEASE_PLAN_STARTED, RELEASE_PLAN_FINISHED]
CANNOT_RELEASE = [RELEASE_PLAN_FAILED, RELEASE_PLAN_ABORTED, RELEASE_PLAN_SKIPPED, RELEASE_PLAN_PENDING]

release_plan_lut = {}


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


def parse_args():
    parser = argparse.ArgumentParser()

    parser.add_argument(
        '-R', '--release-plan',
        type=data_file,
        help='release plan')

    parser.add_argument(
        '-n', '--environment-name',
        help='environment name')

    parser.add_argument(
        '-s', '--release-status',
        choices=[RELEASE_PLAN_FINISHED, RELEASE_PLAN_FAILED, RELEASE_PLAN_ABORTED, RELEASE_PLAN_SKIPPED],
        help='release status')

    args = parser.parse_args()

    return args


def read_yaml(yaml_file_path):
    with open(yaml_file_path, 'r') as f:
        return yaml.safe_load(f)


def write_yaml(yaml_file_path, data):
    with open(yaml_file_path, 'w') as f:
        yaml.dump(data, f, default_flow_style=False)


def read_json(json_file_path):
    with open(json_file_path, 'r') as f:
        return json.load(f)


def write_json(json_file_path, data):
    with open(json_file_path, 'w') as f:
        json.dump(data, f)


def read_data_file(file_path):
    if check_extension(file_path, YAML_EXTENSIONS):
        return read_yaml(file_path)
    else:
        return read_json(file_path)


def set_environment_status(environment, status):
    print('{}: status is "{}"'.format(environment['name'], status))
    environment['status'] = status


def set_group_status(group, status):
    print('group {} ({}): status is "{}"'.format(group['group'], group['name'], status))
    group['status'] = status


def set_release_place_status(release_plan, status):
    print('{} {}: status is "{}"'.format(release_plan['service']['name'], release_plan['service']['version'], status))
    release_plan['status'] = status


def update_release_group(release_plan, group):
    # check if group is 'finished'
    group_finished = True
    for environment in group['environments']:
        if not environment['status'] in [RELEASE_PLAN_FINISHED, RELEASE_PLAN_SKIPPED]:
            group_finished = False
            break
    if group_finished:
        set_group_status(group, RELEASE_PLAN_FINISHED)
        group['canStart'] = False

        # update next group and overall plan
        all_groups_finished = True
        for g in release_plan['releaseGroups']:
            if g['group'] >= group['group'] + 1 and g['status'] == RELEASE_PLAN_NOT_STARTED:
                g['canStart'] = True
                print('group {} ({}): can start'.format(g['group'], g['name']))
                all_groups_finished = False
                break
            if g['status'] != RELEASE_PLAN_FINISHED:
                all_groups_finished = False
                break
        if all_groups_finished:
            set_release_place_status(release_plan, RELEASE_PLAN_FINISHED)


def update_release_plan(environment_name, file_path, status):
    release_plan = read_json(file_path)

    if status == RELEASE_PLAN_STARTED:
        if release_plan['status'] == RELEASE_PLAN_NOT_STARTED:
            set_release_place_status(release_plan, RELEASE_PLAN_STARTED)

    for group in release_plan['releaseGroups']:
        for environment in group['environments']:
            if environment['name'] == environment_name:
                set_environment_status(environment, status)
                if status == RELEASE_PLAN_STARTED and group['status'] == RELEASE_PLAN_NOT_STARTED:
                    # mark group as started
                    set_group_status(group, RELEASE_PLAN_STARTED)
                elif status in [RELEASE_PLAN_FAILED, RELEASE_PLAN_ABORTED]:
                    # mark group as failed/aborted
                    set_group_status(group, status)
                    group['canStart'] = False
                    if status == RELEASE_PLAN_FAILED:
                        set_release_place_status(release_plan, RELEASE_PLAN_FAILED)
                elif status == RELEASE_PLAN_FINISHED:
                    update_release_group(release_plan, group)
                break
        else:
            continue
        break

    print('Updating release plan: {}'.format(file_path))
    write_json(file_path, release_plan)


def main():
    args = parse_args()

    # update the release plans
    update_release_plan(args.environment_name, args.release_plan, args.release_status)

if __name__ == '__main__':
    main()
