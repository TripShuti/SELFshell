// ============================================================
// LauncherWidget.qml — кнопка лаунчера на панелі
// ============================================================
import "../Palette.js" as Palette
import QtQuick


// Кнопка відкриття лаунчера на панелі — іконка з анімацією при наведенні
Item {
  id: root

  property bool hovered: false

  signal clicked()

  implicitWidth: 28
  implicitHeight: parent?.height ?? 28

  // Іконка лаунчера (гліф) — збільшується та підсвічується при ховері
  Text {
    anchors.centerIn: parent
    text: "\uDB82\uDCC7"
    color: root.hovered ? Palette.green : Palette.widgetFg
    font.family: Palette.font; font.pixelSize: 18
    scale: root.hovered ? 1.2 : 1.0

    Behavior on color { ColorAnimation { duration: 220 } }
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
  }

  // Область кліку з відстеженням наведення
  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onEntered: root.hovered = true
    onExited: root.hovered = false
    onClicked: root.clicked()
  }
}
