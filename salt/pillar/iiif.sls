iiif:
    loris:
        protocol: http-socket
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
            digests: https://s3.amazonaws.com/prod-elife-published/digests/%s
            journal-cms: https://prod--journal-cms.elifesciences.org/sites/default/files/iiif/%s

    fallback:
        # since some .tif make Loris explode, we fall back to the equivalent JPG
        tif: jpg
elife:
    webserver:
        app: caddy