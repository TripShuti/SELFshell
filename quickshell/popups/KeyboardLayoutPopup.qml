// ============================================================
// quickshell/popups/KeyboardLayoutPopup.qml — вибір розкладки клавіатури
// ============================================================
import Quickshell
import QtQuick
import QtQuick.Layouts
import "../core"

// Відкривається ПКМ на віджеті розкладки. Показує список розкладок
// з input:kb_layout; клік — перемикання через switchxkblayout.
// Дані бере з KeyboardLayoutState (monitor вимкнено — лише разовий
// refresh при відкритті, живого сокета попапу не треба).
AnimatedPopup {
  id: root

  required property QtObject window
  required property QtObject anchorItem
  palette: window.palette
  appConfig: window.appConfig

  popupWindow: window
  anchorTarget: anchorItem

  implicitWidth: 170

  KeyboardLayoutState {
    id: kbState
    monitor: false
  }

  Component.onCompleted: { anchor.window = window }

  onVisibleChanged: {
    if (visible) {
      root.positionUnderAnchor()
      kbState.refreshMenu()
    }
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 10
    spacing: 4

    Text {
      text: "Keyboard Layout"
      color: window.palette.gray
      font.family: window.palette.font
      font.pixelSize: appConfig.scaled(9)
      font.bold: true
    }

    Repeater {
      model: kbState.layoutsModel

      delegate: Rectangle {
        required property var modelData
        required property int index
        readonly property bool isActive: modelData.active

        Layout.fillWidth: true
        height: 26
        radius: 5
        color: rowArea.containsMouse ? window.palette.bg2 : "transparent"
        Behavior on color { ColorAnimation { duration: appConfig.anim(120) } }

        Text {
          anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
          text: modelData.label
          color: isActive ? window.palette.green : window.palette.fg
          font.family: window.palette.font
          font.pixelSize: appConfig.scaled(11)
          font.bold: isActive
        }

        Rectangle {
          // Fade замість visible: плавна поява точки активної розкладки
          opacity: isActive ? 1 : 0
          scale: isActive ? 1 : 0.4
          anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
          width: 6
          height: 6
          radius: 3
          color: window.palette.green
          Behavior on opacity { NumberAnimation { duration: appConfig.anim(150); easing.type: Easing.OutCubic } }
          Behavior on scale {
            NumberAnimation { duration: appConfig.anim(150); easing.type: Easing.OutBack; easing.overshoot: 1.5 }
          }
        }

        MouseArea {
          id: rowArea
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          hoverEnabled: true
          onClicked: {
            kbState.switchTo(index)
            root.close()
          }
        }
      }
    }

    // Порожній стан — не вдалось отримати список розкладок
    Text {
      visible: kbState.menuReady && kbState.layoutsModel.length === 0
      text: "No layouts"
      color: window.palette.muted
      font.family: window.palette.font
      font.pixelSize: appConfig.scaled(10)
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignHCenter
    }
  }
}
