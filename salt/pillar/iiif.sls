iiif:
    loris:
        storage: /ext/loris
        cache:
            soft_limit: 2097152 # 2 GB
            hard_limit: 3145728 # 3 GB
        resolver:
            #impl: loris.resolver.SimpleFSResolver
            #src_img_root: /usr/local/share/images

            #impl: loris.resolver.SimpleHTTPResolver
            #source_prefix: https://publishing-cdn.elifesciences.org/

            impl: loris.resolver.TemplateHTTPResolver
        # only work with TemplateHTTPResolver
        templates:
            lax: https://s3.amazonaws.com/prod-elife-published/articles/%s
            journal-cms: https://prod--journal-cms.elifesciences.org/sites/default/files/iiif/%s

    fallback:
        # since some .tif make Loris explode, we fall back to the equivalent JPG
        tif: jpg
        
elife:

# to enable New Relic APM for the Python application
# depends on pillar.elife.newrelic in builder-base-formula
#    newrelic_python:
#        application_folder: /opt/loris
#        service: loris-uwsgi-ready
#        dependency_state: loris-setup

    # 16.04+ systemd managed uwsgi
    uwsgi:
        services:
            loris:
                folder: /opt/loris
