// ============================================================
// popups/OsdPopup.qml — оверлей OSD під час зміни гучності
// або яскравості гарячими клавішами
// ============================================================
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

// Оверлей у центрі екрана (під панеллю): іконка + значення + смужка.
// Показується через IPC (`qs ipc call osd volume|brightness`), живе 1.5 с,
// клік/прокрутка закривають. Гучність читається напряму з PipeWire
// (реактивно), яскравість — з ddcutil getvcp 10.
PopupWindow {
  id: root

  property QtObject anchorWindow: null
  readonly property QtObject palette: anchorWindow ? anchorWindow.palette : null
  readonly property QtObject appConfig: anchorWindow ? anchorWindow.appConfig : null

  // "volume" | "brightness"
  property string mode: "volume"

  color: "transparent"
  // Висота вікна = висота контейнера: якщо вікно нижче, нижня обводка/кут
  // контейнера обрізаються краєм поверхні (попередній +12 різав рамку).
  implicitWidth: 240
  implicitHeight: container.implicitHeight
  grabFocus: false
  visible: false

  // --- Гучність: значення прямо з Pipewire ---
  readonly property var volumeSink: Pipewire.defaultAudioSink
  readonly property var volumeAudio: volumeSink ? volumeSink.audio : null
  readonly property real volume: volumeAudio ? Math.max(0, Math.min(volumeAudio.volume, 1)) : 0
  readonly property bool muted: volumeAudio ? volumeAudio.muted : false

  // --- Яскравість (ddcutil) ---
  property int brightness: -1

  // Таймер автозакриття
  Timer {
    id: autoCloseTimer
    interval: 1500
    onTriggered: root.hide()
  }

  // Показує OSD для змінного значення гучності (або мьюта)
  function showVolume() {
    root.mode = "volume"
    root._show()
  }

  // Показує OSD для яскравості: спершу читаємо поточне значення
  function showBrightness() {
    root.mode = "brightness"
    brightnessProc.running = true
    root._show()
  }

  function _show() {
    if (!root.anchorWindow) return
    root.anchor.window = root.anchorWindow
    var scr = root.anchorWindow.screen?.geometry ?? ({ width: 1920, height: 1080 })
    // Центр екрану, нижче бара (висота бара + 16 px)
    var barH = root.anchorWindow.height ?? root.anchorWindow.implicitHeight ?? 36
    var y = barH + 16
    root.anchor.rect = Qt.rect((scr.width - root.width) / 2, y, root.width, 0)
    root.visible = true
    root.show()
  }

  // Анімація появи/зникнення
  function show() {
    if (autoCloseTimer.running) autoCloseTimer.stop()
    if (exitAnim.running) exitAnim.stop()
    container.opacity = 0
    container.scale = 0.85
    container.x = 24
    enterAnim.start()
    autoCloseTimer.start()
  }

  function hide() {
    if (exitAnim.running) return
    exitAnim.start()
  }

  ParallelAnimation {
    id: enterAnim
    NumberAnimation { target: container; property: "opacity"; from: 0; to: 1; duration: appConfig ? appConfig.anim(180) : 180; easing.type: Easing.OutCubic }
    NumberAnimation { target: container; property: "scale"; from: 0.88; to: 1.0; duration: appConfig ? appConfig.anim(260) : 260; easing.type: Easing.OutCubic }
    NumberAnimation { target: container; property: "x"; from: 24; to: 0; duration: appConfig ? appConfig.anim(220) : 220; easing.type: Easing.OutCubic }
  }

  SequentialAnimation {
    id: exitAnim
    ParallelAnimation {
      NumberAnimation { target: container; property: "opacity"; to: 0; duration: appConfig ? appConfig.anim(140) : 140; easing.type: Easing.OutCubic }
      NumberAnimation { target: container; property: "scale"; to: 0.92; duration: appConfig ? appConfig.anim(140) : 140; easing.type: Easing.InCubic }
      NumberAnimation { target: container; property: "x"; to: 24; duration: appConfig ? appConfig.anim(140) : 140; easing.type: Easing.InCubic }
    }
    ScriptAction { script: root.visible = false }
  }

  // Клік / прокрутка — закрити
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: root.hide()
    onWheel: root.hide()
  }

  // Гліфи іконок залежно від режиму та стану.
  // Увага: у панельному шрифті (JetBrainsMonoNL Nerd Font) НЕМАЄ гліфа
  // \uF6A9 (volume-xmark) — замість нього рендериться чужий гліф
  // («склянка»), тому mute позначаємо \uF026 + червоний колір.
  readonly property string icon: {
    if (root.mode === "brightness") return "\uF185"
    if (root.muted || root.volume <= 0.01) return "\uF026"
    if (root.volume < 0.5) return "\uF027"
    return "\uF028"
  }

  readonly property color iconColor: {
    if (!root.palette) return "#8aa9fc"
    if (root.mode === "brightness") return root.palette.yellow
    if (root.muted) return root.palette.red
    return root.palette.audioVolume
  }

  // Значення для смужки (0..1)
  readonly property real fill: {
    if (root.mode === "brightness")
      return root.brightness >= 0 ? Math.min(root.brightness / 100, 1) : 0
    return root.volume
  }

  // Текст значення
  readonly property string valueText: {
    if (root.mode === "brightness")
      return root.brightness >= 0 ? root.brightness + "%" : "—"
    return Math.round(root.volume * 100) + "%"
  }

  Rectangle {
    id: container
    width: parent.width
    implicitHeight: osdLayout.implicitHeight + 14
    // Стиль як у AnimatedPopup, але на тон світліший щоб OSD не губився
    radius: appConfig ? appConfig.cfg.osdRadius : 10
    border.width: 1
    border.color: root.palette ? root.palette.bg2 : "#57514b"
    opacity: 0
    scale: 0.88
    property color _base: root.palette ? root.palette.bg1 : "#3b3b3f"
    property color _top: Qt.lighter(_base, appConfig ? appConfig.cfg.osdLighten : 1.5)
    property real bgOpacity: appConfig ? appConfig.cfg.osdBgOpacity : 0.90
    gradient: Gradient {
      orientation: Gradient.Vertical
      GradientStop { position: 0.0; color: Qt.rgba(_top.r, _top.g, _top.b, bgOpacity) }
      GradientStop { position: 1.0; color: Qt.rgba(_base.r, _base.g, _base.b, bgOpacity) }
    }

    ColumnLayout {
      id: osdLayout
      anchors.fill: parent
      anchors.margins: 8
      spacing: 8

      // Все в один рядок: іконка — смужка — значення
      RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Text {
          text: root.icon
          color: root.iconColor
          font.family: root.palette.font
          font.pixelSize: appConfig.scaled(16)
          Layout.alignment: Qt.AlignVCenter
        }

        // Смужка значення
        Rectangle {
          Layout.fillWidth: true
          implicitHeight: 6
          radius: 3
          color: root.palette ? root.palette.bgAlpha : "#3a3733"

          Rectangle {
            width: parent.width * root.fill
            height: parent.height
            radius: parent.radius
            color: root.muted ? (root.palette ? root.palette.red : "#ff5555") : root.iconColor
            Behavior on width { NumberAnimation { duration: appConfig ? appConfig.anim(140) : 140; easing.type: Easing.OutCubic } }
          }
        }

        Text {
          text: root.valueText
          color: root.palette.fg
          font.family: root.palette.font
          font.pixelSize: appConfig.scaled(13)
          font.bold: true
          Layout.alignment: Qt.AlignVCenter
        }
      }
    }
  }

  // Читання яскравості (той самий формат, що і в ControlPopup)
  StdioCollector {
    id: brightnessCollector
    waitForEnd: true
    onDataChanged: {
      var text = brightnessCollector.text.trim()
      var match = text.match(/current value = +(\d+).+max value = +(\d+)/)
      if (match) root.brightness = parseInt(match[1])
    }
  }

  Process {
    id: brightnessProc
    command: ["ddcutil", "getvcp", "10"]
    stdout: brightnessCollector
    onExited: running = false
  }
}