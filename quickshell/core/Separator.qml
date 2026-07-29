// ============================================================
// Separator.qml — вертикальний роздільник між секціями панелі
// ============================================================
import QtQuick

// Вертикальний роздільник між секціями панелі
Item {
  required property QtObject pal

  implicitWidth: 5
  implicitHeight: 16
  width: 5
  height: 16

  // Центральна лінія з градієнтом
  Rectangle {
    anchors.centerIn: parent
    width: 1
    height: parent.height
    gradient: Gradient {
      orientation: Gradient.Vertical
      GradientStop { position: 0.0; color: "#00000000" }
      GradientStop { position: 0.5; color: pal.green }
      GradientStop { position: 1.0; color: "#00000000" }
    }
    opacity: 0.65
  }

  // М'яке світіння з боків лінії
  Rectangle {
    anchors.centerIn: parent
    width: 3
    height: parent.height * 0.7
    radius: 1.5
    color: pal.aqua
    opacity: 0.10
  }
}
