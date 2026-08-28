import QtQuick
import qs.Ui
import "I18n.js" as I18n

BarWidget {
  id: root

  property var settings: ({})
  readonly property var service: bar && bar.shell && typeof bar.shell.serviceFor === "function"
    ? bar.shell.serviceFor("io.github.patrickfanella.shelfish") : null

  function tr(key) { return service && typeof service.tr === "function" ? service.tr(key) : I18n.translate(Qt.locale().name, key) }

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
