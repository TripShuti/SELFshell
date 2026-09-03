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
  readonly property string wallpaperOnlyPath: Qt.resolvedUrl("../../scripts/update-wallpaper-only.sh").toString().replace("file://", "")
  readonly property string listScriptPath: Qt.resolvedUrl("../../scripts/update-palette.py").toString().replace("file://", "")

  property var wallpapers: []
  property string statusText: ""
  // StdioCollector не чиститься між запусками — прапор свіжих даних
  property bool _listGotData: false

  implicitWidth: parent?.width ?? 0
  implicitHeight: col.implicitHeight

  Component.onCompleted: refresh()

  function refresh() { listProc.running = true }

  // Список шпалер з директорії wp/ (той самий механізм, що в WallpaperPopup)
  Process {
    id: listProc
    stdout: listCollector
    command: ["python3", root.listScriptPath, "list"]
    onStarted: root._listGotData = false
    onExited: {
      running = false
      if (!root._listGotData) root.wallpapers = []
    }
  }

  StdioCollector {
    id: listCollector
    waitForEnd: true
    onDataChanged: {
      root._listGotData = true
      if (listCollector.text) {
        root.wallpapers = listCollector.text.trim().split("\n").filter(p => p.trim() !== "")
      }
    }
  }

  // Застосовує вибрану шпалеру; статус "Setting wallpaper..." зникає
  // за кілька секунд (як у WallpaperPopup); помилку показуємо текстом
  Process {
    id: applyProc
    onExited: (exitCode) => {
      running = false
      if (exitCode !== 0) root.statusText = "\u26A0 Failed to set wallpaper (code " + exitCode + ")"
      statusTimer.restart()
    }
  }

  Timer {
    id: statusTimer
    interval: 3000
    onTriggered: root.statusText = ""
  }

  function setWallpaper(path) {
    if (applyProc.running) return
    var isStatic = window.appConfig.cfg.themeMode === "black"
    root.statusText = isStatic ? "\uF002 Setting wallpaper (palette stays)..." : "\uF002 Setting wallpaper..."
    applyProc.command = isStatic ? [root.wallpaperOnlyPath, path] : [root.paletteScriptPath, path]
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
        text: {
          if (root.statusText !== "") return root.statusText
          if (window.appConfig.cfg.themeMode === "black")
            return "Pick a wallpaper — palette stays fixed (black theme, wallpaper-only)"
          return "Pick a wallpaper — the palette regenerates automatically (Matugen)"
        }
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
      text: window.appConfig.cfg.themeMode === "black"
            ? "Note: in Black theme the palette is static — only the wallpaper image changes."
            : "Note: applying a wallpaper re-runs the palette generator — bar and popup colors update live."
      color: window.palette.mutedAlt
      font.family: window.palette.font
      font.pixelSize: window.appConfig.scaled(10)
      wrapMode: Text.WordWrap
      Layout.fillWidth: true
    }
  }
}