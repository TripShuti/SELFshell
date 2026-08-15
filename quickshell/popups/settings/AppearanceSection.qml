// ============================================================
// settings/AppearanceSection.qml — розділ Appearance: дизайн поза
// автопалітрою — прозорість, градієнти, радіуси, сяйво, масштаб шрифтів
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
    spacing: 12

    // --- Попапи: база AnimatedPopup, тому стосується всіх вікон ---
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

    // --- Тост сповіщень і OSD ---
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

    // --- Бар: пігулки ---
    SetCard {
      sys: root.sys
      SetLabel { sys: root.sys; text: "Bar" }
      SetSlider {
        sys: root.sys
        label: "Pill background opacity"; from: 0.2; to: 1.0; step: 0.05; decimals: 2
        sub: "Multiplies the pill background alpha. 1.0 = palette color as-is, 0.2 = barely visible."
        value: root.cfg.barBgOpacity
        onMoved: v => { root.cfg.barBgOpacity = v; root.ac.saveToFile() }
      }
      SetSlider {
        sys: root.sys
        label: "Pill gradient"; from: 1.0; to: 2.0; step: 0.05; decimals: 2
        sub: "How much lighter the top of the pills is than the bottom. 1.0 = flat color."
        value: root.cfg.barLighten
        onMoved: v => { root.cfg.barLighten = v; root.ac.saveToFile() }
      }
      SetSlider {
        sys: root.sys
        label: "Pill border width"; from: 0; to: 4; step: 1; suffix: "px"
        sub: "Outline around each pill. 0 = no border."
        value: root.cfg.barBorderWidth
        onMoved: v => { root.cfg.barBorderWidth = v; root.ac.saveToFile() }
      }
      SetSlider {
        sys: root.sys
        label: "Pill glow size"; from: 0; to: 24; step: 1; suffix: "px"
        sub: "Colored halo around each pill. 0 = no glow."
        value: root.cfg.barGlowSize
        onMoved: v => { root.cfg.barGlowSize = v; root.ac.saveToFile() }
      }
      // Сяйво без розміру нічого не малює — тьмяніємо, як у Panacea,
      // замість того щоб ховати повзунок і руйнувати розкладку.
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 6
        opacity: root.cfg.barGlowSize > 0 ? 1.0 : 0.4
        Behavior on opacity { NumberAnimation { duration: 120 } }
        SetSlider {
          sys: root.sys
          label: "Pill glow opacity"; from: 0; to: 0.5; step: 0.01; decimals: 2
          value: root.cfg.barGlowOpacity
          onMoved: v => { root.cfg.barGlowOpacity = v; root.ac.saveToFile() }
        }
      }
    }

    // --- Роздільники між віджетами ---
    SetCard {
      sys: root.sys
      SetLabel { sys: root.sys; text: "Separators" }
      SetSlider {
        sys: root.sys
        label: "Line opacity"; from: 0; to: 1.0; step: 0.05; decimals: 2
        sub: "The thin gradient line between widget groups in a pill."
        value: root.cfg.separatorOpacity
        onMoved: v => { root.cfg.separatorOpacity = v; root.ac.saveToFile() }
      }
      SetSlider {
        sys: root.sys
        label: "Glow"; from: 0; to: 0.5; step: 0.01; decimals: 2
        sub: "Soft glow around the separator line. 0 = no glow."
        value: root.cfg.separatorGlowOpacity
        onMoved: v => { root.cfg.separatorGlowOpacity = v; root.ac.saveToFile() }
      }
    }

    // --- Глобальний масштаб шрифтів/гліфів ---
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
  }
}