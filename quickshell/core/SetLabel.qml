// ============================================================
// core/SetLabel.qml — заголовок групи всередині картки налаштувань
// ============================================================
import QtQuick
import QtQuick.Layouts

Text {
  required property QtObject sys

  // Uppercase-overline: заголовок структурує картку, не змагаючись
  // з контентом рядків (ті — 10px fg/muted)
  color: sys.palette.muted
  font.family: sys.palette.font
  font.pixelSize: 10
  font.bold: true
  font.letterSpacing: 1.5
  font.capitalization: Font.AllUppercase
  Layout.fillWidth: true
}
