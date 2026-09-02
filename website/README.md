# HiInterval static product site

This directory is the deployable document root for `https://hiinterval.malaber.de`.
It has no build step, JavaScript dependency, analytics, or backend requirement.

Public site URLs:

- Product: `https://hiinterval.malaber.de/`
- Capabilities: `https://hiinterval.malaber.de/capabilities/`
- Support: `https://hiinterval.malaber.de/support/`
- Privacy: `https://hiinterval.malaber.de/privacy/`

For local preview:

```bash
cd website
python3 -m http.server 8080
```

The support/privacy contact address is `hiinterval@schaedler.rocks`; change both HTML files if a different mailbox should be used.

## GitHub Pages

`.github/workflows/pages.yml` publishes this directory after website changes land on `main`.
In the repository's **Settings → Pages**, select **GitHub Actions** as the publishing source and
set `hiinterval.malaber.de` as the custom domain. The DNS record for `hiinterval` must be a CNAME
to `malaber.github.io`. The `CNAME` file documents the intended hostname, but GitHub requires the
custom domain to be configured in repository settings when publishing through Actions.
