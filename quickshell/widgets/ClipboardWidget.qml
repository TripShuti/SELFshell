// ============================================================
// ClipboardWidget.qml — кнопка історії буфера обміну на панелі
// ============================================================
import "../core"
import QtQuick


// Кнопка відкриття історії буфера обміну (ClipboardPopup).
// Єдина функція — виклик попапа (клік через HoverItem.clicked,
// з'єднання в Bar.qml -> Connections onClicked -> clipboardPopup.toggle())
HoverItem {
  id: root

  required property QtObject window

  implicitWidth: 28
  implicitHeight: parent?.height ?? 28

  HoverText {
    anchors.centerIn: parent
    text: "\uF0EA"
    palette: window.palette
    normalColor: window.palette.widgetFg
    hoverColor: window.palette.green
    hoverScale: 1.2
    font.pixelSize: 18
  }
}