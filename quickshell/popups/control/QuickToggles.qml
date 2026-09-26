// ============================================================
// quickshell/popups/control/QuickToggles.qml — ряд швидких дій: мережа, Bluetooth, шпалери, налаштування, скріншоти
// ============================================================
import QtQuick
import QtQuick.Layouts
import "../../core"

// Шість кнопок верхнього ряду. Власного стану нема — тільки емісія:
// відкриття менеджерів форвардяться коренем (його сигнали лишаються,
// проводка Bar не чіпається), скріншоти йдуть через takeShot з дебаунсом
// у корені (shotDebouncedClick + takeScreenshot).
RowLayout {
  id: root

  required property QtObject window
  signal openNetManager()
  signal openBtManager()
  signal openWallpaperPopup()
  signal openSettingsPopup()
  signal takeShot(string kind)

  Layout.fillWidth: true
  spacing: 8

  RowLayout {
    Layout.fillWidth: true
    spacing: 8

    // Шість кнопок одним Repeater: іконка + дія з моделі
    Repeater {
      model: [
        { icon: "󰖩", act: "net" },
        { icon: "", act: "bt" },
        { icon: "\uF03E", act: "wall" },
        { icon: "", act: "settings" },
        { icon: "\uF030", act: "full" },
        { icon: "\uF125", act: "region" },
      ]

      delegate: HoverButton {
        Layout.fillWidth: true
        implicitHeight: 24
        palette: window.palette
        appConfig: window.appConfig
        icon: modelData.icon
        onClicked: {
          switch (modelData.act) {
            case "net": root.openNetManager(); break
            case "bt": root.openBtManager(); break
            case "wall": root.openWallpaperPopup(); break
            case "settings": root.openSettingsPopup(); break
            case "full": root.takeShot("full"); break
            case "region": root.takeShot("region"); break
          }
        }
      }
    }
  }
}
