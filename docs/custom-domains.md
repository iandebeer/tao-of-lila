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

Deploy the **contents** of `web/reading-site/dist` to Cloudflare Pages using
Direct Upload. To update, rebuild and upload a new production deployment to the
same Pages project. Pushing the game repository alone does not update a Direct
Upload project. Alternatively create a Git-integrated Pages project with repository
root `.`, build command `npm ci --prefix web/reading-site && npm run build --prefix
web/reading-site`, output `web/reading-site/dist`, and Node 22 or later.

Attach `read.leela.day` through the Pages project's **Custom domains** tab. Let
Cloudflare create its DNS record. A DNS record alone does not register the host
with Pages. See [Cloudflare Pages custom domains](https://developers.cloudflare.com/pages/configuration/custom-domains/).

Validation: build succeeds; local page, image and section links checked; desktop
Safari appearance inspected. HTTPS checks returned 200 for `play.leela.day/health` and `read.leela.day/`
on 14 October 2026. The deployed homepage, manual, pamphlet, diagram and stylesheet
were byte-compared against the final local build and matched. These changes do
not modify the Haskell engine.
