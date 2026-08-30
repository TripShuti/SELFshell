// ============================================================
// quickshell/popups/audio/EmptyState.qml — placeholder для порожніх списків
// ============================================================
import QtQuick
import QtQuick.Layouts

Rectangle {
  id: root

  required property QtObject window
  property string text: ""
  property int boxHeight: 60

  Layout.fillWidth: true
  implicitHeight: boxHeight
  radius: 6
  color: window.palette.bgAlpha

  Text {
    anchors.centerIn: parent
    text: root.text
    color: window.palette.gray
    font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(10)
    wrapMode: Text.WordWrap
    horizontalAlignment: Text.AlignHCenter
    width: parent.width - 16
  }
}
