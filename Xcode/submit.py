# -*- coding: utf-8 -*-

from __future__ import print_function
import os
from subprocess import CalledProcessError, check_call, check_output
import sys

def find_altool():
    developer_dir = check_output(['xcode-select', '-p'])
    return os.path.join(developer_dir, 'usr', 'bin', 'altool')


def upload_to_app_store(ipa_path, apple_id_username):
    altool = find_altool()
    try:
        check_call([altool,
                    '--upload-app',
                    '-f', ipa_path,
                    '-t', 'ios',
                    '-u', apple_id_username,
                    '-p', '@keychain:Application Loader: {}'.format(apple_id_username),
                   ])
    except CalledProcessError as e:
        if e.returncode == 44:
            print(("To support scripted uploads: "
                   "please launch Application Loader, "
                   "sign in as '{}', "
                   "and tick 'Keep me logged in'."
                   "").format(apple_id_username),
                  file=sys.stderr)
        raise
