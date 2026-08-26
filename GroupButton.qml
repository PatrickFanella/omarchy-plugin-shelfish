import QtQuick
import qs.Ui

BarWidget {
  id: root

  property var settings: ({})
  readonly property string groupId: String(settings.shelfishGroupId || "")
  readonly property var service: bar && bar.shell && typeof bar.shell.serviceFor === "function"
    ? bar.shell.serviceFor("io.github.patrickfanella.shelfish") : null
  readonly property var group: {
    if (!service) return null
    for (var i = 0; i < service.config.groups.length; i++)
      if (service.config.groups[i].id === groupId) return service.config.groups[i]
    return null
  }
  readonly property bool opened: service && service.revealedGroupId === groupId

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.group ? root.group.icon : "\uf07b"
    active: root.opened
    tooltipText: root.group ? root.group.name : "Shelfish group"
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton && root.service) root.service.manage()
      else if (mouseButton === Qt.MiddleButton && root.service) root.service.hide()
      else if (root.service && root.service.canToggleGroups()) root.service.toggleGroup(root.groupId)
    }
  }
}
