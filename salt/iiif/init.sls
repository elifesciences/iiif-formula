get-loris:
    docker_image.present:
        - name: elifesciences/loris:latest
        - force: true # always check remote
        - require:
            - docker-ready


# loris user is deprecated in favour of www-data

{% set loris_user = pillar.elife.webserver.username %}

loris-user:
    user.present: 
        - name: {{ loris_user }}
        #- uid: ... # on vagrant this is 1003, everywhere else it's 1002. www-data is consistently uid 33
        #- shell: /sbin/false
        #- home: /home/loris
        #- createhome: False

# directories the container will have mounted

loris-tmp-directory:
    file.directory:
        - name: {{ pillar.iiif.loris.storage }}/tmp
        - user: {{ loris_user }}
        - group: {{ loris_user }}
        - dir_mode: 755
        - makedirs: True
        - require:
            - loris-user
            - mount-external-volume

loris-cache-general:
    file.directory:
        - name: {{ pillar.iiif.loris.storage }}/cache-general
        - user: {{ loris_user }}
        - group: {{ loris_user }}
        - dir_mode: 755
        - makedirs: True
        - require:
            - loris-user
            - mount-external-volume

loris-cache-resolver:
    file.directory:
        - name: {{ pillar.iiif.loris.storage }}/cache-resolver
        - user: {{ loris_user }}
        - group: {{ loris_user }}
        - makedirs: True
        - require:
            - loris-user
            - mount-external-volume

loris-log-directory:
    file.directory:
        - name: {{ pillar.iiif.loris.storage }}/log
        - user: {{ loris_user }}
        - group: {{ loris_user }}
        - makedirs: True
        - require:
            - loris-user
            - mount-external-volume


# configuration files Docker will bind between host and container


loris-dir:
    file.directory:
        - user: {{ pillar.elife.deploy_user.username }}
        - name: /opt/loris

# note: this state has a reverse requisite with newrelic-python.newrelic-python-license-configuration
# see iiif pillar builder-private
loris-config:
    file.managed:
        - user: {{ pillar.elife.deploy_user.username }}
        - name: /opt/loris/loris2.conf
        - source: salt://iiif/config/opt-loris-loris2.conf
        - template: jinja
        - makedirs: True
        - require:
            - loris-dir

# required by newrelic-python.sls as it uses the 'newrelic' installed in the venv to generate the licence file
loris-newrelic-venv:
    cmd.run:
        - cwd: /opt/loris
        - runas: {{ pillar.elife.deploy_user.username }}
        - name: |
            python3 -m venv venv
            venv/bin/pip install newrelic==5.8.0.136
        - unless:
            - test -d /opt/loris/venv


# newrelic-python.sls starts running about here


loris-uwsgi-config:
    file.managed:
        - name: /opt/loris/uwsgi.ini
        - source: salt://iiif/config/opt-loris-uwsgi.ini
        - template: jinja
        - require:
            - loris-dir

loris-wsgi-entry-point:
    file.managed:
        - name: /opt/loris/loris2.wsgi
        - source: salt://iiif/config/opt-loris-loris2.wsgi
        - require:
            - loris-dir



{% if pillar.elife.env == "dev" %}

# good for development.
# just clone or move the 'loris-docker' repository into the root of your builder installation.
build-loris:
    docker_image.present:
        - name: elifesciences/loris
        - tag: latest
        - build: /vagrant/loris-docker
        - force: true
        - require_in:
            - docker_container: run-loris
        - watch_in:
            - service: run-loris
        - onlyif:
            - test -e /vagrant/loris-docker/Dockerfile

{% endif %}

log-file-monitoring:
    file.managed:
        - name: /etc/syslog-ng/conf.d/loris.conf
        - source: salt://iiif/config/etc-syslog-ng-conf.d-loris.conf
        - template: jinja
        - require:
            - loris-log-directory
        - watch_in:
            - service: syslog-ng


loris-docker-compose-.env:
    file.managed:
        - name: /opt/loris/.env
        - source: salt://iiif/config/opt-loris-.env
        - template: jinja
        - require:
            - loris-dir

loris-docker-compose:
    file.managed:
        - name: /opt/loris/docker-compose.yaml
        - source: salt://iiif/config/opt-loris-docker-compose.yaml
        - template: jinja
        - require:
            - loris-dir

run-loris:
    file.managed:
        - name: /lib/systemd/system/iiif-service.service
        - source: salt://iiif/config/lib-systemd-system-iiif-service.service
        - template: jinja
        - require:
            - loris-docker-compose
            - loris-docker-compose-.env

    service.running:
        - name: iiif-service
        - enable: True
        - require:
            - file: run-loris

            - get-loris

            - loris-cache-resolver
            - loris-cache-general
            - loris-tmp-directory
            - loris-log-directory

            - loris-config
            - loris-newrelic-venv
            - loris-uwsgi-config
            - loris-wsgi-entry-point

            {% if pillar.elife.newrelic.enabled %}
            # ensure newrelic-python.sls has finished before we try running loris.
            # if run beforehand then the *directory* /opt/loris/newrelic.ini is created :(
            - newrelic-python-logfile-agent-in-ini-configuration
            {% endif %}
        - watch:
            # if the image has changed, restart
            - get-loris
            # if the config has changed, restart
            {% if pillar.elife.newrelic.enabled %}
            - newrelic-python-logfile-agent-in-ini-configuration
            {% endif %}
            - loris-wsgi-entry-point
            - loris-uwsgi-config
            - loris-config
            - loris-docker-compose
            - loris-docker-compose-.env


loris-nginx-ready:
    file.managed:
        - name: /etc/nginx/sites-enabled/loris-container.conf
        - source: salt://iiif/config/etc-nginx-sites-enabled-loris-container.conf
        - template: jinja
        - require:
            - loris-cleaning-complete
            - log-file-monitoring
            - run-loris
        # restart nginx if web config has changed
        - watch_in:
            - service: nginx-server-service

loris-ready:
    file.managed:
        # lsh@2020-03: replaces /usr/local/bin/loris-smoke
        - name: /opt/loris/smoke.sh
        - source: salt://iiif/config/opt-loris-smoke.sh
        - template: jinja
        - mode: 755
        - require:
            - loris-dir

    cmd.run:
        - name: |
            set -e
            wait_for_port 80
            /opt/loris/smoke.sh
        - user: {{ pillar.elife.deploy_user.username }}
        - require:
            - file: loris-ready
            - loris-nginx-ready

