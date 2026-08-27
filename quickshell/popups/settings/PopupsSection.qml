// ============================================================
// settings/PopupsSection.qml — налаштування попапів: фон, градієнт,
// радіуси, бордери, тости/OSD
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
      SetLabel { sys: root.sys; text: "Popups" }
      SetSlider {
        sys: root.sys
        label: "Background opacity"; from: 0.5; to: 1.0; step: 0.05; decimals: 2
        value: root.cfg.popupBgOpacity
        onMoved: v => { root.cfg.popupBgOpacity = v; root.ac.saveToFile() }
      }
      SetSlider {
        sys: root.sys
        label: "Gradient lighten"; from: 1.0; to: 2.0; step: 0.05; decimals: 2
        sub: "How much lighter the top of the background is than the bottom. 1.0 = flat color, no gradient."
        value: root.cfg.popupBgLighten
        onMoved: v => { root.cfg.popupBgLighten = v; root.ac.saveToFile() }
      }
      SetSlider {
        sys: root.sys
        label: "Corner radius"; from: 0; to: 24; step: 1; suffix: "px"
        value: root.cfg.popupRadius
        onMoved: v => { root.cfg.popupRadius = v; root.ac.saveToFile() }
      }
      SetSlider {
        sys: root.sys
        label: "Border width"; from: 0; to: 4; step: 1; suffix: "px"
        value: root.cfg.popupBorderWidth
        onMoved: v => { root.cfg.popupBorderWidth = v; root.ac.saveToFile() }
      }
      SetSlider {
        sys: root.sys
        label: "Glow"; from: 0; to: 0.4; step: 0.01; decimals: 2
        sub: "Soft outer glow around the popup. 0 = no glow."
        value: root.cfg.popupGlowOpacity
        onMoved: v => { root.cfg.popupGlowOpacity = v; root.ac.saveToFile() }
      }
    }

    SetCard {
      sys: root.sys
      SetLabel { sys: root.sys; text: "Toast & OSD" }
      SetSlider {
        sys: root.sys
        label: "Toast radius"; from: 0; to: 24; step: 1; suffix: "px"
        value: root.cfg.toastRadius
        onMoved: v => { root.cfg.toastRadius = v; root.ac.saveToFile() }
      }
      SetSlider {
        sys: root.sys
        label: "Toast gradient"; from: 1.0; to: 2.0; step: 0.05; decimals: 2
        value: root.cfg.toastLighten
        onMoved: v => { root.cfg.toastLighten = v; root.ac.saveToFile() }
      }
      SetSlider {
        sys: root.sys
        label: "Toast glow"; from: 0; to: 0.5; step: 0.01; decimals: 2
        value: root.cfg.toastGlowOpacity
        onMoved: v => { root.cfg.toastGlowOpacity = v; root.ac.saveToFile() }
      }
      SetSlider {
        sys: root.sys
        label: "OSD radius"; from: 0; to: 24; step: 1; suffix: "px"
        value: root.cfg.osdRadius
        onMoved: v => { root.cfg.osdRadius = v; root.ac.saveToFile() }
      }
      SetSlider {
        sys: root.sys
        label: "OSD gradient"; from: 1.0; to: 2.0; step: 0.05; decimals: 2
        value: root.cfg.osdLighten
        onMoved: v => { root.cfg.osdLighten = v; root.ac.saveToFile() }
      }
    }
  }
}
