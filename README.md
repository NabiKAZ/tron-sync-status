# tron-sync-status

A tiny bash script that shows live sync progress of a local **TRON full node**, comparing it against the public network via [TronGrid](https://www.trongrid.io/).

It prints a continuously updating, color-coded status line with:

- **Local** — latest block number on your local node, plus the delta since the last check
- **Network** — latest block number on the public network, plus the delta since the last check
- **Remain** — how many blocks you're behind, plus the delta since the last check
- **Speed** — local sync speed, in blocks/second
- **ETA** — estimated time until your node is fully synced

## Example output

```
[2026-07-27 11:06:17] Local=84737711 (+194) Network=84822778 (+192) Remain=85067 (-2) Speed=19.40 blk/s ETA=1h 13m 5s
```

## Screenshot

<img width="1000" height="436" alt="Image" src="https://github.com/user-attachments/assets/0dc8a90c-64e0-49c4-8588-f762cb200242" />

## Requirements

- `bash`
- `curl`
- [`jq`](https://stedolan.github.io/jq/)
- `bc`

On Debian/Ubuntu:

```bash
sudo apt-get install -y curl jq bc
```

## Usage

```bash
chmod +x status.sh

# refresh every 10 seconds (default)
./status.sh

# refresh every 20 seconds
./status.sh 20
```

Stop it anytime with `Ctrl+C`. It runs in an infinite loop, so leave it running in a dedicated terminal, `tmux`/`screen` pane, or in the background with `nohup ./status.sh &`.

## Configuration

By default the script talks to:

- Local node: `http://127.0.0.1:8090`
- Public network: `https://api.trongrid.io`

If your local node's HTTP API listens on a different host/port, edit the `LOCAL_RAW=...` line near the top of the loop in `status.sh`.

## How ETA is calculated

ETA is based on how fast the **gap** (`Remain`) is shrinking between two consecutive checks, not just on your local node's raw block-processing speed. This is intentional: while you sync, the network keeps producing new blocks too, so the true catch-up rate is `network growth − local growth`. If the gap isn't shrinking, the script shows `Not closing` instead of a misleading estimate.

## Ideas for further improvements

See the [Possible improvements](#possible-improvements) notes below if you'd like to extend the script — contributions welcome.

<a id="possible-improvements"></a>
### Possible improvements

- **Smoother ETA/speed**: average the last N iterations (e.g. a rolling window) instead of only the previous one, to reduce jitter — especially with short intervals.
- **Config via flags/env vars**: `--local-url`, `--network-url`, `--interval`, instead of editing the script or relying on a single positional argument.
- **Multiple network endpoints**: fall back to another public API (or your own trusted node) if TronGrid is unreachable or rate-limits you.
- **Retry/backoff**: retry a failed request a couple of times before printing an error line.
- **JSON/quiet output mode**: an optional machine-readable output mode for piping into other tools or dashboards (e.g. Grafana via a text file / Prometheus textfile collector).
- **Desktop/Telegram notification** when sync completes (`Remain` reaches 0).
- **API key / rate limiting**: support passing a TronGrid API key (`TRON-PRO-API-KEY` header) to avoid public rate limits.
- **Logging option**: optional `--log FILE` flag for users who *do* want persistent logs (kept optional, since the default is terminal-only by design).
- **Progress bar**: a simple ASCII progress bar showing `Local/Network` as a percentage.
- **Systemd service / cron-friendly single-run mode**: a `--once` flag to print one line and exit, for use in monitoring systems instead of the infinite loop.

## Author

Made with ❤️ by **NabiKAZ**.

- 🐦 Twitter: [twitter.com/NabiKAZ](https://twitter.com/NabiKAZ)
- 💬 Telegram: [t.me/BotSorati](https://t.me/BotSorati)
- 💻 GitHub: [github.com/NabiKAZ](https://github.com/NabiKAZ)

If this project was useful for you, please consider giving it a ⭐ on GitHub!

## Donate

If you'd like to support continued development:

- **TON Wallet:** `nabikaz.ton`

## License

MIT — see [LICENSE](LICENSE).

