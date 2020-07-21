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

