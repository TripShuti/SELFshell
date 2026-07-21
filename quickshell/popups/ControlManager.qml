// ============================================================
// ControlManager.qml — центр керування: сповіщення, швидкі дії,
// кнопки живлення
// ============================================================
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"
import "../Palette.js" as Palette

// Центр керування — сповіщення, швидкі перемикачі та кнопки живлення
AnimatedPopup {
  id: root

  required property QtObject anchorItem
  required property QtObject window

  implicitWidth: 320
  implicitHeight: 400
  transformOrigin: Item.Top

  property var notificationsModel: null

  readonly property int unread: notificationsModel?.values?.length ?? 0
  readonly property var notifications: notificationsModel

  signal openWallpaperPopup()
  signal openBtManager()
  signal openNetManager()

  // Виконує дію живлення: shutdown, reboot, suspend, logout, lock
  function runPowerAction(action) {
    var cmd = []
    switch (action) {
      case "shutdown": cmd = ["/usr/bin/systemctl", "poweroff"]; break
      case "reboot":   cmd = ["/usr/bin/systemctl", "reboot"]; break
      case "suspend":  cmd = ["/usr/bin/systemctl", "suspend"]; break
      case "logout":   cmd = ["/usr/bin/hyprctl", "dispatch", "exit"]; break
      case "lock":     cmd = ["/usr/bin/hyprlock"]; break
    }
    powerProc.command = cmd
    powerProc.running = true
  }

  Process {
    id: powerProc
    onExited: running = false
  }

  // Закриває всі сповіщення
  function clearAll() {
    var model = root.notificationsModel
    if (!model) return
    var toDismiss = []
    var vals = model.values
    if (!vals) return
    for (var i = 0; i < vals.length; ++i) toDismiss.push(vals[i])
    for (var i = 0; i < toDismiss.length; ++i) if (toDismiss[i]) toDismiss[i].dismiss()
  }

  Component.onCompleted: { anchor.window = window }

  onVisibleChanged: {
    if (visible) {
      var r = window.itemRect(anchorItem)
      anchor.rect = Qt.rect(r.x, r.y + r.height + 4, implicitWidth, implicitHeight)
    }
  }

  // Додаткове тло під контентом
  Rectangle {
    id: bg
    anchors.fill: parent
    radius: 8
    color: Palette.bg0H
    opacity: 0.70
    border.width: 1
    border.color: Palette.bg2
  }

  ColumnLayout {
    id: layout
    anchors.fill: parent
    anchors.margins: 10
    spacing: 8

    // Ряд швидких дій: мережа, Bluetooth, шпалери
    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      // Кнопка мережі
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 24
        radius: 6
        color: netArea.containsMouse ? Palette.bg2 : Palette.bg1
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
          anchors.centerIn: parent
          text: "󰖩"
          color: netArea.containsMouse ? Palette.green : Palette.gray
          Behavior on color { ColorAnimation { duration: 120 } }
          font.family: Palette.font; font.pixelSize: 13
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
        color: btArea.containsMouse ? Palette.bg2 : Palette.bg1
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
          anchors.centerIn: parent
          text: ""
          color: btArea.containsMouse ? Palette.green : Palette.gray
          Behavior on color { ColorAnimation { duration: 120 } }
          font.family: Palette.font; font.pixelSize: 13
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
        color: wallArea.containsMouse ? Palette.bg2 : Palette.bg1
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
          anchors.centerIn: parent
          text: "\uF03E"
          color: wallArea.containsMouse ? Palette.green : Palette.gray
          Behavior on color { ColorAnimation { duration: 120 } }
          font.family: Palette.font; font.pixelSize: 13
        }

        MouseArea {
          id: wallArea
          anchors.fill: parent
          hoverEnabled: true
          onClicked: root.openWallpaperPopup()
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

    // Список сповіщень
    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true

      ListView {
        id: notifList
        anchors.fill: parent
        visible: root.unread > 0
        spacing: 6
        interactive: contentHeight > height
        model: root.notifications

        delegate: Rectangle {
          required property var modelData
          readonly property var notif: modelData
          property bool hovered: false

          width: notifList.width
          height: delLayout.implicitHeight + 12
          radius: 6
          color: hovered ? Palette.bg2 : Palette.bg1
          Behavior on color { ColorAnimation { duration: 120 } }

          HoverHandler { onHoveredChanged: parent.hovered = hovered }

          // Акцентна смужка ліворуч
          Rectangle {
            width: 3
            height: parent.height - 8
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 2
            radius: 2
            color: Palette.yellow
          }

          RowLayout {
            id: delLayout
            x: 14; y: 6
            width: parent.width - 22
            spacing: 8

            // Іконка додатка (або заглушка)
            Rectangle {
              width: 26; height: 26; radius: 13
              color: Palette.bg2
              border.width: 1
              border.color: Palette.gray

              Image {
                anchors.fill: parent
                anchors.margins: 2
                source: notif.appIcon
                fillMode: Image.PreserveAspectFit
                visible: notif.appIcon !== ""
              }

              Text {
                anchors.centerIn: parent
                text: "\uF0A2"
                color: Palette.gray
                font.family: Palette.font; font.pixelSize: 12
                visible: notif.appIcon === ""
              }
            }

            // Назва додатка, заголовок, тіло сповіщення
            ColumnLayout {
              Layout.fillWidth: true
              spacing: 2

              Text {
                text: notif.appName
                color: Palette.green
                font.family: Palette.font; font.pixelSize: 10; font.bold: true
              }

              Text {
                text: notif.summary
                color: Palette.fg
                font.family: Palette.font; font.pixelSize: 11; font.bold: true
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                maximumLineCount: 1
                elide: Text.ElideRight
              }

              Text {
                text: notif.body
                color: Palette.gray
                font.family: Palette.font; font.pixelSize: 10
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                maximumLineCount: 3
                elide: Text.ElideRight
                visible: notif.body !== ""
              }
            }

            // Кнопка закриття сповіщення
            Rectangle {
              implicitWidth: 18; implicitHeight: 18; radius: 9
              color: closeArea.containsMouse ? Palette.red : Palette.bg1
              Behavior on color { ColorAnimation { duration: 120 } }

              Text {
                anchors.centerIn: parent
                text: "\uF00D"
                color: closeArea.containsMouse ? Palette.bg0H : Palette.gray
                Behavior on color { ColorAnimation { duration: 120 } }
                font.family: Palette.font; font.pixelSize: 9
              }

              MouseArea {
                id: closeArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: notif.dismiss()
              }
            }
          }
        }
      }

      // Порожній стан — немає сповіщень
      ColumnLayout {
        anchors.centerIn: parent
        visible: root.unread === 0
        spacing: 4

        Text {
          Layout.alignment: Qt.AlignHCenter
          text: "\uF0F3"
          color: Palette.gray
          font.family: Palette.font; font.pixelSize: 22
        }

        Text {
          Layout.alignment: Qt.AlignHCenter
          text: "No notifications"
          color: Palette.gray
          font.family: Palette.font; font.pixelSize: 12
        }
      }
    }

    // Кнопка "очистити все"
    RowLayout {
      id: clearAreaRow
      Layout.fillWidth: true
      visible: root.unread > 0

      Item { Layout.fillWidth: true }

      Rectangle {
        implicitWidth: 24; implicitHeight: 24; radius: 6
        color: clearArea.containsMouse ? Palette.bg2 : Palette.bg1
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
          anchors.centerIn: parent
          text: "\uF12D"
          color: Palette.gray
          font.family: Palette.font; font.pixelSize: 11
        }

        MouseArea {
          id: clearArea
          anchors.fill: parent
          hoverEnabled: true
          onClicked: root.clearAll()
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

    // Кнопки живлення (Lock, Suspend, Logout, Reboot, Shutdown)
    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      property var actions: [
        { icon: "\uF023", tooltip: "Lock",     action: "lock",     accent: Palette.blue },
        { icon: "\uF186", tooltip: "Suspend",  action: "suspend",  accent: Palette.purple },
        { icon: "\uF2F5", tooltip: "Logout",   action: "logout",   accent: Palette.orange },
        { icon: "\uF021", tooltip: "Reboot",   action: "reboot",   accent: Palette.yellow },
        { icon: "\uF011", tooltip: "Shutdown", action: "shutdown", accent: Palette.red }
      ]

      Repeater {
        model: parent.actions

        delegate: Rectangle {
          required property var modelData
          readonly property var act: modelData
          property bool hovered: false

          Layout.fillWidth: true
          Layout.preferredWidth: 48
          implicitHeight: 36
          radius: 6
          color: hovered ? Palette.bg2 : Palette.bg1
          Behavior on color { ColorAnimation { duration: 150 } }

          Text {
            anchors.centerIn: parent
            text: act.icon
            color: Palette.fg
            font.family: Palette.font; font.pixelSize: 16
            Behavior on color { ColorAnimation { duration: 150 } }
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: parent.hovered = true
            onExited: parent.hovered = false
            onClicked: root.runPowerAction(act.action)
          }

          ToolTip.visible: containsMouseGlobal
          ToolTip.text: act.tooltip
          ToolTip.delay: 400
          property bool containsMouseGlobal: false
        }
      }
    }
  }
}
