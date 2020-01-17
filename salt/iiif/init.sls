# neccessary for docker_* states
# this is like the python mysql library for mysql_* Salt states
docker-py:
    pip.installed:
        - name: docker==4.1.0

# todo: temporary. remove once image in repo
loris-docker-repo:
    git.latest:
        - name: https://github.com/elifesciences/loris-docker
        - rev: elife
        - branch: elife
        - force_fetch: True
        - force_checkout: True
        - force_reset: True
        - target: /opt/loris-docker

# should match the id of the user in the container
# TODO: stick into pillar
{% set loris_user_id = 1005 %}

loris-user:
    user.present: 
        - name: loris
        - uid: {{ loris_user_id }}
        - shell: /sbin/false
        - home: /nonexistent
        - createhome: False

# directories the container will have mounted

loris-tmp-directory:
    file.directory:
        - name: {{ pillar.iiif.loris.storage }}/tmp
        - user: loris
        - group: loris
        - dir_mode: 755
        - makedirs: True
        - require:
            - loris-user
            - mount-external-volume

loris-cache-general:
    file.directory:
        - name: {{ pillar.iiif.loris.storage }}/cache-general
        - user: loris
        - group: loris
        - dir_mode: 755
        - makedirs: True
        - require:
            - loris-user
            - mount-external-volume

loris-cache-resolver:
    file.directory:
        - name: {{ pillar.iiif.loris.storage }}/cache-resolver
        - user: loris
        - group: loris
        - require:
            - loris-user
            - mount-external-volume

# empty folder that can be synced over the caches to clean them
loris-cache-blank:
    file.directory:
        - name: {{ pillar.iiif.loris.storage }}/blank
        - user: loris
        - group: loris
        - dir_mode: 755
        - makedirs: True
        - require:
            - loris-user
            - mount-external-volume


# loris is built using the *default* loris config in the `loris-docker` repo.
# those default config files are overridden below when the *formula* loris config
# files are mounted/bound just before running image.
# TODO: don't build here, just pull from repo
get-loris:
    docker_image.present:
        - name: elifesciences/loris
        - build: /opt/loris-docker/
        - tag: latest
        - require:
            - loris-docker-repo
        # build image if repo changes
        # TODO: remove once we're pulling image from docker directly
        - watch:
            - loris-docker-repo

# Docker needs to bind certain configuration files between host and container
# this is where you put them
loris-dir:
    file.directory:
        - name: /opt/loris

loris-config:
    file.managed:
        - name: /opt/loris/loris2.conf
        - source: salt://iiif/config/etc-loris2-loris2.conf
        - template: jinja
        - makedirs: True
        - require:
            - loris-dir

loris-uwsgi-config:
    file.managed:
        # systemd service file expects to find uwsgi.ini in app folder
        # see builder-base.uwsgi
        - name: /opt/loris/uwsgi.ini
        - source: salt://iiif/config/etc-loris2-uwsgi.ini
        - template: jinja
        - require:
            - loris-dir

loris-wsgi-entry-point:
    file.managed:
        - name: /opt/loris/loris2.wsgi
        - source: salt://iiif/config/var-www-loris2-loris2.wsgi
        - require:
            - loris-dir

run-loris:
    docker_container.running:
        - name: loris--{{ pillar.elife.env }} # loris--dev, loris--prod
        - image: elifesciences/loris
        - auto_remove: True # False?
        - port_bindings:
            - 5004:5004 # uwsgi
        - binds:
            # rendered config
            - /opt/loris/loris2.conf:/opt/loris/etc/loris2.conf
            - /opt/loris/loris2.wsgi:/var/www/loris2/loris2.wsgi
            - /opt/loris/uwsgi.ini:/etc/loris2/uwsgi.ini
            # directories
            # these paths are specified in `loris2.conf`
            - {{ pillar.iiif.loris.storage }}/cache-resolver:/usr/local/share/images/loris
            - {{ pillar.iiif.loris.storage }}/cache-general:/var/cache/loris
        - require:
            - docker-py
            - get-loris

            - loris-cache-resolver
            - loris-cache-general
            - loris-tmp-directory
            - loris-cache-blank

            - loris-docker-repo # temp
            - loris-config
            - loris-uwsgi-config
            - loris-wsgi-entry-point

loris-nginx-ready:
    file.managed:
        - name: /etc/nginx/sites-enabled/loris.conf
        - source: salt://iiif/config/etc-nginx-sites-enabled-loris.conf
        - template: jinja
        - require:
            - run-loris
        # restart nginx (later) if web config has changed
        - listen_in:
            - service: nginx-server-service

