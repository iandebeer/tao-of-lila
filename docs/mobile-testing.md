# Test on a phone with Podman and Tailscale

## Prepared on this Mac

The container build, health check, and Persona/journey HTTP smoke tests passed.
Private Tailscale TCP forwarding is configured on port 8080. With Tailscale connected
on your phone, open **http://100.123.26.48:8080/journey/** (Mac: `bowcaster-2`).
The tailnet hostname is **http://bowcaster-2.tailf32b27.ts.net:8080/journey/**.
These addresses belong to this Mac's current Tailscale registration; use
`tailscale ip -4` if the device is re-registered. HTTPS setup below is optional.

The mobile stack runs both the Haskell API and PostgreSQL inside Podman. It builds
both TypeScript ceremonies and serves the browser UI and API from one address.
Its `tao-mobile` Compose project has a separate persistent database volume; your
existing local prototype accounts are not copied into it. PostgreSQL has no
published host port.

The image uses GHC 9.10.3 on Debian Bookworm. `cabal.project.container` supplies
the container-only Crypton version constraint needed for ARM builds with GCC 12;
it does not change your native Cabal configuration.

## 1. Start the app on your Mac

Podman and the Docker Compose provider are already installed on this Mac.
From Terminal:

```bash
cd /Users/ian/dev/iandebeer.github.io/tao-of-lila
./scripts/mobile.sh start
```

The script starts the existing Podman VM if needed, builds the image, waits for
PostgreSQL, then checks the API. The first build downloads Linux images and
compiles Haskell dependencies, so allow substantial time. Later builds use caches.
If Compose is not found, install the provider with `brew install docker-compose`.
On a new Mac without a VM, first run `podman machine init`.

Open <http://localhost:8080/> (which opens `/journey/`) and register a test
account. Choose **Create Persona and begin** to enter its journey. The older
diagnostic UI is at `/?prototype`; the standalone ceremony is at `/yarrow/`.
Both casting interfaces generate one complete line per click. Check that six
clicks reveal all six lines, and that returning to an interrupted cast resumes
its accepted state.

AI contemplation is optional. To enable it, make `OPENAI_API_KEY` available in
your shell before starting the stack; `OPENAI_MODEL` is optional. Restart with
the start command after changing these variables. Keys stay on the server;
do not put them in browser files or commit them. Without a key, game mechanics
work but live AI contemplation is unavailable.

If port 8080 is occupied, use `TAO_PORT=8082 ./scripts/mobile.sh start` and replace
8080 with 8082 in the commands below.

## 2. Connect Tailscale on the Mac and phone

Open the installed Tailscale app on your Mac, sign in if prompted, and turn the
connection on. Install Tailscale on your iPhone or Android phone, sign in to the
same Tailscale network, and enable its VPN connection.

Tailscale is a private network between your devices, separate from your Wi-Fi
subnet. The phone can use Wi-Fi or mobile data. Keep the Mac awake and connected.

The Mac app includes its CLI even though `tailscale` is not currently on PATH:

```bash
TS=/Applications/Tailscale.app/Contents/MacOS/Tailscale
"$TS" status
"$TS" serve --bg --tcp=8080 tcp://127.0.0.1:8080
"$TS" ip -4
```

Open `http://THE_PRINTED_IP:8080/journey/` on the phone. This private TCP forwarder carries the app's HTTP traffic
and works without enabling Tailscale's HTTPS certificates. To use HTTPS instead:

```bash
"$TS" serve --bg --https=443 http://127.0.0.1:8080
"$TS" serve status
```

If Serve prints an enablement URL, follow it to enable HTTPS for your tailnet,
then repeat the command. Serve prints a URL such as
`https://your-mac.your-tailnet.ts.net`. This is private to your tailnet; Funnel
is not needed. The app's host port is bound to loopback by default.

## 3. Open the game on the phone

In Safari or Chrome, open the HTTPS URL printed above with `/journey/` appended:

```text
https://your-mac.your-tailnet.ts.net/journey/
```

Use your test account, create a Persona, and begin its journey. Do not use
`localhost` on the phone—it refers to the phone itself.

For a literal Tailscale IP instead of the HTTPS hostname, you can use a separate
TCP forwarder:

```bash
"$TS" serve --bg --tcp=8080 tcp://127.0.0.1:8080
"$TS" ip -4
```

Open `http://THE_PRINTED_IP:8080/journey/` on the connected phone. Raw TCP forwarding
accepts both the IP and hostname; Tailscale's HTTP proxy can reject an IP Host header. Prefer HTTPS
for the normal flow. Browser login storage is separate for different origins,
so changing between IP and hostname can require signing in again.

## Optional: same Wi-Fi without Tailscale

Publish the app on the Mac's network interfaces:

```bash
TAO_BIND_ADDRESS=0.0.0.0 ./scripts/mobile.sh start
ipconfig getifaddr en0
```

Find the Wi-Fi IP in System Settings → Wi-Fi → Details → TCP/IP if `en0` is not
your Wi-Fi interface. On the same Wi-Fi, open
`http://YOUR_MAC_WIFI_IP:8080/journey/`. Allow incoming connections through the
Mac firewall if prompted. Guest Wi-Fi/client isolation can prevent this path.
This exposes the app to that LAN over HTTP; use it on a trusted test network.
Run `./scripts/mobile.sh start` without the binding override to return to the
default loopback binding.

## Stop, restart, and troubleshoot

```bash
./scripts/mobile.sh status
./scripts/mobile.sh logs
curl --fail http://127.0.0.1:8080/health
./scripts/mobile.sh stop
```

Stop preserves the database volume. Do not add `down -v` unless you intend to
delete test accounts and journeys. Run `start` again after source changes to
rebuild. Neither command stops other Podman projects.

Disable the Tailscale listeners when finished (only those you enabled):

```bash
"$TS" serve --https=443 off
"$TS" serve --tcp=8080 off
```

If localhost works but the phone cannot connect, check both devices are connected
to the same tailnet, check `"$TS" serve status`, and check that tailnet access
rules allow the phone to reach the Mac. If building runs out of memory, stop
the VM when other containers are not needed, allocate more memory with
`podman machine set --memory 4096`, then start again.

References: [Podman Compose](https://docs.podman.io/en/latest/markdown/podman-compose.1.html),
[Tailscale Serve](https://tailscale.com/docs/reference/tailscale-cli/serve),
[macOS CLI](https://tailscale.com/docs/reference/tailscale-cli?tab=macos).
