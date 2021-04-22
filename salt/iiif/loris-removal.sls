uwsgi-loris-is-dead:
    service.dead:
        - enable: false
        - name: uwsgi-loris

uwsgi-loris-socket-is-dead:
    service.dead:
        - enable: false
        - name: uwsgi-loris.socket

{% for path in [
    "/etc/loris2/loris2.conf", 
    "/var/www/loris2/loris2.wsgi", 
    "/var/log/uwsgi-loris.log", 
    "/var/log/loris2",
    "/etc/init/uwsgi-loris.conf",
    "/etc/nginx/sites-enabled/unencrypted-redirect.conf",
    "/etc/logrotate.d/loris",
    "/etc/nginx/sites-enabled/loris.conf",
    "/usr/local/bin/loris-smoke",
    "/lib/systemd/system/uwsgi-loris.service",
    "/lib/systemd/system/uwsgi-loris.socket"
] %}
loris-{{ path }}-to-be-deleted:
    file.absent:
        - name: {{ path }}
        - require:
            - uwsgi-loris-is-dead
            - uwsgi-loris-socket-is-dead
        - require_in:
            - loris-cleaning-complete
{% endfor %}

loris-dependencies:
    pkg.purged:
        - pkgs:
            #- libjpeg8 # dependency of nginx
            - libjpeg8-dev
            #- libfreetype6 # dependency of nginx
            - libfreetype6-dev
            - zlib1g-dev
            - liblcms2-2 
            - liblcms2-dev 
            - liblcms2-utils
            - libtiff5-dev
            - libxml2-dev
            - libxslt1-dev

loris-cache-owner-changed:
    cmd.run:
        - name: |
            set -e
            cd {{ pillar.iiif.loris.storage }}
            chown www-data:www-data -R cache-resolver cache-general tmp
            touch /root/loris-cache-owner-changed.flag
        - creates: /root/loris-cache-owner-changed.flag
        - onlyif:
            - test -d {{ pillar.iiif.loris.storage }}/cache-resolver || test -d {{ pillar.iiif.loris.storage }}/cache-general || test -d {{ pillar.iiif.loris.storage }}/tmp

loris-cleaning-complete:
    cmd.run:
        - name: echo "loris cleanup complete"
        - require:
            - loris-dependencies
            - loris-cache-owner-changed
