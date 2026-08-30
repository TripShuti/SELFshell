// ============================================================
// quickshell/popups/audio/PortCombo.qml — комбобокс вибору порту (sink/source)
// ============================================================
import QtQuick
import QtQuick.Layouts

ColumnLayout {
  id: root

  required property QtObject window
  property var ports: [] // [{name, description, availability}]
  property string activePort: ""
  property bool menuOpen: false
  property int comboWidth: 140

  signal portPicked(string portName)

  spacing: 2
  Layout.fillWidth: true

  // Кнопка комбо
  Rectangle {
    visible: root.ports && root.ports.length > 0
    Layout.preferredWidth: root.comboWidth
    Layout.alignment: Qt.AlignRight
    implicitHeight: 22
    radius: 4
    color: root.menuOpen ? window.palette.bg2 : window.palette.bgAlpha
    border.width: 1; border.color: window.palette.bg2

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: 6; anchors.rightMargin: 6
      spacing: 4
      Text {
        text: {
          if (!root.activePort) return "Port"
          for (var i = 0; i < root.ports.length; i++) if (root.ports[i].name === root.activePort) return root.ports[i].description
          return root.activePort
        }
        color: window.palette.fg
        font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(8)
        elide: Text.ElideRight
        Layout.fillWidth: true
      }
      Text { text: root.menuOpen ? "\uF077" : "\uF078"; color: window.palette.gray; font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(8) }
    }
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: root.menuOpen = !root.menuOpen
    }
  }

  // Випадаючий список (inline)
  ColumnLayout {
    visible: root.menuOpen
    Layout.fillWidth: true
    spacing: 2
    Repeater {
      model: root.ports
      delegate: Rectangle {
        required property var modelData
        Layout.fillWidth: true
        implicitHeight: 22
        radius: 4
        property bool isActive: root.activePort === modelData.name
        color: isActive ? window.palette.green : (ma.containsMouse ? window.palette.bg2 : window.palette.bgAlpha)
        Text {
          anchors.verticalCenter: parent.verticalCenter
          anchors.left: parent.left; anchors.leftMargin: 8
          anchors.right: parent.right; anchors.rightMargin: 8
          text: modelData.description + (modelData.availability === "not available" ? " (unplugged)" : "")
          color: isActive ? window.palette.baseOverlay : window.palette.fg
          font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(9)
          elide: Text.ElideRight
        }
        MouseArea {
          id: ma
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.portPicked(modelData.name)
            root.menuOpen = false
          }
        }
      }
    }
  }
}
