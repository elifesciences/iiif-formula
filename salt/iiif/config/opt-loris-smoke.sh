#!/bin/bash

. /opt/smoke.sh/smoke.sh

smoke_url_ok "http://localhost/"
smoke_url_ok "http://localhost/ping"
smoke_report
