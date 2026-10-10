// ============================================================
// quickshell/popups/WallpaperPopup.qml — вибір та встановлення шпалер
// ============================================================
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../core"

// Вибір шпалер — сітка мініатюр з можливістю встановити
AnimatedPopup {
  id: root

  required property QtObject window
  palette: window.palette
  appConfig: window.appConfig

  preferredWidth: 780
  preferredHeight: 210
  transformOrigin: Item.Top

  readonly property var wpCtl: root.window.wallpaperController

  centerScreen: window.screen ?? Quickshell.screens[0]

  Component.onCompleted: {
    anchor.window = window
    wpCtl.refresh()
  }

  onVisibleChanged: {
    if (visible) {
      // список шпалер перечитується при кожному відкритті — нові файли
      // в wp/ з'являлись лише після рестарту шела
      wpCtl.refresh()
      root.centerOnScreen()
    }
  }



  ColumnLayout {
    x: 10; y: 10
    width: parent.width - 20
    height: parent.height - 20
    spacing: 6

    // Заголовок 
    RowLayout {
      Layout.fillWidth: true
      spacing: 6

      Text {
        text: wpCtl.statusText !== "" ? wpCtl.statusText : "\uF03E  Wallpapers"
        color: window.palette.green
        font.family: window.palette.font; font.pixelSize: appConfig.scaled(14); font.bold: true
        elide: Text.ElideRight
        Layout.fillWidth: true
      }

    }

    // Роздільник
    GradientSeparator { midColor: window.palette.bg2 }

    // Сітка мініатюр (горизонтальний скрол)
    ListView {
      Layout.fillWidth: true
      Layout.preferredHeight: 148
      orientation: ListView.Horizontal
      spacing: 6
      clip: true
      reuseItems: true
      model: wpCtl.wallpapers
      delegate: Rectangle {
        required property string modelData
        width: 200; height: 140; radius: 6
        color: window.palette.bg1
        border.width: 1
        border.color: ma.containsMouse ? window.palette.green : "transparent"
        Behavior on border.color { ColorAnimation { duration: appConfig.anim(120) } }
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
          onClicked: wpCtl.setWallpaper(modelData)
        }
      }
    }
  }
}
