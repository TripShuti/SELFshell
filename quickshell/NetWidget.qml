// ============================================================
// NetWidget.qml — віджет мережі на панелі
// ============================================================
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "Palette.js" as Palette

// Віджет мережі на панелі — показує іконку та назву підключення
Rectangle {
  id: root

  implicitWidth: netRow.implicitWidth + 12
  implicitHeight: 26
  radius: 6
  color: mouseArea.containsMouse ? Palette.bg2 : "transparent"

  property string currentIcon: "󰤮"
  property string connectionName: "Disconnected"

  signal clicked()

  // Опитує nmcli для визначення активного з'єднання
  Process {
    id: netStatusProc
    command: ["/usr/bin/nmcli", "-t", "-f", "TYPE,STATE,CONNECTION", "device"]
    running: true

    property string buffer: ""

    onExited: (exitCode) => {
      if (exitCode === 0) {
        var lines = netStatusProc.buffer.split("\n")
        var icon = "󰤮"
        var name = "Disconnected"
        for (var i = 0; i < lines.length; i++) {
          var parts = lines[i].split(":")
          if (parts.length < 3) continue
          if (parts[1] === "connected") {
            if (parts[0] === "ethernet") {
              icon = "󰈀"
              name = parts[2]
              break
            } else if (parts[0] === "wifi") {
              icon = "󰖩"
              name = parts[2]
              break
            }
          }
        }
        root.currentIcon = icon
        root.connectionName = name
      }
      netStatusProc.buffer = ""
      running = false
    }
  }

  // Збирає дані з stdout процесу
  Connections {
    target: netStatusProc.stdout
    function onData(data) { netStatusProc.buffer += data }
  }

  // Періодичне опитування кожні 5 секунд
  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: netStatusProc.running = true
  }

  // Іконка мережі + назва підключення
  RowLayout {
    id: netRow
    anchors.centerIn: parent
    spacing: 6

    // Іконка: Ethernet / Wi-Fi / відключено
    Text {
      text: root.currentIcon
      color: root.connectionName !== "Disconnected" ? Palette.accent : Palette.gray
      font.family: Palette.font; font.pixelSize: 14
    }

    // Назва мережі (прихована якщо відключено)
    Text {
      text: root.connectionName
      color: Palette.textLight
      font.family: Palette.font; font.pixelSize: 11
      visible: root.connectionName !== "Disconnected"
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    onClicked: root.clicked()
  }
}
