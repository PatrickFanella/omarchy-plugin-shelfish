import QtQuick
import qs.Ui
import "I18n.js" as I18n

BarWidget {
  id: root

  property var settings: ({})
  function getSlots() {
    var top = root
    while (top && top.parent) top = top.parent
    var found = []
    if (!top) return found
    var queue = [top]
    while (queue.length > 0) {
      var cur = queue.shift()
      if (!cur) continue
      if (cur.moduleName !== undefined && "activeItem" in cur) {
        found.push(cur)
      }
      var ch = cur.children
      if (ch && ch.length) {
        for (var i = 0; i < ch.length; i++) queue.push(ch[i])
      }
    }
    return found
  }

  function findService() {
    if (bar && bar.shell && typeof bar.shell.serviceFor === "function") {
      var s = bar.shell.serviceFor("io.github.patrickfanella.shelfish")
      if (s) return s
    }
    var top = root
    while (top && top.parent) top = top.parent
    if (top) {
      var queue = [top]
      while (queue.length > 0) {
        var cur = queue.shift()
        if (!cur) continue
        if (cur.registeredService) return cur.registeredService
        var ch = cur.children
        if (ch && ch.length) {
          for (var i = 0; i < ch.length; i++) queue.push(ch[i])
        }
      }
    }
    return null
  }
  readonly property var service: findService()

  function tr(key) { return service && typeof service.tr === "function" ? service.tr(key) : I18n.translate(Qt.locale().name, key) }

  function syncHost() {
    if (service && typeof service.registerPanelHost === "function") {
      service.registerPanelHost(root)
    }
  }

  onParentChanged: syncHost()
  Component.onCompleted: syncHost()
  onServiceChanged: syncHost()

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
