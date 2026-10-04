import QtQuick
import qs.Ui
import "I18n.js" as I18n

BarWidget {
  id: root

  property var settings: ({})
  readonly property string groupId: String(settings.shelfishGroupId || "")
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
  readonly property var group: {
    if (!service) return null
    for (var i = 0; i < service.config.groups.length; i++)
      if (service.config.groups[i].id === groupId) return service.config.groups[i]
    return null
  }
  readonly property bool opened: service && (service.revealedGroupId ? service.revealedGroupId === groupId : service.config.activeGroupId === groupId)

  function tr(key) { return service && typeof service.tr === "function" ? service.tr(key) : I18n.translate(Qt.locale().name, key) }

  function syncHost() {
    if (service && typeof service.registerPanelHost === "function") {
      service.registerPanelHost(root)
    }
  }

  onParentChanged: syncHost()
  Component.onCompleted: syncHost()
  Component.onDestruction: {
    if (service && typeof service.unregisterPanelHost === "function") {
      service.unregisterPanelHost(root)
    }
  }
  onServiceChanged: syncHost()

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.group ? root.group.icon : "\uf07b"
    active: root.opened
    tooltipText: root.group ? root.group.name : root.tr("group.fallback")
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton && root.service) root.service.manage()
      else if (mouseButton === Qt.MiddleButton && root.service) root.service.hide()
      else if (root.service && root.service.canToggleGroups()) root.service.toggleGroup(root.groupId)
    }
  }
}
