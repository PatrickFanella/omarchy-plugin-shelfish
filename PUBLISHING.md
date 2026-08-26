# Publishing Shelfish

## Marketplace submission

- Repository URL: `https://github.com/patrickfanella/omarchy-plugin-shelfish`
- Category: `Widgets`
- Tags: `Bar`, `Quickshell`
- Issue title: `[Plugin]: Shelfish`

Submit through the [Omarchy Plugin Marketplace issue form](https://github.com/HANCORE-linux/omarchy-plugin-marketplace/issues/new?template=submit-plugin.yml).

## Release checklist

1. Run `tests/check-all.sh`.
2. Test install, enable, disable, restart, restore, and remove behavior.
3. Confirm `manifest.json` still reports version `1.0.2`.
4. Confirm the repository is public and unarchived.
5. Optionally add a root `preview.png`, `preview.jpg`, `preview.jpeg`, `preview.webp`, or `preview.avif`.
6. Commit and push the reviewed release files.
7. Optionally create tag and release `v1.0.2`.
8. Submit the repository root URL through the marketplace issue form.

The marketplace validates the submitted commit but does not security-audit or sandbox the plugin.
