# AI Usage Meters (Rainmeter)

Two small Rainmeter skins — **Claude Limits** and **Codex Tokens** — that show
how much of your current Claude Code and OpenAI Codex usage windows you've
burned through, as simple percentage bars on the Windows desktop.

## What it does

- Reads `@Resources/UsageData.json` once per second and renders:
  - a percent (e.g. `40%`)
  - a horizontal fill bar
  - a short reset-time label
- Optionally refreshes that JSON every 5 minutes by shelling out to
  `@Resources/Update-UsageData.ps1`, which scrapes the `/usage` panel from
  the Claude Code TUI and the `/status` panel from the Codex TUI via
  [`node-pty`].

The scrapers use whatever CLI you're already logged into — nothing is sent
anywhere, no API keys are involved, and nothing is stored besides the local
`UsageData.json`.

## Install

1. Copy this folder into your Rainmeter skins directory, e.g.
   `C:\Users\<you>\Documents\Rainmeter\Skins\AIUsageMeters\`.
2. In Rainmeter, refresh all, then load:
   - `AIUsageMeters\Claude\Claude.ini`
   - `AIUsageMeters\Codex\Codex.ini`

That's enough to see the skins — they'll read whatever is in
`UsageData.json` (zeros by default).

## Optional: auto-refresh from the CLIs

If you want the numbers to update themselves:

1. Install Node.js 18+.
2. From `@Resources/`, run `npm install` (pulls in `node-pty`).
3. Make sure `claude` and `codex` are on your PATH and already logged in.
4. The Claude skin runs `Update-UsageData.ps1` every 5 minutes on its own.

On Windows, node-pty can't spawn the `codex.cmd` shim directly, so
`scrape-codex.js` targets the real `codex.exe` inside the npm global install.
If yours lives somewhere else, set the `CODEX_EXE` env var.

## Manual editing

You can also just hand-edit `@Resources/UsageData.json`:

```json
{
  "claude": {
    "session":         { "used": 40, "max": 100, "resetAtUtc": "2026-04-13T23:15:00Z" },
    "weeklyAllModels": { "used": 5,  "max": 100, "resetAtUtc": "2026-04-20T17:00:00Z" },
    "weeklySonnet":    { "used": 9,  "max": 100, "resetAtUtc": "2026-04-14T15:00:00Z" }
  },
  "codex": {
    "session": { "used": 7, "max": 100, "resetAtUtc": "2026-04-14T05:41:00Z" },
    "weekly":  { "used": 1, "max": 100, "resetAtUtc": "2026-04-20T20:41:00Z" }
  }
}
```

`resetAtUtc` accepts ISO-8601 UTC (`...Z`) for a live countdown, or any free
text (`"6am"`, `"Apr 20"`) which is shown as-is.

## License

MIT.

[`node-pty`]: https://github.com/microsoft/node-pty
