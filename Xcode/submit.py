# -*- coding: utf-8 -*-

from __future__ import print_function
import os
from plistlib import readPlistFromString
from subprocess import CalledProcessError, check_call, check_output
import sys
import time

def _get_notarization_info(request_uuid, apple_id_username):
    return check_output(['xcrun', 'altool',
                         '--notarization-info', request_uuid,
                         '--output-format', 'xml',
                         '--asc-provider', 'NolanWaite133631772',
                         '--username', apple_id_username,
                         '--password', '@keychain:Application Loader: {}'.format(apple_id_username),
                        ])


def _notarize(zip_path, apple_id_username):
    try:
        return check_output(['xcrun', 'altool',
                             '--notarize-app',
                             '--primary-bundle-id', "com.awfulapp.Awful",
                             '--output-format', 'xml',
                             '--asc-provider', 'NolanWaite133631772',
                             '--file', zip_path,
                             '--username', apple_id_username,
                             '--password', '@keychain:Application Loader: {}'.format(apple_id_username),
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


def notarize_and_staple(app_path, zip_path, apple_id_username):
    upload_output = _notarize(zip_path, apple_id_username)
    upload_plist = readPlistFromString(upload_output)

    request_uuid = upload_plist['notarization-upload']['RequestUUID']
    while True:
        info_output = _get_notarization_info(request_uuid, apple_id_username)
        info_plist = readPlistFromString(info_output)
        status = info_plist['notarization-info']['Status']
        if status == "in progress":
            time.sleep(60)
        else:
            break

    if status != "success":
        print(info_output, file=sys.stderr)
        raise Exception("Notarization failed")

    check_call(['xcrun', 'stapler', 'staple', app_path])


def upload_to_app_store(ipa_path, apple_id_username):
    try:
        check_call(['xcrun', 'altool',
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
