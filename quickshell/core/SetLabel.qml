// ============================================================
// core/SetLabel.qml — заголовок групи всередині картки налаштувань
// ============================================================
import QtQuick
import QtQuick.Layouts

Text {
  property QtObject sys

  color: sys.palette.gray
  font.family: sys.palette.font
  font.pixelSize: 9
  font.bold: true
  Layout.fillWidth: true
}
