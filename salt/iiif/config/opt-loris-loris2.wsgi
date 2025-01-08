#!/usr/bin/env python3

import os, sys
from loris.webapp import create_app

# lsh@2021-06-28: temporary until loris upgraded to 3.1.0+ and .conf file support exists.
# 256 million pixels is roughly 8000x8000 @ 4bytes/pixel (RGB, RGBa). default is 178956970.
# An image 2x this value (512 million pixels) will throw a `DecompressionBombError` and you'll get a 5xx.
# Setting it to `None` will cause (even longer) pauses and possible crashing via OOM killer.
from PIL import Image
Image.MAX_IMAGE_PIXELS = 256000000

loris_application = create_app(config_file_path='/opt/loris/etc/loris2.conf')

# wrap any exceptions that make it this far in a non-descriptive 500 Error
def application(environ, start_response):
    try:
        return loris_application(environ, start_response)
    except Exception:
        start_response('500 Internal Server Error', [('Content-Type', 'text/plain')])
        return ['Internal Server Error'.encode('utf-8')]
