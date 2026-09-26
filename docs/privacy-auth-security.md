# Authentication, privacy policy and security

This document describes authentication, the admin scope, the privacy policy gate and the security
measures. It uses Simplified Technical English (ASD-STE100).

## 1. Authentication and admin

There are two separate scopes:

- **Users** sign in to the site. Devise handles registration, confirmation and lockout. Community
  members can create and edit catalog entities.
- **Admin users** sign in to the back office (ActiveAdmin). They can use the full admin interface.
  After 10 failed sign-in attempts, the admin account locks for 1 hour. Then it unlocks
  automatically. There is no unlock email. To unlock an account before that time, use a Rails
  console.

## 2. Privacy policy

The published policy text has two numbers:

- A **version**. A new version needs a new acceptance.
- A **content revision**. It is for text changes that do not need a new acceptance.

Users store which version they accepted and when.

- The sign-up needs the acceptance.
- A user with an old version must accept the new version or delete the account before they can use
  the application.
- Static and legal pages and account recovery stay available during this gate.
- The unsubscribe controllers do not use the gate, because the recipient is possibly not signed in
  (see [users-and-social.md](users-and-social.md#7-unsubscribe-from-emails)).

## 3. Security

- **Rack::Attack** limits the request rate for authentication, catalog writes, bookmarks, notes,
  search, and follow and block changes. Rails sends a path with a format suffix to the same
  action, for example `/user/sign_in.json` and `/user/sign_in`. Thus, Rack::Attack removes the
  format suffix before it compares a path, and the two paths share one limit.
- **ActiveAdmin** shows the names that users write as text. This applies to product, brand,
  custom product and product option names. An admin session has full access, thus HTML in such a
  name must not become markup. The admin code does not mark a string that contains such a name as
  HTML safe. It builds markup with `safe_join` and `tag`, which escape the name.
- **Uploads**: the images of possessions and custom products and the avatar accept only JPEG,
  WebP, PNG and GIF files. An image can be 10 MB at most, an avatar 5 MB. The model validates
  this when a record is created and when it changes. The forms send the files together with the
  record, so the application does not use the direct upload endpoint of Active Storage. That
  endpoint needs no sign-in, thus the application answers it with 404.
- **Host Authorization**: in production, Rails answers 403 when the `Host` or `X-Forwarded-Host`
  header of a request contains a host that is not in the `ALLOWED_HOSTS` environment variable (a
  comma-separated list). Rails builds absolute URLs from the request host, for example canonical
  links, structured data and the sitemap. Without this check, a request could put any host into
  these URLs. An empty list turns the check off. Thus, the application does not boot without
  `ALLOWED_HOSTS` or with an empty value.
- **Malformed parameters**: every paginated list reads `page` as one value, and the search reads
  `query` as one value. A request can send them as a list or a hash, for example `page[]=1`. The
  application removes such a value, and the request continues as if the value was not sent: a list
  shows its first page, and the search asks for a query. Before, such a value caused an error
  (500).
- A **content security policy** applies to all pages.
- A **Turnstile** bot challenge protects registration, sign-in, password reset, and the forms that
  send the confirmation and unlock emails again. At sign-in, the challenge is checked before Devise
  reads the form. Thus, a failed challenge does not check the password and does not count toward
  the lockout. The admin login has no Turnstile.
