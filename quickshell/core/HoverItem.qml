// ============================================================
// core/HoverItem.qml — контейнер з вбудованим MouseArea для hover/click
// ============================================================
import QtQuick

Item {
  id: root
  default property alias content: inner.data
  signal clicked()
  readonly property alias hovered: ma.containsMouse

  MouseArea {
    id: ma
    anchors.fill: parent
    hoverEnabled: true
    onClicked: root.clicked()
  }
  Item {
    id: inner
    anchors.fill: parent
    readonly property alias hovered: root.hovered
  }
}