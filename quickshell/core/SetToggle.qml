// ============================================================
// core/SetToggle.qml — рядок налаштувань з тумблером
// ============================================================
import QtQuick
import QtQuick.Layouts

// Підпис ліворуч (з необов'язковим поясненням під ним),
// перемикач праворуч. Перемикач — спільний core/ToggleSwitch.
RowLayout {
  id: row

  property QtObject sys
  property string label: ""
  property string sub: ""
  property bool on: false
  signal toggled(bool value)

  Layout.fillWidth: true
  spacing: 12

  ColumnLayout {
    Layout.fillWidth: true
    spacing: 2

    Text {
      Layout.fillWidth: true
      text: row.label
      color: row.sys.palette.fg
      elide: Text.ElideRight
      font.family: row.sys.palette.font
      font.pixelSize: 9
    }
    Text {
      Layout.fillWidth: true
      visible: row.sub.length > 0
      text: row.sub
      color: row.sys.palette.gray
      wrapMode: Text.WordWrap
      font.family: row.sys.palette.font
      font.pixelSize: 8
    }
  }

  ToggleSwitch {
    Layout.alignment: Qt.AlignVCenter
    palette: row.sys.palette
    checked: row.on
    onToggled: v => row.toggled(v)
  }
}
