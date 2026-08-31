// ============================================================
// quickshell/popups/settings/AppearanceSection.qml — глобальні налаштування вигляду: масштаб, анімації та тема (Black/Matugen)
// ============================================================
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../core"

Item {
  id: root
  required property QtObject sys

  readonly property var cfg: sys.cfg
  readonly property var ac: sys.ac
  readonly property var window: sys.window

  readonly property string palettePy: Qt.resolvedUrl("../../scripts/update-palette.py").toString().replace("file://", "")
  readonly property string wallpaperOnlySh: Qt.resolvedUrl("../../scripts/update-wallpaper-only.sh").toString().replace("file://", "")
  readonly property string wallpaperSh: Qt.resolvedUrl("../../scripts/update-palette.sh").toString().replace("file://", "")
  readonly property string wpDir: Qt.resolvedUrl("../../wp").toString().replace("file://", "")

  property string themeStatus: ""
  property bool themeBusy: false

  implicitWidth: parent?.width ?? 0
  implicitHeight: col.implicitHeight

  // Застосовує статичну тему + ставить відповідну шпалеру без matugen
  function applyTheme(id) {
    if (themeBusy) return
    themeBusy = true
    root.cfg.themeMode = id
    root.ac.saveToFile()
    if (id === "black") {
      themeStatus = "Applying black theme..."
      themePaletteProc.command = ["python3", palettePy, "--theme", id]
      themePaletteProc.running = true
    } else {
      // Matugen — регенеруємо з поточної шпалери, якщо вона є
      themeStatus = "Switching to Matugen..."
      matugenCheckProc.running = true
    }
  }

  StdioCollector {
    id: curCollector
    waitForEnd: true
  }

  // Перевіряє current.* для Matugen
  Process {
    id: matugenCheckProc
    stdout: curCollector
    command: ["python3", palettePy, "current"]
    onExited: {
      var cur = curCollector.text.trim()
      if (cur !== "") {
        themePaletteProc.command = [wallpaperSh, cur]
        themePaletteProc.running = true
      } else {
        // Немає current.* — просто скидаємо статус, палітра лишається до наступної шпалери
        themeStatus = "Matugen — pick a wallpaper to generate palette"
        themeBusy = false
        themeStatusTimer.restart()
        // Все одно сповіщаємо shell — раптом палітру міняли вручну
        window.palette.reload()
      }
    }
  }

  Process {
    id: themePaletteProc
    onExited: {
      if (root.cfg.themeMode === "black") {
        // Ставимо шпалеру black.png без регенерації
        var wp = wpDir + "/black.png"
        themeWallpaperProc.command = [wallpaperOnlySh, wp]
        themeWallpaperProc.running = true
      } else {
        // Matugen через update-palette.sh вже поставив шпалеру + палітру
        themeStatus = "Matugen active"
        themeBusy = false
        themeStatusTimer.restart()
        // Шел вже отримав palette-reload з update-palette.sh, але підстрахуємось
        window.palette.reload()
        footProc.command = ["pkill", "-USR1", "-x", "foot"]
        footProc.running = true
      }
    }
  }

  Process {
    id: themeWallpaperProc
    onExited: {
      window.palette.reload()
      footProc.command = ["pkill", "-USR1", "-x", "foot"]
      footProc.running = true
      themeStatus = "Black theme applied"
      themeBusy = false
      themeStatusTimer.restart()
    }
  }

  Process { id: footProc; onExited: running = false }

  Timer {
    id: themeStatusTimer
    interval: 3000
    onTriggered: root.themeStatus = ""
  }

  ColumnLayout {
    id: col
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    spacing: 16

    SetCard {
      sys: root.sys
      SetLabel { sys: root.sys; text: "Theme" }
      SetSelect {
        sys: root.sys
        label: "Theme mode"
        options: [{ id: "black", text: "Black" }, { id: "matugen", text: "Matugen" }]
        value: root.cfg.themeMode === "white" ? "matugen" : root.cfg.themeMode
        onPicked: id => root.applyTheme(id)
      }
      Text {
        visible: root.themeStatus !== ""
        text: root.themeStatus
        color: window.palette.green
        font.family: window.palette.font
        font.pixelSize: root.window.appConfig.scaled(10)
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
      }
      Text {
        visible: root.themeStatus === ""
        text: {
          if (root.cfg.themeMode === "black") return "Black — soft mono static palette, wallpaper changes without regeneration."
          return "Matugen — dynamic palette from wallpaper (awww + matugen + palette reload)."
        }
        color: window.palette.gray
        font.family: window.palette.font
        font.pixelSize: window.appConfig.scaled(10)
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
      }
      Text {
        visible: root.cfg.themeMode === "black"
        text: "In Black, picking a wallpaper in Wallpaper section/popup only changes the image — colors stay fixed."
        color: window.palette.mutedAlt
        font.family: window.palette.font
        font.pixelSize: window.appConfig.scaled(9)
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
      }
    }

    SetCard {
      sys: root.sys
      SetLabel { sys: root.sys; text: "Scale" }
      SetSlider {
        sys: root.sys
        label: "UI scale"; from: 0.8; to: 1.5; step: 0.05; decimals: 2; suffix: "\u00D7"
        sub: "Multiplies all text and icon glyph sizes in the bar, popups and settings. 1.0 = default."
        value: root.cfg.uiScale
        onMoved: v => { root.cfg.uiScale = v; root.ac.saveToFile() }
      }
    }

    SetCard {
      sys: root.sys
      SetLabel { sys: root.sys; text: "Animations" }
      SetToggle {
        sys: root.sys
        label: "Enable animations"
        sub: "Disables all transitions: changes apply instantly."
        on: root.cfg.animationsEnabled
        onToggled: v => { root.cfg.animationsEnabled = v; root.ac.saveToFile() }
      }
      SetSlider {
        sys: root.sys
        label: "Animation speed"; from: 0.5; to: 2.0; step: 0.1; decimals: 1; suffix: "\u00D7"
        sub: "Multiplies every animation duration in the shell. 1.0 = default, 0.5 = twice as fast."
        value: root.cfg.animSpeed
        onMoved: v => { root.cfg.animSpeed = v; root.ac.saveToFile() }
      }
    }
  }
}
