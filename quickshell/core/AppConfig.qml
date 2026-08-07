// ============================================================
// AppConfig.qml — спільний стан конфігурації панелі (видимість,
// порядок віджетів) з персистентністю через FileView
// ============================================================
import Quickshell.Io
import QtQuick

// Невидимий контейнер — єдиний екземпляр створюється в Bar.qml
// і доступний усім попапам через window.appConfig.
Item {
  visible: false

  FileView {
    id: configFile
    path: Qt.resolvedUrl("../data/config.json")
    blockLoading: true
  }

  property bool launcherEnabled: true
  property bool workspacesEnabled: true
  property bool mprisEnabled: true
  property bool clockEnabled: true
  property bool timerEnabled: true
  property bool genshinEnabled: true
  property bool keyboardEnabled: true
  property bool audioEnabled: true
  property bool controlEnabled: true
  // Дефолти вимкнених сервісів співпадають з config.json (bt/net/tray
  // за замовчуванням вимкнені, вмикаються через Settings)
  property bool btEnabled: false
  property bool netEnabled: false
  property bool trayEnabled: false
  property bool batteryEnabled: false

  // DND — повністю ховає сповіщення (тост, список, звук)
  property bool dndEnabled: false

  // Кастомний шлях до звуку завершення таймера ("" = звук з assets/)
  property string timerSoundPath: ""

  // --- Поведінка системи (JSON-налаштування) ---
  // Idle-таймаути (секунди). Порядок має бути зростаючим:
  // lock < dpms < suspend, інакше рівні спрацьовуватимуть у несподіваному
  // порядку.
  property int idleLockTimeout: 300
  property int idleDpmsTimeout: 360
  property int idleSuspendTimeout: 900

  // Інкременти змін значень (wheel/клавіші)
  property real audioStep: 0.05
  property int brightnessStep: 5

  // Зовнішній вигляд панелі
  property int barHeight: 36
  property int barRadius: 4

  // Фіксований канонічний список усіх віджетів — використовується
  // Settings-попапом для стабільного порядку рядків (не залежить від
  // того, в якій пігулці зараз лежить віджет).
  readonly property var allWidgetNames: [
    "launcher", "workspaces", "mpris", "clock", "timer",
    "genshin", "keyboard", "audio", "battery", "control", "bt", "net", "tray"
  ]

  // Порядок ВСЕРЕДИНІ пігулки + приналежність до пігулки визначаються
  // належністю імені до одного з цих трьох масивів. Окремої властивості
  // "xPill" більше не потрібно — пігулка це і є масив, де лежить ім'я.
  // Фабричні дефолти — на випадок відсутнього/порожнього config.json.
  // При старті перезаписуються реальними значеннями з config.json.
  property var leftOrder: ["launcher", "workspaces", "mpris"]
  property var centerOrder: ["clock", "timer", "genshin"]
  property var rightOrder: ["tray", "sep-0", "bt", "net", "sep-1", "keyboard", "audio", "control"]

  function isSep(name) {
    return name === "sep" || String(name).startsWith("sep-")
  }

  function addSep(pillName) {
    var maxId = -1
    var all = [leftOrder, centerOrder, rightOrder]
    for (var a = 0; a < all.length; a++) {
      for (var i = 0; i < all[a].length; i++) {
        var m = String(all[a][i]).match(/^sep-(\d+)$/)
        if (m) maxId = Math.max(maxId, parseInt(m[1]))
      }
    }
    var name = "sep-" + (maxId + 1)
    var arr = pillOrderFor(pillName).slice()
    arr.push(name)
    if (pillName === "left") leftOrder = arr
    else if (pillName === "center") centerOrder = arr
    else rightOrder = arr
  }

  function pillOrderFor(pillName) {
    return pillName === "left" ? leftOrder : pillName === "center" ? centerOrder : rightOrder
  }

  function pillOf(name) {
    if (leftOrder.indexOf(name) !== -1) return "left"
    if (centerOrder.indexOf(name) !== -1) return "center"
    if (rightOrder.indexOf(name) !== -1) return "right"
    return "left"
  }

  // Переносить віджет в іншу пігулку (додається в кінець її списку)
  function moveToPill(name, targetPill) {
    leftOrder = leftOrder.filter(n => n !== name)
    centerOrder = centerOrder.filter(n => n !== name)
    rightOrder = rightOrder.filter(n => n !== name)
    if (targetPill === "left") leftOrder = leftOrder.concat([name])
    else if (targetPill === "center") centerOrder = centerOrder.concat([name])
    else rightOrder = rightOrder.concat([name])
  }

  function moveToPillAt(name, targetPill, targetIndex) {
    leftOrder = leftOrder.filter(n => n !== name)
    centerOrder = centerOrder.filter(n => n !== name)
    rightOrder = rightOrder.filter(n => n !== name)
    var arr = pillOrderFor(targetPill).slice()
    var idx = Math.max(0, Math.min(targetIndex, arr.length))
    arr.splice(idx, 0, name)
    if (targetPill === "left") leftOrder = arr
    else if (targetPill === "center") centerOrder = arr
    else rightOrder = arr
  }

  function cyclePill(name) {
    var pills = ["left", "center", "right"]
    var idx = pills.indexOf(pillOf(name))
    moveToPill(name, pills[(idx + 1) % 3])
  }

  // Пересуває віджет на 1 позицію вгору(-1)/вниз(+1) всередині його
  // поточної пігулки. Межі списку — no-op (нікуди рухати).
  function moveWithinPill(name, direction) {
    var p = pillOf(name)
    var arr = pillOrderFor(p).slice()
    var idx = arr.indexOf(name)
    if (idx === -1) return
    var newIdx = idx + direction
    if (newIdx < 0 || newIdx >= arr.length) return
    var tmp = arr[idx]; arr[idx] = arr[newIdx]; arr[newIdx] = tmp
    if (p === "left") leftOrder = arr
    else if (p === "center") centerOrder = arr
    else rightOrder = arr
  }

  function loadFromJson(data) {
    if (data.launcherEnabled !== undefined)   launcherEnabled   = data.launcherEnabled
    if (data.workspacesEnabled !== undefined) workspacesEnabled = data.workspacesEnabled
    if (data.mprisEnabled !== undefined)      mprisEnabled      = data.mprisEnabled
    if (data.clockEnabled !== undefined)      clockEnabled      = data.clockEnabled
    if (data.timerEnabled !== undefined)      timerEnabled      = data.timerEnabled
    if (data.genshinEnabled !== undefined)    genshinEnabled    = data.genshinEnabled
    if (data.keyboardEnabled !== undefined)   keyboardEnabled   = data.keyboardEnabled
    if (data.audioEnabled !== undefined)      audioEnabled      = data.audioEnabled
    if (data.controlEnabled !== undefined)    controlEnabled    = data.controlEnabled
    if (data.btEnabled !== undefined)         btEnabled         = data.btEnabled
    if (data.netEnabled !== undefined)        netEnabled        = data.netEnabled
    if (data.trayEnabled !== undefined)       trayEnabled       = data.trayEnabled
    if (data.dndEnabled !== undefined)        dndEnabled        = data.dndEnabled
    if (data.timerSoundPath !== undefined)    timerSoundPath    = data.timerSoundPath
    if (data.idleLockTimeout !== undefined)   idleLockTimeout   = data.idleLockTimeout
    if (data.idleDpmsTimeout !== undefined)   idleDpmsTimeout   = data.idleDpmsTimeout
    if (data.idleSuspendTimeout !== undefined) idleSuspendTimeout = data.idleSuspendTimeout
    if (data.audioStep !== undefined)         audioStep         = data.audioStep
    if (data.brightnessStep !== undefined)    brightnessStep    = data.brightnessStep
    if (data.barHeight !== undefined)         barHeight         = data.barHeight
    if (data.barRadius !== undefined)         barRadius         = data.barRadius
    if (data.leftOrder !== undefined)         leftOrder         = data.leftOrder
    if (data.centerOrder !== undefined)       centerOrder       = data.centerOrder
    if (data.rightOrder !== undefined)        rightOrder        = data.rightOrder
  }

  function saveToFile() {
    configFile.setText(JSON.stringify({
      launcherEnabled:   launcherEnabled,
      workspacesEnabled: workspacesEnabled,
      mprisEnabled:      mprisEnabled,
      clockEnabled:      clockEnabled,
      timerEnabled:      timerEnabled,
      genshinEnabled:    genshinEnabled,
      keyboardEnabled:   keyboardEnabled,
      audioEnabled:      audioEnabled,
      controlEnabled:    controlEnabled,
      btEnabled:         btEnabled,
      netEnabled:        netEnabled,
      trayEnabled:       trayEnabled,
      dndEnabled:        dndEnabled,
      timerSoundPath:    timerSoundPath,
      idleLockTimeout:   idleLockTimeout,
      idleDpmsTimeout:   idleDpmsTimeout,
      idleSuspendTimeout: idleSuspendTimeout,
      audioStep:         audioStep,
      brightnessStep:    brightnessStep,
      barHeight:         barHeight,
      barRadius:         barRadius,
      leftOrder:         leftOrder,
      centerOrder:       centerOrder,
      rightOrder:        rightOrder
    }, null, 2))
  }

  // Читає збережені налаштування з config.json при старті.
  // Якщо файл відсутній або пошкоджений — залишаються фабричні дефолти.
  Component.onCompleted: {
    var text = configFile.text()
    if (text) {
      try { loadFromJson(JSON.parse(text)) }
      catch (e) { console.warn("AppConfig: не вдалось розпарсити config.json", e) }
    }
  }
}