// ============================================================
// SettingsPopup.qml — налаштування бару: розділи Bar / Layout /
// Behavior. Кожен розділ — окремий файл у settings/, завантажується
// через Loader (патерн SettingsView з Panacea).
// ============================================================
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../core"

AnimatedPopup {
  id: root

  required property QtObject window
  palette: window.palette

  implicitWidth: 800
  implicitHeight: contentColumn.implicitHeight + 30
  enterScale: 0.75
  slideDistance: 6
  transformOrigin: Item.Center

  property int screenW: window ? window.screen.width : 1920
  property int screenH: window ? window.screen.height : 1080

  // Адаптер config.json (дані) і обгортка (хелпери isSep/addSep/...)
  readonly property var cfg: window.appConfig.cfg
  readonly property var ac: window.appConfig

  // Розділи налаштувань — кожен окремим файлом, сторінка отримує sys = root
  readonly property var sections: [
    { title: "Bar", page: "settings/BarSection.qml" },
    { title: "Layout", page: "settings/LayoutSection.qml" },
    { title: "Behavior", page: "settings/BehaviorSection.qml" }
  ]
  property int section: 0

  Component.onCompleted: { anchor.window = window }

  // Висота попапа залежить від розділу — центруємо заново при кожній зміні
  onImplicitHeightChanged: { if (visible) root.recenter() }
  function recenter() {
    anchor.rect = Qt.rect(
      (screenW - root.implicitWidth) / 2,
      (screenH - root.implicitHeight) / 2,
      root.implicitWidth,
      root.implicitHeight
    )
  }

  onVisibleChanged: {
    if (visible) {
      anchor.edges = PopupAnchor.None
      anchor.gravity = PopupAnchor.None
      root.recenter()
    } else if (sectionLoader.item?.cancelDrag) {
      // Перетягування скасовується без коміту (раніше onVisibleChanged
      // викликав commitDrag, і "закривши" драг все одно переносив/вимикав віджет)
      sectionLoader.item.cancelDrag()
    }
  }

  Item {
    id: coordSpace
    anchors.fill: parent

    ColumnLayout {
      id: contentColumn
      anchors.fill: parent
      anchors.margins: 15
      spacing: 12

      RowLayout {
        Layout.fillWidth: true
        Text {
          text: "\u2699 Settings"
          color: window.palette.fg
          font.family: window.palette.font
          font.pixelSize: 14
          font.bold: true
        }
        Item { Layout.fillWidth: true }
      }

      // Перемикач розділів
      RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Repeater {
          model: root.sections
          delegate: Rectangle {
            id: tabBtn
            required property var modelData
            required property int index
            readonly property bool active: root.section === tabBtn.index

            Layout.preferredWidth: tabText.implicitWidth + 24
            Layout.preferredHeight: 24
            radius: 4
            color: tabBtn.active
                   ? window.palette.accent
                   : (tabMa.containsMouse ? window.palette.bg2 : window.palette.bg1)
            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
              id: tabText
              anchors.centerIn: parent
              text: tabBtn.modelData.title
              color: tabBtn.active ? window.palette.bg0H : window.palette.fg
              font.family: window.palette.font
              font.pixelSize: 9
              font.bold: true
            }

            MouseArea {
              id: tabMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.section = tabBtn.index
            }
          }
        }
        Item { Layout.fillWidth: true }
      }

      // Вміст поточного розділу: setSource з готовим sys, щоб сторінка
      // не будувалась із порожньою прив'язкою до палітри
      Loader {
        id: sectionLoader
        Layout.fillWidth: true

        function reload() {
          setSource(root.sections[root.section].page, { sys: root })
        }
        Component.onCompleted: reload()

        Connections {
          target: root
          function onSectionChanged() { sectionLoader.reload() }
        }
      }
    }
  }
}
