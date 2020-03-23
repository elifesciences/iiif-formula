get-loris:
    docker_image.present:
        - name: elifesciences/loris:latest
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

# empty folder that can be synced over the caches to clean them
loris-cache-blank:
    file.directory:
        - name: {{ pillar.iiif.loris.storage }}/blank
        - user: {{ loris_user }}
        - group: {{ loris_user }}
        - dir_mode: 755
        - makedirs: True
        - require:
            - loris-user
            - mount-external-volume


# Docker needs to bind certain configuration files between host and container


loris-dir:
    file.directory:
        - user: {{ pillar.elife.deploy_user.username }}
        - name: /opt/loris

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
            
# required by newrelic-python.sls because it's using builder-private and not the formula's pillar
# todo: remove once builder-private changes are in and the service is removed
loris-uwsgi-ready:
    service.running:
        - name: nginx # could be anything that should be enabled by default

# required by newrelic-python.sls because it's using builder-private and not the formula's pillar
# todo: remove once builder-private changes are in
loris-setup:
    cmd.run:
        - name: "echo dummy state"
        - require:
            - loris-config
            - loris-newrelic-venv
            - loris-uwsgi-ready


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
        - onlyif:
            - test -d /vagrant/loris-docker

{% endif %}        

# `docker_container.running` state:
# - https://docs.saltstack.com/en/latest/ref/states/all/salt.states.docker_container.html#salt.states.docker_container.running
run-loris:
    docker_container.running:
        - name: loris
        - image: elifesciences/loris:latest
        - auto_remove: True # "Enable auto-removal of the container on daemon side when the container’s process exits"
        - hostname: {{ salt['elife.cfg']('project.full_hostname') }} # prod--iiif.elifesciences.org
        - environment:
            - NEW_RELIC_ENABLED: {{ pillar.elife.newrelic.enabled }}
        - port_bindings:
            - 5004:5004 # uwsgi
        - binds:
            # salt-rendered config
            - /opt/loris/loris2.conf:/opt/loris/etc/loris2.conf
            - /opt/loris/loris2.wsgi:/var/www/loris2/loris2.wsgi
            - /opt/loris/uwsgi.ini:/etc/loris2/uwsgi.ini
            - /opt/loris/newrelic.ini:/etc/newrelic.ini
            # directories (host:container)
            # these paths are specified in `loris2.conf`
            - {{ pillar.iiif.loris.storage }}/tmp:/tmp/loris2/tmp
            - {{ pillar.iiif.loris.storage }}/cache-resolver:/usr/local/share/images/loris
            - {{ pillar.iiif.loris.storage }}/cache-general:/var/cache/loris
            # test directory with a filesystem (fs) resolver
            - {{ pillar.iiif.loris.storage }}/test:/usr/local/share/images/loris-test
        - log_driver: syslog # previously /var/log/uwsgi.log
        - require:
            - get-loris

            - loris-cache-resolver
            - loris-cache-general
            - loris-tmp-directory
            - loris-cache-blank

            - loris-config
            - loris-newrelic-venv
            - loris-uwsgi-config
            - loris-wsgi-entry-point

            {% if pillar.elife.newrelic.enabled %}
            # ensure newrelic-python.sls has finished before we try running loris.
            # if run beforehand then the *directory* /opt/loris/newrelic.ini is created :(
            - newrelic-python-logfile-agent-in-ini-configuration
            {% endif %}


loris-nginx-ready:
    file.managed:
        - name: /etc/nginx/sites-enabled/loris.conf
        - source: salt://iiif/config/etc-nginx-sites-enabled-loris.conf
        - template: jinja
        - require:
            - run-loris
        # restart nginx if web config has changed
        - watch_in:
            - service: nginx-server-service

loris-ready:
    file.managed:
        - name: /usr/local/bin/loris-smoke
        - source: salt://iiif/config/usr-local-bin-loris-smoke
        - template: jinja
        - mode: 755
        - require:
            - loris-nginx-ready

    cmd.run:
        - name: |
            set -e
            wait_for_port 80
            loris-smoke
        - user: {{ pillar.elife.deploy_user.username }}
        - require:
            - file: loris-ready

