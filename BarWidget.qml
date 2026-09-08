import QtQuick
import qs.Ui
import "I18n.js" as I18n

BarWidget {
  id: root

  moduleName: "io.github.patrickfanella.shelfish"
  property bool managerOpen: false
  property var registeredService: null
  readonly property bool opened: managerOpen
  function findHostBar() {
    var cur = root.parent
    while (cur) {
      if (cur.moduleSlots !== undefined && Array.isArray(cur.moduleSlots)) return cur
      cur = cur.parent
    }
    return null
  }
  readonly property var hostBar: findHostBar()
  readonly property var service: {
    if (bar && bar.shell && typeof bar.shell.serviceFor === "function") {
      var s = bar.shell.serviceFor(moduleName)
      if (s) return s
    }
    if (hostBar && hostBar.shell && typeof hostBar.shell.serviceFor === "function") {
      return hostBar.shell.serviceFor(moduleName)
    }
    return null
  }

  function tr(key) { return service && typeof service.tr === "function" ? service.tr(key) : I18n.translate(Qt.locale().name, key) }

  function syncRegistration() {
    if (registeredService === service) {
      if (service && hostBar && typeof service.registerHostBar === "function") service.registerHostBar(hostBar)
      return
    }
    if (registeredService) registeredService.unregisterPanelHost(root)
    registeredService = service
    if (registeredService) {
      registeredService.registerPanelHost(root)
      if (hostBar && typeof registeredService.registerHostBar === "function") registeredService.registerHostBar(hostBar)
    }
  }
  function openManager() {
    if (service) {
      service.suppressStatusReveal()
      service.hide()
    }
    managerOpen = true
  }
  function open() { openManager() }
  function close() {
    if (service) {
      service.suppressStatusReveal()
      service.suppressGroupToggles()
      service.hide()
    }
    managerOpen = false
  }

  implicitWidth: managerButton.implicitWidth
  implicitHeight: managerButton.implicitHeight

  Component.onCompleted: syncRegistration()
  Component.onDestruction: if (registeredService) registeredService.unregisterPanelHost(root)
  onServiceChanged: syncRegistration()
  onHostBarChanged: syncRegistration()

  BarIconButton {
    id: managerButton
    anchors.fill: parent
    bar: root.bar
    text: "\uf1de"
    active: root.managerOpen
    tooltipText: root.tr("settings.shortcut")
    onPressed: root.managerOpen ? root.close() : root.openManager()
  }

  ManagePanel {
    anchorItem: managerButton
    owner: root
    bar: root.bar
    service: root.service
    open: root.managerOpen
    onOpenChanged: if (!open && root.managerOpen) root.close()
  }
}
