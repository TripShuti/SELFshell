// ============================================================
// quickshell/core/EmptyHint.qml — центрована підказка порожнього списку
// ============================================================
import QtQuick
import QtQuick.Layouts

// Іконка + текст для порожніх списків (буфер, лаунчер, mpris, сповіщення).
// На відміну від audio/EmptyState (бокс з рамкою) — без фону, центрується
// викликачем (anchors.centerIn або Layout). Умови visible — на місці.
ColumnLayout {
  id: root

  property QtObject palette: null
  // Опційно: для scaled() розмірів
  property QtObject appConfig: null
  property string icon: ""
  property real iconSize: 22
  property string text: ""
  property color color: palette?.mutedAlt ?? "#b4a799"

  spacing: 4

  Text {
    Layout.alignment: Qt.AlignHCenter
    text: root.icon
    color: root.color
    font.family: root.palette?.font ?? "JetBrainsMonoNL Nerd Font"
    font.pixelSize: root.appConfig ? root.appConfig.scaled(root.iconSize) : root.iconSize
  }

  Text {
    Layout.alignment: Qt.AlignHCenter
    text: root.text
    color: root.color
    font.family: root.palette?.font ?? "JetBrainsMonoNL Nerd Font"
    font.pixelSize: root.appConfig ? root.appConfig.scaled(12) : 12
  }
}
