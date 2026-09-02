# HiInterval static product site

This directory is the deployable document root for `https://hiinterval.malaber.de`.
It has no build step, JavaScript dependency, analytics, or backend requirement.

Public App Store URLs:

- Product: `https://hiinterval.malaber.de/`
- Capabilities: `https://hiinterval.malaber.de/capabilities/`
- Support: `https://hiinterval.malaber.de/support/`
- Privacy: `https://hiinterval.malaber.de/privacy/`

For local preview:

```bash
cd website
python3 -m http.server 8080
```

The support/privacy contact address is currently `hiinterval@malaber.de`; change both HTML files if a different mailbox should be used.
