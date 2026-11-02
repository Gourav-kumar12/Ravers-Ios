# Supabase email login

The current app uses a six-digit email OTP, verified by Supabase before Home opens.
Follow [the email OTP setup guide](EMAIL_OTP_SETUP.md) for hosted Email provider,
SMTP, email templates, OTP length/expiry, migrations, and acceptance checks.

The previous anonymous email-entry flow is no longer used. Saved anonymous
sessions cannot open Home. Existing anonymous data is retained under its original
UUID and is not automatically merged into a verified account by matching email.
