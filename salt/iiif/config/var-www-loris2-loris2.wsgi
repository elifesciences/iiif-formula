#!/usr/bin/env python3

# I don't think this is necessary
# see /etc/loris2/uwsgi.ini
#import site;
#site.addsitedir('/opt/loris/venv/lib/python3.6/site-packages')

import newrelic.agent
from loris.webapp import create_app

# `Unsupported web frameworks` section at:
# https://docs.newrelic.com/docs/agents/python-agent/installation-configuration/python-agent-integration 
application = newrelic.agent.WSGIApplicationWrapper(create_app(config_file_path='/etc/loris2/loris2.conf'))

