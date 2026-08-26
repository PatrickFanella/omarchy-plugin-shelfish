# Shelfish

Shelfish organizes existing Omarchy bar widgets into named, collapsible groups. It adds a settings button and one icon button per group while keeping each member widget's normal popup and interactions.

## Compatibility and dependencies

Shelfish targets Omarchy 4 with the Quattro shell. It uses the standard Omarchy bar plugin API and Quattro's internal `shell.bar.moduleSlots` API. Changes to that internal API may break group visibility management.

Shelfish has no third-party runtime dependencies.

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

Shelfish stores its settings on its own bar layout entry. When configuration changes, it uses Omarchy's `mutateShellConfig` API to move each configured member beside the Shelfish entry. Groups follow manager order. Members follow their order inside each group. A right-facing group uses `group icon, members`; a left-facing group uses `members, group icon`.

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

Omarchy plugins run unsandboxed. Shelfish changes `~/.config/omarchy/shell.json` only through Omarchy's `mutateShellConfig` API. It does not use the network, request elevated privileges, or start external processes.

## Development and validation

Run all checks from the repository root:

```sh
tests/check-all.sh
omarchy plugin validate .
qmllint BarWidget.qml GroupButton.qml ManagePanel.qml Service.qml
```

The test script runs model and release metadata tests, then runs `qmllint` and Omarchy validation when those commands are installed.

## Known limitations

- Shelfish depends on Quattro's internal `moduleSlots` API.
- It groups only installed bar plugins with live module slots.
- It cannot restore pre-group layout positions.
- Status discovery is polling-based with a 500 ms interval.
