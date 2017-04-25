loris-repository:
    git.latest:
        # read-only fork to cherry pick bugfixes
        - name: git@github.com:elifesciences/loris.git
        - rev: {{ salt['elife.rev']() }}
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
            - liblcms
            - liblcms-dev
            - liblcms-utils
            - liblcms2-2 
            - liblcms2-dev 
            - liblcms2-utils
            - libtiff4-dev
            - libtiff5-dev
            - libxml2-dev
            - libxslt1-dev

    cmd.run:
        - name: |
            echo "don't do anything for now"
            venv/bin/pip install Werkzeug
            venv/bin/pip install configobj
            venv/bin/pip install Pillow
            venv/bin/pip install uwsgi==2.0.14
        - cwd: /opt/loris
        - user: {{ pillar.elife.deploy_user.username }}
        - require:
            - loris-repository
            - pkg: loris-dependencies


loris-user:
    user.present: 
        - name: loris
        - shell: /sbin/false
        - home: /home/loris

loris-images-folder:
    file.directory:
        - name: /usr/local/share/images
        - user: loris

# only runs on second time?
# has to be run multiple times, unclear what it's doing
# add requires, experiment
loris-setup:
    cmd.run:
        - name: |
            venv/bin/python setup.py install
        - user: root
        - cwd: /opt/loris
        - require:
            - loris-dependencies
            - loris-user
            - loris-images-folder

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

loris-config:
    file.managed:
        - name: /etc/loris2/loris2.conf
        - source: salt://iiif/config/etc-loris2-loris2.conf
        - template: jinja
        - require:
            - loris-setup
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
        - name: /etc/loris2/uwsgi.ini
        - source: salt://iiif/config/etc-loris2-uwsgi.ini
        - require:
            - loris-setup

loris-uwsgi-log:
    file.managed:
        - name: /var/log/uwsgi-loris.log
        # don't want to lose any write to this
        - mode: 666

loris-uwsgi-ready:
    file.managed:
        - name: /etc/init/uwsgi-loris.conf
        - source: salt://iiif/config/etc-init-uwsgi-loris.conf
        - require:
            - loris-uwsgi-configuration
            - loris-uwsgi-log

    service.running:
        - name: uwsgi-loris
        - enable: True
        - restart: True
        - watch:
            - loris-repository
            - loris-dependencies
            - loris-setup
            - loris-config
            - loris-wsgi-entry-point

loris-nginx-ready:
    file.managed:
        - name: /etc/nginx/sites-enabled/loris.conf
        - source: salt://iiif/config/etc-nginx-sites-enabled-loris.conf
        - template: jinja
        - require:
            - loris-uwsgi-ready

    service.running:
        - name: nginx
        - enable: True
        - reload: True
        - watch:
            - file: loris-nginx-ready

loris-ready:
    file.managed:
        - name: /usr/local/bin/loris-smoke
        - source: salt://iiif/config/usr-local-bin-loris-smoke
        - template: jinja
        - mode: 755
        - require:
            - loris-nginx-ready

    cmd.run:
        - name: loris-smoke
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

loris-cache-clean:
    file.managed:
        - name: /usr/local/bin/loris-cache-clean
        - source: salt://iiif/config/usr-local-bin-loris-cache-clean
        - template: jinja
        - mode: 755
        - require:
            - loris-ready

    cron.absent:
        - identifier: loris-cache-clean
        - user: loris
        - require:
            - file: loris-cache-clean

loris-safe-cache-clean:
    file.managed:
        - name: /usr/local/bin/loris-safe-cache-clean
        - source: salt://iiif/config/usr-local-bin-loris-safe-cache-clean
        - template: jinja
        - mode: 755
        - require:
            - loris-cache-clean

    cron.absent:
        - identifier: loris-safe-cache-clean
        - name: /usr/local/bin/loris-safe-cache-clean
        - user: root
        #{% if salt['elife.cfg']('project.node', 1) % 2 == 1 %}
        ## odd server
        #- minute: '0,10,20,30,40,50'
        #{% else %}
        ## even server
        #- minute: '5,15,25,35,45,55'
        #{% endif %}
        - require:
            - file: loris-cache-clean

loris-cache-purge:
    file.managed:
        - name: /usr/local/bin/loris-cache-purge
        - source: salt://iiif/config/usr-local-bin-loris-cache-purge
        - template: jinja
        - mode: 755
        - require:
            - loris-ready
