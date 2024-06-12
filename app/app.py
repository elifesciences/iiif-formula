import os
from loris.webapp import create_app  # type: ignore
from PIL import Image

# Temporary setting until Loris is upgraded to version 3.1.0+ and .conf file support exists.
# 256 million pixels is roughly 8000x8000 @ 4 bytes/pixel (RGB, RGBA).
# Default is 178956970. An image 2x this value (512 million pixels) will throw a `DecompressionBombError`,
# and you'll get a 5xx.
# Setting it to `None` will cause (even longer) pauses and possible crashing via OOM killer.
Image.MAX_IMAGE_PIXELS = 256000000

def create_loris_application():
    """Create and configure the Loris application."""
    config_file_path = '/opt/loris/loris2.conf'
    if not os.path.exists(config_file_path):
        raise FileNotFoundError(f"Configuration file not found: {config_file_path}")
    return create_app(config_file_path=config_file_path)

# Create the Flask application
application = create_loris_application()

if __name__ == "__main__":
    # Run the application in debug mode if specified, otherwise in production mode
    debug_mode = os.getenv('FLASK_ENV', 'production') == 'development'
    application.run(host='0.0.0.0', port=8000, debug=debug_mode)
