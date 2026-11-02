# Email OTP rollout

The app uses Supabase `signInWithOTP(email:shouldCreateUser: true)` followed by
`verifyOTP(email:token:type: .email)`. New and returning users share the same screen.
Codes are generated, expired, rate limited, and verified by Supabase. There is no
fixed code or debug bypass. Gmail is a supported recipient; this is email OTP,
not Google OAuth or access to the user's Gmail account.

## Required hosted project configuration

These settings must be applied in the Supabase dashboard; changing Swift code or
running the database migration does not change hosted Auth configuration.

1. In Authentication → Providers / Sign In, enable Email and allow new user signups.
   Keep email confirmation enabled. Configure email OTP length to **6 digits** and
   expiry to **600 seconds**. The UI expects six digits; keep both sides aligned.
2. In Authentication → Email Templates, set both **Magic Link** and **Confirm signup**
   bodies to the contents of `supabase/templates/email-otp.html`. Use subject
   `Your Raverse sign-in code`. Include `{{ .Token }}`; a template containing only
   `{{ .ConfirmationURL }}` sends a link the code-entry screen cannot use.
3. Configure **custom SMTP** with a transactional email provider and a verified
   sender domain. Enter SMTP host, port, username, password, sender address and
   sender name in Supabase only. Configure the provider's SPF/DKIM/DMARC records.
   Supabase's default mailer only delivers to project team addresses and is not
   suitable for real users. SMTP credentials must never ship in the iOS app.
4. Set the per-address resend interval to **60 seconds**. Review project email and
   verification rate limits for launch volume. Server enforcement is required;
   the app countdown is only a UX guard and can be reset by reinstalling the app.
   If enabling Supabase CAPTCHA later, integrate its challenge and token into
   the client before enabling that requirement on the hosted project.
5. Apply migrations in order with your usual deployment process (`supabase db push`
   after linking the correct project). `202610160001_email_otp_profiles.sql` adds
   auth email to the profile creation trigger and backfills missing email for
   verified existing accounts. UUID ownership and RLS policies remain unchanged.
6. After migrating existing users, disable anonymous sign-ins and phone sign-ins
   in the dashboard if no other supported client needs them.

## Existing accounts and profile contact email

Old anonymous development sessions and phone-only sessions no longer unlock the
app. A new email sign-in creates a distinct auth UUID unless that email is already
attached to the existing Supabase auth account. Do not merge users by matching
`profiles.email`: that field is editable contact information, not proof of ownership.
Before switching existing real phone users, use a separately authenticated account
linking/migration process so their original UUID and owned data are preserved.
This change does not delete or transfer existing data.

Changing email in Edit Profile updates contact information only. It does not
change the login address. Login email changes require a separate verified Supabase
Auth email-change flow.

## Release acceptance checks (real backend + inbox)

- Send to a fresh Gmail address and another provider; verify delivery to Inbox or
  Spam, a six-digit code, successful verification, profile/preferences creation,
  and UUID agreement between auth.users and profiles.
- Sign out and sign back into the same email: the UUID and saved profile stay the
  same. Relaunch with a valid saved session; an anonymous saved session must show
  email login. Switch accounts and confirm the previous user's local stores reset.
- Try wrong, expired, and already-used codes: none unlock the app. On network
  failure, keep the entered code so the Verify button can retry it.
- Resend immediately, edit back to the same email, background for more than a
  minute, resend after the wait, and verify using the latest email. Supabase
  remains authoritative when a server limit lasts longer than the UI cooldown.
- Test delivery failure / invalid SMTP, disabled Email provider, signup disabled,
  network timeout, and offline sign-out. Confirm errors never grant app access.
- Check profile photo reads/writes and owner-only RLS with two real identities.
  Local stub tests cannot prove hosted schema, policies, SMTP, or inbox delivery.

References: [Supabase Swift OTP](https://supabase.com/docs/reference/swift/auth-signinwithotp),
[verification](https://supabase.com/docs/reference/swift/auth-verifyotp),
[custom SMTP](https://supabase.com/docs/guides/auth/auth-smtp).
