# Shelfish

<a href="https://subcult.tv">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/brand/subcult-dark.svg">
    <img src="docs/brand/subcult-light.svg" alt="SUBCULT" width="400">
  </picture>
</a>

[SUBCULT](https://subcult.tv) · [Support on Patreon](https://patreon.com/subcult)

Shelfish organizes existing Omarchy bar widgets into named, collapsible groups. It adds a settings button and one icon button per group while keeping each member widget's normal popup and interactions. Its interface is localized in ten languages.

## Compatibility and dependencies

Shelfish targets Omarchy 4 with the Quattro shell. It uses the standard Omarchy bar plugin API and Quattro's internal `shell.bar.moduleSlots` API. Changes to that internal API may break group visibility management.

Shelfish has no third-party runtime dependencies.

## Languages

Shelfish supports English, German, Spanish, French, Italian, Brazilian Portuguese, Dutch, Polish, Croatian, and Simplified Chinese. It detects the locale from the shell automatically and falls back to English when necessary.

Omarchy does not support localized plugin manifest fields. The plugin name, description, category, and advanced schema metadata therefore remain in English.

## Install

```sh
omarchy plugin add https://github.com/patrickfanella/omarchy-plugin-shelfish.git --enable
```

Add the Shelfish bar widget through Omarchy's bar settings if it is not added automatically.

## Set up and use groups

1. Select the sliders icon to open Shelfish settings.
2. Create or select a group.
3. Set its name, icon, and direction.
4. Add installed bar plugins from the available plugins list.
5. Use Up and Down to order groups and members.

Select a group icon to reveal that group's widgets. Select it again to close the group. Right-click a group icon to open settings. Middle-click one to close all groups.

The available-plugin list also includes a `Shelfish settings` shortcut. Add it to any group to place a second settings icon beside that group. This shortcut opens the manager directly and does not toggle or reveal the group. The primary Shelfish settings icon remains a stable anchor and stays outside groups.

Shelfish can reveal a group when a member's watched status changes. Advanced status paths use `plugin.id=path|nested.path;other.id=count`. Shelfish also reads explicit `shelfishStatus` and legacy `omatenderStatus` properties. It does not infer status from unrelated widget internals. Per-widget policies can disable automatic reveal or override its duration.

Status snapshots accept only `null`, booleans, finite numbers, and strings. Shelfish limits path count and depth, truncates scalar strings, and caps each aggregate snapshot.

## Layout changes

Shelfish stores its settings on its own bar layout entry. Omarchy Quattro only lets `bar`-kind plugins call `mutateShellConfig`, so Shelfish saves through `apply-layout.py`. The helper writes the settings to that entry and places the open group's members beside its group button. It replaces `shell.json` atomically. Groups follow manager order. Members follow their order inside each group. A right-facing group uses `group icon, members`; a left-facing group uses `members, group icon`.

Only the open group's members are in the layout. Closed groups keep their members' settings in `widgetConfigs`, so hidden widgets are not loaded on every bar. Opening or closing a group saves the layout, and the bar rebuilds.

Member entries, including duplicate instances, keep their complete configuration. Missing entries are skipped. A widget can belong to only one Shelfish group. The native `omarchy.tray` entry cannot be grouped.

Shelfish does not remember a member's original layout position.

## Restore and remove

Restore removes every generated group entry and makes all managed widget instances visible. It does not restore their historical positions. Run restore immediately before removing the plugin:

```sh
omarchy-shell io.github.patrickfanella.shelfish restoreAll
```

Then immediately remove Shelfish:

```sh
omarchy plugin remove io.github.patrickfanella.shelfish
```

## Permissions and security

Omarchy plugins run unsandboxed. Shelfish changes `~/.config/omarchy/shell.json` by running its bundled `apply-layout.py` helper with `python3`. It does not use the network or request elevated privileges.

## Development and validation

Run all checks from the repository root:

```sh
tests/check-all.sh
omarchy plugin validate .
qmllint BarWidget.qml GroupButton.qml ManagePanel.qml Service.qml
```

The test script runs model, localization, scoped shell compatibility, and release metadata tests, then runs Omarchy validation when the CLI is installed. Standalone `qmllint` is not used because it cannot resolve all Quickshell runtime types; releases also receive a controlled live shell check.

## Known limitations

- Shelfish depends on Quickshell's Wayland window scene graph and `moduleSlots` architecture.
- It groups installed bar plugins with live module slots and registered entries in `shell.json`.
- It cannot restore pre-group layout positions.

## Shell API compatibility and multi-monitor architecture

In Omarchy 4.0.3+, third-party plugins are sandboxed behind capability-scoped facades (`PluginShellApi` and `PluginBarApi`). Shelfish supports this architecture seamlessly:

- **Layout-Level Active Group Mounting:** Rather than mounting all configured widgets simultaneously and relying purely on visual hiding, Shelfish mounts only the currently active group in `bar.layout.center`. Inactive group widgets are omitted from the layout array, preventing Quickshell from instantiating redundant `ModuleSlot` and `registryLoader` instances across multi-monitor setups.
- **Widget Option Preservation:** Custom widget configurations and options are preserved in `config.widgetConfigs` across group transitions so that user settings are retained when widgets are swapped.
- **Window Deduplication and Lifecycle Management:** Slot discovery deduplicates traversals by Wayland window root, and group buttons cleanly unregister from the service upon destruction to prevent event loop leaks and invalid QML context evaluations.
- **Fallback State:** When no usable slots or configuration are available, widgets remain visible, saved groups are retained, and an explicit compatibility message is displayed. Grouping resumes automatically when host slot discovery succeeds.

## About SUBCULT and support

Made by [Patrick Fanella](https://patrickfanella.co) as part of
[SUBCULT](https://subcult.tv). Explore the tools and projects at
**[subcult.tv](https://subcult.tv)**.

If this plugin is useful to you, **[support SUBCULT on Patreon](https://patreon.com/subcult)**
to help fund its development and the wider project.
