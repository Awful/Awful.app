# -*- coding: utf-8 -*-

import json
import os
import plistlib
from subprocess import CalledProcessError, check_call, check_output
import sys
import time

def _notarize(zip_path, apple_id, team_id):
    try:
        return check_call(['xcrun', 'notarytool',
                           'submit',
                           '--apple-id', apple_id,
                           '--team-id', team_id,
                           '--keychain-profile', 'Awful',
                           '--wait',
                            zip_path,
                           ])
    except CalledProcessError as e:
        if e.returncode == 44:
            print(("To support scripted uploads: "
                   "obtain an app-specific password "
                   "for the Apple ID '{}', "
                   "and save it using: xcrun notarytool store-credentials Awful"
                   "").format(apple_id),
                  file=sys.stderr)
        raise


def notarize_and_staple(app_path, zip_path, apple_id, team_id):
    _notarize(zip_path, apple_id, team_id)
    check_call(['xcrun', 'stapler', 'staple', app_path])


def upload_to_app_store(ipa_path, apple_id):
    try:
        check_call(['xcrun', 'altool',
                    '--upload-app',
                    '-f', ipa_path,
                    '-t', 'ios',
                    '-u', apple_id,
                    '-p', '@keychain:Application Loader: {}'.format(apple_id),
                   ])
    except CalledProcessError as e:
        if e.returncode == 44:
            print(("To support scripted uploads: "
                   "please launch Application Loader, "
                   "sign in as '{}', "
                   "and tick 'Keep me logged in'."
                   "").format(apple_id),
                  file=sys.stderr)
        raise
