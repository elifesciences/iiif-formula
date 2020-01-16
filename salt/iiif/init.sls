# neccessary for docker_* states
# this is like the python mysql library for mysql_* Salt states
docker-py:
    cmd.run:
        - name: python3 -m pip install docker==4.1.0

loris-repository:
    git.latest:
        - name: https://github.com/elifesciences/loris-docker
        - rev: elife
        - branch: elife
        - force_fetch: True
        - force_checkout: True
        - force_reset: True
        - target: /opt/loris-docker

loris-config:
    file.managed:
        - name: /opt/loris-docker/loris2.conf
        - source: salt://iiif/config/etc-loris2-loris2.conf
        - template: jinja
        - require:
            - loris-repository

loris-uwsgi-config:
    file.managed:
        # systemd service file expects to find uwsgi.ini in app folder
        # see builder-base.uwsgi
        - name: /opt/loris-docker/uwsgi.ini
        - source: salt://iiif/config/etc-loris2-uwsgi.ini
        - template: jinja
        - require:
            - loris-repository

loris-wsgi-entry-point:
    file.managed:
        - name: /opt/loris-docker/loris2.wsgi
        - source: salt://iiif/config/var-www-loris2-loris2.wsgi
        - require:
            - loris-repository

build-loris:    
    docker_image.present:
        - name: elifesciences/loris
        - build: /opt/loris-docker/
        - tag: latest
        - require:
            - docker-py
            - loris-repository
            - loris-config
            - loris-uwsgi-config
            - loris-wsgi-entry-point
