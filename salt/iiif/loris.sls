


#
# 2020-03: loris.sls is being replaced by init.sls 
# the below is deprecated and will be removed once iiif is running stably in a container
# 



{% set osrelease = salt['grains.get']('osrelease') %}

# lsh 2019-03-19: what problem is this trying to solve?
# TODO: sysv init system not supported. use systemd and salt service.* states
maintenance-mode-start:
    cmd.run:
        - name: /etc/init.d/nginx stop
        - require:
            - nginx-server-service

loris-repository:
    git.latest:
        # read-only fork to cherry pick bugfixes
        - name: git@github.com:elifesciences/loris.git
        - rev: {{ salt['elife.rev'](default_branch='approved') }}
        # fixed revision with tested code
        #- rev: approved
        # main branch as of 2017-02-20
        #- rev: 400a4083c7ed20899424d4cc9922d158b3ec8f8d
        - identity: {{ pillar.elife.projects_builder.key or '' }}
        - force_fetch: True
        - force_checkout: True
        - force_reset: True
        - target: /opt/loris

    file.directory:
        - name: /opt/loris
        - user: {{ pillar.elife.deploy_user.username }}
        - group: {{ pillar.elife.deploy_user.username }}
        - recurse:
            - user
            - group
        - require:
            - git: loris-repository

    virtualenv.managed:
        - name: /opt/loris/venv
        - user: {{ pillar.elife.deploy_user.username }}
        - python: /usr/bin/python2.7

loris-dependencies:
    pkg.installed:
        - pkgs:
            - libjpeg8
            - libjpeg8-dev
            - libfreetype6
            - libfreetype6-dev
            - zlib1g-dev
            {% if osrelease == "14.04" %}
            - liblcms
            - liblcms-dev
            - liblcms-utils
            - libtiff4-dev
            {% endif %}

            - liblcms2-2 
            - liblcms2-dev 
            - liblcms2-utils
            - libtiff5-dev
            - libxml2-dev
            - libxslt1-dev

    # TODO: these requirements best live in a requirements.txt file where we can get security feedback
    cmd.run:
        - name: |
            set -e
            venv/bin/pip install Werkzeug==0.12.1
            venv/bin/pip install configobj==5.0.6
            venv/bin/pip install Pillow==4.1.0
            venv/bin/pip install uwsgi==2.0.17.1
            NEW_RELIC_EXTENSIONS=false venv/bin/pip install --no-binary :all: newrelic==2.86.0.65
        - cwd: /opt/loris
        - runas: {{ pillar.elife.deploy_user.username }}
        - require:
            - loris-repository
            - pkg: loris-dependencies

# lsh 2019-03-19: why a special 'loris' user and not www-data?
loris-user:
    user.present: 
        - name: loris
        - shell: /sbin/false
        - home: /home/loris
        - require_in:
            # see 'uwsgi' in pillar data and the builder-base-formula 'uwsgi.sls'
            # this is: uwsgi-(service-name).log
            - file: uwsgi-loris.log

loris-images-folder:
    file.directory:
        - name: /usr/local/share/images
        - user: loris

loris-setup:
    cmd.run:
        - name: |
            venv/bin/python setup.py install
        - runas: root
        - cwd: /opt/loris
        - require:
            - loris-dependencies
            - loris-user
            - loris-images-folder

loris-tmp-directory:
    file.directory:
        - name: {{ pillar.iiif.loris.storage }}/tmp
        - user: loris
        - group: loris
        - dir_mode: 755
        - makedirs: True
        - require:
            - loris-setup
            - mount-external-volume

loris-cache-general:
    file.directory:
        - name: {{ pillar.iiif.loris.storage }}/cache-general
        - user: loris
        - group: loris
        - dir_mode: 755
        - makedirs: True
        - require:
            - loris-setup
            - mount-external-volume

loris-cache-resolver:
    file.directory:
        - name: {{ pillar.iiif.loris.storage }}/cache-resolver
        - user: loris
        - group: loris
        - dir_mode: 755
        - makedirs: True
        - require:
            - loris-setup
            - mount-external-volume

# empty folder that can be synced over the caches to clean them
loris-cache-black:
    file.directory:
        - name: {{ pillar.iiif.loris.storage }}/blank
        - user: loris
        - group: loris
        - dir_mode: 755
        - makedirs: True
        - require:
            - loris-setup
            - mount-external-volume

loris-config:
    file.managed:
        - name: /etc/loris2/loris2.conf
        - source: salt://iiif/config/etc-loris2-loris2.conf
        - template: jinja
        - require:
            - loris-setup
            - loris-tmp-directory
            - loris-cache-general
            - loris-cache-resolver

loris-wsgi-entry-point:
    file.managed:
        - name: /var/www/loris2/loris2.wsgi
        - source: salt://iiif/config/var-www-loris2-loris2.wsgi
        - require:
            - loris-setup

