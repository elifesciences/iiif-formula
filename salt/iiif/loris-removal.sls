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
] %}
loris-{{ path }}-to-be-deleted:
    file.absent:
        - name: {{ path }}
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
            # if the storage dir is there then the others will be as well
            - test -d {{ pillar.iiif.loris.storage }}

loris-cleaning-complete:
    cmd.run:
        - name: echo "loris cleanup complete"
        - require:
            - loris-dependencies
            - loris-cache-owner-changed
