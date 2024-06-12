# Use an official Python runtime as a parent image
FROM python:3.9-slim AS python-base

# Use an official Nginx runtime as a parent image
FROM nginx:latest AS nginx-base

# Use an official syslog-ng image as a parent image
FROM balabit/syslog-ng:latest AS syslog-base

# Final image
FROM python-base

# Copy custom nginx configuration from nginx-base
COPY --from=nginx-base /etc/nginx /etc/nginx

# Copy custom syslog-ng configuration from syslog-base
COPY --from=syslog-base /etc/syslog-ng /etc/syslog-ng

# Set the working directory in the container
WORKDIR /app

# Install dependencies
RUN apt-get update && apt-get install -y \
    imagemagick \
    git \
    curl \
    default-jdk

# Install Leiningen
COPY config/tmp-lein-install-script.sh /tmp/lein-install-script.sh
RUN chmod +x /tmp/lein-install-script.sh && /tmp/lein-install-script.sh && rm /tmp/lein-install-script.sh

# Clone the deviation checker repository
RUN git clone https://github.com/elifesciences/elife-iiif-deviation-checker /opt/elife-iiif-deviation-checker

# Set permissions for the cloned repository
RUN chown -R www-data:www-data /opt/elife-iiif-deviation-checker

# Copy configuration files and scripts
COPY config/etc-loris2-uwsgi.ini /etc/loris2/uwsgi.ini
COPY config/etc-nginx-sites-enabled-loris-container.conf /etc/nginx/sites-enabled/loris-container.conf
COPY config/etc-syslog-ng-conf.d-loris.conf /etc/syslog-ng/conf.d/loris.conf
COPY config/lib-systemd-system-iiif-service.service /lib/systemd/system/iiif-service.service
COPY config/opt-loris-loris2.conf /opt/loris/loris2.conf
COPY config/opt-loris-loris2.wsgi /opt/loris/loris2.wsgi
COPY config/opt-loris-smoke.sh /opt/loris/smoke.sh
COPY config/opt-loris-uwsgi.ini /opt/loris/uwsgi.ini
COPY config/usr-local-bin-loris-cache-clean /usr/local/bin/loris-cache-clean
COPY config/usr-local-bin-loris-cache-clean-hard /usr/local/bin/loris-cache-clean-hard
COPY config/usr-local-bin-loris-cache-clean-soft /usr/local/bin/loris-cache-clean-soft

# Make scripts executable
RUN chmod +x /opt/elife-iiif-deviation-checker/disable-loris-caching.sh \
    /usr/local/bin/loris-cache-clean-soft /usr/local/bin/loris-cache-clean-hard /usr/local/bin/loris-cache-clean \
    /opt/loris/smoke.sh

# Add the cron job for cache cleaning
RUN (echo "0,10,20,30,40,50 * * * * root /usr/local/bin/loris-cache-clean ${LORIS_CACHE_SOFT_LIMIT:-500M} ${LORIS_CACHE_HARD_LIMIT:-1G}" >> /etc/crontab) \
    || (echo "5,15,25,35,45,55 * * * * root /usr/local/bin/loris-cache-clean ${LORIS_CACHE_SOFT_LIMIT:-500M} ${LORIS_CACHE_HARD_LIMIT:-1G}" >> /etc/crontab)

# Disable IIIF caching
RUN /opt/elife-iiif-deviation-checker/disable-loris-caching.sh

# Expose ports for nginx (80) and your application (8000)
EXPOSE 80 8000

# Copy the Flask application
COPY app/start_loris.py /app/start_loris.py

# Run the Flask application when the container launches
CMD ["python", "app.py"]
