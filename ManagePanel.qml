import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

KeyboardPanel {
  id: root

  required property var service
  readonly property var shell: bar ? bar.shell : null
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property var selectedGroup: service ? service.activeGroup : null
  focusTarget: newGroupName
  property string chosenIcon: "\uf07b"
  readonly property var glyphs: [
    "\uf07b", "\uf07c", "\uf015", "\uf013", "\uf085", "\uf0ad", "\uf121", "\uf120",
    "\uf108", "\uf109", "\uf233", "\uf1c0", "\uf0e0", "\uf075", "\uf086", "\uf0ac",
    "\uf135", "\uf11b", "\uf001", "\uf03d", "\uf03e", "\uf02d", "\uf044", "\uf073",
    "\uf017", "\uf0f3", "\uf0e7", "\uf06d", "\uf004", "\uf005", "\uf023", "\uf2db"
  ]
  readonly property var widgetCatalogue: {
    var revision = service ? service.revision : 0
    var out = []
    var live = {}
    var slots = service ? service.slots() : []
    for (var s = 0; s < slots.length; s++) if (slots[s]) live[String(slots[s].moduleName || "")] = true
    var installed = shell && shell.pluginRegistry ? shell.pluginRegistry.installedPlugins : null
    if (!installed) return out
    for (var id in installed) {
      var manifest = installed[id]
      if (id === "io.github.patrickfanella.shelfish" || id === "omarchy.tray" || !manifest || !Array.isArray(manifest.kinds)
          || manifest.kinds.indexOf("bar-widget") === -1 || !live[id]) continue
      out.push({ id: id, name: String(manifest.name || id) })
    }
    out.sort(function(a, b) { return a.name.localeCompare(b.name) })
    return out
  }
  readonly property var selectedWidgets: {
    var revision = service ? service.revision : 0
    var out = []
    if (!selectedGroup) return out
    for (var i = 0; i < selectedGroup.widgets.length; i++) {
      var id = selectedGroup.widgets[i]
      var match = widgetCatalogue.find(function(item) { return item.id === id })
      out.push(match || { id: id, name: id })
    }
    return out
  }

  function syncEditors() {
    if (!selectedGroup) return
    if (!editName.activeFocus) editName.text = selectedGroup.name
    chosenIcon = selectedGroup.icon
    direction.currentIndex = selectedGroup.direction === "left" ? 0 : 1
  }

  onSelectedGroupChanged: syncEditors()
  Component.onCompleted: syncEditors()

  contentWidth: fittedContentWidth(Style.space(680))
  contentHeight: fittedContentHeight(Style.space(600), Style.space(680))

  Column {
    anchors.fill: parent
    spacing: Style.space(8)

    Text { text: "Shelfish settings"; color: root.foreground; font.family: Style.font.family; font.pixelSize: Style.font.subtitle; font.bold: true }

    Flickable {
      width: parent.width
      height: Style.space(38)
      contentWidth: groupTabs.implicitWidth
      contentHeight: height
      clip: true

      Row {
        id: groupTabs
        spacing: Style.space(4)
        Repeater {
          model: root.service ? root.service.config.groups : []
          delegate: Button {
            required property var modelData
            text: modelData.icon + " " + modelData.name
            selected: root.service && root.service.config.activeGroupId === modelData.id
            bordered: true
            foreground: root.foreground
            onClicked: root.service.setActiveGroup(modelData.id)
          }
        }
      }
    }

    Row {
      id: createRow
      z: 20
      width: parent.width
      height: Style.space(36)
      spacing: Style.space(6)

      TextField {
        id: newGroupName
        z: 21
        width: Style.space(180)
        height: parent.height
        focusPolicy: Qt.StrongFocus
        activeFocusOnPress: true
        selectByMouse: true
        placeholderText: "New group name"
        onAccepted: createGroup()
        function createGroup() {
          var value = text.trim()
          if (!value || !root.service) return
          root.service.createGroup(value)
          text = ""
          forceActiveFocus()
        }
      }
      Button { text: "Create"; foreground: root.foreground; onClicked: newGroupName.createGroup() }
    }

    Row {
      width: parent.width
      height: Style.space(38)
      spacing: Style.space(6)

      TextField {
        id: editName
        width: Style.space(180)
        text: ""
        enabled: !!root.selectedGroup
        focusPolicy: Qt.StrongFocus
        activeFocusOnPress: true
        selectByMouse: true
        onAccepted: saveButton.save()
      }
      ComboBox {
        id: direction
        width: Style.space(100)
        model: ["left", "right"]
      }
      Button {
        id: saveButton
        text: "Save"
        foreground: root.foreground
        function save() {
          if (root.selectedGroup) root.service.updateGroup(root.selectedGroup.id,
            { name: editName.text, icon: root.chosenIcon, direction: direction.currentText })
        }
        onClicked: save()
      }
      Button { text: "Up"; foreground: root.foreground; onClicked: if (root.selectedGroup) root.service.moveGroup(root.selectedGroup.id, -1) }
      Button { text: "Down"; foreground: root.foreground; onClicked: if (root.selectedGroup) root.service.moveGroup(root.selectedGroup.id, 1) }
      Button {
        text: "Delete"
        foreground: root.foreground
        enabled: root.service && root.service.config.groups.length > 1
        onClicked: if (root.selectedGroup) root.service.deleteGroup(root.selectedGroup.id)
      }
    }

    Text { text: "GROUP ICON"; color: root.foreground; font.bold: true }
    Flickable {
      width: parent.width
      height: Style.space(92)
      contentWidth: width
      contentHeight: iconGrid.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      Grid {
        id: iconGrid
        width: parent.width
        columns: 16
        spacing: Style.space(3)
        Repeater {
          model: root.glyphs
          delegate: Button {
            required property string modelData
            width: Style.space(36)
            height: Style.space(36)
            text: modelData
            selected: root.chosenIcon === modelData
            bordered: true
            foreground: root.foreground
            onClicked: root.chosenIcon = modelData
          }
        }
      }
    }

    Rectangle { width: parent.width; height: 1; color: Color.popups.border }

    Row {
      width: parent.width
      height: parent.height - y
      spacing: Style.space(14)

      Flickable {
        width: (parent.width - parent.spacing) / 2
        height: parent.height
        contentWidth: width
        contentHeight: catalogueColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
          id: catalogueColumn
          width: parent.width
          spacing: Style.space(4)
          Text { text: "AVAILABLE PLUGINS"; color: root.foreground; font.bold: true }
          Repeater {
            model: root.widgetCatalogue
            delegate: Item {
              id: catalogueRow
              required property var modelData
              width: catalogueColumn.width
              height: Style.space(32)
              readonly property bool selectedMember: root.selectedGroup && root.selectedGroup.widgets.indexOf(modelData.id) !== -1
              Text {
                anchors.left: parent.left; anchors.right: addButton.left; anchors.verticalCenter: parent.verticalCenter
                text: parent.modelData.name; elide: Text.ElideRight; color: root.foreground
              }
              Button {
                id: addButton
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                text: catalogueRow.selectedMember ? "Selected" : "Add"
                enabled: !catalogueRow.selectedMember && !!root.selectedGroup
                foreground: root.foreground
                onClicked: root.service.setWidget(root.selectedGroup.id, catalogueRow.modelData.id, true)
              }
            }
          }
        }
      }

      Flickable {
        width: (parent.width - parent.spacing) / 2
        height: parent.height
        contentWidth: width
        contentHeight: selectedColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
          id: selectedColumn
          width: parent.width
          spacing: Style.space(4)
          Text { text: "SELECTED GROUP MEMBERS"; color: root.foreground; font.bold: true }
          Repeater {
            model: root.selectedWidgets
            delegate: Item {
              id: selectedRow
              required property var modelData
              required property int index
              width: selectedColumn.width
              height: Style.space(32)
              Text {
                anchors.left: parent.left; anchors.right: upButton.left; anchors.verticalCenter: parent.verticalCenter
                text: parent.modelData.name; elide: Text.ElideRight; color: root.foreground
              }
              Button {
                id: upButton
                anchors.right: downButton.left; anchors.verticalCenter: parent.verticalCenter
                text: "Up"; enabled: selectedRow.index > 0; foreground: root.foreground
                onClicked: root.service.moveWidget(root.selectedGroup.id, selectedRow.modelData.id, -1)
              }
              Button {
                id: downButton
                anchors.right: removeButton.left; anchors.verticalCenter: parent.verticalCenter
                text: "Down"; enabled: selectedRow.index + 1 < root.selectedWidgets.length; foreground: root.foreground
                onClicked: root.service.moveWidget(root.selectedGroup.id, selectedRow.modelData.id, 1)
              }
              Button {
                id: removeButton
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                text: "Remove"; foreground: root.foreground
                onClicked: root.service.setWidget(root.selectedGroup.id, selectedRow.modelData.id, false)
              }
            }
          }
        }
      }
    }
  }
}
