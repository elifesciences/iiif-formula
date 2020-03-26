# `iiif` formula

This repository contains instructions for installing and configuring the `iiif`
project.

This repository should be structured as any Saltstack formula should, but it 
should also conform to the structure required by the [builder](https://github.com/elifesciences/builder) 
project.

## Related:

* eLife's loris-docker fork: https://github.com/elifesciences/loris-docker

## NewRelic and a containerised IIIF

NewRelic Infrastructure remains unchanged, it will continue monitoring the host.

NewRelic APM is done from inside the container. This is the setup:

`host -> nginx -> container -> uwsgi -> NewRelic wrapper -> app`

uwsgi depends on an `application` being made available inside the `.wsgi` file. Here is an example of the default wsgi 
file that comes with the container: 
https://github.com/elifesciences/loris-docker/blob/development/loris2.wsgi

And here is the replacement `.wsgi` file that eLife mounts within the container:
https://github.com/elifesciences/iiif-formula/blob/master/salt/iiif/config/opt-loris-loris2.wsgi

which is mounted here:
https://github.com/elifesciences/iiif-formula/blob/master/salt/iiif/config/opt-loris-docker-compose.yaml#L13

It creates the `application` as usual but if the environment variable `NEW_RELIC_ENABLED` is set to `"true"` it then 
wraps the `application` instance. The value of this envvar comes from Salt pillar data and is passed in here: 
https://github.com/elifesciences/iiif-formula/blob/master/salt/iiif/config/opt-loris-docker-compose.yaml#L7

It depends on the NewRelic licence file being available, so if `NEW_RELIC_ENABLED` is true but there is no licence file
then it dies immediately. The licence file is generated as usual and the result is mounted within the container here:
https://github.com/elifesciences/iiif-formula/blob/master/salt/iiif/config/opt-loris-docker-compose.yaml#L15

The licence generation requires the pillar data to be a certain shape as it will depend on a specific formula state and 
also attempt to restart a service in another state.
