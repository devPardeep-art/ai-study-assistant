import os
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

SMTP_HOST = "smtp.gmail.com"
SMTP_PORT = 587
SMTP_EMAIL = os.getenv("SMTP_EMAIL", "")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD", "")
FRONTEND_URL = os.getenv("FRONTEND_URL", "http://localhost:8000")

_BUTTON_STYLE = (
    "display:inline-block;margin:20px 0;padding:14px 28px;"
    "background:linear-gradient(135deg,#4F46E5,#7C3AED);"
    "color:#fff;text-decoration:none;border-radius:10px;font-weight:bold"
)

_WRAPPER = (
    "font-family:Arial,sans-serif;max-width:600px;margin:auto;"
    "padding:24px;border:1px solid #e5e7eb;border-radius:12px"
)


def _send(to_email: str, subject: str, html: str) -> None:
    if not SMTP_EMAIL or not SMTP_PASSWORD:
        print(f"[EMAIL] SMTP not configured — skipping send to {to_email}: {subject}")
        return

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = f"Study Companion <{SMTP_EMAIL}>"
    msg["To"] = to_email
    msg.attach(MIMEText(html, "html"))

    with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as server:
        server.ehlo()
        server.starttls()
        server.login(SMTP_EMAIL, SMTP_PASSWORD)
        server.sendmail(SMTP_EMAIL, to_email, msg.as_string())


def send_verification_email(to_email: str, name: str, token: str) -> None:
    url = f"{FRONTEND_URL}/auth/verify-email?token={token}"
    html = f"""
    <div style="{_WRAPPER}">
      <h2 style="color:#4F46E5;margin-top:0">Welcome to Study Companion, {name}!</h2>
      <p>Thanks for signing up. Click the button below to verify your email address and activate your account.</p>
      <a href="{url}" style="{_BUTTON_STYLE}">Verify My Email</a>
      <p>Or copy this link into your browser:<br>
         <a href="{url}" style="color:#4F46E5;word-break:break-all">{url}</a></p>
      <hr style="border:none;border-top:1px solid #e5e7eb;margin:20px 0">
      <p style="color:#6b7280;font-size:13px">
        This link expires in <strong>24 hours</strong>.<br>
        If you did not create a Study Companion account you can safely ignore this email.
      </p>
    </div>"""
    _send(to_email, "Verify your Study Companion account", html)


def send_password_reset_email(to_email: str, name: str, token: str) -> None:
    url = f"{FRONTEND_URL}/auth/reset-password?token={token}"
    html = f"""
    <div style="{_WRAPPER}">
      <h2 style="color:#4F46E5;margin-top:0">Password Reset Request</h2>
      <p>Hi <strong>{name}</strong>,</p>
      <p>We received a request to reset your Study Companion password. Click the button below to choose a new one.</p>
      <a href="{url}" style="{_BUTTON_STYLE}">Reset My Password</a>
      <p>Or copy this link into your browser:<br>
         <a href="{url}" style="color:#4F46E5;word-break:break-all">{url}</a></p>
      <hr style="border:none;border-top:1px solid #e5e7eb;margin:20px 0">
      <p style="color:#6b7280;font-size:13px">
        This link expires in <strong>1 hour</strong>.<br>
        If you did not request a password reset you can safely ignore this email — your password will not change.
      </p>
    </div>"""
    _send(to_email, "Reset your Study Companion password", html)
