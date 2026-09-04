// ============================================================
// quickshell/popups/settings/BarSection.qml — розділ Bar: геометрія, позиція, пігулки, лейаут (drag-and-drop), вигляд пігулок і роздільників
// ============================================================
import QtQuick
import QtQuick.Layouts
import "../../core"

Item {
  id: root
  required property QtObject sys

  readonly property var cfg: sys.cfg
  readonly property var ac: sys.ac
  readonly property var window: sys.window

  readonly property var displayNames: ({
    launcher: "Launcher",
    workspaces: "Workspaces",
    mpris: "Mpris Player",
    clock: "Clock",
    timer: "Timer",
    selftrack: "Time Tracking",
    genshin: "Genshin Impact",
    keyboard: "Keyboard Layout",
    audio: "Audio",
    control: "Control Center",
    bt: "Bluetooth",
    net: "Network",
    tray: "System Tray",
    battery: "Battery",
    sep: "\u2014 \u2014"
  })

  implicitWidth: parent?.width ?? 0
  implicitHeight: col.implicitHeight

  // --- Стан drag-and-drop (з LayoutSection) ---
  property bool dragActive: false
  property string dragName: ""
  property Item dragHoverZoneItem: null
  property int dragDropIndex: -1

  function updateHoverZone(globalPos) {
    var zones = [leftZone, centerZone, rightZone, poolZone]
    for (var i = 0; i < zones.length; i++) {
      var z = zones[i]
      if (!z) continue
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

  function startDrag(name, globalPos, grabOffset) {
    dragActive = true
    dragName = name
    var isSep = ac.isSep(name)
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
      if (ac.isSep(dragName)) {
        if (targetPill === "pool") {
          cfg.leftOrder = cfg.leftOrder.filter(n => n !== dragName)
          cfg.centerOrder = cfg.centerOrder.filter(n => n !== dragName)
          cfg.rightOrder = cfg.rightOrder.filter(n => n !== dragName)
        } else {
          ac.moveToPillAt(dragName, targetPill, dragDropIndex)
        }
      } else {
        if (targetPill === "pool") {
          cfg[dragName + "Enabled"] = false
        } else {
          cfg[dragName + "Enabled"] = true
          ac.moveToPillAt(dragName, targetPill, dragDropIndex)
        }
      }
      ac.saveToFile()
    }
    dragActive = false
    dragName = ""
    dragHoverZoneItem = null
    dragDropIndex = -1
    ghost.visible = false
  }

  function cancelDrag() {
    dragActive = false
    dragName = ""
    dragHoverZoneItem = null
    dragDropIndex = -1
    ghost.visible = false
  }

  Item {
    id: coordSpace
    anchors.fill: parent
  }

  ColumnLayout {
    id: col
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    spacing: 16

    SetCard {
      sys: root.sys
      SetLabel { sys: root.sys; text: "Size" }
      SetSlider {
        sys: root.sys
        label: "Bar height"; from: 24; to: 96; step: 1; suffix: "px"
        value: root.cfg.barHeight
        onMoved: v => { root.cfg.barHeight = v; root.ac.saveToFile() }
      }
      SetSlider {
        sys: root.sys
        label: "Pill radius"; from: 0; to: 24; step: 1; suffix: "px"
        value: root.cfg.barRadius
        onMoved: v => { root.cfg.barRadius = v; root.ac.saveToFile() }
      }
      SetSlider {
        sys: root.sys
        label: "Edge margin"; from: 0; to: 32; step: 1; suffix: "px"
        value: root.cfg.edgeMargin
        onMoved: v => { root.cfg.edgeMargin = v; root.ac.saveToFile() }
      }
      SetSlider {
        sys: root.sys
        label: "Pill padding"; from: 2; to: 24; step: 1; suffix: "px"
        value: root.cfg.pillPadding
        onMoved: v => { root.cfg.pillPadding = v; root.ac.saveToFile() }
      }
      SetSlider {
        sys: root.sys
        label: "Content spacing"; from: 0; to: 16; step: 1; suffix: "px"
        value: root.cfg.contentSpacing
        onMoved: v => { root.cfg.contentSpacing = v; root.ac.saveToFile() }
      }
    }

    SetCard {
      sys: root.sys
      SetLabel { sys: root.sys; text: "Position" }
      SetSelect {
        sys: root.sys
        label: "Bar position"
        options: [{ id: "top", text: "Top" }, { id: "bottom", text: "Bottom" }]
        value: root.cfg.barPos
        onPicked: id => { root.cfg.barPos = id; root.ac.saveToFile() }
      }
      SetToggle {
        sys: root.sys
        label: "Auto-hide"
        sub: "The bar slides behind the screen edge and returns on hover of the thin edge strip. While hidden, windows get the full screen."
        on: root.cfg.barAutoHide
        onToggled: v => { root.cfg.barAutoHide = v; root.ac.saveToFile() }
      }
    }

    SetCard {
      sys: root.sys
      SetLabel { sys: root.sys; text: "Pills" }
      SetToggle {
        sys: root.sys
        label: "Left pill"
        sub: "Hide the whole pill. Its widgets stay configured in Layout and come back when shown again."
        on: root.cfg.leftPillEnabled
        onToggled: v => { root.cfg.leftPillEnabled = v; root.ac.saveToFile() }
      }
      SetToggle {
        sys: root.sys
        label: "Center pill"
        sub: "Hide the whole pill. Its widgets stay configured in Layout and come back when shown again."
        on: root.cfg.centerPillEnabled
        onToggled: v => { root.cfg.centerPillEnabled = v; root.ac.saveToFile() }
      }
      SetToggle {
        sys: root.sys
        label: "Right pill"
        sub: "Hide the whole pill. Its widgets stay configured in Layout and come back when shown again."
        on: root.cfg.rightPillEnabled
        onToggled: v => { root.cfg.rightPillEnabled = v; root.ac.saveToFile() }
      }
    }

    // --- Layout: drag-and-drop між пігулками (колишня LayoutSection) ---
    SetCard {
      sys: root.sys
      SetLabel { sys: root.sys; text: "Layout" }
      Text {
        text: "Drag widgets between pills, or down to the pool to disable"
        color: window.palette.gray
        font.family: window.palette.font
        font.pixelSize: root.window.appConfig.scaled(10)
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
      }
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        RowLayout {
          Layout.fillWidth: true
          Text { text: "Left"; color: window.palette.gray; font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(10); font.bold: true }
          Item { Layout.fillWidth: true }
          Text { visible: !root.cfg.leftPillEnabled; text: "hidden"; color: window.palette.gray; font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(9); font.italic: true }
          Rectangle {
            implicitWidth: 18; implicitHeight: 18; radius: 3; color: window.palette.bg2
            Text { anchors.centerIn: parent; text: "+"; color: window.palette.fg; font.pixelSize: window.appConfig.scaled(11); font.bold: true }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { ac.addSep("left"); ac.saveToFile() } }
          }
        }
        DnDZone { id: leftZone; pillName: "left"; wrap: true; Layout.fillWidth: true }
      }
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        RowLayout {
          Layout.fillWidth: true
          Text { text: "Center"; color: window.palette.gray; font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(10); font.bold: true }
          Item { Layout.fillWidth: true }
          Text { visible: !root.cfg.centerPillEnabled; text: "hidden"; color: window.palette.gray; font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(9); font.italic: true }
          Rectangle {
            implicitWidth: 18; implicitHeight: 18; radius: 3; color: window.palette.bg2
            Text { anchors.centerIn: parent; text: "+"; color: window.palette.fg; font.pixelSize: window.appConfig.scaled(11); font.bold: true }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { ac.addSep("center"); ac.saveToFile() } }
          }
        }
        DnDZone { id: centerZone; pillName: "center"; wrap: true; Layout.fillWidth: true }
      }
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        RowLayout {
          Layout.fillWidth: true
          Text { text: "Right"; color: window.palette.gray; font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(10); font.bold: true }
          Item { Layout.fillWidth: true }
          Text { visible: !root.cfg.rightPillEnabled; text: "hidden"; color: window.palette.gray; font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(9); font.italic: true }
          Rectangle {
            implicitWidth: 18; implicitHeight: 18; radius: 3; color: window.palette.bg2
            Text { anchors.centerIn: parent; text: "+"; color: window.palette.fg; font.pixelSize: window.appConfig.scaled(11); font.bold: true }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { ac.addSep("right"); ac.saveToFile() } }
          }
        }
        DnDZone { id: rightZone; pillName: "right"; wrap: true; Layout.fillWidth: true }
      }
      GradientSeparator { midColor: window.palette.bg2 }
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        Text { text: "Pool (disabled)"; color: window.palette.gray; font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(10); font.bold: true }
        DnDZone { id: poolZone; pillName: "pool"; Layout.fillWidth: true; wrap: true; minHeight: 34 }
      }
    }

    SetCard {
      sys: root.sys
      SetLabel { sys: root.sys; text: "Pills Appearance" }
      SetSlider {
        sys: root.sys
        label: "Pill background opacity"; from: 0.2; to: 1.0; step: 0.05; decimals: 2
        sub: "Multiplies the pill background alpha. 1.0 = palette color as-is, 0.2 = barely visible."
        value: root.cfg.barBgOpacity
        onMoved: v => { root.cfg.barBgOpacity = v; root.ac.saveToFile() }
      }
      SetSlider {
        sys: root.sys
        label: "Pill gradient"; from: 1.0; to: 2.0; step: 0.05; decimals: 2
        sub: "How much lighter the top of the pills is than the bottom. 1.0 = flat color."
        value: root.cfg.barLighten
        onMoved: v => { root.cfg.barLighten = v; root.ac.saveToFile() }
      }
      SetSlider {
        sys: root.sys
        label: "Pill border width"; from: 0; to: 4; step: 1; suffix: "px"
        sub: "Outline around each pill. 0 = no border."
        value: root.cfg.barBorderWidth
        onMoved: v => { root.cfg.barBorderWidth = v; root.ac.saveToFile() }
      }
    }

    SetCard {
      sys: root.sys
      SetLabel { sys: root.sys; text: "Separators" }
      SetSlider {
        sys: root.sys
        label: "Line opacity"; from: 0; to: 1.0; step: 0.05; decimals: 2
        sub: "The thin gradient line between widget groups in a pill."
        value: root.cfg.separatorOpacity
        onMoved: v => { root.cfg.separatorOpacity = v; root.ac.saveToFile() }
      }
      SetSlider {
        sys: root.sys
        label: "Glow"; from: 0; to: 0.5; step: 0.01; decimals: 2
        sub: "Soft glow around the separator line. 0 = no glow."
        value: root.cfg.separatorGlowOpacity
        onMoved: function(v) { root.cfg.separatorGlowOpacity = v; root.ac.saveToFile() }
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
    color: root.dragHoverZoneItem === zone ? Qt.lighter(window.palette.bg1, 1.15) : window.palette.bg1
    border.width: 1
    border.color: root.dragHoverZoneItem === zone ? window.palette.green : window.palette.bg2
    Behavior on color { ColorAnimation { duration: root.ac.anim(120) } }
    Behavior on border.color { ColorAnimation { duration: root.ac.anim(120) } }
    opacity: zone.pillName !== "pool" && !root.cfg[zone.pillName + "PillEnabled"] ? 0.55 : 1
    Behavior on opacity { NumberAnimation { duration: root.ac.anim(120) } }
    readonly property var allNames: pillName === "pool" ? ac.allWidgetNames.filter(n => !cfg[n + "Enabled"]) : ac.pillOrderFor(pillName).filter(n => ac.isSep(n) || cfg[n + "Enabled"])
    readonly property int maxPerRow: Math.max(1, Math.floor((zone.width - 8) / (chipW + spacing2)))
    readonly property var chipLayout: {
      var items = []
      var row = 0
      var x = 4, y = 4
      var widgetCount = 0
      for (var i = 0; i < allNames.length; i++) {
        var isSep = ac.isSep(allNames[i])
        var w = isSep ? 6 : chipW
        if (wrap && !isSep && widgetCount >= maxPerRow) { row++; x = 4; y = 4 + row * (chipH + spacing2); widgetCount = 0 }
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
        var w = ac.isSep(allNames[i]) ? 6 : chipW
        var dLeft = Math.abs(localX - chipLayout[i].x)
        if (dLeft < bestDist) { bestDist = dLeft; bestIdx = i }
        var dRight = Math.abs(localX - (chipLayout[i].x + w))
        if (dRight < bestDist) { bestDist = dRight; bestIdx = i + 1 }
      }
      return bestIdx
    }
    Rectangle {
      visible: root.dragHoverZoneItem === zone
      radius: root.dragActive && ac.isSep(root.dragName) ? 1 : 4
      color: "transparent"
      border.width: 1
      border.color: window.palette.green
      opacity: 0.5
      width: root.dragActive && ac.isSep(root.dragName) ? 6 : zone.chipW
      height: zone.chipH
      x: root.dragDropIndex >= 0 && root.dragDropIndex < zone.chipLayout.length ? zone.chipLayout[root.dragDropIndex].x : lastItemEndX()
      y: root.dragDropIndex >= 0 && root.dragDropIndex < zone.chipLayout.length ? zone.chipLayout[root.dragDropIndex].y : lastItemEndY()
      Behavior on x { NumberAnimation { duration: root.ac.anim(100) } }
      Behavior on y { NumberAnimation { duration: root.ac.anim(100) } }
    }
    function lastItemEndX() {
      if (chipLayout.length === 0) return 4
      var tr = Math.min(Math.max(0, Math.floor((lastLocalY - 4) / (chipH + spacing2))), chipRows - 1)
      for (var i = chipLayout.length - 1; i >= 0; i--) if (Math.floor((chipLayout[i].y - 4) / (chipH + spacing2)) === tr) return chipLayout[i].x + (ac.isSep(allNames[i]) ? 6 : chipW) + spacing2
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
        readonly property bool _isSep: ac.isSep(modelData)
        readonly property bool _isDragged: root.dragActive && root.dragName === modelData
        width: _isSep ? 6 : zone.chipW
        height: zone.chipH
        x: index < zone.chipLayout.length ? zone.chipLayout[index].x : 0
        y: index < zone.chipLayout.length ? zone.chipLayout[index].y : 0
        opacity: _isDragged ? 0.35 : 1.0
        Behavior on x { enabled: !root.dragActive; NumberAnimation { duration: root.ac.anim(120); easing.type: Easing.OutCubic } }
        Behavior on y { enabled: !root.dragActive; NumberAnimation { duration: root.ac.anim(120); easing.type: Easing.OutCubic } }
        radius: _isSep ? 2 : 4
        color: _isSep ? "transparent" : (chipArea.pressed ? window.palette.bg2 : window.palette.bgAlpha)
        border.width: _isSep ? 0 : 1
        border.color: _isDragged ? window.palette.accent : window.palette.bg2
        Rectangle { visible: _isSep; anchors.centerIn: parent; width: 2; height: 12; radius: 1; color: window.palette.mutedAlt; opacity: 0.5 }
        Text {
          visible: !_isSep
          anchors.centerIn: parent
          text: root.displayNames[chip.modelData] ?? chip.modelData
          color: _isDragged ? window.palette.mutedAlt : window.palette.fg
          font.family: window.palette.font
          font.pixelSize: window.appConfig.scaled(10)
          elide: Text.ElideRight
          width: parent.width - 6
          horizontalAlignment: Text.AlignHCenter
        }
        MouseArea {
          id: chipArea
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          preventStealing: true
          onPressed: function(mouse) {
            var globalPos = chip.mapToItem(coordSpace, mouse.x, mouse.y)
            root.startDrag(chip.modelData, globalPos, Qt.point(mouse.x, mouse.y))
          }
          onPositionChanged: function(mouse) {
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

  Rectangle {
    id: ghost
    property string text: ""
    property point grabOffset: Qt.point(0, 0)
    visible: false
    z: 1000
    width: 64
    height: 20
    radius: 4
    color: window.palette.green
    opacity: 0.85
    border.width: 1
    border.color: window.palette.bg0H
    Text {
      visible: ghost.text !== ""
      anchors.centerIn: parent
      text: ghost.text
      color: window.palette.bg0H
      font.family: window.palette.font
      font.pixelSize: window.appConfig.scaled(10)
      font.bold: true
      elide: Text.ElideRight
      width: parent.width - 6
      horizontalAlignment: Text.AlignHCenter
    }
  }
}
