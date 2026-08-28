import QtQuick
import qs.Ui
import "I18n.js" as I18n

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

  function tr(key) { return service && typeof service.tr === "function" ? service.tr(key) : I18n.translate(Qt.locale().name, key) }

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
