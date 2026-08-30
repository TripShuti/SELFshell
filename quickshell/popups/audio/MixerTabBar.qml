// ============================================================
// quickshell/popups/audio/MixerTabBar.qml — вкладки pavucontrol (5 штук)
// ============================================================
import QtQuick
import QtQuick.Layouts

RowLayout {
  id: root

  required property QtObject window
  required property var tabNames
  property int selectedTab: 0

  signal tabPicked(int index)

  spacing: 2
  Layout.fillWidth: true

  Repeater {
    model: root.tabNames
    delegate: Rectangle {
      required property var modelData
      required property int index
      readonly property bool active: root.selectedTab === index
      property bool hovered: false
      Layout.fillWidth: true
      implicitHeight: 28
      radius: 6
      color: active ? window.palette.green : (hovered ? window.palette.hoverBg : window.palette.bgAlpha)
      Behavior on color { ColorAnimation { duration: window.appConfig.anim(150) } }

      Text {
        anchors.centerIn: parent
        text: modelData
        color: active ? window.palette.baseOverlay : window.palette.fg
        font.family: window.palette.font
        font.pixelSize: window.appConfig.scaled(modelData.length > 14 ? 9 : 10)
        font.bold: active
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        width: parent.width - 8
      }


      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: parent.hovered = true
        onExited: parent.hovered = false
        onClicked: root.tabPicked(index)
      }
    }
  }
}
