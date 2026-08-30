// ============================================================
// popups/audio/DeviceCard.qml — картка пристрою (Output/Input)
// з портом, fallback та слайдером
// ============================================================
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import "../../core"

Item {
  id: root

  required property QtObject window
  required property PwNode deviceNode
  property bool isSink: true // true=Output, false=Input
  property var portMap: ({})
  property bool isDefault: false

  signal setDefaultRequested()
  signal setPortRequested(string portName)

  IconResolver { id: iconResolver }

  implicitHeight: card.implicitHeight
  Layout.fillWidth: true

  Rectangle {
    id: card
    width: parent.width
    implicitHeight: col.implicitHeight + 12
    radius: 6
    color: window.palette.bg1
    border.width: 1; border.color: window.palette.bg2

    ColumnLayout {
      id: col
      anchors.fill: parent
      anchors.margins: 6
      spacing: 6

      // Header: icon + name + port combo + fallback
      RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Item {
          Layout.preferredWidth: 22; Layout.preferredHeight: 22
          property string _res: {
            var n = deviceNode.properties["device.icon_name"] || (root.isSink ? "audio-card-analog" : "audio-input-microphone")
            var r = iconResolver.resolve(n)
            return r
          }
          Image {
            anchors.fill: parent
            source: parent._res
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            visible: status === Image.Ready
          }
          Text {
            anchors.centerIn: parent
            visible: parent._res === ""
            text: deviceNode.name === "SELFshell_EQ" ? "\uF1DE" : (root.isSink ? "\uF028" : "\uF130")
            color: deviceNode.name === "SELFshell_EQ" ? window.palette.purple : (root.isSink ? window.palette.green : window.palette.red)
            font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(12)
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0
          Text {
            text: deviceNode.description || deviceNode.nickname || deviceNode.name
            color: window.palette.fg
            font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(11); font.bold: true
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
          Text {
            text: deviceNode.name
            color: window.palette.gray
            font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(8)
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
        }

        // Fallback
        Rectangle {
          property bool hovered: false
          width: 24; height: 24; radius: 4
          color: root.isDefault ? window.palette.green : (hovered ? window.palette.hoverBg : window.palette.bgAlpha)
          Behavior on color { ColorAnimation { duration: window.appConfig.anim(120) } }
          Text {
            anchors.centerIn: parent
            text: "\uF00C"
            color: root.isDefault ? window.palette.baseOverlay : window.palette.muted
            font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(11)
          }
          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: parent.hovered = true
            onExited: parent.hovered = false
            onClicked: root.setDefaultRequested()
          }
        }
      }

      // Порт — через PortCombo (кнопка + меню)
      PortCombo {
        window: root.window
        ports: {
          var info = root.portMap[deviceNode.name]
          return info && info.ports ? info.ports : []
        }
        activePort: {
          var info = root.portMap[deviceNode.name]
          return info ? (info.active_port || "") : ""
        }
        comboWidth: 140
        onPortPicked: portName => root.setPortRequested(portName)
      }

      // Slider — напряму PwNode (фікс багу 100%→0)
      AudioSlider {
        Layout.fillWidth: true
        window: root.window
        node: deviceNode
        activeColor: root.isSink ? window.palette.green : window.palette.red
        isInput: !root.isSink
        baseVolume: {
          if (!root.isSink) return 1.0
          var info = root.portMap[deviceNode.name]
          if (info && info.base_volume) return info.base_volume.value / 65536.0
          return 1.0
        }
        showBaseMarker: root.isSink
      }

      // Base info (як у pavucontrol)
      Text {
        visible: {
          if (!root.isSink) return false
          var info = root.portMap[deviceNode.name]
          return !!(info && info.base_volume && info.base_volume.value_percent !== "100%")
        }
        text: {
          var info = root.portMap[deviceNode.name]
          if (!info || !info.base_volume) return ""
          return "Base: " + info.base_volume.value_percent + " / " + info.base_volume.db
        }
        color: window.palette.gray
        font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(8)
      }
    }
  }

  PwObjectTracker { objects: [deviceNode] }
}
