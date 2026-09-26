// ============================================================
// quickshell/core/HoverButton.qml — прямокутна hover-кнопка з іконкою
// ============================================================
import QtQuick

// Однакова кнопка для попапах (раніше копіпаст Rectangle+Text+MouseArea
// в QuickToggles, KdeConnect/Network/Bluetooth-попапах). Розмір
// (Layout/implicit) задає викликач; кольори/анімації всередині.
Rectangle {
  id: root

  signal clicked()

  // Для динамічних стилів на місці виклику (напр. бордер Accept
  // в паруванні: hovered ? accent : bg2)
  readonly property alias hovered: ma.containsMouse

  property QtObject palette: null
  // Опційно: для глобального множника тривалостей анімацій
  property QtObject appConfig: null
  property string icon: ""
  property real iconSize: 13
  property bool fontBold: false
  property color normalBg: palette?.bg1 ?? "#403b35"
  property color hoverBg: palette?.bg2 ?? "#57514b"
  property color normalFg: palette?.gray ?? "#9b8f80"
  property color hoverFg: palette?.green ?? "#e79c06"
  property int borderWidth: 0
  property color borderColor: "transparent"
  property int cursorShape: Qt.ArrowCursor
  // Ширина контенту — для кнопок-лейблів (implicitWidth: btn.contentWidth + N)
  readonly property real contentWidth: label.implicitWidth

  radius: 6
  color: ma.containsMouse ? root.hoverBg : root.normalBg
  border.width: root.borderWidth
  border.color: root.borderColor
  Behavior on color { ColorAnimation { duration: root.appConfig ? root.appConfig.anim(120) : 120 } }

  Text {
    id: label
    anchors.centerIn: parent
    text: root.icon
    color: ma.containsMouse ? root.hoverFg : root.normalFg
    font.family: root.palette?.font ?? "JetBrainsMonoNL Nerd Font"
    font.pixelSize: root.appConfig ? root.appConfig.scaled(root.iconSize) : root.iconSize
    font.bold: root.fontBold
    Behavior on color { ColorAnimation { duration: root.appConfig ? root.appConfig.anim(120) : 120 } }
  }

  MouseArea {
    id: ma
    anchors.fill: parent
    cursorShape: root.cursorShape
    hoverEnabled: true
    onClicked: root.clicked()
  }
}
