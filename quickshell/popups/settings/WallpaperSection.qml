// ============================================================
// quickshell/popups/settings/WallpaperSection.qml — вибір шпалер: мініатюри, клік застосовує через update-palette.sh і перегенеровує палітру
// ============================================================
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../core"

Item {
  id: root
  required property QtObject sys

  readonly property var window: sys.window

  readonly property string paletteScriptPath: Qt.resolvedUrl("../../scripts/update-palette.sh").toString().replace("file://", "")
  readonly property string listScriptPath: Qt.resolvedUrl("../../scripts/update-palette.py").toString().replace("file://", "")

  property var wallpapers: []
  property string statusText: ""

  implicitWidth: parent?.width ?? 0
  implicitHeight: col.implicitHeight

  Component.onCompleted: refresh()

  function refresh() { listProc.running = true }

  // Список шпалер з директорії wp/ (той самий механізм, що в WallpaperPopup)
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
        root.wallpapers = listCollector.text.trim().split("\n").filter(p => p.trim() !== "")
      }
    }
  }

  // Застосовує вибрану шпалеру; статус "Setting wallpaper..." зникає
  // за кілька секунд (як у WallpaperPopup)
  Process {
    id: applyProc
    onExited: { running = false; statusTimer.restart() }
  }

  Timer {
    id: statusTimer
    interval: 3000
    onTriggered: root.statusText = ""
  }

  function setWallpaper(path) {
    root.statusText = "\uF002 Setting wallpaper..."
    applyProc.command = [root.paletteScriptPath, path]
    applyProc.running = true
  }

  ColumnLayout {
    id: col
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    spacing: 10

    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      Text {
        text: root.statusText !== "" ? root.statusText
                                     : "Pick a wallpaper — the palette regenerates automatically"
        color: root.statusText !== "" ? window.palette.green : window.palette.gray
        font.family: window.palette.font
        font.pixelSize: window.appConfig.scaled(11)
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
      }

      // Кнопка перечитати список шпалер
      Rectangle {
        implicitWidth: 22; implicitHeight: 22; radius: 4
        color: refreshMa.containsMouse ? window.palette.bg2 : window.palette.bg1
        Behavior on color { ColorAnimation { duration: window.appConfig.anim(120) } }
        Text {
          anchors.centerIn: parent
          text: "\uF021"
          color: refreshMa.containsMouse ? window.palette.fg : window.palette.gray
          font.family: window.palette.font
          font.pixelSize: window.appConfig.scaled(11)
        }
        MouseArea {
          id: refreshMa
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.refresh()
        }
      }
    }

    // Сітка мініатюр: обтікає під ширину сторінки (3 на рядок)
    Flow {
      id: grid
      Layout.fillWidth: true
      spacing: 8

      Repeater {
        model: root.wallpapers

        delegate: Rectangle {
          required property string modelData
          readonly property real thumbW: Math.max(140, (grid.width - 16) / 3)

          width: thumbW
          height: 100
          radius: 6
          color: window.palette.bg1
          border.width: 1
          border.color: ma.containsMouse ? window.palette.green : "transparent"
          Behavior on border.color { ColorAnimation { duration: window.appConfig.anim(120) } }

          Image {
            anchors.fill: parent
            anchors.margins: 2
            source: "file://" + modelData
            sourceSize.width: 200
            sourceSize.height: 100
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

    Text {
      text: "Note: applying a wallpaper re-runs the palette generator — bar and popup colors update live."
      color: window.palette.mutedAlt
      font.family: window.palette.font
      font.pixelSize: window.appConfig.scaled(10)
      wrapMode: Text.WordWrap
      Layout.fillWidth: true
    }
  }
}