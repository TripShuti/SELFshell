// sddm/ActionButton.qml — кнопка екрана входу (власний стиль:
// напівпрозорі оверлеї наведення/натискання поверх основного кольору)
import QtQuick 2.15
import "colors.js" as Palette

Rectangle {
  id: root
  width: 120
  height: 46
  radius: 10
  color: background

  property string background: Palette.Colors["accent"]
  property string foreground: Palette.Colors["bg0H"]
  property int fontSize: 15
  property bool bold: false
  signal clicked()

  Rectangle {
    anchors.fill: parent
    radius: parent.radius
    color: pressed ? Palette.Colors["pressOverlay"]
                   : (hovered ? Palette.Colors["hoverOverlay"] : "transparent")
    Behavior on color { ColorAnimation { duration: 100 } }
    visible: hovered || pressed

    property bool hovered: mouseArea.containsMouse
    property bool pressed: mouseArea.pressed
  }

  Text {
    anchors.centerIn: parent
    text: root.text
    color: root.foreground
    font.family: Palette.Colors["font"]
    font.pixelSize: root.fontSize
    font.bold: root.bold
    font.letterSpacing: 1
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }

  Keys.onReturnPressed: root.clicked()
  Keys.onEnterPressed: root.clicked()
  Keys.onSpacePressed: root.clicked()
}
