// ============================================================
// settings/AppearanceSection.qml — розділ Appearance: дизайн поза
// автопалітрою — прозорість, градієнти, радіуси, сяйво, масштаб шрифтів,
// плюс візуальні налаштування Hyprland (visual.json + hyprctl reload)
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
  // Без цього root.window = undefined: старий код брав `window` з
  // контексту попапа, новий (Hyprland-картка) — через властивість
  readonly property var window: sys.window

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
        Behavior on opacity { NumberAnimation { duration: root.ac.anim(120) } }
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

    // --- Глобальні анімації ---
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

    // --- Hyprland: візуал вікон (visual.json + hyprctl reload) ---
    SetCard {
      sys: root.sys
      SetLabel { sys: root.sys; text: "Hyprland windows" }

      SetSelect {
        sys: root.sys
        label: "Layout"
        options: [{ id: "dwindle", text: "Dwindle" }, { id: "master", text: "Master" }]
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
          sub: "Master tile stays in place even when smaller than slaves. Applies with a brief layout restart."
          on: root.vis.always_keep_position
          onToggled: v => root.setVal("always_keep_position", v)
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

      // Кольори бордерів: свотчі з палітри + hex
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
              // свотчі — кольори з палітри шелла
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
                  onClicked: root.setVal(colorRow.modelData.key,
                    "rgba(" + parent.c.toString().replace("#", "").toLowerCase() + "ff)")
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
                text: colorRow.val.startsWith("rgba(")
                      ? "#" + colorRow.val.substring(5, 13)
                      : colorRow.val
                onEditingFinished: {
                  var t = text.trim()
                  if (t === "") { root.setVal(colorRow.modelData.key, ""); return }
                  if (/^#[0-9a-fA-F]{6}$/.test(t))
                    root.setVal(colorRow.modelData.key, "rgba(" + t.substring(1).toLowerCase() + "ff)")
                }
              }

              MouseArea {
                anchors.fill: parent
                visible: !hexInput.activeFocus
                onClicked: hexInput.forceActiveFocus()
              }
            }

            Item { Layout.fillWidth: true }

            // скинути колір до дефолту (градієнт/дефолтний сірий)
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
  }

  // ---------- Hyprland visual.json ----------
  // Дефолти мають збігатися з хелперами num/bool/str у general.lua.
  // У файл пишуться лише відрізнені від дефолтів ключі.
  readonly property var hyprDefaults: ({
    gaps_in: 3, gaps_out: 1, border_size: 1, resize_on_border: false,
    active_opacity: 1.0, inactive_opacity: 1.0,
    rounding: 0, rounding_power: 2.0,
    dim_inactive: false, dim_strength: 0.3, shadows: true,
    active_border: "", inactive_border: "",
    layout: "dwindle", mfact: 0.55, orientation: "left",
    new_status: "inherit", always_keep_position: false,
    inactive_timeout: 3
  })

  property var vis: hyprDefaults
  // Сирі ключі з файлу, яких немає в hyprDefaults (json-only: rounding_power,
  // тіньові деталі тощо) — зберігаються при кожному записі, інакше перший же
  // рух слайдера їх стирав
  property var fileData: ({})
  property string hyprStatus: ""
  property bool hyprKickNeeded: false
  property string kickStage: "" // "" | "to-dwindle" | "back" — ланцюг реініціалізації master

  function setVal(key, value) {
    var next = Object.assign({}, vis)
    next[key] = value
    vis = next
    // always_keep_position не ре-застосовується hyprctl reload — master-
    // лейаут продовжує жити зі старим значенням до перестворення. Тому
    // після reload робимо короткий kick (dwindle→master), див. onExited
    hyprKickNeeded = key === "always_keep_position" && vis.layout === "master"
    hyprSaveTimer.restart()
  }

  function resetHypr() {
    vis = Object.assign({}, hyprDefaults)
    fileData = {}
    hyprKickNeeded = vis.layout === "master"
    hyprSaveTimer.restart()
  }

  // Повний знімок усіх UI-ключів (навіть рівних дефолтах — інакше
  // always_keep_position: false тощо "зникали" з файлу) + збереження
  // json-only ключів, яких UI не торкається
  function hyprSnapshot(source) {
    var out = {}
    for (var k in hyprDefaults)
      out[k] = source[k] !== undefined ? source[k] : hyprDefaults[k]
    for (var extra in fileData)
      if (out[extra] === undefined) out[extra] = fileData[extra]
    return JSON.stringify(out, null, 2) + "\n"
  }

  function writeHypr() {
    hyprStatus = "Reloading Hyprland..."
    // reload — тільки в onSaved: setText пишеться асинхронно, і hyprctl
    // встигав прочитати СТАРИЙ вміст (значення відставало на один крок)
    _visualFile.setText(hyprSnapshot(vis))
  }

  Timer {
    id: hyprSaveTimer
    interval: 400 // дебаунс: слайдер генерує десятки подій, reload на кожен тик уб'є інтерактивність
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
    onExited: (code) => {
      if (code !== 0) {
        root.kickStage = ""
        root.hyprKickNeeded = false
        root.hyprStatus = "hyprctl reload failed"
        return
      }
      // always_keep_position не ре-застосовується простим reload — Hyprland
      // читає його лише при створенні лейаута (hyprctl keyword з Lua-конфігом
      // теж не працює). Кік = перемикнути лейаут у файлі + reload туди й назад
      if (root.kickStage === "") {
        if (root.hyprKickNeeded) {
          root.kickStage = "to-dwindle"
          _visualFile.setText(hyprSnapshot(Object.assign({}, root.vis, { layout: "dwindle" })))
        } else {
          root.hyprStatus = "Applied"
        }
      } else if (root.kickStage === "to-dwindle") {
        root.kickStage = "back"
        _visualFile.setText(hyprSnapshot(root.vis))
      } else {
        root.kickStage = ""
        root.hyprKickNeeded = false
        root.hyprStatus = "Applied"
      }
    }
  }

  // Початкове завантаження: дефолти + те, що вже є у visual.json
  FileView {
    id: _visualRead
    path: "file://" + Quickshell.env("HOME") + "/.config/hypr/visual.json"
    watchChanges: false
    onFileChanged: this.reload()
  }

  Component.onCompleted: {
    var merged = Object.assign({}, hyprDefaults)
    try {
      var data = JSON.parse(_visualRead.text() || "{}")
      fileData = data
      for (var k in merged)
        if (data[k] !== undefined) merged[k] = data[k]
    } catch (e) {}
    vis = merged
  }
}