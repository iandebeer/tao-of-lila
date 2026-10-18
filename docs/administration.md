# Private administration

The read-only dashboard uses the existing Railway application and PostgreSQL
instance. It is mounted at `/admin` only on the exact hostname in `ADMIN_ORIGIN`. There are
no links to it in the public game. Its assets live in `app/admin`, outside the
public static directory. No player-management, deletion, or game-editing API is
provided. The administrator is separate from all player accounts, even a player
whose username happens to be `admin`.

## Deployment and first-time setup

1. Deploy the application changes with the existing Dockerfile. Startup adds
   analytics and administrator tables in the existing database transactionally.
2. Set `ADMIN_ORIGIN=https://play.leela.day` in Railway service variables.
3. Generate a random setup secret with `openssl rand -hex 32`. Put it in Railway's
   private `ADMIN_SETUP_TOKEN` variable. Do not commit it or put it in a URL.
4. Keep the existing `play.leela.day` Railway domain and HTTPS configuration.
   No additional custom domain, DNS record, service, or plan upgrade is needed.
5. Visit `https://play.leela.day/admin`. Supply the setup secret and your chosen
   administrator password. Username is fixed to `admin`. Passwords must have
   at least 12 characters and at most 72 UTF-8 bytes; spaces are supported.
6. After successful setup, remove `ADMIN_SETUP_TOKEN` from Railway variables.
   Existing sessions and password login continue working. Setup cannot replace
   an established account even if the secret is still configured.
7. Verify sign-out, sign-in, the public game, and the admin dashboard over HTTPS.

The administrator password is entered privately in the setup form, transmitted
only over HTTPS, and stored as a salted bcrypt hash using the application's
existing slower bcrypt policy. It is never shipped in browser assets, committed,
logged, or returned by the API. The setup secret is not the administrator password.
No default administrator credentials are installed.

Railway terminates TLS. The application accepts its `X-Forwarded-Proto: https`
header as the secure-transport signal. Do not expose the backend directly through
an untrusted proxy which lets callers forge this header. The admin origin must be
a lowercase HTTPS hostname with no path or port. Omitting it disables admin
routing. Keep the existing TLS configuration and exclude `/admin` and its
subpaths from any Cloudflare caching rules. Assets and API calls use
`/admin/admin.js`, `/admin/admin.css`, and `/admin/api/*`; game routes remain public.
The dashboard shares the game origin, so trusted game scripts share its browser
security boundary. Administrator sessions remain separate from player sessions.

