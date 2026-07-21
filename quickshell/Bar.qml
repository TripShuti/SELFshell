// ============================================================
// Bar.qml — головна панель системи (top bar) з віджетами,
// попапами та моніторами
// ============================================================
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "Palette.js" as Palette
import QtQuick
import QtQuick.Layouts
import "widgets"
import "popups"
import "monitors"

// Головна панель системи — прикріплена до верхнього краю екрана
PanelWindow {
  id: root

  required property var modelData
  screen: modelData

  readonly property real pillHeight: root.implicitHeight - 8

  anchors {
    top: true
    left: true
    right: true
  }

  implicitHeight: 36
  color: "transparent"
  exclusiveZone: 36

  // Пігулка — контейнер з градієнтом для групи віджетів
  component Pill: Item {
    id: pillRoot
    property alias pillColor: pillBg.color
    property alias radius: pillBg.radius
    default property alias data: pillBg.data
    property real glowStrength: 0.16

    // Зовнішнє сяйво навколо пігулки
    Rectangle {
      anchors.fill: pillBg
      anchors.margins: -2
      radius: pillBg.radius + 2
      color: "transparent"
      border.width: 1
      border.color: Palette.hoverBg
      opacity: 0.1
    }

    // Тіло пігулки з градієнтом
    Rectangle {
      id: pillBg
      anchors.fill: parent
      clip: true
      color: Palette.bgAlpha
      opacity: 1
      border.width: 0
      border.color: Palette.outlineVariant

      gradient: Gradient {
        orientation: Gradient.Vertical
        GradientStop { position: 0.0; color: Qt.lighter(Palette.baseOverlay, 1.18) }
        GradientStop { position: 1.0; color: Palette.bgAlpha }
      }

      Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    }
  }

  // Ліва пігулка — лаунчер, робочі столи, медіаплеєр
  Pill {
    id: leftPill
    anchors {
      left: parent.left
      leftMargin: 8
      verticalCenter: parent.verticalCenter
    }
    height: pillHeight
    radius: pillHeight / 8
    width: leftRow.implicitWidth + 16

    RowLayout {
      id: leftRow
      x: 8
      anchors.verticalCenter: parent.verticalCenter
      spacing: 4

      LauncherWidget {
        id: launcherWidget
        Layout.alignment: Qt.AlignVCenter
      }

      Separator {
        Layout.alignment: Qt.AlignVCenter
      }

      Workspaces {
        id: workspacesRow
        Layout.alignment: Qt.AlignVCenter
      }

      Separator {
        Layout.alignment: Qt.AlignVCenter
      }

      MprisWidget {
        id: mprisWidget
        Layout.fillHeight: true
        cavBars: cavaMonitor.bars
      }
    }
  }

  // Центральна пігулка — годинник, таймер, Genshin
  Pill {
    id: centerPill
    anchors.centerIn: parent
    height: pillHeight
    radius: pillHeight / 8
    width: centerRow.implicitWidth + 16
    glowStrength: genshinWidget.resinClass === "critical" ? 0.32 : 0.16

    Behavior on glowStrength { NumberAnimation { duration: 220 } }

    RowLayout {
      id: centerRow
      x: 8
      anchors.verticalCenter: parent.verticalCenter
      spacing: 4

      ClockWidget {
        id: clockWidget
      }

      Separator {
        Layout.alignment: Qt.AlignVCenter
      }

      TimerWidget {
        id: timerWidget
        Layout.alignment: Qt.AlignVCenter
      }

      Separator {
        Layout.alignment: Qt.AlignVCenter
      }

      GenshinWidget {
        id: genshinWidget
        Layout.alignment: Qt.AlignVCenter
        resinText: genshinMonitor.resinText
        resinClass: genshinMonitor.resinClass
      }
    }
  }

  // Права пігулка — розкладка клавіатури, аудіо, сповіщення
  Pill {
    id: rightPill
    anchors {
      right: parent.right
      rightMargin: 8
      verticalCenter: parent.verticalCenter
    }
    height: pillHeight
    radius: pillHeight / 8
    width: rightRow.implicitWidth + 16

    RowLayout {
      id: rightRow
      x: 8
      anchors.verticalCenter: parent.verticalCenter
      spacing: 4

      KeyboardLayout {
        id: kbLayout
        Layout.alignment: Qt.AlignVCenter
      }

      Separator {
        Layout.alignment: Qt.AlignVCenter
      }

      Audio {
        id: audioWidget
        Layout.fillHeight: true
      }

      Separator {
        Layout.alignment: Qt.AlignVCenter
      }


      ControlWidget {
        id: controlWidget
        Layout.alignment: Qt.AlignVCenter
        unread: controlPopup.unread
      }
    }
  }

  // Календар
  CalendarPopup {
    id: calendarPopup
    window: root
    anchorItem: clockWidget
    visible: false
  }

  // Мікшер аудіо
  AudioMixerPopup {
    id: audioPopup
    window: root
    anchorItem: audioWidget
    visible: false
  }

  // Керування Bluetooth
  BtManager {
    id: btPopup
    window: root
    visible: false
  }

  // Керування мережами
  NetManager {
    id: netPopup
    window: root
    visible: false
  }

  // Сервер сповіщень — ловить системні сповіщення
  NotificationServer {
    id: notifServer
    actionsSupported: true
    bodySupported: true

    onNotification: (notif) => {
      notif.tracked = true
      notifToast.showNotif(notif)
    }
  }

  // Монітор аудіо-візуалізації (cava)
  CavaMonitor {
    id: cavaMonitor
  }

  // Монітор Genshin Impact
  GenshinMonitor {
    id: genshinMonitor
  }

  // Попап медіаплеєра
  MprisPopup {
    id: mprisPopup
    window: root
    anchorItem: mprisWidget
    visible: false
    cavBars: cavaMonitor.bars
  }

  // Попап Genshin
  GenshinPopup {
    id: genshinPopup
    window: root
    anchorItem: genshinWidget
    visible: false
    resinText: genshinMonitor.resinText
    resinClass: genshinMonitor.resinClass
    details: genshinMonitor.tooltip
    refreshStatus: genshinMonitor.refreshStatus
    refreshMessage: genshinMonitor.refreshMessage
  }

  // Центр керування (сповіщення, швидкі дії)
  ControlManager {
    id: controlPopup
    window: root
    anchorItem: controlWidget
    visible: false
    notificationsModel: notifServer.trackedNotifications
  }

  // Вибір шпалер
  WallpaperPopup {
    id: wallpaperPopup
    window: root
    visible: false
  }

  // Спливаюче сповіщення (тост)
  NotifToast {
    id: notifToast
    anchorWindow: root
    visible: false
  }

  // Лаунчер додатків
  LauncherPopup {
    id: launcherPopup
    window: root
    anchorItem: launcherWidget
    visible: false
  }

  // IpcHandler для глобального виклику лаунчера
  IpcHandler {
    target: "launcher"
    function toggle(): void {
      launcherPopup.toggle()
    }
  }

  // Зв'язки: клік на віджеті → відкриває відповідний попап
 Connections { target: launcherWidget; function onClicked() { launcherPopup.toggle() } }
  Connections { target: clockWidget;    function onClicked() { calendarPopup.toggle() } }
  Connections { target: audioWidget;    function onClicked() { audioPopup.toggle() } }
  Connections { target: mprisWidget;    function onClicked() { mprisPopup.toggle() } }
  Connections { target: genshinWidget;  function onClicked() { genshinPopup.toggle() } }
  Connections { target: controlWidget;  function onClicked() { controlPopup.toggle() } }
  Connections { target: controlPopup;   function onOpenWallpaperPopup() { controlPopup.visible = false; wallpaperPopup.toggle() } }
  Connections { target: controlPopup;   function onOpenBtManager() { controlPopup.visible = false; btPopup.toggle() } }
  Connections { target: controlPopup;   function onOpenNetManager() { controlPopup.visible = false; netPopup.toggle() } }
  Connections { target: genshinPopup;   function onRefreshRequested() { genshinMonitor.refreshNow() } }
 }
