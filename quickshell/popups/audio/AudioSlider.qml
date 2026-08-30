// ============================================================
// popups/audio/AudioSlider.qml — уніфікований рядок гучності:
// mute-кнопка + трек + відсоток/dB + lock (як у pavucontrol)
// ============================================================
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import "../../scripts/AudioMixerUtils.js" as AudioUtils

Item {
  id: root

  required property QtObject window
  required property PwNode node

  property real baseVolume: 1.0
  property bool showBaseMarker: false
  property color activeColor: window ? window.palette.green : "#00ff00"
  property bool isInput: false

  readonly property real frac: node && node.audio ? Math.max(0, Math.min(1, node.audio.volume)) : 0
  readonly property bool isMuted: node && node.audio ? node.audio.muted : false
  readonly property real vol: node && node.audio ? node.audio.volume : 0

  Layout.fillWidth: true
  implicitHeight: 24

  // Mute кнопка
  Rectangle {
    id: muteBtn
    property bool hovered: false
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    width: 24; height: 24; radius: 4
    color: root.isMuted ? window.palette.red : (hovered ? window.palette.hoverBg : window.palette.bgAlpha)
    Behavior on color { ColorAnimation { duration: window.appConfig.anim(120) } }
    Text {
      anchors.centerIn: parent
      text: {
        if (root.isMuted) return root.isInput ? "\uF131" : "\uF026"
        return root.isInput ? "\uF130" : "\uF028"
      }
      color: root.isMuted ? window.palette.baseOverlay : window.palette.fg
      font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(11)
    }
    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: parent.hovered = true
      onExited: parent.hovered = false
      onClicked: { if (node && node.audio) node.audio.muted = !node.audio.muted }
    }
  }

  // Lock — праворуч
  Text {
    id: lockIcon
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    text: "\uF023"
    color: window.palette.gray
    font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(10)
  }

  // Відсоток + dB — перед lock
  Column {
    id: volLabel
    anchors.right: lockIcon.left
    anchors.rightMargin: 6
    anchors.verticalCenter: parent.verticalCenter
    spacing: 0
    width: 48
    Text {
      text: AudioUtils.formatPercent(root.vol)
      color: window.palette.fg
      font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(10)
      horizontalAlignment: Text.AlignRight
      width: parent.width
    }
    Text {
      text: AudioUtils.formatDb(root.vol)
      color: window.palette.gray
      font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(7)
      horizontalAlignment: Text.AlignRight
      width: parent.width
    }
  }

  // Трек — розтягується між mute і volLabel через anchor-и
  Item {
    id: bar
    anchors.left: muteBtn.right
    anchors.leftMargin: 6
    anchors.right: volLabel.left
    anchors.rightMargin: -16
    anchors.verticalCenter: parent.verticalCenter
    height: 18

    PwObjectTracker { objects: [node] }

    function pick(px) {
      var f = Math.max(0, Math.min(1, px / Math.max(1, bar.width)))
      if (node && node.audio) node.audio.volume = f
    }

    // Трек фон
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width
      height: 6
      radius: 3
      color: window.palette.bgAlpha

      // Base marker (жовта риска) — тільки для Output Devices
      Rectangle {
        width: 2; height: 10; radius: 1
        color: window.palette.yellow
        opacity: 0.9
        anchors.verticalCenter: parent.verticalCenter
        x: parent.width * Math.min(root.baseVolume, 1) - width / 2
        visible: root.showBaseMarker && root.baseVolume > 0 && root.baseVolume < 1
      }

      // Заповнена частина
      Rectangle {
        width: parent.width * root.frac
        height: parent.height
        radius: 3
        color: root.isMuted ? window.palette.muted : root.activeColor
        Behavior on width { enabled: !volMa.pressed; NumberAnimation { duration: window.appConfig.anim(120); easing.type: Easing.OutCubic } }
      }
    }

    // Кнопка (коло)
    Rectangle {
      width: 10; height: 10; radius: 5
      color: window.palette.fg
      anchors.verticalCenter: parent.verticalCenter
      x: Math.max(0, Math.min(bar.width - width, bar.width * root.frac - width / 2))
      Behavior on x { enabled: !volMa.pressed; NumberAnimation { duration: window.appConfig.anim(120) } }
    }

    MouseArea {
      id: volMa
      anchors.fill: parent
      anchors.margins: -6
      cursorShape: Qt.PointingHandCursor
      preventStealing: true
      onPressed: function(mouse) { bar.pick(mouse.x + volMa.x) }
      onPositionChanged: function(mouse) { if (pressed) bar.pick(mouse.x + volMa.x) }
      onWheel: function(wheel) {
        if (wheel.angleDelta.y === 0) return
        if (!node || !node.audio) return
        var s = wheel.angleDelta.y > 0 ? window.appConfig.cfg.audioStep : -window.appConfig.cfg.audioStep
        node.audio.volume = Math.max(0, Math.min(node.audio.volume + s, 1))
      }
    }
  }
}
