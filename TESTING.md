# Testing the Claude Code Max Setup on Railway

This guide covers deploying Hermes with your Claude Code Max subscription via the Meridian proxy.

---

## Prerequisites

- Claude Code installed and logged in on your Mac (`claude --version` should work)
- Hermes deployed to Railway (or ready to redeploy)
- Railway CLI installed (`npm install -g @railway/cli`) or access to the Railway dashboard

---

## Step 1 — Extract your Claude Code credentials

Run this in your terminal. It reads the credentials JSON from your macOS Keychain:

```bash
security find-generic-password -s "Claude Code-credentials" -w
```

You should get a JSON blob starting with `{`. Copy the **entire output** — you'll need it in the next step.

If this returns nothing or an error, make sure you're logged into Claude Code:

```bash
claude login
```

Then try the `security` command again.

---

## Step 2 — Add the Railway environment variable

In the Railway dashboard for your Hermes service, go to **Variables** and add:

| Variable | Value |
|---|---|
| `CLAUDE_CREDENTIALS` | The full JSON blob from Step 1 |

This is treated as a secret — Railway will mask it in the UI.

> **Note:** Every time you log out and back in to Claude Code locally, your credentials will rotate. If the proxy stops working, repeat Steps 1–2 and redeploy.

---

## Step 3 — Redeploy

Trigger a redeploy in Railway (push a commit or click **Deploy** in the dashboard).

---

## Step 4 — Verify Meridian started in the logs

In Railway, open the **Deploy Logs** for the new deployment and look for these lines near the top:

```
[start] Claude credentials written
[start] Meridian proxy starting on http://127.0.0.1:3456
[start] Meridian is ready
```

If you see `WARNING: Meridian did not start in time`, click **View Logs** on the deployment and check for errors. The most common cause is expired or malformed credentials — redo Steps 1–2.

---

## Step 5 — Configure Hermes via the admin UI

1. Open your Railway service URL in a browser (e.g. `https://your-app.up.railway.app`)
2. Log in with your admin credentials (printed in deploy logs on first boot if you haven't set `ADMIN_PASSWORD`)
3. In the **LLM Provider** section:
   - **Provider:** `Claude Code (Proxy)`
   - **API Key:** `x` (any dummy value — Meridian handles real auth)
   - **API Base URL:** `http://127.0.0.1:3456`
   - **LLM Model:** `claude-opus-4-5` (or whichever Claude model you want)
4. Click **Save & Restart**

---

## Step 6 — Confirm the gateway started

Back in Railway deploy logs (or the live log stream), you should see the Hermes gateway start:

```
[gateway] model=claude-opus-4-5 | provider_key=set
```

If `provider_key=⚠ NOT SET` appears, the config wasn't saved correctly — go back to Step 5.

---

## Step 7 — Send a test message

Depending on which messaging channel you've configured:

**Telegram:** Open your bot and send:
```
Hello, what model are you?
```

**Discord:** Mention the bot or use its DM:
```
@HermesBot what model are you?
```

A successful response confirms the full chain is working:
`Your app → Railway → Hermes → Meridian → Claude Code SDK → Claude API (billed to your Max subscription)`

---

## Troubleshooting

**Meridian crashes after a few hours**

Your OAuth access token expired (8-hour lifetime). Meridian should auto-refresh using the refresh token in your credentials JSON. If it doesn't:
- Check if the credentials JSON you extracted includes a `refreshToken` field
- Try logging out and back in locally (`claude logout && claude login`), then redo Steps 1–2

**"Model not found" or 401 errors from Hermes**

- Confirm `ANTHROPIC_BASE_URL` is set to `http://127.0.0.1:3456` (not a public URL)
- Confirm Meridian started successfully in the logs (Step 4)
- Check `/tmp/meridian.log` via Railway's shell: `railway run cat /tmp/meridian.log`

**Admin UI shows setup as incomplete**

The `isSetupDone` check requires both `ANTHROPIC_API_KEY` and `LLM_MODEL` to be set. Make sure you filled in both fields in Step 5.
