import os
from loris.webapp import create_app  # Import the function to create the Loris app

# Configure PIL to handle large images by setting a maximum image size
# 256 million pixels is roughly 8000x8000 pixels at 4 bytes per pixel (RGB, RGBA)
# This prevents DecompressionBombError for images up to this size
from PIL import Image
Image.MAX_IMAGE_PIXELS = 256000000

# Path to the Loris configuration file
config_file_path = '/opt/loris/etc/loris2.conf'

# Create the Flask application using the Loris configuration
application = create_app(config_file_path=config_file_path)
