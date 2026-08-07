// ============================================================
// WorkspacesPopup.qml — попап воркспейса: вікна стола,
// навігація, переміщення/закриття вікон
// ============================================================
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "../core"

// Відкривається ПКМ на номері стола в WorkspacesWidget.
// Показує вікна стола: клік — фокус, ◀/▶ — перенести на
// сусідній стіл, ✕ — закрити вікно. В шапці — навігація.
AnimatedPopup {
  id: root

  required property QtObject window
  required property QtObject anchorItem
  palette: window.palette

  // Воркспейс, для якого відкрито попап (задається з Bar.qml)
  property var workspace: null

  popupWindow: window
  anchorTarget: anchorItem

  implicitWidth: 330

  Component.onCompleted: { anchor.window = window }

  onVisibleChanged: {
    if (visible) root.positionUnderAnchor()
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 12
    spacing: 8

    // --- Шапка: назва стола + навігація ---
    RowLayout {
      Layout.fillWidth: true
      spacing: 6

      NavBtn {
        text: "\u25C0"
        onClicked: Hyprland.dispatch("workspace -1")
      }

      Text {
        text: root.workspace ? ("Workspace " + root.workspace.id + (root.workspace.name ? " \u2014 " + root.workspace.name : "")) : "Workspace"
        color: window.palette.fg
        font.family: window.palette.font
        font.pixelSize: 12
        font.bold: true
        elide: Text.ElideRight
        Layout.fillWidth: true
      }

      NavBtn {
        text: "\u25B6"
        onClicked: Hyprland.dispatch("workspace +1")
      }

      NavBtn {
        text: "\u2715"
        onClicked: root.close()
      }
    }

    // --- Список вікон ---
    ColumnLayout {
      Layout.fillWidth: true
      spacing: 2

      Text {
        text: "Windows"
        color: window.palette.gray
        font.family: window.palette.font
        font.pixelSize: 9
        font.bold: true
      }

      Repeater {
        model: root.workspace ? (root.workspace.windows ?? []) : []

        delegate: WindowRow {
          required property var modelData
          win: modelData
          window: root.window
        }
      }

      // Порожній стан
      Text {
        visible: !root.workspace || (root.workspace.windows ?? []).length === 0
        text: "No windows"
        color: window.palette.muted
        font.family: window.palette.font
        font.pixelSize: 10
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
      }
    }
  }

  // Рядок вікна: іконка, назва, дії (перенести/закрити).
  // MouseArea під контентом, щоб кнопки приймали кліки
  component WindowRow: Rectangle {
    id: row

    required property QtObject win
    required property QtObject window

    readonly property color rowColor: rowMouse.containsMouse ? window.palette.bg2 : "transparent"

    Layout.fillWidth: true
    height: 34
    radius: 6
    color: rowColor
    Behavior on color { ColorAnimation { duration: 120 } }

    MouseArea {
      id: rowMouse
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: Hyprland.dispatch("focuswindow address:" + row.win.address)
    }

    RowLayout {
      anchors.fill: parent
      anchors.margins: 6
      spacing: 8

      IconImage {
        Layout.preferredWidth: 18
        Layout.preferredHeight: 18
        source: row.win.icon
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        Text {
          text: row.win.title || row.win.class || "Window"
          color: window.palette.fg
          font.family: window.palette.font
          font.pixelSize: 10
          elide: Text.ElideRight
          Layout.fillWidth: true
        }

        Text {
          text: row.win.class || ""
          color: window.palette.muted
          font.family: window.palette.font
          font.pixelSize: 8
          elide: Text.ElideRight
          visible: text !== ""
          Layout.fillWidth: true
        }
      }

      ActionBtn {
        text: "\u25C0"
        onClicked: Hyprland.dispatch("movetoworkspace -1 address:" + row.win.address)
      }

      ActionBtn {
        text: "\u25B6"
        onClicked: Hyprland.dispatch("movetoworkspace +1 address:" + row.win.address)
      }

      ActionBtn {
        text: "\u2715"
        onClicked: Hyprland.dispatch("closewindow address:" + row.win.address)
      }
    }
  }

  // Компактна кнопка з дією
  component ActionBtn: Rectangle {
    id: btn

    required property string text
    signal clicked()

    implicitWidth: 22
    implicitHeight: 20
    radius: 4
    color: btnMouse.containsMouse ? window.palette.bgAlpha : window.palette.bg2
    Behavior on color { ColorAnimation { duration: 120 } }

    Text {
      anchors.centerIn: parent
      text: btn.text
      color: window.palette.fg
      font.family: window.palette.font
      font.pixelSize: 9
      font.bold: true
    }

    MouseArea {
      id: btnMouse
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true
      onClicked: btn.clicked()
    }
  }

  // Кнопка навігації в шапці
  component NavBtn: ActionBtn {
    implicitWidth: 26
    implicitHeight: 22
  }
}
