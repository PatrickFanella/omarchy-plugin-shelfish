import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model
import "I18n.js" as I18n
import "SharedService.js" as SharedService

Item {
  id: root

  readonly property string moduleName: "io.github.patrickfanella.shelfish"
  readonly property string groupPrefix: moduleName + ".group."
  readonly property string localeName: Qt.locale().name
  property var shell: null
  property var manifest: null
  property var hostBar: null
  readonly property var effectiveShell: hostBar && hostBar.shell ? hostBar.shell : root.shell
  readonly property var effectiveBar: hostBar ? hostBar : (root.shell ? root.shell.bar : null)
  property var config: Model.normalizeConfig({})
  property string activeGroupId: config && config.activeGroupId ? config.activeGroupId : ""
  onConfigChanged: {
    var target = config && config.activeGroupId ? config.activeGroupId : ""
    if (target !== activeGroupId) activeGroupId = target
    if (target) selectedGroupId = target
  }
  property string revealedGroupId: ""
  readonly property bool revealed: revealedGroupId !== ""
  property var managedIds: []
  property var snapshots: ({})
  property double suppressStatusUntil: 0
  property double suppressGroupToggleUntil: 0
  property bool suspended: false
  property var panelHosts: []
  property var barWidgetRegistry: null
  // Group being edited in the manager; it survives closing groups on the bar.
  property string selectedGroupId: ""
  readonly property var editGroup: Model.groupById(config, selectedGroupId)
    || Model.activeGroup(config) || (config.groups.length ? config.groups[0] : null)
  property int revision: 0

  readonly property var activeGroup: Model.activeGroup(config)
  readonly property int managedCount: Model.allWidgetIds(config).length

  function tr(key, args) { return I18n.translate(localeName, key, args) }

  function entryId(entry) {
    return String(entry && typeof entry === "object" ? entry.id : entry || "")
  }

  function getHostBar() {
    if (hostBar) return hostBar
    for (var i = 0; i < panelHosts.length; i++) {
      if (panelHosts[i]) {
        var b = panelHosts[i].hostBar || panelHosts[i].bar
        if (b) return b
      }
    }
    return null
  }

  function registerHostBar(b) {
    if (!b || b === hostBar) return
    hostBar = b
    loadConfig()
    Qt.callLater(ensureGroupEntries)
    Qt.callLater(reconcileSlots)
  }

  function findEntry(configRoot) {
    var layout = configRoot ? (configRoot.bar ? configRoot.bar.layout : configRoot.layout) : null
    var sections = ["left", "center", "right"]
    for (var s = 0; layout && s < sections.length; s++) {
      var entries = layout[sections[s]]
      if (!Array.isArray(entries)) continue
      for (var i = 0; i < entries.length; i++)
        if (entryId(entries[i]) === moduleName)
          return typeof entries[i] === "object" ? entries[i] : { id: moduleName }
    }
    return null
  }

  function getEffectiveConfig() {
    var b = getHostBar()
    if (b && b.shell && b.shell.shellConfig) return b.shell.shellConfig
    if (shell && shell.shellConfig) return shell.shellConfig
    try {
      var fileText = userConfigFile.text()
      if (fileText) {
        var parsed = JSON.parse(fileText)
        if (parsed && typeof parsed === "object") return parsed
      }
    } catch (e) {}
    if (b && b.barConfig) return { bar: b.barConfig }
    if (shell && shell.barConfig) return { bar: shell.barConfig }
    return null
  }

  function sourceDir() {
    return decodeURIComponent(Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "")).replace(/\/$/, "")
  }

  // Preserve host slot discovery; show the fallback only when it finds no slots.
  readonly property bool groupingAvailable: canGroup()
  readonly property string compatibilityMessage: groupingAvailable ? ""
    : "No usable bar slots are available. Widgets remain visible; group editing is unavailable."

  function canGroup() {
    return !!effectiveShell && typeof effectiveShell.mutateShellConfig === "function"
      && !!getEffectiveConfig() && slots().length > 0
  }

  function syncGroupEntries(shellConfig, nextConfig) {
    var layout = shellConfig && shellConfig.bar ? shellConfig.bar.layout : (shellConfig ? shellConfig.layout : null)
    var dir = sourceDir()
    if (!layout || !dir) return
    var activeId = revealedGroupId || (nextConfig ? nextConfig.activeGroupId : "")
    var wConfigs = nextConfig ? nextConfig.widgetConfigs : null
    Model.syncGroupEntries(layout, nextConfig.groups, moduleName, groupPrefix, dir, activeId, wConfigs)
  }

  function ensureGroupEntries() {
    var shell = effectiveShell
    var raw = getEffectiveConfig()
    if (suspended || !groupingAvailable || !shell || !raw || typeof shell.mutateShellConfig !== "function" || !sourceDir()) return
    var copy
    try { copy = JSON.parse(JSON.stringify(raw)) } catch (error) { return }
    var before = JSON.stringify(copy.bar ? copy.bar.layout : copy.layout)
    syncGroupEntries(copy, config)
    if (before === JSON.stringify(copy.bar ? copy.bar.layout : copy.layout)) return
    shell.mutateShellConfig(function(shellConfig) { root.syncGroupEntries(shellConfig, root.config) })
  }

  function loadConfig() {
    var raw = getEffectiveConfig()
    var next = Model.normalizeConfig(findEntry(raw) || {})
    if (JSON.stringify(config.groups) !== JSON.stringify(next.groups)) revealedGroupId = ""
    // Keep the runtime open group across unrelated config reloads.
    if (activeGroupId && Model.groupById(next, activeGroupId)) next.activeGroupId = activeGroupId
    config = next
    activeGroupId = next.activeGroupId || ""
    revision++
  }

  Timer {
    id: settleTimer
    property int pass: 0
    interval: 250
    repeat: true
    onTriggered: {
      root.reconcileSlots()
      if (++pass >= 8) stop()
    }
  }

  Process {
    id: layoutWriter
    stderr: StdioCollector {
      onStreamFinished: if (text.trim()) console.warn("shelfish: apply-layout failed:", text.trim())
    }
  }

  FileView {
    id: userConfigFile
    path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    watchChanges: true
    onFileChanged: reload()
  }

  function persist(next) {
    if (suspended || !groupingAvailable) return false
    var normalized = Model.normalizeConfig(next)
    var payload = Model.serializeConfig(normalized)
    // Quattro refuses mutateShellConfig for non-`bar` plugins, so the helper
    // writes shell.json and places group members beside their buttons.
    layoutWriter.exec(["python3", sourceDir() + "/apply-layout.py", moduleName, groupPrefix,
      sourceDir(), JSON.stringify(payload)])
    var wrote = true
    // The bar rebuilds its slots asynchronously after shell.json changes, and
    // new slots start visible; re-apply visibility once they exist.
    settleTimer.pass = 0
    settleTimer.restart()
    if (wrote) {
      suppressStatusReveal()
      revealTimer.stop()
      revealedGroupId = ""
      config = normalized
      activeGroupId = normalized.activeGroupId || ""
      revision++
    }
    return wrote
  }

  function setActiveGroup(groupId) {
    if (groupId && !Model.groupById(config, groupId)) return false
    // Quattro only lets `bar`-kind plugins mutate the layout, so members stay in
    // the layout and opening a group is runtime slot visibility.
    var next = Model.normalizeConfig(config)
    next.activeGroupId = groupId
    config = next
    activeGroupId = groupId
    reconcileSlots()
    return true
  }
  function createGroup(name) { return persist(Model.addGroup(config, name)) }
  function deleteGroup(id) { return persist(Model.deleteGroup(config, id)) }
  function updateGroup(id, values) { return persist(Model.updateGroup(config, id, values)) }
  function moveGroup(id, offset) { return persist(Model.moveGroup(config, id, offset)) }
  function setWidget(groupId, widgetId, present) {
    if (widgetId === moduleName || widgetId === "omarchy.tray" || widgetId.indexOf(groupPrefix) === 0) return false
    return persist(Model.setWidgetMembership(config, groupId, widgetId, present))
  }
  function getEffectiveBar() {
    if (hostBar && hostBar.moduleSlots !== undefined) return hostBar
    for (var i = 0; i < panelHosts.length; i++) {
      if (panelHosts[i] && panelHosts[i].hostBar && panelHosts[i].hostBar.moduleSlots !== undefined)
        return panelHosts[i].hostBar
    }
    if (effectiveBar && effectiveBar.moduleSlots !== undefined) return effectiveBar
    return null
  }

  function slots() {
    var all = []
    var liveHosts = []
    var seenBars = []
    for (var i = 0; i < panelHosts.length; i++) {
      var host = panelHosts[i]
      if (!host) continue
      try {
        if (typeof host.getSlots === "function" && host.parent !== undefined) {
          liveHosts.push(host)
          var bar = host.hostBar || host.bar
          var top = host
          while (top && top.parent) top = top.parent
          var dedupeKey = bar || top
          if (dedupeKey && seenBars.indexOf(dedupeKey) !== -1) continue
          if (dedupeKey) seenBars.push(dedupeKey)

          var s = host.getSlots()
          if (s && s.length) {
            for (var j = 0; j < s.length; j++) {
              if (all.indexOf(s[j]) === -1) all.push(s[j])
            }
          }
        }
      } catch (e) {}
    }
    if (liveHosts.length !== panelHosts.length) panelHosts = liveHosts
    if (all.length > 0) return all

    var b = getEffectiveBar()
    if (!b || !b.moduleSlots) return []
    if (Array.isArray(b.moduleSlots)) return b.moduleSlots
    if (b.moduleSlots.length !== undefined) {
      var arr = []
      for (var k = 0; k < b.moduleSlots.length; k++) arr.push(b.moduleSlots[k])
      return arr
    }
    return []
  }

  function restoreAll() {
    var restore = {}
    var configured = Model.allWidgetIds(config)
    for (var c = 0; c < configured.length; c++) restore[configured[c]] = true
    for (var i = 0; i < managedIds.length; i++) restore[managedIds[i]] = true
    suspended = true
    revealTimer.stop()
    // mutateShellConfig is gated to `bar` plugins under Quattro; the helper
    // strips the generated group buttons instead.
    if (groupingAvailable)
      layoutWriter.exec(["python3", sourceDir() + "/apply-layout.py", moduleName, groupPrefix, sourceDir(), "--restore"])
    var all = slots()
    for (var s = 0; s < all.length; s++) {
      var slot = all[s]
      var id = slot ? String(slot.moduleName || "") : ""
      if (restore[id]) {
        slot.visible = true
        if (slot.activeItem) slot.activeItem.visible = true
      }
    }
    managedIds = []
    revealedGroupId = ""
    revision++
    return true
  }

  function reconcileSlots() {
    if (suspended || !groupingAvailable) return
    var nextManaged = Model.allWidgetIds(config).filter(function(id) {
      return id !== root.moduleName && id !== "omarchy.tray" && id.indexOf(root.groupPrefix) !== 0
    })
    var managed = {}
    var previous = {}
    for (var i = 0; i < nextManaged.length; i++) managed[nextManaged[i]] = true
    for (var p = 0; p < managedIds.length; p++) previous[managedIds[p]] = true
    var effectiveGroupId = revealedGroupId || config.activeGroupId || ""
    var group = Model.groupById(config, effectiveGroupId)
    var active = group ? group.widgets : []
    var all = slots()
    for (var s = 0; s < all.length; s++) {
      var slot = all[s]
      if (!slot) continue
      var id = String(slot.moduleName || "")
      if (id === "omarchy.tray" || id === moduleName) continue
      if (id.indexOf(groupPrefix) === 0) {
        if (id.slice(-9) === ".settings") {
          var shortcutGroup = id.slice(groupPrefix.length, -9)
          var shortcutVisible = revealedGroupId === shortcutGroup
          slot.visible = shortcutVisible
          if (slot.activeItem) slot.activeItem.visible = shortcutVisible
        }
        continue
      }
      if (managed[id]) {
        var show = active.indexOf(id) !== -1
        slot.visible = show
        if (slot.activeItem) slot.activeItem.visible = show
      } else if (previous[id]) {
        slot.visible = true
        if (slot.activeItem) slot.activeItem.visible = true
      }
    }
    managedIds = nextManaged
    revision++
  }

  function showGroup(id) {
    revealTimer.stop()
    if (!Model.groupById(config, id)) return
    revealedGroupId = ""
    setActiveGroup(id)
  }
  function hide() {
    revealedGroupId = ""
    revealTimer.stop()
    setActiveGroup("")
  }
  function toggleGroup(id) {
    revealTimer.stop()
    var isCurrent = (revealedGroupId ? revealedGroupId === id : config.activeGroupId === id)
    if (isCurrent) {
      hide()
    } else {
      showGroup(id)
    }
  }
  function show() { showGroup(config.activeGroupId || (config.groups[0] ? config.groups[0].id : "")) }
  function toggle() { config.activeGroupId ? hide() : show() }

  function suppressStatusReveal() { suppressStatusUntil = Date.now() + 1000 }
  function suppressGroupToggles() { suppressGroupToggleUntil = Date.now() + 350 }
  function canToggleGroups() { return !suspended && Date.now() >= suppressGroupToggleUntil }

  function registerPanelHost(host) {
    if (host && panelHosts.indexOf(host) === -1) {
      var next = panelHosts.slice(); next.push(host); panelHosts = next
      var b = host.hostBar || host.bar
      if (b) registerHostBar(b)
      Qt.callLater(reconcileSlots)
    }
  }
  function unregisterPanelHost(host) { panelHosts = panelHosts.filter(function(item) { return item !== host }) }
  function manage() {
    for (var i = 0; i < panelHosts.length; i++) {
      if (panelHosts[i] && typeof panelHosts[i].openManager === "function") return panelHosts[i].openManager()
    }
  }

  function policy(id) { return config.policies[id] || { autoReveal: true, revealSeconds: 0 } }
  function pollStatus() {
    if (suspended || !groupingAvailable) return
    var next = {}; var changed = false; var all = slots()
    var suppressed = Date.now() < suppressStatusUntil
    for (var i = 0; i < all.length; i++) {
      var slot = all[i]; var id = slot ? String(slot.moduleName || "") : ""
      var groupId = Model.widgetGroupId(config, id)
      if (!id || !groupId || !slot.activeItem) continue
      var snapshot = Model.statusSnapshot(slot.activeItem, id, config.watchedPaths)
      if (!snapshot) continue
      next[id] = snapshot
      if (!suppressed && snapshots[id] !== undefined && snapshots[id] !== snapshot && policy(id).autoReveal) {
        changed = true; revealedGroupId = groupId
        revealTimer.interval = (policy(id).revealSeconds || config.revealSeconds) * 1000
      }
    }
    snapshots = next
    if (changed) { reconcileSlots(); revealTimer.restart() }
  }

  function revealedMemberOwnsPopout() {
    var bar = getEffectiveBar()
    var owner = bar ? bar.activePopout : null
    var group = Model.groupById(config, revealedGroupId)
    if (!owner || !group) return false
    if (group.widgets.indexOf(String(owner.moduleName || "")) !== -1) return true
    var all = slots()
    for (var i = 0; i < all.length; i++) {
      var slot = all[i]
      if (!slot || group.widgets.indexOf(String(slot.moduleName || "")) === -1) continue
      var current = owner
      while (current) {
        if (current === slot.activeItem) return true
        try { current = current.parent } catch (error) { current = null }
      }
    }
    return false
  }

  function statusObject() {
    return {
      groupingAvailable: groupingAvailable,
      compatibilityMessage: compatibilityMessage,
      activeGroupId: config ? config.activeGroupId : "",
      revealedGroupId: revealedGroupId,
      managedWidgets: managedCount
    }
  }

  IpcHandler {
    target: root.moduleName
    function manage(): void { root.manage() }
    function show(): void { root.show() }
    function hide(): void { root.hide() }
    function toggle(): void { root.toggle() }
    function toggleGroup(id: string): void { root.toggleGroup(id) }
    function showGroup(id: string): void { root.showGroup(id) }
    function status(): string { return JSON.stringify(root.statusObject()) }
    function restore(): string { return root.restoreAll() ? "ok" : "failed" }
    function restoreAll(): string { return root.restoreAll() ? "ok" : "failed" }
  }

  Timer { id: pollTimer; interval: 500; repeat: true; running: false; onTriggered: root.pollStatus() }
  Timer {
    id: revealTimer
    interval: root.config.revealSeconds * 1000
    onTriggered: {
      if (root.revealedMemberOwnsPopout()) { interval = 500; restart() }
      else root.hide()
    }
  }

  Component.onCompleted: { SharedService.setService(root); loadConfig(); Qt.callLater(ensureGroupEntries); Qt.callLater(reconcileSlots) }
  onShellChanged: { loadConfig(); Qt.callLater(ensureGroupEntries); Qt.callLater(reconcileSlots) }
  onHostBarChanged: { loadConfig(); Qt.callLater(ensureGroupEntries); Qt.callLater(reconcileSlots) }
  Connections {
    target: root.shell
    ignoreUnknownSignals: true
    function onShellConfigChanged() { root.loadConfig(); Qt.callLater(root.ensureGroupEntries); Qt.callLater(root.reconcileSlots) }
    function onBarConfigChanged() { root.loadConfig(); Qt.callLater(root.ensureGroupEntries); Qt.callLater(root.reconcileSlots) }
    function onBarChanged() { Qt.callLater(root.reconcileSlots) }
  }
  Connections {
    target: root.shell ? root.shell.bar : null
    ignoreUnknownSignals: true
    function onModuleSlotsChanged() { Qt.callLater(root.reconcileSlots) }
  }
  Connections {
    target: root.hostBar
    ignoreUnknownSignals: true
    function onModuleSlotsChanged() { Qt.callLater(root.reconcileSlots) }
  }
  Connections {
    target: root.hostBar && root.hostBar.shell ? root.hostBar.shell : null
    ignoreUnknownSignals: true
    function onShellConfigChanged() { root.loadConfig(); Qt.callLater(root.ensureGroupEntries); Qt.callLater(root.reconcileSlots) }
  }
}
