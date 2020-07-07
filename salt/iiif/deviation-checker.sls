# the deviation checker is a script that checks the original image against those derived from IIIF

install-deps:
    pkg.installed:
        - pkgs:
            - imagemagick

install-babashka:
    archive.extracted:
        - name: /usr/bin
        - source: https://github.com/borkdude/babashka/releases/download/v0.1.3/babashka-0.1.3-linux-static-amd64.zip
        - source_hash: f01e1e6f4c6b8e25e8a88133569c79bb
        - enforce_toplevel: False
        - overwrite: True

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

