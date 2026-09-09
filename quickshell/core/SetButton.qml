// ============================================================
// quickshell/core/SetButton.qml — кнопка-рядок для сторінок налаштувань
// ============================================================
import QtQuick
import QtQuick.Layouts

Rectangle {
  id: btn

  required property QtObject sys
  property string text: ""
  // задизейблена кнопка: тьмяна, кліки ігноруються (дефолт лишає старі місця без змін)
  property bool disabled: false
  signal clicked()

  Layout.fillWidth: true
  Layout.preferredHeight: 28
  radius: 5
  opacity: btn.disabled ? 0.45 : 1.0
  color: btnArea.pressed && !btn.disabled
       ? Qt.darker(btn.sys.palette.bg2, 1.2)
       : (btnArea.containsMouse && !btn.disabled ? btn.sys.palette.bg2 : btn.sys.palette.bgAlpha)
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
    cursorShape: btn.disabled ? Qt.ArrowCursor : Qt.PointingHandCursor
    onClicked: if (!btn.disabled) btn.clicked()
  }
}
