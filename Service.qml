import QtQuick
import Quickshell.Io
import "Model.js" as Model
import "I18n.js" as I18n

Item {
  id: root

  readonly property string moduleName: "io.github.patrickfanella.shelfish"
  readonly property string groupPrefix: moduleName + ".group."
  readonly property string localeName: Qt.locale().name
  property var shell: null
  property var manifest: null
  property var config: Model.normalizeConfig({})
  property string revealedGroupId: ""
  readonly property bool revealed: revealedGroupId !== ""
  property var managedIds: []
  property var snapshots: ({})
  property double suppressStatusUntil: 0
  property double suppressGroupToggleUntil: 0
  property bool suspended: false
  property var panelHosts: []
  property int revision: 0

  readonly property var activeGroup: Model.activeGroup(config)
  readonly property int managedCount: Model.allWidgetIds(config).length

  function tr(key, args) { return I18n.translate(localeName, key, args) }

  function entryId(entry) {
    return String(entry && typeof entry === "object" ? entry.id : entry || "")
  }

  function findEntry(configRoot) {
    var layout = configRoot && configRoot.bar ? configRoot.bar.layout : null
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

  function sourceDir() {
    var stamped = manifest && manifest.__sourceDir ? manifest : null
    if (!stamped && shell && shell.pluginRegistry && shell.pluginRegistry.installedPlugins)
      stamped = shell.pluginRegistry.installedPlugins[moduleName]
    return stamped && stamped.__sourceDir ? String(stamped.__sourceDir).replace(/\/$/, "") : ""
  }

  function syncGroupEntries(shellConfig, nextConfig) {
    var layout = shellConfig && shellConfig.bar ? shellConfig.bar.layout : null
    var dir = sourceDir()
    if (!layout || !dir) return
    Model.syncGroupEntries(layout, nextConfig.groups, moduleName, groupPrefix, dir)
  }

  function ensureGroupEntries() {
    if (suspended || !shell || !shell.shellConfig || typeof shell.mutateShellConfig !== "function" || !sourceDir()) return
    var copy
    try { copy = JSON.parse(JSON.stringify(shell.shellConfig)) } catch (error) { return }
    var before = JSON.stringify(copy.bar && copy.bar.layout)
    syncGroupEntries(copy, config)
    if (before === JSON.stringify(copy.bar && copy.bar.layout)) return
    shell.mutateShellConfig(function(shellConfig) { root.syncGroupEntries(shellConfig, root.config) })
  }

  function loadConfig() {
    var next = Model.normalizeConfig(findEntry(shell ? shell.shellConfig : null) || {})
    if (JSON.stringify(config.groups) !== JSON.stringify(next.groups)) revealedGroupId = ""
    config = next
    revision++
  }

  function persist(next) {
    if (suspended || !shell || typeof shell.mutateShellConfig !== "function") return false
    var normalized = Model.normalizeConfig(next)
    var payload = Model.serializeConfig(normalized)
    var wrote = false
    shell.mutateShellConfig(function(shellConfig) {
      var entry = root.findEntry(shellConfig)
      if (!entry) return
      for (var key in payload) entry[key] = payload[key]
      root.syncGroupEntries(shellConfig, normalized)
      wrote = true
    })
    if (wrote) {
      suppressStatusReveal()
      revealTimer.stop()
      revealedGroupId = ""
      config = normalized
      Qt.callLater(reconcileSlots)
      revision++
    }
    return wrote
  }

  function setActiveGroup(groupId) {
    if (!Model.groupById(config, groupId)) return false
    var next = Model.normalizeConfig(config); next.activeGroupId = groupId
    return persist(next)
  }
  function createGroup(name) { return persist(Model.addGroup(config, name)) }
  function deleteGroup(id) { return persist(Model.deleteGroup(config, id)) }
  function updateGroup(id, values) { return persist(Model.updateGroup(config, id, values)) }
  function moveGroup(id, offset) { return persist(Model.moveGroup(config, id, offset)) }
  function setWidget(groupId, widgetId, present) {
    if (widgetId === moduleName || widgetId === "omarchy.tray" || widgetId.indexOf(groupPrefix) === 0) return false
    return persist(Model.setWidgetMembership(config, groupId, widgetId, present))
  }
  function moveWidget(groupId, widgetId, offset) { return persist(Model.moveWidget(config, groupId, widgetId, offset)) }

  function slots() {
    var bar = shell ? shell.bar : null
    return bar && Array.isArray(bar.moduleSlots) ? bar.moduleSlots : []
  }

  function restoreAll() {
    var restore = {}
    var configured = Model.allWidgetIds(config)
    for (var c = 0; c < configured.length; c++) restore[configured[c]] = true
    for (var i = 0; i < managedIds.length; i++) restore[managedIds[i]] = true
    suspended = true
    revealTimer.stop()
    var mutated = false
    if (shell && typeof shell.mutateShellConfig === "function") {
      shell.mutateShellConfig(function(shellConfig) {
        var layout = shellConfig && shellConfig.bar ? shellConfig.bar.layout : null
        Model.removeGeneratedEntries(layout, root.groupPrefix)
        mutated = true
      })
    }
    var all = slots()
    for (var s = 0; s < all.length; s++) {
      var slot = all[s]
      var id = slot ? String(slot.moduleName || "") : ""
      if (restore[id]) slot.visible = true
    }
    managedIds = []
    revealedGroupId = ""
    revision++
    return mutated
  }

  function reconcileSlots() {
    if (suspended) return
    var nextManaged = Model.allWidgetIds(config).filter(function(id) {
      return id !== root.moduleName && id !== "omarchy.tray" && id.indexOf(root.groupPrefix) !== 0
    })
    var managed = {}
    var previous = {}
    for (var i = 0; i < nextManaged.length; i++) managed[nextManaged[i]] = true
    for (var p = 0; p < managedIds.length; p++) previous[managedIds[p]] = true
    var group = Model.groupById(config, revealedGroupId)
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
          slot.visible = revealedGroupId === shortcutGroup
        }
        continue
      }
      if (managed[id]) slot.visible = active.indexOf(id) !== -1
      else if (previous[id]) slot.visible = true
    }
    managedIds = nextManaged
    revision++
  }

  function showGroup(id) {
    revealTimer.stop()
    if (!Model.groupById(config, id)) return
    revealedGroupId = id
    reconcileSlots()
  }
  function hide() { revealedGroupId = ""; revealTimer.stop(); reconcileSlots() }
  function toggleGroup(id) {
    revealTimer.stop()
    revealedGroupId === id ? hide() : showGroup(id)
  }
  function show() { showGroup(config.activeGroupId) }
  function toggle() { revealed ? hide() : show() }

  function suppressStatusReveal() { suppressStatusUntil = Date.now() + 1000 }
  function suppressGroupToggles() { suppressGroupToggleUntil = Date.now() + 350 }
  function canToggleGroups() { return !suspended && Date.now() >= suppressGroupToggleUntil }

  function registerPanelHost(host) {
    if (host && panelHosts.indexOf(host) === -1) {
      var next = panelHosts.slice(); next.push(host); panelHosts = next
    }
  }
  function unregisterPanelHost(host) { panelHosts = panelHosts.filter(function(item) { return item !== host }) }
  function manage() { if (panelHosts.length && typeof panelHosts[0].openManager === "function") panelHosts[0].openManager() }

  function policy(id) { return config.policies[id] || { autoReveal: true, revealSeconds: 0 } }
  function pollStatus() {
    if (suspended) return
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
    var bar = shell ? shell.bar : null
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
    return { activeGroupId: config.activeGroupId, revealedGroupId: revealedGroupId, managedWidgets: managedCount }
  }

  IpcHandler {
    target: root.moduleName
    function manage(): void { root.manage() }
    function show(): void { root.show() }
    function hide(): void { root.hide() }
    function toggle(): void { root.toggle() }
    function status(): string { return JSON.stringify(root.statusObject()) }
    function restore(): string { return root.restoreAll() ? "ok" : "failed" }
    function restoreAll(): string { return root.restoreAll() ? "ok" : "failed" }
  }

  Timer { id: pollTimer; interval: 500; repeat: true; running: true; onTriggered: root.pollStatus() }
  Timer {
    id: revealTimer
    interval: root.config.revealSeconds * 1000
    onTriggered: {
      if (root.revealedMemberOwnsPopout()) { interval = 500; restart() }
      else root.hide()
    }
  }

  Component.onCompleted: { loadConfig(); Qt.callLater(ensureGroupEntries); Qt.callLater(reconcileSlots) }
  Component.onDestruction: restoreAll()
  onShellChanged: { loadConfig(); Qt.callLater(ensureGroupEntries); Qt.callLater(reconcileSlots) }
  Connections {
    target: root.shell
    ignoreUnknownSignals: true
    function onShellConfigChanged() { root.loadConfig(); Qt.callLater(root.ensureGroupEntries); Qt.callLater(root.reconcileSlots) }
    function onBarChanged() { Qt.callLater(root.reconcileSlots) }
  }
  Connections {
    target: root.shell ? root.shell.bar : null
    ignoreUnknownSignals: true
    function onModuleSlotsChanged() { Qt.callLater(root.reconcileSlots) }
  }
}
