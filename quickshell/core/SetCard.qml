// ============================================================
// core/SetCard.qml — картка-секція сторінок налаштувань
// ============================================================
import QtQuick
import QtQuick.Layouts

// Темна плашка зі скругленням, всередині — рядки налаштувань.
// Стиль повторює зони SettingsPopup (bg1 + рамка bg2).
Rectangle {
  id: card

  required property QtObject sys
  default property alias content: inner.data
  property alias spacing: inner.spacing
  property int pad: 12

  Layout.fillWidth: true
  implicitHeight: inner.implicitHeight + card.pad * 2
  radius: 6
  color: card.sys.palette.bg1
  border.width: 1
  border.color: card.sys.palette.bg2

  ColumnLayout {
    id: inner
    anchors.fill: parent
    anchors.margins: card.pad
    spacing: 12
  }
}
