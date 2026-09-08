import QtQuick
import qs.Ui
import "I18n.js" as I18n

BarWidget {
  id: root

  property var settings: ({})
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
      var s = bar.shell.serviceFor("io.github.patrickfanella.shelfish")
      if (s) return s
    }
    if (hostBar && hostBar.shell && typeof hostBar.shell.serviceFor === "function") {
      return hostBar.shell.serviceFor("io.github.patrickfanella.shelfish")
    }
    return null
  }

  function tr(key) { return service && typeof service.tr === "function" ? service.tr(key) : I18n.translate(Qt.locale().name, key) }

  function syncHostBar() {
    if (service && hostBar && typeof service.registerHostBar === "function") {
      service.registerHostBar(hostBar)
    }
  }

  Component.onCompleted: syncHostBar()
  onServiceChanged: syncHostBar()
  onHostBarChanged: syncHostBar()

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uf1de"
    tooltipText: root.tr("settings.shortcut")
    onPressed: function(mouseButton) {
      if (!root.service) return
      if (mouseButton === Qt.MiddleButton) root.service.hide()
      else root.service.manage()
    }
  }
}
