// ============================================================
// WallpaperPopup.qml — вибір та встановлення шпалер
// ============================================================
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"
import "../Palette.js" as Palette

// Вибір шпалер — сітка мініатюр з можливістю встановити
AnimatedPopup {
  id: root

  required property QtObject window

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
      var scr = window.screen
      anchor.rect = Qt.rect(
        (scr.width - implicitWidth) / 2,
        (scr.height - implicitHeight) / 2,
        implicitWidth,
        implicitHeight
      )
    }
  }

  // Тло попапа
  Rectangle {
    anchors.fill: parent
    radius: 12
    color: Palette.bg0H
    opacity: 0.88
  }

  // Отримує список файлів шпалер з директорії wp/
  Process {
    id: listProc
    stdout: listCollector
    command: ["sh", "-c", "ls $HOME/.config/quickshell/wp/*.{jpg,jpeg,png} 2>/dev/null"]
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
    onExited: running = false
  }

  function setWallpaper(path) {
    statusText = "\uF002 Setting wallpaper..."
    applyProc.command = ["sh", "-c", "$HOME/.config/quickshell/scripts/update-palette.sh \"$1\"", "--", path]
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
        color: Palette.green
        font.family: Palette.font; font.pixelSize: 14; font.bold: true
        elide: Text.ElideRight
        Layout.fillWidth: true
      }

      Rectangle {
        implicitWidth: 22; implicitHeight: 22; radius: 4
        color: closeArea.containsMouse ? Palette.bg2 : Palette.bg1
        Behavior on color { ColorAnimation { duration: 100 } }

        Text {
          anchors.centerIn: parent
          text: "\uF00D"
          color: closeArea.containsMouse ? Palette.fg : Palette.gray
          Behavior on color { ColorAnimation { duration: 120 } }
          font.family: Palette.font; font.pixelSize: 11
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
            color: Palette.bg1
            border.width: 1
            border.color: ma.containsMouse ? Palette.green : "transparent"
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