loris-uwsgi-configuration:
    file.managed:
        {% if osrelease == "14.04" %}
        - name: /etc/loris2/uwsgi.ini
        {% else %}
        # systemd service file expects to find uwsgi.ini in app folder
        # see builder-base.uwsgi
        - name: /opt/loris/uwsgi.ini
        {% endif %}
        - source: salt://iiif/config/etc-loris2-uwsgi.ini
        - template: jinja
        - require:
            - loris-setup

# deprecated, systemd managed uwsgi will write to /var/log/uwsgi-loris.log
loris-uwsgi-log:
{% if osrelease == "14.04" %}
    file.managed:
        - name: /var/log/uwsgi-loris.log
        # don't want to lose any write to this
        - user: loris
        - group: loris
        - mode: 664
{% else %}
    # handled by state "uwsgi-$name.log" in "elife.uwsgi"
    file.exists:
        - name: /var/log/uwsgi-loris.log
        - require:
            - uwsgi-loris.log
{% endif %}

loris-application-log-directory:
    file.directory:
        - name: /var/log/loris2/
        - user: loris
        - group: loris
        - mode: 664
        - require:
            - loris-config

loris-uwsgi-upstart:
    file.managed:
        - name: /etc/init/uwsgi-loris.conf
        - source: salt://iiif/config/etc-init-uwsgi-loris.conf
        - template: jinja
        # lsh@2020-03: /etc/init doesn't exist any more in some cases
        - makedirs: True

{% if osrelease != "14.04" %}
uwsgi-loris.socket:
    service.running:
        - enable: True
        - require_in:
            - service: loris-uwsgi-ready
{% endif %}

loris-uwsgi-ready:
    service.running:
        - name: uwsgi-loris
        - enable: True
        - restart: True
        - require:
            - loris-uwsgi-upstart
            - loris-uwsgi-configuration
            - loris-uwsgi-log
            - loris-application-log-directory
        - watch:
            - loris-repository
            - loris-dependencies
            - loris-setup
            - loris-config
            - loris-wsgi-entry-point

# temporary state: remove after file is absent
# we use HSTS for the redirection, if any
# we typically have port 80 closed externally and allow unencrypted internally
loris-unencrypted-redirect:
    file.absent:
        - name: /etc/nginx/sites-enabled/unencrypted-redirect.conf

loris-nginx-ready:
    file.managed:
        - name: /etc/nginx/sites-enabled/loris.conf
        - source: salt://iiif/config/etc-nginx-sites-enabled-loris.conf
        - template: jinja
        - require:
            - loris-uwsgi-ready
            - loris-unencrypted-redirect

# TODO: sysv init system not supported. use systemd and salt service.* states
maintenance-mode-end:
    cmd.run:
        - name: /etc/init.d/nginx start
        - require:
            - file: loris-nginx-ready

# TODO: sysv init system not supported. use systemd and salt service.* states
maintenance-mode-check-nginx-stays-up:
    cmd.run:
        - name: sleep 2 && /etc/init.d/nginx status
        - require:
            - maintenance-mode-end

loris-ready:
    file.managed:
        - name: /usr/local/bin/loris-smoke
        - source: salt://iiif/config/usr-local-bin-loris-smoke
        - template: jinja
        - mode: 755
        - require:
            - maintenance-mode-check-nginx-stays-up

    cmd.run:
        - name: |
            wait_for_port 80
            loris-smoke
        - runas: {{ pillar.elife.deploy_user.username }}
        - require:
            - file: loris-ready

loris-logrotate:
    file.managed:
        - name: /etc/logrotate.d/loris
        - source: salt://iiif/config/etc-logrotate.d-loris
        - template: jinja
        - require:
            - loris-ready

# TODO: optimize with unless

loris-cache-clean-soft:
    file.managed:
        - name: /usr/local/bin/loris-cache-clean-soft
        - source: salt://iiif/config/usr-local-bin-loris-cache-clean-soft
        - template: jinja
        - mode: 755
        - require:
            - loris-ready

loris-cache-clean-hard:
    file.managed:
        - name: /usr/local/bin/loris-cache-clean-hard
        - source: salt://iiif/config/usr-local-bin-loris-cache-clean-hard
        - template: jinja
        - mode: 755
        - require:
            - loris-ready

loris-cache-clean-hard-deprecated:
    file.absent:
        - name: /usr/local/bin/loris-cache-purge
        - require:
            - loris-cache-clean-hard

loris-cache-clean:
    file.managed:
        - name: /usr/local/bin/loris-cache-clean
        - source: salt://iiif/config/usr-local-bin-loris-cache-clean
        - template: jinja
        - mode: 755
        - require:
            - loris-cache-clean-soft
            - loris-cache-clean-hard

    cron.present:
        - identifier: loris-cache-clean
        - name: /usr/local/bin/loris-cache-clean {{ pillar.iiif.loris.cache.soft_limit }} {{ pillar.iiif.loris.cache.hard_limit }}
        - user: root
        {% if salt['elife.cfg']('project.node', 1) % 2 == 1 %}
        # odd server
        - minute: '0,10,20,30,40,50'
        {% else %}
        # even server
        - minute: '5,15,25,35,45,55'
        {% endif %}
        - require:
            - file: loris-cache-clean
