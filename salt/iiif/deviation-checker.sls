# the deviation checker is a script that checks the original image against those derived from IIIF

include:
- iiif

extend:
    loris-nginx-ready:
        file.managed:
            - name: /etc/nginx/sites-enabled/loris-container.conf
            - source: salt://iiif/config/etc-nginx-sites-enabled-loris-container.conf.devchk
            - template: jinja

    #loris-uwsgi-config:
    #    file.managed:
    #        - name: /opt/loris/uwsgi.ini
    #        - source: salt://iiif/config/opt-loris-uwsgi.ini.devchk
    #        - template: jinja

install-deps:
    pkg.installed:
        - pkgs:
            - imagemagick
            - python3.8
            - python3.8-venv

remove-leiningen:
    file.absent:
        - name: /bin/lein
        
remove-old-checker:
    file.absent:
        - name: /opt/elife-iiif-deviation-checker

install-checker:

    file.directory:
        - name: /opt/iiif-deviation-checker
        - user: {{ pillar.elife.deploy_user.username }}
        - group: {{ pillar.elife.deploy_user.username }}

    builder.git_latest:
        - name: git@github.com:elifesciences/iiif-deviation-checker.git
        - identity: {{ pillar.elife.projects_builder.key or '' }}
        - rev: develop
        - branch: develop
        - target: /opt/iiif-deviation-checker
        - user: {{ pillar.elife.deploy_user.username }}
        - require:
            - file: install-checker

    cmd.run:
        - user: {{ pillar.elife.deploy_user.username }}
        - cwd: /opt/iiif-deviation-checker
        - name: ./install.sh
        - require:
            - builder: install-checker

disable-iiif-caching:
    cmd.run:
        - runas: {{ pillar.elife.deploy_user.username }}
        - name: ./disable-loris-caching.sh
        - name: |
            sed --in-place 's/enable_caching = True/enable_caching = False/g' /opt/loris/loris2.conf
        - require:
            - loris-ready
        - listen_in:
            - service: run-loris

# see `loris-maintenance.sls`
# this restarts the service and interferes with the testing.
disable-loris-cache-clean:
    cron.absent:
        - identifier: loris-cache-clean
        - require:
            - loris-cache-clean
            - disable-iiif-caching

# because disabling the iiif-caching isn't working and files are still accumulating,
# delete files older than 10 minutes every minute.
enable-devchk-loris-cache-clean:
    cron.present:
        - identifier: original-loris-cache-clean
        - name: /usr/local/bin/original-loris-cache-clean
        - user: root
        # every thirty minutes
        - minute: "*/30"
        - require:
            - file: loris-original-cache-clean
