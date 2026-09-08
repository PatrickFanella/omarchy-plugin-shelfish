import QtQuick
import qs.Ui
import "I18n.js" as I18n

BarWidget {
  id: root

  property var settings: ({})
  readonly property string groupId: String(settings.shelfishGroupId || "")
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
  readonly property var group: {
    if (!service) return null
    for (var i = 0; i < service.config.groups.length; i++)
      if (service.config.groups[i].id === groupId) return service.config.groups[i]
    return null
  }
  readonly property bool opened: service && service.revealedGroupId === groupId

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
