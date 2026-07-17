# nerd.dad

Site and documentation for [nerd.dad](https://nerd.dad/) (GitHub Pages).

## Homelab docs

Hand-written homelab / cluster documentation lives under **`docs/homelab/`** and is published at:

https://nerd.dad/latest/homelab/

See `docs/homelab/index.md` for conventions. GitOps cluster config lives in [truecharts](https://github.com/nerddotdad/truecharts).

## Docs deploy

- **Push to `main`:** updates rolling `main` → `latest` (no new history entry)
- **Monthly (1st):** snapshots previous month as `YYYY.MM` if there were commits since the last `docs/*` tag
- **Actions → Run workflow:** choose `rolling` or `milestone` (current `YYYY.MM`)
