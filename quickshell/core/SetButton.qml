// ============================================================
// quickshell/core/SetButton.qml — кнопка-рядок для сторінок налаштувань
// ============================================================
import QtQuick
import QtQuick.Layouts

Rectangle {
  id: btn

  required property QtObject sys
  property string text: ""
  signal clicked()

  Layout.fillWidth: true
  Layout.preferredHeight: 28
  radius: 5
  color: btnArea.pressed
       ? Qt.darker(btn.sys.palette.bg2, 1.2)
       : (btnArea.containsMouse ? btn.sys.palette.bg2 : btn.sys.palette.bgAlpha)
  border.width: 1
  border.color: btn.sys.palette.bg2
  Behavior on color { ColorAnimation { duration: btn.sys.ac.anim(120) } }

  Text {
    anchors.centerIn: parent
    text: btn.text
    color: btn.sys.palette.fg
    font.family: btn.sys.palette.font
    font.pixelSize: 10
  }

  MouseArea {
    id: btnArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: btn.clicked()
  }
}
