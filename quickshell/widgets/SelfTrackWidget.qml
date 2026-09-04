// ============================================================
// quickshell/widgets/SelfTrackWidget.qml — віджет трекера часу на панелі
// ============================================================
import "../core"
import QtQuick
import QtQuick.Layouts

// Віджет трекера на панелі — активний час сьогодні, клік відкриває попап
Item {
  id: root

  required property QtObject window
  signal clicked()

  property string todayText: ""
  property bool hovered: false

  implicitWidth: layout.implicitWidth
  implicitHeight: parent?.height ?? 36

  RowLayout {
    id: layout
    anchors.verticalCenter: parent.verticalCenter
    spacing: 4

    Text {
      text: "󰥔"
      color: root.hovered ? window.palette.green : window.palette.blue
      font.family: window.palette.font
      font.pixelSize: window.appConfig.scaled(14)
      Layout.alignment: Qt.AlignVCenter
      Behavior on color { ColorAnimation { duration: window.appConfig.anim(220) } }
    }

    Text {
      text: root.todayText === "" ? "—" : root.todayText
      color: root.hovered ? window.palette.green : window.palette.widgetFg
      font.family: window.palette.font
      font.pixelSize: window.appConfig.scaled(14)
      Layout.alignment: Qt.AlignVCenter
      scale: root.hovered ? 1.08 : 1.0
      Behavior on color { ColorAnimation { duration: window.appConfig.anim(220) } }
      Behavior on scale {
        NumberAnimation { duration: window.appConfig.anim(120); easing.type: Easing.OutBack; easing.overshoot: 2.5 }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton
    hoverEnabled: true
    onEntered: root.hovered = true
    onExited: root.hovered = false
    onClicked: root.clicked()
  }
}
