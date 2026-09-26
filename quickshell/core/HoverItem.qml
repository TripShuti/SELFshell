// ============================================================
// quickshell/core/HoverItem.qml — контейнер з вбудованим MouseArea для hover/click
// ============================================================
import QtQuick

Item {
  id: root
  default property alias content: inner.data
  signal clicked()
  signal rightClicked()
  signal wheel(var event)
  // Курсор лишається стрілкою за замовчуванням (як було у всіх споживачів
  // до міграції); віджети з рукою прокидають Qt.PointingHandCursor явно
  property int cursorShape: Qt.ArrowCursor
  readonly property alias hovered: ma.containsMouse
  readonly property alias pressed: ma.pressed

  MouseArea {
    id: ma
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: root.cursorShape
    hoverEnabled: true
    onClicked: mouse => {
      if (mouse.button === Qt.RightButton) root.rightClicked()
      else root.clicked()
    }
    onWheel: wheel => root.wheel(wheel)
  }
  Item {
    id: inner
    anchors.fill: parent
    readonly property alias hovered: root.hovered
    readonly property alias pressed: root.pressed
  }
}