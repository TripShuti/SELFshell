// ============================================================
// quickshell/popups/settings/HyprlandSection.qml — візуальні налаштування Hyprland: вікна (gaps, border, rounding, opacity, shadows) + blur (visual.json + hyprctl reload)
// ============================================================
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../core"

Item {
  id: root
  required property QtObject sys

  readonly property var cfg: sys.cfg
  readonly property var ac: sys.ac
  readonly property var window: sys.window

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
      SetLabel { sys: root.sys; text: "Windows" }

      SetSelect {
        sys: root.sys
        label: "Layout"
        options: [{ id: "dwindle", text: "Dwindle" }, { id: "master", text: "Master" }, { id: "scrolling", text: "Scrolling" }]
        value: root.vis.layout
        onPicked: id => root.setVal("layout", id)
      }
      ColumnLayout {
        visible: root.vis.layout === "master"
        Layout.fillWidth: true
        spacing: 6
        SetSlider {
          sys: root.sys
          label: "Master ratio"; from: 0.3; to: 0.7; step: 0.05; decimals: 2
          sub: "Width fraction of the master column."
          value: root.vis.mfact
          onMoved: v => root.setVal("mfact", v)
        }
        SetSelect {
          sys: root.sys
          label: "Master side"
          options: [
            { id: "left", text: "Left" }, { id: "right", text: "Right" },
            { id: "top", text: "Top" }, { id: "bottom", text: "Bottom" },
            { id: "center", text: "Center" }
          ]
          value: root.vis.orientation
          onPicked: id => root.setVal("orientation", id)
        }
        SetSelect {
          sys: root.sys
          label: "New window goes"
          options: [
            { id: "master", text: "Master" }, { id: "slave", text: "Slave" },
            { id: "inherit", text: "Inherit" }
          ]
          value: root.vis.new_status
          onPicked: id => root.setVal("new_status", id)
        }
        SetToggle {
          sys: root.sys
          label: "Keep master position"
          sub: "Master tile stays in place even when smaller than slaves."
          on: root.vis.always_keep_position
          onToggled: v => root.setVal("always_keep_position", v)
        }
      }
      ColumnLayout {
        visible: root.vis.layout === "scrolling"
        Layout.fillWidth: true
        spacing: 6
        SetSlider {
          sys: root.sys
          label: "Column width"; from: 0.1; to: 1.0; step: 0.05; decimals: 2
          sub: "Default width of a column, as a fraction of the screen."
          value: root.vis.scroll_column_width
          onMoved: v => root.setVal("scroll_column_width", v)
        }
        SetSelect {
          sys: root.sys
          label: "Direction"
          options: [
            { id: "left", text: "Left" }, { id: "right", text: "Right" },
            { id: "up", text: "Up" }, { id: "down", text: "Down" }
          ]
          value: root.vis.scroll_direction
          onPicked: id => root.setVal("scroll_direction", id)
        }
        SetSelect {
          sys: root.sys
          label: "Focus fit"
          options: [
            { id: "center", text: "Center" }, { id: "fit", text: "Fit" }
          ]
          value: root.vis.scroll_focus_fit
          onPicked: id => root.setVal("scroll_focus_fit", id)
        }
        SetToggle {
          sys: root.sys
          label: "Follow focus"
          sub: "Auto-scroll the tape to the focused window."
          on: root.vis.scroll_follow_focus
          onToggled: v => root.setVal("scroll_follow_focus", v)
        }
        SetSlider {
          visible: root.vis.scroll_follow_focus
          sys: root.sys
          label: "Follow min visible"; from: 0; to: 1.0; step: 0.1; decimals: 1
          sub: "Fraction of a window that must stay visible for focus to follow."
          value: root.vis.scroll_follow_min_visible
          onMoved: v => root.setVal("scroll_follow_min_visible", v)
        }
        SetToggle {
          sys: root.sys
          label: "Fullscreen single column"
          sub: "A lone column on a workspace spans the whole screen."
          on: root.vis.scroll_fullscreen_on_one_column
          onToggled: v => root.setVal("scroll_fullscreen_on_one_column", v)
        }
      }
      SetSlider {
        sys: root.sys
        label: "Gaps in"; from: 0; to: 20; step: 1; suffix: "px"
        value: root.vis.gaps_in
        onMoved: v => root.setVal("gaps_in", v)
      }
      SetSlider {
        sys: root.sys
        label: "Gaps out"; from: 0; to: 20; step: 1; suffix: "px"
        sub: "Space between windows and the screen edge."
        value: root.vis.gaps_out
        onMoved: v => root.setVal("gaps_out", v)
      }
      SetSlider {
        sys: root.sys
        label: "Border width"; from: 0; to: 5; step: 1; suffix: "px"
        value: root.vis.border_size
        onMoved: v => root.setVal("border_size", v)
      }
      SetSlider {
        sys: root.sys
        label: "Corner rounding"; from: 0; to: 20; step: 1; suffix: "px"
        value: root.vis.rounding
        onMoved: v => root.setVal("rounding", v)
      }
      SetSlider {
        sys: root.sys
        label: "Active opacity"; from: 0.5; to: 1.0; step: 0.05; decimals: 2
        value: root.vis.active_opacity
        onMoved: v => root.setVal("active_opacity", v)
      }
      SetSlider {
        sys: root.sys
        label: "Inactive opacity"; from: 0.3; to: 1.0; step: 0.05; decimals: 2
        value: root.vis.inactive_opacity
        onMoved: v => root.setVal("inactive_opacity", v)
      }
      SetToggle {
        sys: root.sys
        label: "Dim inactive window"
        on: root.vis.dim_inactive
        onToggled: v => root.setVal("dim_inactive", v)
      }
      SetSlider {
        visible: root.vis.dim_inactive
        sys: root.sys
        label: "Dim strength"; from: 0; to: 1.0; step: 0.05; decimals: 2
        value: root.vis.dim_strength
        onMoved: v => root.setVal("dim_strength", v)
      }
      SetToggle {
        sys: root.sys
        label: "Window shadows"
        on: root.vis.shadows
        onToggled: v => root.setVal("shadows", v)
      }
      SetToggle {
        sys: root.sys
        label: "Resize by border"
        sub: "Drag the window edge to resize (needs border width > 0)."
        on: root.vis.resize_on_border
        onToggled: v => root.setVal("resize_on_border", v)
      }
      SetSlider {
        sys: root.sys
        label: "Cursor idle timeout"; from: 0; to: 60; step: 1; suffix: "s"
        sub: "Hide the cursor after this many seconds idle. 0 = never."
        value: root.vis.inactive_timeout
        onMoved: v => root.setVal("inactive_timeout", v)
      }

      Repeater {
        model: [
          { key: "active_border", label: "Active border color" },
          { key: "inactive_border", label: "Inactive border color" }
        ]
        delegate: ColumnLayout {
          id: colorRow
          required property var modelData
          readonly property string val: root.vis[modelData.key] || ""
          Layout.fillWidth: true
          spacing: 4
          Text {
            text: modelData.label + (colorRow.val === "" ? " (default)" : "")
            color: root.window.palette.fg
            font.family: root.window.palette.font
            font.pixelSize: root.window.appConfig.scaled(10)
          }
          RowLayout {
            spacing: 4
            Layout.fillWidth: true
            Repeater {
              model: ["accent", "green", "blue", "purple", "orange", "aqua", "yellow", "red", "fg"]
              delegate: Rectangle {
                required property string modelData
                readonly property color c: root.window.palette[modelData]
                readonly property bool picked: root.vis[colorRow.modelData.key] === ("rgba(" + c.toString().replace("#", "").toLowerCase() + "ff)")
                width: 16; height: 16; radius: 4
                color: c
                border.width: picked ? 2 : 0
                border.color: root.window.palette.textLight
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.setVal(colorRow.modelData.key, "rgba(" + parent.c.toString().replace("#", "").toLowerCase() + "ff)")
                }
              }
            }
            Rectangle {
              Layout.preferredWidth: 110
              Layout.preferredHeight: 20
              radius: 4
              color: root.window.palette.bg0H
              border.width: hexInput.activeFocus ? 1 : 0
              border.color: root.window.palette.accent
              TextInput {
                id: hexInput
                anchors.fill: parent
                anchors.margins: 4
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                color: root.window.palette.textLight
                font.family: root.window.palette.font
                font.pixelSize: root.window.appConfig.scaled(9)
                text: colorRow.val.startsWith("rgba(") ? "#" + colorRow.val.substring(5, 13) : colorRow.val
                onEditingFinished: {
                  var t = text.trim()
                  if (t === "") { root.setVal(colorRow.modelData.key, ""); return }
                  if (/^#[0-9a-fA-F]{6}$/.test(t)) root.setVal(colorRow.modelData.key, "rgba(" + t.substring(1).toLowerCase() + "ff)")
                }
              }
              MouseArea { anchors.fill: parent; visible: !hexInput.activeFocus; onClicked: hexInput.forceActiveFocus() }
            }
            Item { Layout.fillWidth: true }
            Text {
              text: "\u2715"
              color: clearMa.containsMouse ? root.window.palette.danger : root.window.palette.mutedAlt
              font.pixelSize: root.window.appConfig.scaled(11)
              MouseArea {
                id: clearMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.setVal(colorRow.modelData.key, "")
              }
            }
          }
        }
      }

      Text {
        visible: root.hyprStatus !== ""
        text: root.hyprStatus
        color: root.hyprStatus === "Applied" ? root.window.palette.green : root.window.palette.muted
        font.family: root.window.palette.font
        font.pixelSize: root.window.appConfig.scaled(10)
        Layout.fillWidth: true
      }

      SetButton {
        sys: root.sys
        text: "Reset Hyprland visuals to defaults"
        onClicked: root.resetHypr()
      }
    }

    SetCard {
      sys: root.sys
      SetLabel { sys: root.sys; text: "Blur" }
      SetToggle {
        sys: root.sys
        label: "Blur enabled"
        sub: "Global Hyprland blur. Disabling restores performance."
        on: root.vis.blur_enabled
        onToggled: v => root.setVal("blur_enabled", v)
      }
      SetSlider {
        sys: root.sys
        label: "Blur size"; from: 1; to: 12; step: 1; suffix: "px"
        value: root.vis.blur_size
        onMoved: v => root.setVal("blur_size", v)
      }
      SetSlider {
        sys: root.sys
        label: "Passes"; from: 1; to: 6; step: 1
        value: root.vis.blur_passes
        onMoved: v => root.setVal("blur_passes", v)
      }
      SetSlider {
        sys: root.sys
        label: "Vibrancy"; from: 0; to: 1.0; step: 0.05; decimals: 2
        value: root.vis.blur_vibrancy
        onMoved: v => root.setVal("blur_vibrancy", v)
      }
      SetSlider {
        sys: root.sys
        label: "Vibrancy darkness"; from: 0; to: 1.0; step: 0.05; decimals: 2
        value: root.vis.blur_vibrancy_darkness
        onMoved: v => root.setVal("blur_vibrancy_darkness", v)
      }
      SetToggle {
        sys: root.sys
        label: "Xray (decoration)"
        sub: "Blur behind windows, not only wallpaper. Needed for xray layers as well."
        on: root.vis.blur_xray
        onToggled: v => root.setVal("blur_xray", v)
      }
      SetToggle {
        sys: root.sys
        label: "Ignore opacity"
        sub: "If true, semi-transparent windows are treated as opaque for blur."
        on: root.vis.blur_ignore_opacity
        onToggled: v => root.setVal("blur_ignore_opacity", v)
      }
      SetToggle {
        sys: root.sys
        label: "Blur popups (decorations)"
        sub: "Also blur behind xdg-popups from apps."
        on: root.vis.blur_popups
        onToggled: v => root.setVal("blur_popups", v)
      }
      SetSlider {
        sys: root.sys
        label: "Popups ignore alpha (decoration)"; from: 0; to: 1.0; step: 0.05; decimals: 2
        visible: root.vis.blur_popups
        value: root.vis.blur_popups_ignorealpha
        onMoved: v => root.setVal("blur_popups_ignorealpha", v)
      }
      SetSlider {
        sys: root.sys
        label: "Layer blur ignore alpha (bar)"; from: 0; to: 1.0; step: 0.05; decimals: 2
        sub: "Threshold for bar layer. Lower = more of the bar is considered for blur. Must be < barBgOpacity."
        value: root.vis.layer_ignore_alpha
        onMoved: v => root.setVal("layer_ignore_alpha", v)
      }
      SetSlider {
        sys: root.sys
        label: "Layer blur popups ignore alpha"; from: 0; to: 1.0; step: 0.05; decimals: 2
        sub: "Threshold for popup layers. Must be < popupBgOpacity (Popups → Background opacity)."
        value: root.vis.layer_popups_ignore_alpha
        onMoved: v => root.setVal("layer_popups_ignore_alpha", v)
      }
      SetToggle {
        sys: root.sys
        label: "Layer Xray"
        sub: "Blur behind windows for both bar and popups. Disable to blur only wallpaper."
        on: root.vis.layer_xray
        onToggled: v => root.setVal("layer_xray", v)
      }
    }
  }

  readonly property var hyprDefaults: ({
    gaps_in: 3, gaps_out: 6, border_size: 0, resize_on_border: false,
    active_opacity: 0.95, inactive_opacity: 0.9,
    rounding: 10, rounding_power: 2.0,
    dim_inactive: true, dim_strength: 0.3, shadows: false,
    active_border: "", inactive_border: "",
    layout: "master", mfact: 0.7, orientation: "left",
    new_status: "slave", always_keep_position: false,
    scroll_column_width: 0.5, scroll_direction: "right",
    scroll_focus_fit: "fit", scroll_follow_focus: true,
    scroll_follow_min_visible: 0.4, scroll_fullscreen_on_one_column: true,
    inactive_timeout: 3,
    blur_enabled: true, blur_size: 4, blur_passes: 2,
    blur_vibrancy: 0.4, blur_vibrancy_darkness: 0.3,
    blur_noise: 0.02, blur_contrast: 1.05, blur_brightness: 1.0,
    blur_popups: true, blur_popups_ignorealpha: 0.1,
    blur_ignore_opacity: false, blur_xray: false, blur_new_optimizations: true,
    layer_ignore_alpha: 0, layer_popups_ignore_alpha: 0.05, layer_xray: true
  })

  property var vis: hyprDefaults
  property var fileData: ({})
  property string hyprStatus: ""

  function setVal(key, value) {
    var next = Object.assign({}, vis)
    next[key] = value
    vis = next
    hyprSaveTimer.restart()
  }

  function resetHypr() {
    vis = Object.assign({}, hyprDefaults)
    hyprSaveTimer.restart()
  }

  function writeHypr() {
    var out = {}
    for (var k in hyprDefaults) {
      var v = vis[k] !== undefined ? vis[k] : hyprDefaults[k]
      out[k] = typeof v === "number" ? Math.round(v * 100) / 100 : v
    }
    for (var extra in fileData) {
      if (out[extra] !== undefined) continue
      var ev = fileData[extra]
      out[extra] = typeof ev === "number" ? Math.round(ev * 100) / 100 : ev
    }
    hyprStatus = "Reloading Hyprland..."
    _visualFile.setText(JSON.stringify(out, null, 2) + "\n")
  }

  Timer {
    id: hyprSaveTimer
    interval: 400
    onTriggered: root.writeHypr()
  }

  FileView {
    id: _visualFile
    path: "file://" + Quickshell.env("HOME") + "/.config/hypr/visual.json"
    watchChanges: false
    onSaved: _hyprReloadProc.running = true
  }

  Process {
    id: _hyprReloadProc
    command: ["hyprctl", "reload"]
    onExited: (code) => { root.hyprStatus = code === 0 ? "Applied" : "hyprctl reload failed" }
  }

  FileView {
    id: _visualRead
    path: "file://" + Quickshell.env("HOME") + "/.config/hypr/visual.json"
    watchChanges: false
    onFileChanged: this.reload()
    onDataChanged: root.applyFileData()
  }

  Component.onCompleted: {
    applyFileData()
    _visualRead.reload()
  }

  function applyFileData() {
    if (hyprSaveTimer.running) return
    var data
    try { data = JSON.parse(_visualRead.text() || "{}") } catch (e) { data = {} }
    if (!data || typeof data !== "object") data = {}
    fileData = data
    var merged = Object.assign({}, hyprDefaults)
    for (var k in merged) if (data[k] !== undefined) merged[k] = data[k]
    vis = merged
  }

  Component.onDestruction: {
    if (hyprSaveTimer.running) {
      hyprSaveTimer.stop()
      writeHypr()
    }
  }

  function resync() {
    applyFileData()
    _visualRead.reload()
  }
}
