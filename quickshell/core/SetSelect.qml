// ============================================================
// quickshell/core/SetSelect.qml — сегментний вибір варіантів налаштування
// ============================================================
import QtQuick
import QtQuick.Layouts

// Підпис ліворуч, праворуч — сегменти варіантів. Годиться для
// коротких списків (2–4 значення).
RowLayout {
  id: sel

  required property QtObject sys
  property string label: ""
  // [{ id, text }] — id їде в налаштування, text показується
  property var options: []
  property string value: ""
  signal picked(string id)

  Layout.fillWidth: true
  spacing: 12

  Text {
    Layout.fillWidth: true
    text: sel.label
    color: sel.sys.palette.fg
    elide: Text.ElideRight
    font.family: sel.sys.palette.font
    font.pixelSize: 10
  }

  Rectangle {
    Layout.preferredWidth: segs.implicitWidth + 6
    Layout.preferredHeight: 26
    radius: 5
    color: sel.sys.palette.bg2

    RowLayout {
      id: segs
      anchors.centerIn: parent
      spacing: 2

      Repeater {
        model: sel.options
        Rectangle {
          id: seg
          required property var modelData
          readonly property bool active: sel.value === seg.modelData.id

          Layout.preferredWidth: segText.implicitWidth + 20
          Layout.preferredHeight: 20
          radius: 4
          color: seg.active
                 ? sel.sys.palette.accent
                 : (segMa.containsMouse ? sel.sys.palette.bgAlpha : "transparent")
          Behavior on color { ColorAnimation { duration: sel.sys.ac.anim(120) } }

          Text {
            id: segText
            anchors.centerIn: parent
            text: seg.modelData.text
            color: seg.active ? sel.sys.palette.bg0H : sel.sys.palette.gray
            font.family: sel.sys.palette.font
            font.pixelSize: 10
          }

          MouseArea {
            id: segMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: sel.picked(seg.modelData.id)
          }
        }
      }
    }
  }
}
