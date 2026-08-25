// ============================================================
// settings/BarSection.qml — розділ Bar: геометрія панелі, позиція,
// автоскривання, видимість пігулок
// ============================================================
import QtQuick
import QtQuick.Layouts
import "../../core"

Item {
  id: root
  required property QtObject sys

  readonly property var cfg: sys.cfg
  readonly property var ac: sys.ac

  implicitWidth: parent?.width ?? 0
  implicitHeight: col.implicitHeight

  ColumnLayout {
    id: col
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    spacing: 16

    SetCard {
      sys: root.sys
      SetLabel { sys: root.sys; text: "Size" }
      SetSlider {
        sys: root.sys
        label: "Bar height"; from: 24; to: 96; step: 1; suffix: "px"
        value: root.cfg.barHeight
        onMoved: v => { root.cfg.barHeight = v; root.ac.saveToFile() }
      }
      SetSlider {
        sys: root.sys
        label: "Pill radius"; from: 0; to: 24; step: 1; suffix: "px"
        value: root.cfg.barRadius
        onMoved: v => { root.cfg.barRadius = v; root.ac.saveToFile() }
      }
      SetSlider {
        sys: root.sys
        label: "Edge margin"; from: 0; to: 32; step: 1; suffix: "px"
        value: root.cfg.edgeMargin
        onMoved: v => { root.cfg.edgeMargin = v; root.ac.saveToFile() }
      }
      SetSlider {
        sys: root.sys
        label: "Pill padding"; from: 2; to: 24; step: 1; suffix: "px"
        value: root.cfg.pillPadding
        onMoved: v => { root.cfg.pillPadding = v; root.ac.saveToFile() }
      }
      SetSlider {
        sys: root.sys
        label: "Content spacing"; from: 0; to: 16; step: 1; suffix: "px"
        value: root.cfg.contentSpacing
        onMoved: v => { root.cfg.contentSpacing = v; root.ac.saveToFile() }
      }
    }

    SetCard {
      sys: root.sys
      SetLabel { sys: root.sys; text: "Position" }
      SetSelect {
        sys: root.sys
        label: "Bar position"
        options: [{ id: "top", text: "Top" }, { id: "bottom", text: "Bottom" }]
        value: root.cfg.barPos
        onPicked: id => { root.cfg.barPos = id; root.ac.saveToFile() }
      }
      SetToggle {
        sys: root.sys
        label: "Auto-hide"
        sub: "The bar slides behind the screen edge and returns on hover of the thin edge strip. While hidden, windows get the full screen."
        on: root.cfg.barAutoHide
        onToggled: v => { root.cfg.barAutoHide = v; root.ac.saveToFile() }
      }
    }

    SetCard {
      sys: root.sys
      SetLabel { sys: root.sys; text: "Pills" }
      SetToggle {
        sys: root.sys
        label: "Left pill"
        sub: "Hide the whole pill. Its widgets stay configured in the Layout section and come back when the pill is shown again."
        on: root.cfg.leftPillEnabled
        onToggled: v => { root.cfg.leftPillEnabled = v; root.ac.saveToFile() }
      }
      SetToggle {
        sys: root.sys
        label: "Center pill"
        sub: "Hide the whole pill. Its widgets stay configured in the Layout section and come back when the pill is shown again."
        on: root.cfg.centerPillEnabled
        onToggled: v => { root.cfg.centerPillEnabled = v; root.ac.saveToFile() }
      }
      SetToggle {
        sys: root.sys
        label: "Right pill"
        sub: "Hide the whole pill. Its widgets stay configured in the Layout section and come back when the pill is shown again."
        on: root.cfg.rightPillEnabled
        onToggled: v => { root.cfg.rightPillEnabled = v; root.ac.saveToFile() }
      }
    }
  }
}
