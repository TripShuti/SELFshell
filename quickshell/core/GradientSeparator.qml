// ============================================================
// core/GradientSeparator.qml — горизонтальний градієнтний
// роздільник для попапів
// ============================================================
import QtQuick
import QtQuick.Layouts

// Горизонтальний роздільник: суцільний по центру, прозорий по краях.
// Замінює ~12 ідентичних Rectangle-блоків у попапах.
Rectangle {
  id: root

  required property color midColor

  Layout.fillWidth: true
  height: 1
  antialiasing: true

  gradient: Gradient {
    orientation: Gradient.Horizontal
    GradientStop { position: 0.0; color: "transparent" }
    GradientStop { position: 0.5; color: root.midColor }
    GradientStop { position: 1.0; color: "transparent" }
  }
}
