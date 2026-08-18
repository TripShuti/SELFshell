// ============================================================
// widgets/TrayWidget.qml — віджет системного трею на панелі
// ============================================================
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray

// Віджет системного трею на панелі — іконки додатків.
// Меню не рендериться тут: віджет лише сигналить menuRequested,
// а показом займається TrayMenuPopup (QML-рендер через QsMenuOpener).
Item {
  id: root

  required property QtObject window

  implicitWidth: trayRow.implicitWidth
  implicitHeight: parent?.height ?? 36

  // Запит на відкриття меню апки (menu — QsMenuHandle, anchor — іконка, під
  // якою позиціонується попап). Обробляється в Bar.qml через Connections.
  signal menuRequested(var menu, var anchor)

  RowLayout {
    id: trayRow
    anchors.verticalCenter: parent.verticalCenter
    spacing: 6

    Repeater {
      model: SystemTray.items
      delegate: Item {
        // Hover індивідуальний для кожної іконки — не спільний на весь віджет
        width: 20
        height: 20

        // Відкриває меню апки через сигнал (guard: не всі апки мають меню)
        function openMenu() {
          if (!modelData.hasMenu) return
          root.menuRequested(modelData.menu, ma)
        }

        Image {
          anchors.centerIn: parent
          source: modelData.icon
          sourceSize: Qt.size(16, 16)
          scale: ma.containsMouse ? 1.15 : 1.0

          Behavior on scale { NumberAnimation { duration: window.appConfig.anim(120); easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
        }

        MouseArea {
          id: ma
          anchors.fill: parent
          hoverEnabled: true
          acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
          onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
              // onlyMenu (ItemIsMenu, e.g. Steam): ЛКМ не активація, а меню
              if (modelData.onlyMenu) openMenu()
              else modelData.activate()
            }
            else if (mouse.button === Qt.RightButton) openMenu()
            else if (mouse.button === Qt.MiddleButton) modelData.secondaryActivate()
          }
        }
      }
    }
  }
}
