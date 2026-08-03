// ============================================================
// GenshinWidget.qml — віджет Genshin Impact на панелі
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

  // Іконка смоли
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

    // Іконка смоли (блимає якщо critical)
    Image {
      source: root.resinIconSource
      visible: root.resinIconSource !== ""
      Layout.preferredWidth: 18
      Layout.preferredHeight: 18
      smooth: true
      mipmap: true
      fillMode: Image.PreserveAspectFit
      Layout.alignment: Qt.AlignVCenter

      BlinkAnimation {
        running: root.resinClass === "critical"
        minOpacity: 0.45
        blinkDuration: 700
      }
    }

    // Текст смоли
    Text {
      id: txt
      text: root.resinDisplayText
      color: root.resinClass === "critical" ? window.palette.orange : window.palette.blue
      font.family: window.palette.font
      font.pixelSize: 12
      Layout.alignment: Qt.AlignVCenter

      Behavior on color { ColorAnimation { duration: 220 } }

      // Блимання тексту при critical
      BlinkAnimation {
        running: root.resinClass === "critical"
        minOpacity: 0.45
        blinkDuration: 700
      }

      onVisibleChanged: if (!visible) opacity = 1.0
    }
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: mouse => {
      if (mouse.button === Qt.LeftButton)
        root.clicked()
    }
  }
}
