import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../"
import "../Palette.js" as Palette

AnimatedPopup {
  id: root

  required property QtObject window

  implicitWidth: 800
  implicitHeight: contentColumn.implicitHeight + 30
  enterScale: 0.75
  slideDistance: 6
  transformOrigin: Item.Center

  property int screenW: window ? window.screen.width : 1920
  property int screenH: window ? window.screen.height : 1080

  readonly property var cfg: window.appConfig

  readonly property var displayNames: ({
    launcher: "Launcher",
    workspaces: "Workspaces",
    mpris: "Mpris Player",
    clock: "Clock",
    timer: "Timer",
    genshin: "Genshin Impact",
    keyboard: "Keyboard Layout",
    audio: "Audio",
    control: "Control Center",
    bt: "Bluetooth",
    net: "Network",
    tray: "System Tray",
    sep: "\u2014 \u2014"
  })

  // --- Стан драгу ---
  property bool dragActive: false
  property string dragName: ""
  property string dragSourceZone: ""
  property Item dragHoverZoneItem: null
  property int dragDropIndex: -1

  function updateHoverZone(globalPos) {
    var zones = [leftZone, centerZone, rightZone, poolZone]
    for (var i = 0; i < zones.length; i++) {
      var z = zones[i]
      var local = z.mapFromItem(coordSpace, globalPos.x, globalPos.y)
      if (local.x >= 0 && local.x <= z.width && local.y >= 0 && local.y <= z.height) {
        dragHoverZoneItem = z
        dragDropIndex = z.indexForPoint(local.x, local.y)
        z.lastLocalY = local.y
        return
      }
    }
    dragHoverZoneItem = null
    dragDropIndex = -1
  }

  function startDrag(name, sourcePill, globalPos, grabOffset) {
    dragActive = true
    dragName = name
    dragSourceZone = sourcePill
    var isSep = cfg.isSep(name)
    ghost.text = isSep ? "" : (displayNames[name] ?? name)
    ghost.width = isSep ? 6 : 64
    ghost.radius = isSep ? 1 : 4
    ghost.grabOffset = grabOffset
    ghost.x = globalPos.x - grabOffset.x
    ghost.y = globalPos.y - grabOffset.y
    ghost.visible = true
    updateHoverZone(globalPos)
  }

  function updateDrag(globalPos) {
    if (!dragActive) return
    ghost.x = globalPos.x - ghost.grabOffset.x
    ghost.y = globalPos.y - ghost.grabOffset.y
    updateHoverZone(globalPos)
  }

  function commitDrag() {
    if (dragActive && dragHoverZoneItem) {
      var targetPill = dragHoverZoneItem.pillName
      if (cfg.isSep(dragName)) {
        if (targetPill === "pool") {
          cfg.leftOrder = cfg.leftOrder.filter(n => n !== dragName)
          cfg.centerOrder = cfg.centerOrder.filter(n => n !== dragName)
          cfg.rightOrder = cfg.rightOrder.filter(n => n !== dragName)
        } else {
          cfg.moveToPillAt(dragName, targetPill, dragDropIndex)
        }
      } else {
        if (targetPill === "pool") {
          cfg[dragName + "Enabled"] = false
        } else {
          cfg[dragName + "Enabled"] = true
          cfg.moveToPillAt(dragName, targetPill, dragDropIndex)
        }
      }
      cfg.saveToFile()
    }
    dragActive = false
    dragName = ""
    dragSourceZone = ""
    dragHoverZoneItem = null
    dragDropIndex = -1
    ghost.visible = false
  }

  Component.onCompleted: { anchor.window = window }

  onVisibleChanged: {
    if (visible) {
      anchor.edges = PopupAnchor.None
      anchor.gravity = PopupAnchor.None
      anchor.rect = Qt.rect(
        (screenW - implicitWidth) / 2,
        (screenH - implicitHeight) / 2,
        implicitWidth,
        implicitHeight
      )
    } else {
      commitDrag()
    }
  }

  Item {
    id: coordSpace
    anchors.fill: parent

    ColumnLayout {
      id: contentColumn
      anchors.fill: parent
      anchors.margins: 15
      spacing: 12

      RowLayout {
        Layout.fillWidth: true
        Text {
          text: "\u2699 Settings"
          color: Palette.fg
          font.family: Palette.font
          font.pixelSize: 14
          font.bold: true
        }
        Item { Layout.fillWidth: true }

      }

      Text {
        text: "Bar layout — drag widgets between pills, or down to the pool to disable"
        color: Palette.gray
        font.family: Palette.font
        font.pixelSize: 10
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 10

        ColumnLayout {
          Layout.fillWidth: true
          Layout.preferredWidth: 1
          spacing: 4
          RowLayout {
            Layout.fillWidth: true
            Text { text: "Left"; color: Palette.gray; font.family: Palette.font; font.pixelSize: 9; font.bold: true }
            Item { Layout.fillWidth: true }
            Rectangle {
              implicitWidth: 16; implicitHeight: 16; radius: 3
              color: Palette.bg2
              Text { anchors.centerIn: parent; text: "+"; color: Palette.fg; font.pixelSize: 10; font.bold: true }
              MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: { cfg.addSep("left"); cfg.saveToFile() }
              }
            }
          }
          DnDZone { id: leftZone; pillName: "left"; wrap: true; Layout.fillWidth: true }
        }
        ColumnLayout {
          Layout.fillWidth: true
          Layout.preferredWidth: 1
          spacing: 4
          RowLayout {
            Layout.fillWidth: true
            Text { text: "Center"; color: Palette.gray; font.family: Palette.font; font.pixelSize: 9; font.bold: true }
            Item { Layout.fillWidth: true }
            Rectangle {
              implicitWidth: 16; implicitHeight: 16; radius: 3
              color: Palette.bg2
              Text { anchors.centerIn: parent; text: "+"; color: Palette.fg; font.pixelSize: 10; font.bold: true }
              MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: { cfg.addSep("center"); cfg.saveToFile() }
              }
            }
          }
          DnDZone { id: centerZone; pillName: "center"; wrap: true; Layout.fillWidth: true }
        }
        ColumnLayout {
          Layout.fillWidth: true
          Layout.preferredWidth: 1
          spacing: 4
          RowLayout {
            Layout.fillWidth: true
            Text { text: "Right"; color: Palette.gray; font.family: Palette.font; font.pixelSize: 9; font.bold: true }
            Item { Layout.fillWidth: true }
            Rectangle {
              implicitWidth: 16; implicitHeight: 16; radius: 3
              color: Palette.bg2
              Text { anchors.centerIn: parent; text: "+"; color: Palette.fg; font.pixelSize: 10; font.bold: true }
              MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: { cfg.addSep("right"); cfg.saveToFile() }
              }
            }
          }
          DnDZone { id: rightZone; pillName: "right"; wrap: true; Layout.fillWidth: true }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        height: 1
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0.0; color: "transparent" }
          GradientStop { position: 0.5; color: Palette.bg2 }
          GradientStop { position: 1.0; color: "transparent" }
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        Text { text: "Pool (disabled)"; color: Palette.gray; font.family: Palette.font; font.pixelSize: 9; font.bold: true }
        DnDZone {
          id: poolZone
          pillName: "pool"
          Layout.fillWidth: true
          wrap: true
          minHeight: 34
        }
      }
    }

    component DnDZone: Rectangle {
      id: zone
      required property string pillName
      property bool wrap: false
      property real minHeight: 26
      property real chipW: 64
      property real chipH: 20
      property real spacing2: 4
      clip: true

      radius: 6
      color: root.dragHoverZoneItem === zone ? Qt.lighter(Palette.bg1, 1.15) : Palette.bg1
      border.width: 1
      border.color: root.dragHoverZoneItem === zone ? Palette.green : Palette.bg2
      Behavior on color { ColorAnimation { duration: 120 } }
      Behavior on border.color { ColorAnimation { duration: 120 } }

      readonly property var allNames: pillName === "pool"
        ? cfg.allWidgetNames.filter(n => !cfg[n + "Enabled"])
        : cfg.pillOrderFor(pillName).filter(n => cfg.isSep(n) || cfg[n + "Enabled"])

      readonly property var chipLayout: {
        var items = []
        var row = 0
        var x = 4, y = 4
        var widgetCount = 0
        var maxPerRow = 3
        for (var i = 0; i < allNames.length; i++) {
          var isSep = cfg.isSep(allNames[i])
          var w = isSep ? 6 : chipW
          if (wrap && !isSep && widgetCount >= maxPerRow) {
            row++
            x = 4
            y = 4 + row * (chipH + spacing2)
            widgetCount = 0
          }
          items.push(Qt.point(x, y))
          x += w + spacing2
          if (!isSep) widgetCount++
        }
        return items
      }

      readonly property int chipRows: chipLayout.length > 0 ? Math.floor((chipLayout[chipLayout.length - 1].y - 4) / (chipH + spacing2)) + 1 : 0
      property real lastLocalY: 0

      implicitHeight: Math.max(minHeight, 8 + chipRows * (chipH + spacing2))

      function indexForPoint(localX, localY) {
        if (chipLayout.length === 0) return 0
        var targetRow = wrap ? Math.max(0, Math.min(Math.floor((localY - 4) / (chipH + spacing2)), chipRows - 1)) : 0
        var bestIdx = targetRow === 0 ? 0 : allNames.length
        var bestDist = Infinity
        for (var i = 0; i < chipLayout.length; i++) {
          var thisRow = Math.floor((chipLayout[i].y - 4) / (chipH + spacing2))
          if (thisRow > targetRow) break
          if (thisRow < targetRow) continue
          var w = cfg.isSep(allNames[i]) ? 6 : chipW
          var dLeft = Math.abs(localX - chipLayout[i].x)
          if (dLeft < bestDist) { bestDist = dLeft; bestIdx = i }
          var dRight = Math.abs(localX - (chipLayout[i].x + w))
          if (dRight < bestDist) { bestDist = dRight; bestIdx = i + 1 }
        }
        return bestIdx
      }

      Rectangle {
        visible: root.dragHoverZoneItem === zone
        radius: root.dragActive && cfg.isSep(root.dragName) ? 1 : 4
        color: "transparent"
        border.width: 1
        border.color: Palette.green
        opacity: 0.5
        width: root.dragActive && cfg.isSep(root.dragName) ? 6 : zone.chipW
        height: zone.chipH
        x: root.dragDropIndex >= 0 && root.dragDropIndex < zone.chipLayout.length ? zone.chipLayout[root.dragDropIndex].x : lastItemEndX()
        y: root.dragDropIndex >= 0 && root.dragDropIndex < zone.chipLayout.length ? zone.chipLayout[root.dragDropIndex].y : lastItemEndY()
        Behavior on x { NumberAnimation { duration: 100 } }
        Behavior on y { NumberAnimation { duration: 100 } }
      }

      function lastItemEndX() {
        if (chipLayout.length === 0) return 4
        var tr = Math.min(Math.max(0, Math.floor((lastLocalY - 4) / (chipH + spacing2))), chipRows - 1)
        for (var i = chipLayout.length - 1; i >= 0; i--) {
          if (Math.floor((chipLayout[i].y - 4) / (chipH + spacing2)) === tr)
            return chipLayout[i].x + (cfg.isSep(allNames[i]) ? 6 : chipW) + spacing2
        }
        return chipLayout[chipLayout.length - 1].x + chipW + spacing2
      }

      function lastItemEndY() {
        if (chipLayout.length === 0) return 4
        var tr = Math.min(Math.max(0, Math.floor((lastLocalY - 4) / (chipH + spacing2))), chipRows - 1)
        return 4 + tr * (chipH + spacing2)
      }

      Repeater {
        model: zone.allNames

        delegate: Rectangle {
          id: chip
          required property string modelData
          required property int index

          readonly property bool _isSep: cfg.isSep(modelData)
          readonly property bool _isDragged: root.dragActive && root.dragName === modelData

          width: _isSep ? 6 : zone.chipW
          height: zone.chipH
          x: index < zone.chipLayout.length ? zone.chipLayout[index].x : 0
          y: index < zone.chipLayout.length ? zone.chipLayout[index].y : 0
          opacity: _isDragged ? 0.35 : 1.0

          Behavior on x { enabled: !root.dragActive; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
          Behavior on y { enabled: !root.dragActive; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

          radius: _isSep ? 2 : 4
          color: _isSep ? "transparent" : (chipArea.pressed ? Palette.bg2 : Palette.bgAlpha)
          border.width: _isSep ? 0 : 1
          border.color: _isDragged ? Palette.accent : Palette.bg2

          Rectangle {
            visible: _isSep
            anchors.centerIn: parent
            width: 2
            height: 12
            radius: 1
            color: Palette.mutedAlt
            opacity: 0.5
          }

          Text {
            visible: !_isSep
            anchors.centerIn: parent
            text: root.displayNames[chip.modelData] ?? chip.modelData
            color: _isDragged ? Palette.mutedAlt : Palette.fg
            font.family: Palette.font
            font.pixelSize: 9
            elide: Text.ElideRight
            width: parent.width - 6
            horizontalAlignment: Text.AlignHCenter
          }

          MouseArea {
            id: chipArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            preventStealing: true

            onPressed: (mouse) => {
              var globalPos = chip.mapToItem(coordSpace, mouse.x, mouse.y)
              root.startDrag(chip.modelData, zone.pillName, globalPos, Qt.point(mouse.x, mouse.y))
            }
            onPositionChanged: (mouse) => {
              if (!root.dragActive) return
              var globalPos = chip.mapToItem(coordSpace, mouse.x, mouse.y)
              root.updateDrag(globalPos)
            }
            onReleased: root.commitDrag()
            onCanceled: root.commitDrag()
          }
        }
      }
    }
  }

  Rectangle {
    id: ghost
    property string text: ""
    property point grabOffset: Qt.point(0, 0)
    visible: false
    z: 1000
    width: 64
    height: 20
    radius: 4
    color: Palette.green
    opacity: 0.85
    border.width: 1
    border.color: Palette.bg0H

    Text {
      visible: ghost.text !== ""
      anchors.centerIn: parent
      text: ghost.text
      color: Palette.bg0H
      font.family: Palette.font
      font.pixelSize: 9
      font.bold: true
      elide: Text.ElideRight
      width: parent.width - 6
      horizontalAlignment: Text.AlignHCenter
    }
  }
}
