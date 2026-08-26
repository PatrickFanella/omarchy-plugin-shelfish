import QtQuick
import qs.Ui

BarWidget {
  id: root

  moduleName: "io.github.patrickfanella.shelfish"
  property bool managerOpen: false
  property var registeredService: null
  readonly property bool opened: managerOpen
  readonly property var service: bar && bar.shell && typeof bar.shell.serviceFor === "function"
    ? bar.shell.serviceFor(moduleName) : null

  function syncRegistration() {
    if (registeredService === service) return
    if (registeredService) registeredService.unregisterPanelHost(root)
    registeredService = service
    if (registeredService) registeredService.registerPanelHost(root)
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

  BarIconButton {
    id: managerButton
    anchors.fill: parent
    bar: root.bar
    text: "\uf1de"
    active: root.managerOpen
    tooltipText: "Shelfish settings"
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
