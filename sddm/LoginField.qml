// sddm/LoginField.qml — поле вводу екрана входу (власний стиль:
// закруглення, прозорий фон, акцентна рамка фокусу)
import QtQuick 2.15
import "colors.js" as Palette

FocusScope {
  id: root
  implicitHeight: field.height

  property alias text: input.text
  property alias echoMode: input.echoMode
  signal submitted()

  Rectangle {
    id: field
    width: root.width
    height: 46
    radius: 10
    color: input.activeFocus ? Palette.Colors["hoverBg"] : Palette.Colors["bgAlpha"]
    border.color: input.activeFocus ? Palette.Colors["accent"] : Palette.Colors["outlineVariant"]
    border.width: input.activeFocus ? 1.5 : 1

    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: 120 } }

    TextInput {
      id: input
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.leftMargin: 14
      anchors.rightMargin: 14
      anchors.verticalCenter: parent.verticalCenter
      focus: true
      clip: true
      color: Palette.Colors["fg"]
      font.family: Palette.Colors["font"]
      font.pixelSize: 15
      selectionColor: Palette.Colors["accent"]
      selectedTextColor: Palette.Colors["bg0H"]

      Keys.onReturnPressed: root.submitted()
      Keys.onEnterPressed: root.submitted()
    }
  }

  MouseArea {
    anchors.fill: field
    cursorShape: Qt.IBeamCursor
    onClicked: input.forceActiveFocus()
  }
}
