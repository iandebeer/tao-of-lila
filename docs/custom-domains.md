# Leela domains

- `https://play.leela.day/journey/`: existing Railway `web` service, port 8080.
- `https://read.leela.day/`: standalone static reading room on Cloudflare Pages.
- `read.leela.life`: reserved as a future idea for Category of Tao; no deployment
  or domain registration is assumed or configured for it.

## Game domain

Add `play.leela.day` under Railway → web → Settings → Networking → Custom Domain,
using the detected port 8080. Railway supplies two DNS records: a CNAME for `play`
and a TXT verification record for `_railway-verify.play`. Use the exact values
shown in the Railway dashboard. The configured CNAME target is
`k8j312nx.up.railway.app`; keep the verification TXT record in Cloudflare DNS.

The CNAME is DNS-only, so Railway terminates HTTPS directly. The old Railway
hostname remains available. No database or game migration is needed. Log in once
at the new hostname: browser session storage is scoped to each origin, while the
account and Persona history remain in the same database.

References: [Railway custom domains](https://docs.railway.com/networking/domains/working-with-domains),
[Cloudflare subdomain records](https://developers.cloudflare.com/dns/manage-dns-records/how-to/create-subdomain/).

## Reading site

Source: `web/reading-site/`. The build reads `docs/user-manual.md` and
`docs/introduction-pamphlet.md`, copies the interface diagram, and generates a
home page, document pages, print styles, sitemap, 404 page and cache headers.
It has no runtime JavaScript, account, model calls or database connection.
Only these reading materials are published; the Category of Tao book is not yet
included. Existing generated PDFs under `output/` are not published because they
precede the updated text; use the reading pages' browser print/save-as-PDF output.

```sh
npm ci --prefix web/reading-site
npm run build --prefix web/reading-site
python3 -m http.server 8766 --bind 127.0.0.1 --directory web/reading-site/dist
```

The live Pages project is `leela-reading` (`leela-reading.pages.dev`), configured
with `read.leela.day`. It uses Direct Upload.

The GitHub Actions workflow `.github/workflows/static-sites.yml` builds and
uploads both static sites on every push to `main`. Direct Upload projects support
these automated uploads; no migration to a Git-integrated Pages project is needed.
See the one-time setup below. Manual uploads remain available as a fallback.

Attach `read.leela.day` through the Pages project's **Custom domains** tab. Let
Cloudflare create its DNS record. A DNS record alone does not register the host
with Pages. See [Cloudflare Pages custom domains](https://developers.cloudflare.com/pages/configuration/custom-domains/).

Validation: build succeeds; local page, image and section links checked; desktop
Safari appearance inspected. HTTPS checks returned 200 for `play.leela.day/health` and `read.leela.day/`
on 14 October 2026. The deployed homepage, manual, pamphlet, diagram and stylesheet
were byte-compared against the final local build and matched. These changes do
not modify the Haskell engine.

## Root domain menu

`https://leela.day/` is the public entry point, with **Play** linking to
`https://play.leela.day/journey/` and **Read** linking to `https://read.leela.day/`.
Source: `web/landing-site/`. It copies the exact approved game splash artwork
from `app/public/assets/splash/`; no separate image needs to be maintained.

```sh
npm run build --prefix web/landing-site
python3 -m http.server 8767 --bind 127.0.0.1 --directory web/landing-site/dist
```

Deploy `web/landing-site/dist` as a separate Cloudflare Pages project named
`leela-landing`. For Git integration use repository root `.`, build command
`npm run build --prefix web/landing-site`, output `web/landing-site/dist`, and
Node 22 or later. No dependency installation is required. For Direct Upload,
rebuild and upload the contents of this directory on each release.

Attach the apex `leela.day` through that project's Custom domains tab and let
Cloudflare configure the DNS record. Keep `play` and `read` attached to their
existing services. Do not redirect the apex to either subdomain: it serves the
menu itself. The root page needs no JavaScript, login, API or database.

Release checks: `https://leela.day/` must return the Play/Read menu, both links
must reach their respective subdomains, and the splash image must load on mobile
and desktop. This source change prepares the build; it does not itself create
the Pages project or change live DNS.

## Automatic deployment on push

`.github/workflows/static-sites.yml` builds and checks both static sites on pull
requests to `main`. On pushes to `main`, it uploads the checked build artifacts
to `leela-reading` and `leela-landing`. A change to documentation, artwork or site
code therefore goes live without a manual upload. There are no path filters:
every production push rebuilds both sites. Workflow dispatch on `main` can retry
a release without creating a commit; dispatch on other branches only builds.

One-time setup in GitHub → repository Settings → Secrets and variables → Actions:

| Repository secret | Value |
| --- | --- |
| `CLOUDFLARE_API_TOKEN` | An API token with Account → Cloudflare Pages → Edit, limited to the hosting account. |
| `CLOUDFLARE_ACCOUNT_ID` | The Cloudflare account ID containing both Pages projects. |

Ensure both Pages projects exist, have `main` as their production branch, and
have the custom domains described above attached. Create `leela-landing` if it
has not yet been provisioned. The workflow deliberately does not create projects
or change DNS. Missing credentials fail the deployment job with a setup message.

Keep Railway's native GitHub autodeploy enabled for the `web` service, connected
to this repository's `main` branch and the root Dockerfile. That deployment builds
the app, yarrow ceremony, journey assets and shared catalogue. This workflow
handles the two independent static sites alongside Railway; it does not trigger
a second app deployment or require a Railway token. Confirm the Railway source
branch in its service settings when enabling this workflow.

The three deployments are independent, not an atomic release. Check both the
GitHub Actions run and Railway deployment before considering a release complete.
If a Pages upload fails, rerun its failed job after correcting the cause. Uploads
are serialized across production workflow runs; failures for one static site do
not cancel the other. No credentials are passed to pull-request builds.

Local validation:

```sh
npm ci --prefix web/reading-site
npm run build --prefix web/reading-site
npm run build --prefix web/landing-site
node scripts/check-static-sites.mjs
```

Provider reference: [Cloudflare Direct Upload with CI](https://developers.cloudflare.com/pages/how-to/use-direct-upload-with-continuous-integration/).
