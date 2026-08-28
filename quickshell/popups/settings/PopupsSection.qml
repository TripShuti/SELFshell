// ============================================================
// settings/PopupsSection.qml — налаштування попапів: фон, градієнт,
// радіуси, бордери, тости/OSD
// ============================================================
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../core"

Item {
  id: root
  required property QtObject sys

  readonly property var cfg: sys.cfg
  readonly property var ac: sys.ac

  // Preview helpers — at root so SetSlider onMoved can see them
  Process { id: toastPreviewProc; command: ["notify-send", "Preview", "Toast preview — drag sliders"] }
  Process { id: osdPreviewProc; command: ["sh", "-c", "qs ipc call osd volume 2>&1 | head"] }
  function _previewToast() { toastPreviewProc.running = true }
  function _previewOsd() { osdPreviewProc.running = true }

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
        onMoved: function(v) { root.cfg.popupBgOpacity = v; root.ac.saveToFile() }
      }
      SetSlider {
        sys: root.sys
        label: "Gradient lighten"; from: 1.0; to: 2.0; step: 0.05; decimals: 2
        sub: "How much lighter the top of the background is than the bottom. 1.0 = flat color, no gradient."
        value: root.cfg.popupBgLighten
        onMoved: function(v) { root.cfg.popupBgLighten = v; root.ac.saveToFile() }
      }
      SetSlider {
        sys: root.sys
        label: "Corner radius"; from: 0; to: 24; step: 1; suffix: "px"
        value: root.cfg.popupRadius
        onMoved: function(v) { root.cfg.popupRadius = v; root.ac.saveToFile() }
      }
      SetSlider {
        sys: root.sys
        label: "Border width"; from: 0; to: 4; step: 1; suffix: "px"
        value: root.cfg.popupBorderWidth
        onMoved: function(v) { root.cfg.popupBorderWidth = v; root.ac.saveToFile() }
      }
    }

    SetCard {
      sys: root.sys
      SetLabel { sys: root.sys; text: "Toast & OSD" }
      SetSlider {
        sys: root.sys
        label: "Toast radius"; from: 0; to: 24; step: 1; suffix: "px"
        value: root.cfg.toastRadius
        onMoved: function(v) { root.cfg.toastRadius = v; root.ac.saveToFile(); root._previewToast() }
      }
      SetSlider {
        sys: root.sys
        label: "Toast gradient"; from: 1.0; to: 2.0; step: 0.05; decimals: 2
        value: root.cfg.toastLighten
        onMoved: function(v) { root.cfg.toastLighten = v; root.ac.saveToFile(); root._previewToast() }
      }
      SetSlider {
        sys: root.sys
        label: "Toast opacity"; from: 0.5; to: 1.0; step: 0.05; decimals: 2
        value: root.cfg.toastBgOpacity
        onMoved: function(v) { root.cfg.toastBgOpacity = v; root.ac.saveToFile(); root._previewToast() }
      }
      SetSlider {
        sys: root.sys
        label: "OSD radius"; from: 0; to: 24; step: 1; suffix: "px"
        value: root.cfg.osdRadius
        onMoved: function(v) { root.cfg.osdRadius = v; root.ac.saveToFile(); root._previewOsd() }
      }
      SetSlider {
        sys: root.sys
        label: "OSD gradient"; from: 1.0; to: 2.0; step: 0.05; decimals: 2
        value: root.cfg.osdLighten
        onMoved: function(v) { root.cfg.osdLighten = v; root.ac.saveToFile(); root._previewOsd() }
      }
      SetSlider {
        sys: root.sys
        label: "OSD opacity"; from: 0.5; to: 1.0; step: 0.05; decimals: 2
        value: root.cfg.osdBgOpacity
        onMoved: function(v) { root.cfg.osdBgOpacity = v; root.ac.saveToFile(); root._previewOsd() }
      }
    }


  }
}
