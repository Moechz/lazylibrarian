# lazylibrarian-for-tos

> TerraMaster TOS 7 App Center — **Docker application** package for
> [LazyLibrarian](https://gitlab.com/LazyLibrarian/LazyLibrarian).

## What this is

A four-file TOS Docker application archive (`lazylibrariandocker.tar.gz`) that installs
LazyLibrarian on TOS 7 through the App Center:

- `config.ini` — TOS application metadata (`application_type: docker`, id `lazylibrariandocker`)
- `lazylibrariandocker.lang` — 23-language superset (TOS requires 14)
- `lazylibrariandocker.svg` — application icon (326 bytes, 2 SVG elements)
- `docker-compose.yml` — one service, image `linuxserver/lazylibrarian:8b6ba443-ls392`

## How it works

| | |
|---|---|
| Container image | `linuxserver/lazylibrarian:8b6ba443-ls392` (Docker Hub, used unmodified) |
| Open | `http://<NAS-IP>:8008/` (container port 5299) |
| Runs as | non-root, `user: "1000:1000"` |
| Persistent data | `/config` → `/Volume1/DockerAppData/lazylibrariandocker/config`, `/downloads` → `/Volume1/DockerAppData/lazylibrariandocker/downloads`, `/books` → `/Volume1/DockerAppData/lazylibrariandocker/books` |
| Logs | `docker logs lazylibrariandocker` (stdout/stderr) |

`config/` holds `config.ini` (all settings), the SQLite database, `log/` and `cache/`; `/books` is the library folder and `/downloads` the incoming folder, both mounted from the application data directory. Copying the `lazylibrariandocker` folder is a complete backup.

## Design highlights

- **Non-root.** `user: "1000:1000"`; verified on real hardware (the container reports uid 1000).
- **Entrypoint wrapper** (not a privilege shim): the image's s6 service manager needs root, so `src/entrypoint.sh` does the first-run setup and starts LazyLibrarian directly as the unprivileged container user.
- **Deterministic build**: GNU tar with uid/gid 0 and zeroed timestamps, gzip without a timestamp, plus the review-standards self-check above.
- **Non-root by construction.** The s6 service manager of the image needs root, so the wrapper performs the first-run setup itself and starts LazyLibrarian as `1000:1000`; verified on real hardware.
- **Fixed image tag `8b6ba443-ls392`** (upstream has no release numbers, so the app version is the image build date), Docker Hub only, no `privileged`, no `network_mode: host`, no `cap_add`, no Docker socket.
- **Health check** on the UI (`GET /` on port 5299) with a 120 s start period for the first start.

## Runtime file manifest

Everything the application writes on the NAS lives inside its own data
directory; the container-internal `/tmp` is discarded with the container. The
table lists what is created and how it behaves. Nothing else is written.

| Path | Purpose | Created when | Growth bound | Lifecycle |
|---|---|---|---|---|
| `config/config.ini` | all settings - download client, providers, library folders, API key | first start | static, rewritten on every settings change | never overwritten after the first run; it is the whole configuration |
| `config/lazylibrarian.db` | SQLite database with authors, books, wanted list and history | first start | grows with the size of the library | managed by LazyLibrarian; back it up before uninstalling with data removal |
| `config/log` | application logs | first start | rotated by LazyLibrarian | safe to delete |
| `config/cache` | cached version information and covers | first start | small | safe to delete |
| `downloads` | incoming downloads before they are processed into the library | first start (empty) | grows with every download | managed by LazyLibrarian and by you |
| `books` | the organised eBook/audiobook library | first start (empty) | grows with the library | yours - move it out before uninstalling with data removal |
| `/Volume1/DockerAppData/lazylibrariandocker/config` | LazyLibrarian application data (everything the container writes outside /tmp) | on first start / on demand | bounded by your own data | persistent; kept on uninstall unless you ask to delete it |
| `/Volume1/DockerAppData/lazylibrariandocker/downloads` | LazyLibrarian application data (everything the container writes outside /tmp) | on first start / on demand | bounded by your own data | persistent; kept on uninstall unless you ask to delete it |
| `/Volume1/DockerAppData/lazylibrariandocker/books` | LazyLibrarian application data (everything the container writes outside /tmp) | on first start / on demand | bounded by your own data | persistent; kept on uninstall unless you ask to delete it |

## Build

```bash
scripts/build.sh                  # -> out/lazylibrariandocker.tar.gz + .sha256
scripts/build.sh 2026.11.07-2   # packaging iteration bump
scripts/build.sh 2026.11.07-1 aarch64
```

The build stages the four files, substitutes the version/platform placeholders,
embeds `src/entrypoint.sh` into the compose file (escaping every `$` as `$$`), removes CRLF/BOM/AppleDouble, then runs
`tools/verify.py`, a review-standards self-check (archive layout, JSON validity,
required fields, 14+ language coverage, version consistency, Docker-Hub-only
images, fixed tag, reserved/recommended host ports, non-root user, per-service
healthcheck/TZ/restart, data path below the application data root, never the
`/Volume*` wildcard, comment-free sequence blocks, `x-app-meta` position, no
literal secrets and the SVG size/element limits).

## Local verification

```bash
./TOSAppSelfTestingTool -c out/lazylibrariandocker.tar.gz   # official spec check
bash test/install-and-verify.sh                  # on-device E2E (needs root)
```

> Docker applications cannot be side-loaded through the App Center's manual
> install page (it accepts `.deb` only); the official self-testing tool's `-i`
> mode or `docker compose` are the only ways to install one for testing.

## Store submission checklist

1. Public GitHub repo (code + README only).
2. Release **tag `v2026.11.07-1`**, assets `lazylibrariandocker.tar.gz` +
   `lazylibrariandocker.tar.gz.sha256` (Docker asset naming: `<app_id>.tar.gz`, **no
   platform suffix**).
3. Developer platform → Add Application: ID `lazylibrariandocker`, package type Docker,
   repository URL, architecture `x86_64`.
4. Version Management → Add Version `2026.11.07-1` → automated validation → review.

## License / branding

LazyLibrarian is distributed by its upstream authors under **GPL-3.0**. The container image is the official image from Docker Hub (`linuxserver/lazylibrarian:8b6ba443-ls392`) and is used unmodified; no upstream source code is redistributed here. This packaging is an independent community submission by Moechz and is not affiliated with the upstream project or TerraMaster.

## Limitations

LazyLibrarian needs a download client (SABnzbd, NZBGet, Transmission, Deluge) and an indexer or book provider before it can fetch anything; none of them are bundled.
TOS Docker applications cannot mount shared folders: the library stays in `/Volume1/DockerAppData/lazylibrariandocker/books/` and downloads in `.../downloads/`. Edit `/Volume1/@apps/DockerEngine/application/lazylibrariandocker/docker-compose.yml` after installation to mount your own share.
The UI is served over plain HTTP on the LAN. Do not expose the published port to the internet without a TLS reverse proxy.

---

Packaged for TOS 7 by Moechz. Upstream image used unmodified from Docker Hub.
