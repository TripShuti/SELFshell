// ============================================================
// GenshinWidget.qml — віджет Genshin Impact на панелі
// ============================================================
import "../Palette.js" as Palette
import QtQuick
import QtQuick.Layouts

// Віджет Genshin на панелі — смола та статус
Item {
  id: root

  signal clicked()

  property string resinText: "\uF737 0/200"
  property string resinClass: "normal"

  // Іконка смоли
  property string resinIconSource: "../assets/resin2.png"

  // Текст без гліфа, якщо є іконка
  readonly property string resinDisplayText: resinIconSource !== ""
    ? resinText.replace(/^\S+\s*/, "")
    : resinText

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

      SequentialAnimation on opacity {
        running: root.resinClass === "critical"
        loops: Animation.Infinite
        NumberAnimation { to: 0.45; duration: 700; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
      }
    }

    // Текст смоли
    Text {
      id: txt
      text: root.resinDisplayText
      color: root.resinClass === "critical" ? Palette.orange : Palette.blue
      font.family: Palette.font
      font.pixelSize: 12
      Layout.alignment: Qt.AlignVCenter

      Behavior on color { ColorAnimation { duration: 220 } }

      // Блимання тексту при critical
      SequentialAnimation on opacity {
        running: root.resinClass === "critical"
        loops: Animation.Infinite
        NumberAnimation { to: 0.45; duration: 700; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
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
