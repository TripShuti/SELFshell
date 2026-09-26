// ============================================================
// quickshell/popups/settings/WallpaperSection.qml — вибір шпалер: мініатюри, клік застосовує через update-palette.sh і перегенеровує палітру
// ============================================================
import QtQuick
import QtQuick.Layouts
import "../../core"

Item {
  id: root
  required property QtObject sys

  readonly property var window: sys.window

  WallpaperController {
    id: wpCtl
    appConfig: root.window.appConfig
  }

  implicitWidth: parent?.width ?? 0
  implicitHeight: col.implicitHeight

  Component.onCompleted: wpCtl.refresh()

  function refresh() { wpCtl.refresh() }


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
          if (wpCtl.statusText !== "") return wpCtl.statusText
          if (window.appConfig.cfg.themeMode === "black")
            return "Pick a wallpaper — palette stays fixed (black theme, wallpaper-only)"
          return "Pick a wallpaper — the palette regenerates automatically (Matugen)"
        }
        color: wpCtl.statusText !== "" ? window.palette.green : window.palette.gray
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
          onClicked: wpCtl.refresh()
        }
      }
    }

    // Сітка мініатюр: обтікає під ширину сторінки (3 на рядок)
    Flow {
      id: grid
      Layout.fillWidth: true
      spacing: 8

      Repeater {
        model: wpCtl.wallpapers

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
            onClicked: wpCtl.setWallpaper(modelData)
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