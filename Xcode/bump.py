# -*- coding: utf-8 -*-

import os
import re
from subprocess import check_call, check_output
import sys


def ensure_repo_is_clean():
    if check_output(['git', 'status', '--porcelain']):
        _bail("There are uncommitted changes. Please commit and/or stash before continuing.")


def read_bundle_version(path):
    with open(path, 'r') as f:
        match = re.search(r'^\s*DYLIB_CURRENT_VERSION\s*=\s*(\S+)', f.read(), flags=re.MULTILINE)
    if not match:
        _bail("Could not find DYLIB_CURRENT_VERSION in {}".format(path))
    return match.group(1)


def build(bundle_version):
    return str(int(bundle_version) + 1)

def minor(bundle_version):
    return '{}00'.format(int(bundle_version[:-2]) + 1)

def major(bundle_version):
    return '{}0000'.format(int(bundle_version[:-4]) + 1)


def parse_short_version(bundle_version):
    return "{}.{}".format(int(bundle_version[:-4]), int(bundle_version[-4:-2]))


def write_versions(path, bundle_version, short_version):
    with open(path, 'r') as f:
        xcconfig = f.read()

    (xcconfig, count) = re.subn(r'^(\s*DYLIB_CURRENT_VERSION\s*=\s*)\S+',
                                r'\g<1>' + bundle_version,
                                xcconfig,
                                flags=re.MULTILINE)
    if not count:
        _bail("Could not replace DYLIB_CURRENT_VERSION with {} in {}".format(bundle_version, path))

    (xcconfig, count) = re.subn(r'^(\s*MARKETING_VERSION\s*=\s*)\S+',
                                r'\g<1>' + short_version,
                                xcconfig,
                                flags=re.MULTILINE)
    if not count:
        _bail("Could not replace MARKETING_VERSION with {} in {}".format(short_version, path))

    with open(path, 'w') as f:
        f.write(xcconfig)


def git_commit(path, bundle_version, short_version):
    check_call(['git', 'add', '--', path])
    message = "Bump version to {} ({}).".format(short_version, bundle_version)
    check_call(['git', 'commit', '-m', message])

def git_tag(bundle_version, short_version):
    beta = int(bundle_version[-2:])
    message = "Awful {} beta {}".format(short_version, beta)
    tag = "{}-beta{}".format(short_version, beta)
    check_call(['git', 'tag', '-a', '-m', message, tag])


def _bail(message):
    print(message, file=sys.stderr)
    sys.exit(1)


def bump_version(bumper):
    working_dir = os.getcwd()
    script_dir = os.path.dirname(os.path.realpath(sys.argv[0]))
    os.chdir(script_dir)

    ensure_repo_is_clean()

    xcconfig = os.path.join(script_dir, "Config", "Common.xcconfig")
    old_bundle_version = read_bundle_version(xcconfig)

    new_bundle_version = bumper(old_bundle_version)
    short_version = parse_short_version(new_bundle_version)

    write_versions(xcconfig, new_bundle_version, short_version)

    git_commit(xcconfig, new_bundle_version, short_version)
    git_tag(new_bundle_version, short_version)
    os.chdir(working_dir)