Official references: [Railway custom domains](https://docs.railway.com/networking/domains/working-with-domains),
[Cloudflare subdomain records](https://developers.cloudflare.com/dns/manage-dns-records/how-to/create-subdomain/),
[OWASP password storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html).

## Authentication and boundaries

- One singleton administrator record; no public administrator registration.
- First-time setup requires the private setup secret and a database row lock,
  preventing concurrent callers from replacing the initial password.
- Database-backed global limit: five authentication/setup attempts per 15-minute
  window, shared across instances. Successful authentication resets the window.
  This deliberately simple single-account limit may temporarily lock out the
  owner during an attack. Infrastructure rate limiting can be added separately.
- Cryptographically random 256-bit session tokens. Only token hashes are stored.
- `__Host-` cookie with Secure, HttpOnly, SameSite=Strict and Path=/; no Domain.
- Thirty-minute inactivity expiry, plus an absolute twelve-hour expiry. A manual
  report request refreshes inactivity; there is no background keepalive polling.
- POST requests require the exact admin Origin and a custom request header.
  Player bearer tokens cannot authorize admin reports. No CORS is enabled.
- No-store, restrictive CSP, no framing, no referrer, no indexing and HSTS headers.
  Statistics and usernames are rendered as text, never interpreted as HTML.
- Reports exclude profile attributes, passwords, tokens, questions, journals,
  and generated readings. Database failures return a generic response.

Password recovery is an operator-only database operation for this initial version:
remove all administrator sessions and the singleton administrator account in one
transaction, configure a new random setup secret, and repeat first-time setup.
Do not reset player authentication or game tables. There is no public reset route.

## Metrics and time windows

All dates use **UTC**. The period selector provides 30 calendar days, 12 calendar
weeks beginning Monday, or 12 calendar months, including the current partial
period. Empty buckets appear as zeroes. It also controls new-player, new-Persona
and returning-player totals. Daily/weekly/monthly active-user cards always mean
today, the last 7 calendar days and the last 30 calendar days, respectively.

| Metric | Definition |
| --- | --- |
| Registered players | All current rows in `users`, including pre-tracking registrations |
| Personas created | All `personas` rows, including archived ones; archive does not delete |
| Active / archived Personas | Current archive status; active means unarchived, not recently played |
| New Personas | Distinct `personas:INSERT` audit records within the selected range |
| Login events | Successful explicit `/auth/login` calls after tracking installation; registration's automatic initial session is not counted as a login |
| Active players | Distinct players with successful journey commands or prototype game mutations; visual snapshot updates, page loads, polling, logins and failed commands alone do not count |
| Returning players | Players active in the selected range who also participated on an earlier UTC day, including an earlier day within the range |
| Completed casts | A casting recorded as a durable encounter at the responsive `result` step or prototype completion |
| Completed moves | A responsive encounter acknowledged, or prototype movement committed; a completed zero-distance turn also counts |
| Player table | Existing username, ID, Persona count, tracked last login, today/7-day/30-day/total logins, and active days in the last 30 days; 100 players per page |

Tracking is append-only except for daily participation deduplication. Counters are
recorded inside the same transactions as the actions they describe; failed and
stale commands roll back, and a completed event is counted once per kind. Casting
and movement remain separate: waiting for interpretation is not a completed move.

The dashboard displays `trackingSince`. **Earlier logins, participation and moves are not reconstructed**. Existing
saved castings are imported idempotently with their original timestamps. This avoids mistaking a historical casting for an
acknowledged move. Older game events and all private text remain untouched.
Existing player/Persona totals and creation audits can be reported immediately.

## Verification

Run `cabal test` for the normal suite. If the local sandbox cannot write Cabal's
external build summary, the test log still shows test results; this is separate
from a failing assertion. The current machine's global summary setting can also
cause a final permission error even with a per-command summary override.

`node scripts/admin-ui-test.mjs` exercises setup/sign-in/sign-out, clearing
credential fields, escaped username display, Persona counts and period selection.

`AdminHTTP` exercises host isolation, HTTPS enforcement, CSRF rejection, response
headers and password byte limits without a database.

Run database acceptance against a **disposable PostgreSQL database**:

```sh
TAO_ADMIN_TEST_DB='postgresql://localhost/disposable_test' cabal test admin-persistence
TAO_PERSONA_TEST_DB='postgresql://localhost/disposable_test' cabal test persona-persistence
```

Each suite creates and removes its own schema. The admin suite checks idempotent
migration, one-time setup, session cookies, unauthenticated access, expiry, logout,
rate limiting, reporting periods, deduplication and Persona totals. It prints
SKIP when its database variable is absent; a skipped test is not database acceptance.

Deployment variables and live administrator setup require Railway access and
are not performed by building or testing the application.

### Implementation verification on 16 October 2026

The API executable builds. The ordinary Haskell and movement-statistics suites,
admin HTTP boundary tests, and admin UI test pass. Database suites compile but
were skipped: local Podman startup fails at its gvproxy socket, so no disposable
PostgreSQL instance could be started. Database migration, setup, reporting SQL
and real session acceptance remain required before production rollout. Live DNS,
TLS, browser layout review and first-time administrator password setup are pending.

### Database acceptance on 18 October 2026

Both `admin-persistence` and `persona-persistence` executed and passed against a
fresh, temporary PostgreSQL 16 database on localhost. This covers administrator
setup, report SQL, Persona counts, session expiry/revocation, throttling,
idempotent migrations, and existing journey persistence and movement behavior.
The temporary server was stopped and its database removed after testing. No
production database was used. PostgreSQL 16 is installed locally; no persistent
background service was enabled. This supersedes the database-testing blocker
reported above. Live deployment and first-time administrator setup are separate.

### Administration path verification on 18 October 2026

The dashboard, assets and API now use `https://play.leela.day/admin`.
The Haskell suite and admin UI checks pass, including public-route isolation,
HTTPS and CSRF checks. Administrator and Persona persistence acceptance tests
also pass against a disposable PostgreSQL 16 database. Railway must use
`ADMIN_ORIGIN=https://play.leela.day`; the origin contains no path.
