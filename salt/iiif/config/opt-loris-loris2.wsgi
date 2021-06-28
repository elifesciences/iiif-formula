#!/usr/bin/env python3

import os, sys
import newrelic.agent
from loris.webapp import create_app

# lsh@2021-06-28: temporary until loris upgraded to 3.1.0+ and .conf file support exists.
# 256 million pixels is roughly 8000x8000 @ 4bytes/pixel (RGB, RGBa). default is 128000000.
# An image 2x this value (512 million pixels) will throw a `DecompressionBombError` and you'll get a 5xx.
# Setting it to `None` will cause (even longer) pauses and possible crashing via OOM killer.
from PIL import Image
Image.MAX_IMAGE_PIXELS = 256000000

application = create_app(config_file_path='/opt/loris/etc/loris2.conf')

if os.environ.get("NEW_RELIC_ENABLED", "false").lower() == "true":
    newrelic_licence_file = "/etc/newrelic.ini"
    if not os.path.exists(newrelic_licence_file):
        raise SystemExit("newrelic licence file not found: %s" % newrelic_licence_file)

    # see the `Unsupported web frameworks` section:
    # - https://docs.newrelic.com/docs/agents/python-agent/installation-configuration/python-agent-integration
    newrelic.agent.initialize(newrelic_licence_file)
    application = newrelic.agent.WSGIApplicationWrapper(application)
