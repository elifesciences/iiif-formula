# neccessary for docker_* states
# this is like the python mysql library for mysql_* Salt states
docker-py:
    cmd.run:
        - name: python3 -m pip install docker==4.1.0

loris-docker-repo:
    git.latest:
        - name: https://github.com/elifesciences/loris-docker
        - rev: elife
        - branch: elife
        - force_fetch: True
        - force_checkout: True
        - force_reset: True
        - target: /opt/loris-docker

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

loris-config:
    file.managed:
        - name: /opt/loris-docker/loris2.conf
        - source: salt://iiif/config/etc-loris2-loris2.conf
        - template: jinja
        - require:
            - get-loris

loris-uwsgi-config:
    file.managed:
        # systemd service file expects to find uwsgi.ini in app folder
        # see builder-base.uwsgi
        - name: /opt/loris-docker/uwsgi.ini
        - source: salt://iiif/config/etc-loris2-uwsgi.ini
        - template: jinja
        - require:
            - get-loris

loris-wsgi-entry-point:
    file.managed:
        - name: /opt/loris-docker/loris2.wsgi
        - source: salt://iiif/config/var-www-loris2-loris2.wsgi
        - require:
            - get-loris

run-loris:
    docker_container.running:
        - name: loris--{{ pillar.elife.env }} # loris--dev, loris--prod
        - image: elifesciences/loris
        - auto_remove: True # False?
        - port_bindings:
            - 5004:5004 # uwsgi
        - binds:
            - /opt/loris-docker/loris2.conf:/opt/loris/etc/loris2.conf
            - /opt/loris-docker/loris2.wsgi:/var/www/loris2/loris2.wsgi
            - /opt/loris-docker/uwsgi.ini:/etc/loris2/uwsgi.ini
        - require:
            - docker-py
            - get-loris
            - loris-docker-repo
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

