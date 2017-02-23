iiif:
    loris:
        storage: /tmp/loris
        resolver:
            #impl: loris.resolver.SimpleFSResolver
            #src_img_root: /usr/local/share/images

            #impl: loris.resolver.SimpleHTTPResolver
            #source_prefix: https://publishing-cdn.elifesciences.org/

            impl: loris.resolver.TemplateHTTPResolver
        # only work with TemplateHTTPResolver
        templates:
            lax: https://publishing-cdn.elifesciences.org/%s
            journal-cms: https://prod--journal-cms.elifesciences.org/sites/default/files/%s

    fallback:
        # since some .tif make Loris explode, we fall back to the equivalent JPG
        tif: jpg
        
