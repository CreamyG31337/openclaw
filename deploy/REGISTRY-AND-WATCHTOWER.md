# Registry + Watchtower (auto-update) — simple steps

This gets you: **build from your fork → push to GitHub Container Registry → gateway runs from that image → Watchtower pulls updates and restarts the gateway.**

**What the token is for:** The GitHub token is only for **deploying** — i.e. when you (or the deploy script) run the build and push to ghcr.io. The server uses it to run `docker push`. The OpenClaw gateway/agent does **not** use this token unless you later add a feature where the agent triggers a rebuild+push.

---

## Step 1: Create a GitHub token (one-time)

1. Open **https://github.com/settings/tokens**
2. Click **Generate new token (classic)**
3. Name it e.g. `openclaw-push-ghcr`
4. Expiration: pick what you want (90 days or no expiration)
5. Under **Scopes**, check **write:packages** (and **read:packages** if you want)
6. Click **Generate token** and **copy the token** (you won’t see it again)

---

## Step 2: Deploy with registry (from your PC)

**One-time:** Copy `deploy/.env.example` to `deploy/.env` (`.env` is gitignored). Fill in at least:

- `OPENCLAW_SERVER` — your server hostname
- `OPENCLAW_DEPLOY_USER` — SSH user (e.g. `deploy`)
- `OPENCLAW_KEY_PATH` — path to your SSH private key
- `GHCR_TOKEN` — the GitHub token from Step 1 (so the script won’t prompt)

Then open PowerShell in the **deploy** folder and run:

```powershell
.\deploy-with-registry.ps1
```

If `GHCR_TOKEN` isn’t in `.env`, it will prompt for the token once.

That script will:

- Use your fork (**CreamyG31337/openclaw**, branch **deploy**)
- Build the image on the server
- Push it to **ghcr.io/creamyg31337/openclaw:deploy**
- Start the gateway from that image (so Watchtower can update it)

(You can also set `$env:GHCR_TOKEN = "your_token"` and run the script so it doesn’t prompt.)

---

## Step 3: Make the package public (one-time, so Watchtower can pull)

1. Open **https://github.com/CreamyG31337?tab=packages**
2. Click the **openclaw** package
3. **Package settings** → **Change visibility** → **Public**

Then Watchtower on the server can pull without its own login.

---

## Step 4: Run Watchtower on the server (one-time)

SSH to the server and run this once (it starts Watchtower and keeps it running):

```bash
ssh -i YOUR_KEY_PATH YOUR_USER@YOUR_SERVER
```
(Use your usual SSH key path, user, and server hostname.)

Then on the server:

```bash
docker run -d --name watchtower --restart unless-stopped \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e WATCHTOWER_POLL_INTERVAL=3600 \
  containrrr/watchtower openclaw-gateway
```

That checks every **hour** (3600 seconds) by default. If the image **ghcr.io/creamyg31337/openclaw:deploy** has changed, Watchtower pulls it and restarts the **openclaw-gateway** container.

**Faster polling (optional):** Use a shorter interval, e.g. 5 minutes: set `WATCHTOWER_POLL_INTERVAL=300` in the `docker run` above.

---

## Immediate update (no Watchtower wait)

When you push a new image and don't want to wait for the next Watchtower poll, run **trigger-update.ps1** from the deploy folder. It SSHs to the server and runs `~/openclaw/pull-and-restart.sh`, which pulls the latest image and restarts the gateway. (That script is written by remote-setup.sh on each deploy.) So: **deploy** gives you the new image right away; **trigger-update** is for when the image was pushed from elsewhere (e.g. CI) or you want to pull + restart without a full deploy.

---

## After that

- **Normal deploy (you run it):** Run `.\deploy-with-registry.ps1` again (with your token). Server builds from your fork, pushes to ghcr.io, restarts. Watchtower doesn’t need to do anything unless you want it to poll.
- **Immediate update:** After pushing an image (e.g. from CI), run `.\trigger-update.ps1` so the server pulls and restarts without waiting for Watchtower.
- **Watchtower auto-update:** If you don't run trigger-update, Watchtower will pull and restart within the poll interval (e.g. 1 hour or 5 min if you set `WATCHTOWER_POLL_INTERVAL=300`).
- **Agent-driven update (later):** We can add a way for the OpenClaw agent to trigger a rebuild+push so it “updates itself”; that would still use this same image and Watchtower.

---

## Troubleshooting

- **403 when pushing:** Token must have **write:packages**. Check **Step 1**.
- **Watchtower not updating:** Make sure the gateway was started from the registry image (Step 2), and the package is public (Step 3). Check with: `docker inspect openclaw-gateway --format '{{.Config.Image}}'` → should be `ghcr.io/creamyg31337/openclaw:deploy`.
- **Token in script:** The script only uses the token in that run; it’s passed to the server for `docker push` and not saved to disk by this guide.
