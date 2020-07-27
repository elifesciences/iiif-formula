# the deviation checker is a script that checks the original image against those derived from IIIF

install-deps:
    pkg.installed:
        - pkgs:
            - imagemagick

install-leiningen:
    file.managed:
        - name: /bin/lein
        - source: salt://iiif/config/tmp-lein-install-script.sh
        - mode: 0775

install-checker:
    git.latest:
        - name: https://github.com/elifesciences/elife-iiif-deviation-checker
        - target: /opt/elife-iiif-deviation-checker
    
    file.directory:
        - name: /opt/elife-iiif-deviation-checker
        - user: {{ pillar.elife.deploy_user.username }}
        - group: {{ pillar.elife.deploy_user.username }}
        - recurse:
            - user
            - group
        - require:
            - git: install-checker

disable-iiif-caching:
    cmd.run:
        - cwd: /opt/elife-iiif-deviation-checker
        - runas: {{ pillar.elife.deploy_user.username }}
        - name: ./disable-loris-caching.sh
        - require:
            - install-checker
            - loris-ready
        # loris-service is watching this file for changes

# see `loris-maintenance.sls`
# this restarts the service and interferes with the testing.
# it's also unnecessary if iiif caching is disabled
disable-loris-cache-clean:
    cron.absent:
        - identifier: loris-cache-clean
        - require:
            - loris-cache-clean
            - disable-iiif-caching
