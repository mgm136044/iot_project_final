# config.py

EAR_THRESHOLD = 0.200188679245283
CONSEC_FRAMES = 30

ACCEL_THRESHOLD = 2.0

IMPACT_CHECK_DELAY = 10.0
ALERT_CONFIRM_DELAY = 10.0

LEFT_EYE_IDXS = [362, 385, 387, 263, 373, 380]
RIGHT_EYE_IDXS = [33, 160, 158, 133, 153, 144]

LOG_FILE = "driving_events.log"

CAM_WIDTH = 800
CAM_HEIGHT = 480

# Report system settings
REPORT_IMPACT_MONITORING_DURATION = 60.0  # Monitor for 1 minute after last impact
REPORT_EYES_CLOSED_DURATION = 10.0  # seconds of eyes closed (low EAR)
REPORT_NO_FACE_DURATION = 10.0  # seconds of no face detection
REPORT_RESPONSE_TIMEOUT = 10.0  # seconds to wait for user response
AUTO_REPORT_ENABLED = True

# SMS report settings (SOLAPI)
SMS_API_KEY = "NCSCIXA2D5BAFBTJ"  # Replace with your SOLAPI API key
SMS_API_SECRET = "DJ33MVDAPVFQPYOIWDENH2NUHCJLWG4H"  # Replace with your SOLAPI API secret
SMS_FROM_NUMBER = "010-4090-7445"
SMS_TO_NUMBER = "010-7220-5917"
SMS_ENABLED = True  # Set to True to enable SMS reporting

# GPS settings
GPS_ENABLED = True  # Set to True to enable GPS module
GPS_SERIAL_PORT = "/dev/ttyUSB0"  # GPS serial port (Raspberry Pi)
GPS_BAUD_RATE = 9600  # GPS baud rate
DRIVING_SPEED_THRESHOLD = 5.0  # km/h - Speed threshold to determine if vehicle is driving (above this = driving)
NO_FACE_WHILE_DRIVING_TIMEOUT = 10.0  # seconds - Time to wait before activating speaker when no face detected while driving

# UI data directory
UI_DATA_DIR = "data"  # Relative to project root
UI_DROWSINESS_JSON = "drowsiness.json"  # File name for drowsiness status
UI_STATUS_JSON = "status.json"  # File name for system status
SMS_FROM_NUMBER = "010-4090-7445"
SMS_TO_NUMBER = "010-7220-5917"
