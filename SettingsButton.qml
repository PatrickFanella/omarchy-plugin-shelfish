import QtQuick
import qs.Ui

BarWidget {
  id: root

  property var settings: ({})
  readonly property var service: bar && bar.shell && typeof bar.shell.serviceFor === "function"
    ? bar.shell.serviceFor("io.github.patrickfanella.shelfish") : null

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uf1de"
    tooltipText: "Shelfish settings"
    onPressed: function(mouseButton) {
      if (!root.service) return
      if (mouseButton === Qt.MiddleButton) root.service.hide()
      else root.service.manage()
    }
  }
}
