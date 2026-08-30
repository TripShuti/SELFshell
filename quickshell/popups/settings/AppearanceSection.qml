// ============================================================
// quickshell/popups/settings/AppearanceSection.qml — глобальні налаштування вигляду: масштаб і анімації (поп-апи/бар/хайпрленд винесені в свої секції)
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
      SetLabel { sys: root.sys; text: "Scale" }
      SetSlider {
        sys: root.sys
        label: "UI scale"; from: 0.8; to: 1.5; step: 0.05; decimals: 2; suffix: "\u00D7"
        sub: "Multiplies all text and icon glyph sizes in the bar, popups and settings. 1.0 = default."
        value: root.cfg.uiScale
        onMoved: v => { root.cfg.uiScale = v; root.ac.saveToFile() }
      }
    }

    SetCard {
      sys: root.sys
      SetLabel { sys: root.sys; text: "Animations" }
      SetToggle {
        sys: root.sys
        label: "Enable animations"
        sub: "Disables all transitions: changes apply instantly."
        on: root.cfg.animationsEnabled
        onToggled: v => { root.cfg.animationsEnabled = v; root.ac.saveToFile() }
      }
      SetSlider {
        sys: root.sys
        label: "Animation speed"; from: 0.5; to: 2.0; step: 0.1; decimals: 1; suffix: "\u00D7"
        sub: "Multiplies every animation duration in the shell. 1.0 = default, 0.5 = twice as fast."
        value: root.cfg.animSpeed
        onMoved: v => { root.cfg.animSpeed = v; root.ac.saveToFile() }
      }
    }
  }
}
