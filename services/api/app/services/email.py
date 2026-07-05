"""Email notification service using SMTP."""

import smtplib
import asyncio
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from functools import partial
from typing import Optional

from app.config import get_settings

settings = get_settings()


def _send_email_sync(
    to_emails: list[str],
    subject: str,
    html_body: str,
) -> None:
    """Synchronous email sending (run in a thread to avoid blocking)."""
    if not to_emails:
        return

    try:
        msg = MIMEMultipart("alternative")
        msg["Subject"] = subject
        msg["From"] = settings.smtp_from_email
        msg["To"] = ", ".join(to_emails)
        msg.attach(MIMEText(html_body, "html"))

        with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=10) as server:
            if settings.smtp_use_tls:
                server.starttls()
            if settings.smtp_user and settings.smtp_password:
                server.login(settings.smtp_user, settings.smtp_password)
            server.sendmail(settings.smtp_from_email, to_emails, msg.as_string())
    except Exception as e:
        # Log but don't crash — email is non-critical
        print(f"[EmailService] Failed to send email: {e}")


async def send_new_registration_email(
    admin_emails: list[str],
    new_user_email: str,
    new_user_name: str,
    new_user_role: str,
) -> None:
    """Send a 'New Registration Pending Approval' notification to all admins."""
    subject = f"[Egg Guardian] New Registration: {new_user_name} is awaiting approval"

    html_body = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <style>
            body {{ font-family: 'Arial', sans-serif; background: #0f172a; color: #e2e8f0; margin: 0; padding: 20px; }}
            .container {{ max-width: 600px; margin: 0 auto; background: #1e293b; border-radius: 12px; overflow: hidden; }}
            .header {{ background: linear-gradient(135deg, #f59e0b, #d97706); padding: 30px; text-align: center; }}
            .header h1 {{ color: #0f172a; margin: 0; font-size: 1.5rem; font-weight: 700; }}
            .body {{ padding: 30px; }}
            .info-row {{ display: flex; margin-bottom: 12px; }}
            .label {{ color: #94a3b8; min-width: 120px; font-size: 0.9rem; }}
            .value {{ color: #f1f5f9; font-weight: 600; }}
            .cta {{ background: #f59e0b; color: #0f172a; padding: 14px 28px; border-radius: 8px;
                    text-decoration: none; font-weight: 700; display: inline-block; margin-top: 20px; }}
            .footer {{ padding: 20px 30px; border-top: 1px solid #334155; color: #64748b; font-size: 0.8rem; }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>Egg Guardian — Action Required</h1>
            </div>
            <div class="body">
                <p style="color: #94a3b8; margin-top:0;">A new worker has registered on the Egg Guardian mobile app and is awaiting your approval before they can access the system.</p>
                <table style="width:100%; border-collapse: collapse;">
                    <tr><td style="color:#94a3b8; padding:8px 0; width:130px;">Name:</td><td style="color:#f1f5f9; font-weight:600;">{new_user_name}</td></tr>
                    <tr><td style="color:#94a3b8; padding:8px 0;">Email:</td><td style="color:#f1f5f9; font-weight:600;">{new_user_email}</td></tr>
                    <tr><td style="color:#94a3b8; padding:8px 0;">Job Role:</td><td style="color:#f1f5f9; font-weight:600;">{new_user_role}</td></tr>
                </table>
                <p style="color:#94a3b8; margin-top:20px;">Log in to the admin dashboard to review and approve or reject this user.</p>
            </div>
            <div class="footer">
                <p>This is an automated notification from the Egg Guardian monitoring system. Do not reply to this email.</p>
            </div>
        </div>
    </body>
    </html>
    """

    loop = asyncio.get_event_loop()
    await loop.run_in_executor(
        None,
        partial(_send_email_sync, admin_emails, subject, html_body)
    )


async def send_account_approved_email(
    user_email: str,
    user_name: str,
) -> None:
    """Notify a user that their account has been approved."""
    subject = "[Egg Guardian] Your account has been approved!"

    html_body = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <style>
            body {{ font-family: 'Arial', sans-serif; background: #0f172a; color: #e2e8f0; margin: 0; padding: 20px; }}
            .container {{ max-width: 600px; margin: 0 auto; background: #1e293b; border-radius: 12px; overflow: hidden; }}
            .header {{ background: linear-gradient(135deg, #22c55e, #16a34a); padding: 30px; text-align: center; }}
            .header h1 {{ color: #fff; margin: 0; font-size: 1.5rem; font-weight: 700; }}
            .body {{ padding: 30px; }}
            .footer {{ padding: 20px 30px; border-top: 1px solid #334155; color: #64748b; font-size: 0.8rem; }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>Welcome to Egg Guardian!</h1>
            </div>
            <div class="body">
                <p style="color:#94a3b8; margin-top:0;">Hi <strong style="color:#f1f5f9;">{user_name}</strong>,</p>
                <p style="color:#94a3b8;">Great news! Your Egg Guardian account has been reviewed and approved by an administrator. You can now log into the mobile app.</p>
                <p style="color:#94a3b8; margin-top: 20px;">Open the Egg Guardian app and sign in with your registered email and password.</p>
            </div>
            <div class="footer">
                <p>This is an automated notification from the Egg Guardian monitoring system.</p>
            </div>
        </div>
    </body>
    </html>
    """

    loop = asyncio.get_event_loop()
    await loop.run_in_executor(
        None,
        partial(_send_email_sync, [user_email], subject, html_body)
    )


async def send_password_reset_email(
    user_email: str,
    user_name: str,
    reset_token: str,
) -> None:
    """Send a password reset email with the one-time token."""
    subject = "[Egg Guardian] Password Reset Request"

    html_body = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <style>
            body {{ font-family: 'Arial', sans-serif; background: #0f172a; color: #e2e8f0; margin: 0; padding: 20px; }}
            .container {{ max-width: 600px; margin: 0 auto; background: #1e293b; border-radius: 12px; overflow: hidden; }}
            .header {{ background: linear-gradient(135deg, #f59e0b, #d97706); padding: 30px; text-align: center; }}
            .header h1 {{ color: #0f172a; margin: 0; font-size: 1.5rem; font-weight: 700; }}
            .body {{ padding: 30px; }}
            .token-box {{ background: #0f172a; border: 1px solid #334155; border-radius: 8px;
                          padding: 16px 24px; text-align: center; margin: 24px 0; }}
            .token {{ font-family: monospace; font-size: 1rem; color: #f59e0b;
                       word-break: break-all; letter-spacing: 0.05em; }}
            .warning {{ color: #ef4444; font-size: 0.85rem; margin-top: 20px; }}
            .footer {{ padding: 20px 30px; border-top: 1px solid #334155; color: #64748b; font-size: 0.8rem; }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>🥚 Password Reset</h1>
            </div>
            <div class="body">
                <p style="color:#94a3b8; margin-top:0">Hi <strong style="color:#f1f5f9">{user_name}</strong>,</p>
                <p style="color:#94a3b8">We received a request to reset your Egg Guardian password. Copy the reset token below and paste it into the app to set your new password.</p>
                <div class="token-box">
                    <div style="color:#94a3b8; font-size:0.8rem; margin-bottom:8px">YOUR RESET TOKEN</div>
                    <div class="token">{reset_token}</div>
                </div>
                <p class="warning">⚠️ This token expires in <strong>15 minutes</strong>. If you did not request a password reset, please ignore this email — your account is safe.</p>
            </div>
            <div class="footer">
                <p>This is an automated notification from the Egg Guardian monitoring system. Do not reply to this email.</p>
            </div>
        </div>
    </body>
    </html>
    """

    loop = asyncio.get_event_loop()
    await loop.run_in_executor(
        None,
        partial(_send_email_sync, [user_email], subject, html_body)
    )
