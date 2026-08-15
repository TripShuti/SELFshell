// ============================================================
// WallpaperPopup.qml — вибір та встановлення шпалер
// ============================================================
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../core"

// Вибір шпалер — сітка мініатюр з можливістю встановити
AnimatedPopup {
  id: root

  required property QtObject window
  palette: window.palette
  appConfig: window.appConfig

  implicitWidth: 780
  implicitHeight: 210
  transformOrigin: Item.Top

  property var wallpapers: []

  Component.onCompleted: {
    anchor.window = window
    listProc.running = true
  }

  onVisibleChanged: {
    if (visible) {
      var scr = window.screen ?? Quickshell.screens[0]
      if (scr) {
        anchor.rect = Qt.rect(
          (scr.width - implicitWidth) / 2,
          (scr.height - implicitHeight) / 2,
          implicitWidth,
          implicitHeight
        )
      }
    }
  }


  readonly property string paletteScriptPath: Qt.resolvedUrl("../scripts/update-palette.sh").toString().replace("file://", "")
  readonly property string listScriptPath: Qt.resolvedUrl("../scripts/update-palette.py").toString().replace("file://", "")

  // Отримує список файлів шпалер з директорії wp/
  Process {
    id: listProc
    stdout: listCollector
    command: ["python3", root.listScriptPath, "list"]
  }

  StdioCollector {
    id: listCollector
    waitForEnd: true
    onDataChanged: {
      if (listCollector.text) {
        var parts = listCollector.text.trim().split("\n")
        root.wallpapers = parts.filter(function(p) { return p.trim() !== "" })
      }
    }
  }

  // Застосовує вибрану шпалеру через update-palette.sh
  Process {
    id: applyProc
    onExited: {
      running = false
      // Статус "Setting wallpaper..." має зникнути через кілька секунд
      statusResetTimer.restart()
    }
  }

  Timer {
    id: statusResetTimer
    interval: 3000
    onTriggered: root.statusText = ""
  }

  function setWallpaper(path) {
    statusText = "\uF002 Setting wallpaper..."
    applyProc.command = [root.paletteScriptPath, path]
    applyProc.running = true
  }

  property string statusText: ""

  ColumnLayout {
    x: 10; y: 10
    width: parent.width - 20
    height: parent.height - 20
    spacing: 6

    // Заголовок + кнопка закриття
    RowLayout {
      Layout.fillWidth: true
      spacing: 6

      Text {
        text: statusText !== "" ? statusText : "\uF03E  Wallpapers"
        color: window.palette.green
        font.family: window.palette.font; font.pixelSize: appConfig.scaled(14); font.bold: true
        elide: Text.ElideRight
        Layout.fillWidth: true
      }

      Rectangle {
        implicitWidth: 22; implicitHeight: 22; radius: 4
        color: closeArea.containsMouse ? window.palette.bg2 : window.palette.bg1
        Behavior on color { ColorAnimation { duration: 100 } }

        Text {
          anchors.centerIn: parent
          text: "\uF00D"
          color: closeArea.containsMouse ? window.palette.fg : window.palette.gray
          Behavior on color { ColorAnimation { duration: 120 } }
          font.family: window.palette.font; font.pixelSize: appConfig.scaled(11)
        }

        MouseArea {
          id: closeArea
          anchors.fill: parent
          hoverEnabled: true
          onClicked: root.close()
        }
      }
    }

    // Роздільник
    GradientSeparator { midColor: window.palette.bg2 }

    // Сітка мініатюр (горизонтальний скрол)
    Flickable {
      id: flick
      Layout.fillWidth: true
      Layout.preferredHeight: 148
      contentWidth: row.width
      contentHeight: row.height
      clip: true
      flickableDirection: Flickable.HorizontalFlick
      boundsBehavior: Flickable.StopAtBounds
      interactive: row.width > width

      Row {
        id: row
        height: parent.height
        spacing: 6
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
          model: root.wallpapers

          delegate: Rectangle {
            width: 200; height: 140; radius: 6
            color: window.palette.bg1
            border.width: 1
            border.color: ma.containsMouse ? window.palette.green : "transparent"
            Behavior on border.color { ColorAnimation { duration: 120 } }

            Image {
              anchors.fill: parent
              anchors.margins: 2
              source: "file://" + modelData
              sourceSize.width: 200
              sourceSize.height: 140
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              cache: true
            }

            MouseArea {
              id: ma
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.setWallpaper(modelData)
            }
          }
        }
      }
    }
  }
}
