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
        - identifier: devchk-loris-cache-clean
        - name: test -d /ext/loris/ && /usr/bin/find /ext/loris/cache-resolver/ -mmin +10 -type f -delete
        - user: root
        #- minute: "*"
        - require:
            - file: loris-cache-clean
