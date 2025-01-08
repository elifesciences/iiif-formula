
loris-cache-clean-soft:
    file.managed:
        - name: /usr/local/bin/loris-cache-clean-soft
        - source: salt://iiif/config/usr-local-bin-loris-cache-clean-soft
        - template: jinja
        - mode: 755

loris-cache-clean-hard:
    file.managed:
        - name: /usr/local/bin/loris-cache-clean-hard
        - source: salt://iiif/config/usr-local-bin-loris-cache-clean-hard
        - template: jinja
        - mode: 755

loris-cache-clean:
    file.managed:
        - name: /usr/local/bin/loris-cache-clean
        - source: salt://iiif/config/usr-local-bin-loris-cache-clean
        - template: jinja
        - mode: 755
        - require:
            - loris-cache-clean-soft
            - loris-cache-clean-hard

    cron.present:
        - identifier: loris-cache-clean
        - name: /usr/local/bin/loris-cache-clean {{ pillar.iiif.loris.cache.soft_limit }} {{ pillar.iiif.loris.cache.hard_limit }}
        - user: root
        {% if salt['elife.cfg']('project.node', 1) % 2 == 1 %}
        # odd server
        - minute: '0,10,20,30,40,50'
        {% else %}
        # even server
        - minute: '5,15,25,35,45,55'
        {% endif %}
        - require:
            - file: loris-cache-clean

# ---

# cronjob that calls this in deviation-checker.sls
loris-original-cache-clean:
    file.managed:
        - name: /usr/local/bin/original-loris-cache-clean
        - source: https://raw.githubusercontent.com/loris-imageserver/loris/a4da900539a255b8ca286085201963349d58f9cc/bin/loris-cache_clean.sh
        - source: salt://iiif/config/usr-local-bin-original-loris-cache-clean
        - template: jinja
        - mode: 755
