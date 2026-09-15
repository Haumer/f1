# Transactional email

Production uses Resend's SMTP relay with required STARTTLS on port 587,
certificate verification, a five-second connection timeout and ten-second read
timeout. Development/test retain their existing delivery methods. No new gem,
mail server or paid mailbox is needed.

## Activation

1. Create a Resend account on the free transactional plan.
2. Add and verify `f1elo.com` using the exact DNS records shown by Resend. Do not
   replace existing website records or enable inbound email unnecessarily.
3. Create a sending API key restricted to that domain. Store it directly in the
   Heroku `f1-elo` app's Config Vars as `RESEND_API_KEY`. Do not put the key in
   chat, source control, screenshots, shell history or command-line arguments.
4. The sender defaults to `F1 Elo <noreply@f1elo.com>`. Set `MAILER_FROM` only when
   using a different verified sending address. `APP_HOST` controls reset links;
   production defaults to `f1elo.com` over HTTPS.
5. After deployment/restart, test delivery with an explicitly approved test
   account/recipient, check receipt and complete the one-use reset link. Do not
   trigger password resets for other users as a smoke test.

Resend account creation, DNS verification and key provisioning are external
requirements. Code deployment alone does not activate email. Without the key,
password-reset submissions return an honest temporary-unavailability message
(HTTP 503) before any account lookup or reset-token replacement. Provider/network
failures also return 503, with a sanitized error class reported to Sentry. They
are not silently treated as successful sends. Delivery stays synchronous; no
reset tokens are introduced into background-job arguments or their logs.

Users can still sign in and change their password through Edit Account while
email is unavailable. Operator password changes must target a verified exact
account, use a random strong password and normal Devise validation, invalidate
old reset tokens, and be conveyed privately for immediate user replacement.
Temporary credentials must never be added to this document or the repository.

References: [SMTP setup](https://resend.com/docs/send-with-smtp),
[domain verification](https://resend.com/docs/dashboard/domains/introduction),
[pricing](https://resend.com/pricing).
