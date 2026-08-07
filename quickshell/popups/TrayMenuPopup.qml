// ============================================================
// popups/TrayMenuPopup.qml — QML-рендер меню системного трею
// ============================================================
import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../core"

// Меню апки з трею рендериться в QML (підхід Caelestia): DBusMenu
// читається через QsMenuOpener, пункти — звичайні QML-рядки.
// Підменю — навігація через StackView. Не потребує QApplication.
AnimatedPopup {
  id: root

  required property QtObject anchorItem
  required property QtObject window
  palette: window.palette

  // QsMenuHandle меню апки (SystemTrayItem.menu)
  property var menu: null

  popupWindow: window
  anchorTarget: anchorItem

  implicitWidth: 220
  implicitHeight: stack.implicitHeight

  Component.onCompleted: {
    anchor.window = window
  }

  onVisibleChanged: {
    if (visible) root.positionUnderAnchor()
  }

  // Зміна меню (клік на іншу іконку) — скидає навігацію до кореня
  onMenuChanged: stack.showMenu(root.menu)

  // --- Навігація підменю ---
  StackView {
    id: stack
    anchors.fill: parent
    implicitWidth: currentItem?.implicitWidth ?? 0
    implicitHeight: currentItem?.implicitHeight ?? 0
    pushEnter: NoAnim {}
    pushExit: NoAnim {}
    popEnter: NoAnim {}
    popExit: NoAnim {}

    // Показує кореневе меню заданого хендла
    function showMenu(handle) {
      if (!handle) return
      stack.clear()
      stack.push(subMenuComp.createObject(null, { handle: handle }))
    }
  }

  // Шаблон сторінки меню (створюється через createObject для підменю)
  Component {
    id: subMenuComp
    SubMenu {}
  }

  component NoAnim: Transition {
    NumberAnimation { duration: 0 }
  }

  // Сторінка меню: QsMenuOpener віддає пункти DBusMenu, Repeater рендерить.
  // handle — кореневий QsMenuHandle, для підменю — сам QsMenuEntry.
  component SubMenu: Column {
    id: menu

    required property QsMenuHandle handle
    property bool isSubMenu: false
    property bool shown: false

    width: parent.width
    padding: 4
    spacing: 2

    opacity: shown ? 1 : 0
    scale: shown ? 1 : 0.8

    Component.onCompleted: shown = true
    StackView.onActivating: shown = true
    StackView.onDeactivating: shown = false

    Behavior on opacity { NumberAnimation { duration: 100 } }
    Behavior on scale { NumberAnimation { duration: 100 } }

    QsMenuOpener {
      id: opener
      menu: menu.handle
    }

    // Пункти меню (QsMenuEntry)
    Repeater {
      model: opener.children

      delegate: Item {
        required property QsMenuEntry modelData

        width: menu.width
        implicitHeight: modelData.isSeparator ? 7 : 28

        // Роздільник
        Rectangle {
          visible: modelData.isSeparator
          anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
          anchors.leftMargin: 10; anchors.rightMargin: 10
          height: 1
          color: window.palette.bg2
          opacity: 0.8
        }

        // Рядок пункту
        Rectangle {
          visible: !modelData.isSeparator
          anchors.fill: parent
          anchors.margins: 2
          radius: 6
          color: ma.containsMouse ? window.palette.bg2 : "transparent"
          opacity: modelData.enabled ? 1.0 : 0.45

          Behavior on color { ColorAnimation { duration: 120 } }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 8

            IconImage {
              Layout.preferredWidth: 15
              Layout.preferredHeight: 15
              visible: modelData.icon !== ""
              source: modelData.icon !== "" ? Quickshell.iconPath(modelData.icon, true) : ""
            }

            Text {
              Layout.fillWidth: true
              text: modelData.text
              color: window.palette.fg
              font.family: window.palette.font; font.pixelSize: 12
              elide: Text.ElideRight
            }

            // Чекбокс/радіо-позначка (Mute тощо)
            Text {
              visible: modelData.buttonType !== QsMenuButtonType.None && modelData.checkState === Qt.Checked
              text: modelData.buttonType === QsMenuButtonType.RadioButton ? "\uF111" : "\uF00C"
              color: window.palette.mutedAlt
              font.family: window.palette.font; font.pixelSize: 10
            }

            // Стрілка наявності підменю
            Text {
              visible: modelData.hasChildren
              text: "\uF078"
              color: window.palette.mutedAlt
              font.family: window.palette.font; font.pixelSize: 10
            }
          }

          MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
              if (!modelData.enabled) return
              if (modelData.hasChildren) {
                // QsMenuEntry сам є QsMenuHandle — підменю рендериться з нього
                stack.push(subMenuComp.createObject(null, {
                  handle: modelData,
                  isSubMenu: true
                }))
              } else {
                modelData.triggered()
                root.close()
              }
            }
          }
        }
      }
    }

    // Кнопка "назад" — тільки в підменю
    Loader {
      id: backLoader
      active: menu.isSubMenu
      visible: active
      width: parent.width
      height: 30

      sourceComponent: Item {
        width: backLoader.width
        implicitHeight: 30
        height: 30

        Rectangle {
          anchors.fill: parent
          anchors.margins: 2
          radius: 6
          color: backMa.containsMouse ? window.palette.bg2 : "transparent"

          Behavior on color { ColorAnimation { duration: 120 } }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            spacing: 6

            Text {
              text: "\uF075"
              color: window.palette.mutedAlt
              font.family: window.palette.font; font.pixelSize: 10
            }

            Text {
              text: "Back"
              color: window.palette.fg
              font.family: window.palette.font; font.pixelSize: 12
            }
          }

          MouseArea {
            id: backMa
            anchors.fill: parent
            hoverEnabled: true
            onClicked: stack.pop()
          }
        }
      }
    }
  }
}
