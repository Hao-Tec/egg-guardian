"""Firebase Cloud Messaging service."""

import logging
import os
import firebase_admin
from firebase_admin import credentials, messaging
from app.config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

_fcm_initialized = False

def init_fcm():
    """Initialize Firebase Admin SDK."""
    global _fcm_initialized
    if _fcm_initialized:
        return

    if settings.fcm_mock_mode:
        logger.info("FCM is in MOCK mode. Notifications will not be sent.")
        _fcm_initialized = True
        return

    cred_path = "firebase-adminsdk.json"
    if not os.path.exists(cred_path):
        logger.warning(f"FCM credentials not found at {cred_path}. Falling back to MOCK mode.")
        settings.fcm_mock_mode = True
        _fcm_initialized = True
        return

    try:
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)
        _fcm_initialized = True
        logger.info("Firebase Admin SDK initialized successfully.")
    except Exception as e:
        logger.error(f"Failed to initialize Firebase Admin SDK: {e}")
        settings.fcm_mock_mode = True
        _fcm_initialized = True

def send_push_notification(token: str, title: str, body: str, data: dict = None):
    """Send a push notification to a specific FCM token."""
    init_fcm()

    if settings.fcm_mock_mode:
        logger.info(f"[MOCK FCM] Sending push notification to {token}: {title} - {body}")
        return True

    if not token:
        return False

    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=data or {},
            token=token,
        )
        response = messaging.send(message)
        logger.info(f"Successfully sent FCM message: {response}")
        return True
    except Exception as e:
        logger.error(f"Error sending FCM message: {e}")
        return False

def send_multicast_push_notification(tokens: list[str], title: str, body: str, data: dict = None):
    """Send a push notification to multiple FCM tokens."""
    init_fcm()
    
    # Filter out empty tokens
    valid_tokens = [t for t in tokens if t]
    if not valid_tokens:
        return False

    if settings.fcm_mock_mode:
        logger.info(f"[MOCK FCM] Sending multicast to {len(valid_tokens)} devices: {title} - {body}")
        return True

    try:
        message = messaging.MulticastMessage(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=data or {},
            tokens=valid_tokens,
        )
        response = messaging.send_multicast(message)
        logger.info(f"Successfully sent multicast FCM message. {response.success_count} success, {response.failure_count} failed.")
        return True
    except Exception as e:
        logger.error(f"Error sending multicast FCM message: {e}")
        return False
