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
  appConfig: window.appConfig

  // Воркспейс, для якого відкрито попап (задається з Bar.qml)
  property var workspace: null

  popupWindow: window
  anchorTarget: anchorItem

  implicitWidth: 330
  // Розмір попапа — від контентного ColumnLayout: його implicitHeight
  // рахує рядки списку через явну height у delegate
  implicitHeight: layout.implicitHeight + 24

  Component.onCompleted: { anchor.window = window }

  onVisibleChanged: {
    if (visible) root.positionUnderAnchor()
  }

  // Попап слідкує за фокусом: після ▶/◀ (або зміни стола хоткеєм)
  // назва й список оновлюються до активного стола
  Connections {
    target: Hyprland
    function onFocusedWorkspaceChanged() {
      if (root.visible) root.workspace = Hyprland.focusedWorkspace
    }
  }

  ColumnLayout {
    id: layout
    anchors.fill: parent
    anchors.margins: 12
    spacing: 8

    // --- Шапка: назва стола + навігація ---
    RowLayout {
      Layout.fillWidth: true
      spacing: 6

      NavBtn {
        text: "\u25C0"
        onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = \"-1\" })")
      }

      Text {
        // name може дублювати id ("3" == "3") — показуємо лише відмінну частину
        text: root.workspace
          ? "Workspace " + root.workspace.id
            + ((root.workspace.name && root.workspace.name !== String(root.workspace.id)) ? " \u2014 " + root.workspace.name : "")
          : "Workspace"
        color: window.palette.fg
        font.family: window.palette.font
        font.pixelSize: appConfig.scaled(12)
        font.bold: true
        elide: Text.ElideRight
        Layout.fillWidth: true
      }

      NavBtn {
        text: "\u25B6"
        onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = \"+1\" })")
      }
    }

    // --- Список вікон ---
    // Явний Column (не Layout): його implicitHeight — сума висот
    // дітей (Column враховує властивість height), тож попап
    // отримує правильний розмір після асинхронного наповнення моделі
    Column {
      id: listCol
      Layout.fillWidth: true
      spacing: 2

      Text {
        text: "Windows"
        color: window.palette.gray
        font.family: window.palette.font
        font.pixelSize: appConfig.scaled(9)
        font.bold: true
      }

      Repeater {
        model: root.workspace ? root.workspace.toplevels.values : []

        delegate: WindowRow {
          required property var modelData
          win: modelData
          window: root.window
        }
      }

      // Порожній стан
      Text {
        visible: !root.workspace || root.workspace.toplevels.values.length === 0
        text: "No windows"
        color: window.palette.muted
        font.family: window.palette.font
        font.pixelSize: appConfig.scaled(10)
        width: listCol.width
        horizontalAlignment: Text.AlignHCenter
      }
    }
  }

  // Рядок вікна: іконка, назва, закриття.
  // Клік по рядку — фокус вікна, ✕ — закриття.
  // MouseArea під контентом, щоб кнопка приймала кліки
  component WindowRow: Rectangle {
    id: row

    required property QtObject win
    required property QtObject window

    // Нове IPC-ядро Quickshell не має полів class/icon —
    // лише address/title; решта береться з останнього IPC-об'єкта
    readonly property string winClass: (row.win.lastIpcObject && row.win.lastIpcObject["class"]) || ""
    readonly property string winIcon: (row.win.lastIpcObject && row.win.lastIpcObject["icon"]) || ""
    // Quickshell віддає address без префікса 0x, а lua-диспетчери
    // Hyprland 0.56+ шукають вікно за "address:0x..."
    readonly property string winAddr: (row.win.address.startsWith("0x") ? "" : "0x") + row.win.address

    readonly property color rowColor: rowMouse.containsMouse ? window.palette.bg2 : "transparent"

    width: parent ? parent.width : 0
    height: 34
    radius: 6
    color: rowColor
    Behavior on color { ColorAnimation { duration: appConfig.anim(120) } }

    MouseArea {
      id: rowMouse
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      // Lua-синтаксис Hyprland 0.56+: класичні dispatch-команди
      // оцінюються як lua-вираз в обгортці hl.dispatch(...)
      onClicked: Hyprland.dispatch("hl.dsp.focus({ window = \"address:" + row.winAddr + "\" })")
    }

    RowLayout {
      anchors.fill: parent
      anchors.margins: 6
      spacing: 8

      IconImage {
        Layout.preferredWidth: row.winIcon !== "" ? 18 : 0
        Layout.preferredHeight: row.winIcon !== "" ? 18 : 0
        source: row.winIcon
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        Text {
          text: row.win.title || row.winClass || "Window"
          color: window.palette.fg
          font.family: window.palette.font
          font.pixelSize: appConfig.scaled(10)
          elide: Text.ElideRight
          Layout.fillWidth: true
        }

        Text {
          text: row.winClass || ""
          color: window.palette.muted
          font.family: window.palette.font
          font.pixelSize: appConfig.scaled(8)
          elide: Text.ElideRight
          visible: text !== ""
          Layout.fillWidth: true
        }
      }

      ActionBtn {
        text: "\u2715"
        onClicked: Hyprland.dispatch("hl.dsp.window.close({ window = \"address:" + row.winAddr + "\" })")
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
    Behavior on color { ColorAnimation { duration: appConfig.anim(120) } }

    Text {
      anchors.centerIn: parent
      text: btn.text
      color: window.palette.fg
      font.family: window.palette.font
      font.pixelSize: appConfig.scaled(9)
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
