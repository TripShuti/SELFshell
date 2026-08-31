// ============================================================
// quickshell/widgets/GenshinWidget.qml — віджет Genshin Impact на панелі
// ============================================================
import "../core"
import QtQuick
import QtQuick.Layouts

// Віджет Genshin на панелі — смола та статус
Item {
  id: root

  required property QtObject window
  signal clicked()

  property string resinText: "\uF737 0/200"
  property string resinClass: "normal"

  // Hover-стан для фідбеку (HoverText-рецепт: колір + масштаб)
  property bool hovered: false

  property string resinIconSource: "../assets/resin2.png"

  // Текст без гліфа, якщо є іконка
  readonly property string resinDisplayText: resinIconSource !== ""
  ? resinText.replace(/^\S+\s*/, "").trim()
  : resinText.trim()

  implicitWidth: layout.implicitWidth
  implicitHeight: parent?.height ?? 36

  RowLayout {
    id: layout
    anchors.verticalCenter: parent.verticalCenter
    spacing: 4

    Image {
      source: root.resinIconSource
      visible: root.resinIconSource !== ""
      Layout.preferredWidth: 18
      Layout.preferredHeight: 18
      smooth: true
      mipmap: true
      fillMode: Image.PreserveAspectFit
      Layout.alignment: Qt.AlignVCenter
      // як у txt: без цього іконка застигала напівпрозорою, якщо critical
      // скінчився поки віджет був прихований
      onVisibleChanged: if (!visible) opacity = 1.0

      BlinkAnimation {
        running: root.resinClass === "critical"
        minOpacity: 0.45
        blinkDuration: 700
        appConfig: window.appConfig
      }
    }

    Text {
      id: txt
      text: root.resinDisplayText
      color: root.resinClass === "critical" ? window.palette.orange
           : root.hovered ? window.palette.green
           : window.palette.blue
      font.family: window.palette.font
      font.pixelSize: window.appConfig.scaled(14)
      Layout.alignment: Qt.AlignVCenter
      scale: root.hovered ? 1.08 : 1.0

      Behavior on color { ColorAnimation { duration: window.appConfig.anim(220) } }
      Behavior on scale {
        NumberAnimation { duration: window.appConfig.anim(120); easing.type: Easing.OutBack; easing.overshoot: 2.5 }
      }

      // Блимання тексту при critical
      BlinkAnimation {
        running: root.resinClass === "critical"
        minOpacity: 0.45
        blinkDuration: 700
        appConfig: window.appConfig
      }

      onVisibleChanged: if (!visible) opacity = 1.0
    }
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    hoverEnabled: true
    onEntered: root.hovered = true
    onExited: root.hovered = false
    onClicked: mouse => {
      if (mouse.button === Qt.LeftButton)
        root.clicked()
    }
  }
}
