import os
from loris.webapp import create_app  # type: ignore
from PIL import Image
import logging
import subprocess

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Set the maximum image pixel limit
# 256 million pixels is roughly 8000x8000 @ 4 bytes/pixel (RGB, RGBA).
# Default is 178956970. An image 2x this value (512 million pixels) will throw a `DecompressionBombError`.
Image.MAX_IMAGE_PIXELS = 256000000

def start_nginx():
    """Start the Nginx service."""
    try:
        subprocess.run(["service", "nginx", "start"], check=True)
        logger.info("Nginx service started successfully.")
    except subprocess.CalledProcessError as e:
        logger.error(f"Failed to start Nginx service: {e}")

def start_syslog_ng():
    """Start the syslog-ng service."""
    try:
        subprocess.run(["service", "syslog-ng", "start"], check=True)
        logger.info("syslog-ng service started successfully.")
    except subprocess.CalledProcessError as e:
        logger.error(f"Failed to start syslog-ng service: {e}")

def create_loris_app():
    """Create the Loris application."""
    config_file_path = '/opt/loris/loris2.conf'
    if not os.path.exists(config_file_path):
        logger.error(f"Configuration file not found: {config_file_path}")
        raise FileNotFoundError(f"Configuration file not found: {config_file_path}")
    return create_app(config_file_path=config_file_path)

def main():
    logger.info("Starting services...")
    start_nginx()
    start_syslog_ng()

    logger.info("Creating Loris application...")
    application = create_loris_app()
    
    logger.info("Loris application created successfully. Starting application...")
    
    # Here you would normally start the WSGI server, for example:
    # from werkzeug.serving import run_simple
    # run_simple('0.0.0.0', 8000, application)
    # But for Docker, the server is started by the CMD in the Dockerfile:
    # CMD ["uwsgi", "--ini", "/etc/loris2/uwsgi.ini"]

if __name__ == "__main__":
    main()
