// ============================================================
// quickshell/popups/control/QuickToggles.qml — ряд швидких дій: мережа, Bluetooth, шпалери, налаштування, скріншоти
// ============================================================
import QtQuick
import QtQuick.Layouts

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

    // Кнопка мережі
    Rectangle {
      Layout.fillWidth: true
      implicitHeight: 24
      radius: 6
      color: netArea.containsMouse ? window.palette.bg2 : window.palette.bg1
      Behavior on color { ColorAnimation { duration: window.appConfig.anim(120) } }

      Text {
        anchors.centerIn: parent
        text: "󰖩"
        color: netArea.containsMouse ? window.palette.green : window.palette.gray
        Behavior on color { ColorAnimation { duration: window.appConfig.anim(120) } }
        font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(13)
      }

      MouseArea {
        id: netArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.openNetManager()
      }
    }

    // Кнопка Bluetooth
    Rectangle {
      Layout.fillWidth: true
      implicitHeight: 24
      radius: 6
      color: btArea.containsMouse ? window.palette.bg2 : window.palette.bg1
      Behavior on color { ColorAnimation { duration: window.appConfig.anim(120) } }

      Text {
        anchors.centerIn: parent
        text: ""
        color: btArea.containsMouse ? window.palette.green : window.palette.gray
        Behavior on color { ColorAnimation { duration: window.appConfig.anim(120) } }
        font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(13)
      }

      MouseArea {
        id: btArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.openBtManager()
      }
    }

    // Кнопка шпалер
    Rectangle {
      Layout.fillWidth: true
      implicitHeight: 24
      radius: 6
      color: wallArea.containsMouse ? window.palette.bg2 : window.palette.bg1
      Behavior on color { ColorAnimation { duration: window.appConfig.anim(120) } }

      Text {
        anchors.centerIn: parent
        text: "\uF03E"
        color: wallArea.containsMouse ? window.palette.green : window.palette.gray
        Behavior on color { ColorAnimation { duration: window.appConfig.anim(120) } }
        font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(13)
      }

      MouseArea {
        id: wallArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.openWallpaperPopup()
      }
    }

    // Кнопка налаштувань
    Rectangle {
      Layout.fillWidth: true
      implicitHeight: 24
      radius: 6
      color: settingsArea.containsMouse ? window.palette.bg2 : window.palette.bg1
      Behavior on color { ColorAnimation { duration: window.appConfig.anim(120) } }

      Text {
        anchors.centerIn: parent
        text: ""
        color: settingsArea.containsMouse ? window.palette.green : window.palette.gray
        Behavior on color { ColorAnimation { duration: window.appConfig.anim(120) } }
        font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(13)
      }

      MouseArea {
        id: settingsArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.openSettingsPopup()
      }
    }

    // Кнопка скріншота всього екрану
    Rectangle {
      Layout.fillWidth: true
      implicitHeight: 24
      radius: 6
      color: fullArea.containsMouse ? window.palette.bg2 : window.palette.bg1
      Behavior on color { ColorAnimation { duration: window.appConfig.anim(120) } }

      Text {
        anchors.centerIn: parent
        text: "\uF030"
        color: fullArea.containsMouse ? window.palette.green : window.palette.gray
        Behavior on color { ColorAnimation { duration: window.appConfig.anim(120) } }
        font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(13)
      }

      MouseArea {
        id: fullArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
          root.takeShot("full")
        }
      }
    }

    // Кнопка скріншота області (slurp)
    Rectangle {
      Layout.fillWidth: true
      implicitHeight: 24
      radius: 6
      color: regionArea.containsMouse ? window.palette.bg2 : window.palette.bg1
      Behavior on color { ColorAnimation { duration: window.appConfig.anim(120) } }

      Text {
        anchors.centerIn: parent
        text: "\uF125"
        color: regionArea.containsMouse ? window.palette.green : window.palette.gray
        Behavior on color { ColorAnimation { duration: window.appConfig.anim(120) } }
        font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(13)
      }

      MouseArea {
        id: regionArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
          root.takeShot("region")
        }
      }
    }
  }
}
