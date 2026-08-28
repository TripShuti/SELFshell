// ============================================================
// TimerWidget.qml — таймер на панелі
// ============================================================
import Quickshell
import Quickshell.Io
import "../core"
import QtQuick

// Віджет таймера на панелі — відлік, нагадування, керування колесом
Item {
  id: root

  required property QtObject window
  // Передається з Bar.qml: appConfig.cfg.timerSoundPath — кастомний звук завершення
  property QtObject appConfig: null

  property bool timerRunning: false
  property int timerDuration: 25
  property int timerRemaining: 0
  property string timerClass: "idle"

  readonly property string displayText: {
    if (timerClass === "done") return "\uF253 00:00"
    if (timerRunning) {
      var m = Math.floor(timerRemaining / 60)
      var s = timerRemaining % 60
      return "\uF017 " + String(m).padStart(2, "0") + ":" + String(s).padStart(2, "0")
    }
    return "\uF017 " + String(timerDuration).padStart(2, "0") + ":00"
  }

  implicitWidth: txt.implicitWidth
  implicitHeight: parent?.height ?? 36

  // --- Шляхи до звуку ---
  // 1. Кастомний шлях з конфігу (якщо користувач задав свій)
  // 2. Свій звук, що йде в комплекті з репозиторієм (assets/sounds/)
  // 3. Системний freedesktop-звук як останній фолбек
  readonly property string _customSound: (appConfig && appConfig.cfg.timerSoundPath) ? appConfig.cfg.timerSoundPath : ""
  readonly property string _bundledSound: Qt.resolvedUrl("../assets/sounds/timer-done.ogg").toString().replace("file://", "")
  readonly property string _systemFallbackSound: "/usr/share/sounds/freedesktop/stereo/complete.oga"

  function _buildNotifyCommand() {
    // Екранування шляхів через одинарні лапки на випадок пробілів у назвах файлів
    var custom = root._customSound.replace(/'/g, "'\\''")
    var bundled = root._bundledSound.replace(/'/g, "'\\''")
    var sysFallback = root._systemFallbackSound.replace(/'/g, "'\\''")

    return "notify-send -a 'SELFshell' -u critical 'Timer' 'Time is up!' & " +
      "SOUND=''; " +
      "for f in '" + custom + "' '" + bundled + "' '" + sysFallback + "'; do " +
      "  [ -n \"$f\" ] && [ -f \"$f\" ] && SOUND=\"$f\" && break; " +
      "done; " +
      "if [ -n \"$SOUND\" ]; then " +
      "  PLAYER=''; PLAYER_ARGS=''; " +
      "  command -v paplay >/dev/null 2>&1 && PLAYER='paplay'; " +
      "  [ -z \"$PLAYER\" ] && command -v pw-play >/dev/null 2>&1 && PLAYER='pw-play'; " +
      "  [ -z \"$PLAYER\" ] && command -v ffplay >/dev/null 2>&1 && { PLAYER='ffplay'; PLAYER_ARGS='-nodisp -autoexit -loglevel quiet'; }; " +
      "  if [ -n \"$PLAYER\" ]; then " +
      "    echo \"[TimerWidget] Граю через '$PLAYER': $SOUND\" >&2; " +
      "    for i in 1 2 3; do $PLAYER $PLAYER_ARGS \"$SOUND\" 2>/dev/null; sleep 0.5; done; " + // потрійний сигнал — навмисний, щоб не пропустити
      "  else " +
      "    echo '[TimerWidget] Жоден плеєр (paplay/pw-play/ffplay) не знайдено в PATH' >&2; " +
      "  fi; " +
      "else " +
      "  echo \"[TimerWidget] Не знайдено файл. Перевірені шляхи: '" + custom + "' | '" + bundled + "' | '" + sysFallback + "'\" >&2; " +
      "fi"
  }

  // Лічильник з інтервалом 1 секунда
  Timer {
    id: countdown
    interval: 1000
    repeat: true
    triggeredOnStart: false
    onTriggered: {
      root.timerRemaining -= 1
      if (root.timerRemaining <= 0) {
        countdown.stop()
        root.timerRunning = false
        root.timerRemaining = 0
        root.timerClass = "done"
        notifyProc.command = ["sh", "-c", root._buildNotifyCommand()]
        notifyProc.running = true
      }
    }
  }

  // Сповіщення та звук при завершенні (команда будується перед кожним запуском, щоб підхопити зміну timerSoundPath)
  Process {
    id: notifyProc
    stderr: SplitParser {
      splitMarker: "\n"
      onRead: function(data) { if (data) console.warn(data) }
    }
  }

  // Старт / стоп / підтвердження завершення
  function toggle() {
    if (root.timerClass === "done") {
      // Перший клік після завершення лише прибирає блимання, не стартує новий відлік
      root.timerClass = "idle"
      root.timerRemaining = 0
      return
    }
    if (root.timerRunning) {
      countdown.stop()
      root.timerRunning = false
      root.timerClass = "idle"
      root.timerRemaining = 0
    } else {
      root.timerClass = "running"
      root.timerRunning = true
      root.timerRemaining = root.timerDuration * 60
      countdown.start()
    }
  }

  // Збільшити тривалість
  function durUp() {
    if (!root.timerRunning) {
      root.timerDuration += 1
    }
  }

  // Зменшити тривалість
  function durDown() {
    if (!root.timerRunning && root.timerDuration > 1) {
      root.timerDuration -= 1
    }
  }

  // Hover-стан для фідбеку (HoverText-рецепт: колір + масштаб)
  property bool hovered: false

  Text {
    id: txt
    text: root.displayText
    color: root.hovered && root.timerClass === "idle" ? window.palette.green
         : root.timerClass === "running" ? window.palette.green
         : root.timerClass === "done" ? window.palette.red
         : window.palette.widgetFg
    font.family: window.palette.font
    font.pixelSize: window.appConfig.scaled(13)
    anchors.verticalCenter: parent.verticalCenter
    scale: root.hovered ? 1.08 : 1.0

    Behavior on color { ColorAnimation { duration: window.appConfig.anim(220) } }
    Behavior on scale {
      NumberAnimation { duration: window.appConfig.anim(120); easing.type: Easing.OutBack; easing.overshoot: 2.5 }
    }

    // Блимання при завершенні
    BlinkAnimation {
      running: root.timerClass === "done"
      minOpacity: 0.4
      blinkDuration: 600
      appConfig: window.appConfig
    }
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton
    hoverEnabled: true
    onEntered: root.hovered = true
    onExited: root.hovered = false
    onClicked: root.toggle()
    onWheel: function(wheel) {
      if (wheel.angleDelta.y === 0) return // горизонтальний скрол — ігноруємо
      if (wheel.angleDelta.y > 0)
        root.durUp()
      else
        root.durDown()
    }
  }
}
