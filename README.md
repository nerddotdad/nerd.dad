# nerd.dad

Site and documentation for [nerd.dad](https://nerd.dad/) (GitHub Pages).

## Homelab docs

Hand-written homelab / cluster documentation lives under **`docs/homelab/`** and is published at:

https://nerd.dad/latest/homelab/

See `docs/homelab/index.md` for conventions. GitOps cluster config lives in [truecharts](https://github.com/nerddotdad/truecharts).

## Docs deploy

Version = current month (`YYYY.MM`, e.g. `2026.07`), always aliased as `latest`.

- **Push to `main` / manual run:** overwrite that month’s version and refresh `latest`
- **New month:** first deploy creates the new `YYYY.MM`; prior months stay in the version dropdown
