// ============================================================
// quickshell/core/KeyboardLayoutState.qml — спільний стан розкладки клавіатури
// ============================================================
import Quickshell.Io
import QtQuick

// Єдине джерело правди про розкладку для віджета бара, попапа вибору
// і локскріна (раніше було три копіпасти логіки hyprctl/socket).
// Невізуальний контейнер: процеси тримає Item, бо QtObject не приймає
// дочірні об'єкти.
Item {
  id: root
  visible: false

  // monitor=true — живий трекінг через hyprctl + socket (віджет, локскрін);
  // false — лише разові опитування (попап: refreshMenu() при відкритті)
  property bool monitor: true

  property string layout: "US"
  property string activeKeymap: ""
  property string mainKeyboard: ""
  property var rawCodes: []
  property var layoutsModel: []
  property bool menuDevsDone: false
  property bool menuLayoutsDone: false
  readonly property bool menuReady: root.menuDevsDone && root.menuLayoutsDone

  readonly property string displayText: {
    var l = root.layout
    if (l.indexOf("Ukrainian") >= 0) return "UA"
    if (l.indexOf("Russian") >= 0) return "RU"
    if (l.indexOf("German") >= 0) return "DE"
    if (l.indexOf("French") >= 0) return "FR"
    if (l.indexOf("(UK)") >= 0) return "UK"
    if (l.indexOf("English") >= 0 || l.indexOf("(US)") >= 0) return "US"
    // Невідома розкладка — перші 3 літери першого слова (Persian → PER)
    var first = String(l).split(/[\s(-]+/)[0] ?? ""
    return first.slice(0, 3).toUpperCase()
  }

  // Перекладає код розкладки (us, ua, de...) в коротку мітку
  function layoutLabel(code) {
    var map = {
      us: "US", ua: "UA", ru: "RU", de: "DE", fr: "FR", gb: "GB", uk: "UK",
      es: "ES", it: "IT", pl: "PL", cz: "CZ", se: "SE", fi: "FI", no: "NO",
      tr: "TR", il: "IL", br: "BR", pt: "PT", nl: "NL", be: "BE", ch: "CH",
      jp: "JP", kr: "KR", cn: "CN"
    }
    var key = String(code).toLowerCase().split(/[\s(-]+/)[0]
    return map[key] || String(code).toUpperCase()
  }

  // Визначає індекс активної розкладки за active_keymap
  function activeIndex(activeKeymap, codes) {
    var ak = String(activeKeymap || "").toLowerCase()
    var words = {
      us: "us", ua: "ukrain", ru: "russi", de: "german", fr: "french",
      gb: "english (uk)", uk: "english (uk)", es: "spanish", it: "italian",
      pl: "polish", cz: "czech", se: "swedish", fi: "finnish", tr: "turkish",
      il: "hebrew", br: "brazil", pt: "portuguese", nl: "dutch", jp: "japanese",
      kr: "korean", cn: "chinese"
    }
    for (var i = 0; i < codes.length; ++i) {
      var c = String(codes[i]).toLowerCase()
      var w = words[c]
      if (w && ak.indexOf(w) >= 0) return i
    }
    for (var j = 0; j < codes.length; ++j) {
      var n = String(codes[j]).toLowerCase().replace(/[^a-z]/g, "")
      if (n !== "" && ak.replace(/[^a-z]/g, "").indexOf(n) >= 0) return j
    }
    return -1
  }

  // Модель готовить тільки коли є обидва джерела даних
  function rebuildModel() {
    if (!root.menuDevsDone || !root.menuLayoutsDone) return
    var idx = root.activeIndex(root.activeKeymap, root.rawCodes)
    var out = []
    for (var i = 0; i < root.rawCodes.length; ++i) {
      out.push({ label: root.layoutLabel(root.rawCodes[i]), active: i === idx })
    }
    root.layoutsModel = out
  }

  function refreshMenu() {
    root.menuDevsDone = false
    root.menuLayoutsDone = false
    menuDevsProc.running = true
    menuLayoutsProc.running = true
  }

  // ЛКМ — наступна розкладка (ім'я main-клавіатури щоразу свіже)
  function cycleNext() {
    nextProc.running = true
  }

  // ПКМ-список — прямий вибір за індексом
  function switchTo(index) {
    if (root.mainKeyboard !== "") {
      switchProc.command = ["hyprctl", "switchxkblayout", root.mainKeyboard, String(index)]
      switchProc.running = true
    }
  }

  function pickKeyboard(obj) {
    var keyboards = obj.keyboards ?? []
    for (var i = 0; i < keyboards.length; ++i) {
      if (keyboards[i].active_keymap && keyboards[i].main === true)
        return keyboards[i]
    }
    for (var j = 0; j < keyboards.length; ++j) {
      var k = keyboards[j]
      if (k.active_keymap && k.name.indexOf("keyboard") < 0 && k.name.indexOf("system") < 0 && k.name.indexOf("consumer") < 0)
        return k
    }
    if (keyboards.length > 0 && keyboards[0].active_keymap)
      return keyboards[0]
    return null
  }

  // Поточна розкладка при старті
  JsonProcess {
    id: initialProc
    command: ["hyprctl", "devices", "-j"]
    onParsed: obj => {
      var keyboards = obj.keyboards ?? []
      for (var i = 0; i < keyboards.length; ++i) {
        if (keyboards[i].main === true) { root.mainKeyboard = keyboards[i].name; break }
      }
      if (root.mainKeyboard === "" && keyboards.length > 0) root.mainKeyboard = keyboards[0].name
      var kb = root.pickKeyboard(obj)
      if (kb !== null) {
        root.layout = kb.active_keymap
        root.activeKeymap = kb.active_keymap
      }
    }
  }

  // Стежить за змінами розкладки через Hyprland socket (рядкові події,
  // не JSON — тому звичайний SplitParser, не JsonProcess)
  Process {
    id: socketProc
    command: ["sh", "-c", "while true; do socat - UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock 2>/dev/null; sleep 1; done"]

    stdout: SplitParser {
      splitMarker: "\n"
      onRead: data => {
        var text = (data ?? "").trim()
        if (text === "") return
        if (text.indexOf("activelayout") === 0) {
          var eventParts = text.split(">>")
          if (eventParts.length >= 2) {
            var dataParts = eventParts[1].split(",")
            var name = dataParts[dataParts.length - 1].trim()
            root.layout = name
            root.activeKeymap = name
            root.rebuildModel()
          }
        }
      }
    }
  }

  // Ім'я main-клавіатури для cycleNext
  JsonProcess {
    id: nextProc
    command: ["hyprctl", "devices", "-j"]
    onParsed: obj => {
      var mainName = ""
      var keyboards = obj.keyboards ?? []
      for (var i = 0; i < keyboards.length; ++i) {
        if (keyboards[i].main === true) { mainName = keyboards[i].name; break }
      }
      if (mainName === "" && keyboards.length > 0) mainName = keyboards[0].name
      if (mainName !== "") {
        switchProc.command = ["hyprctl", "switchxkblayout", mainName, "next"]
        switchProc.running = true
      }
    }
  }

  // Ім'я main-клавіатури + активна розкладка для меню
  JsonProcess {
    id: menuDevsProc
    command: ["hyprctl", "devices", "-j"]
    onParsed: obj => {
      var keyboards = obj.keyboards ?? []
      for (var i = 0; i < keyboards.length; ++i) {
        if (keyboards[i].main === true) {
          root.mainKeyboard = keyboards[i].name
          root.activeKeymap = keyboards[i].active_keymap ?? ""
          break
        }
      }
      if (root.mainKeyboard === "" && keyboards.length > 0) {
        root.mainKeyboard = keyboards[0].name
        root.activeKeymap = keyboards[0].active_keymap ?? ""
      }
      root.menuDevsDone = true
      root.rebuildModel()
    }
  }

  // Список розкладок з input:kb_layout
  JsonProcess {
    id: menuLayoutsProc
    command: ["hyprctl", "getoption", "input:kb_layout", "-j"]
    onParsed: obj => {
      var codes = String(obj.str ?? "").split(",")
      var out = []
      for (var i = 0; i < codes.length; ++i) {
        var code = codes[i].trim()
        if (code !== "") out.push(code)
      }
      root.rawCodes = out
      root.menuLayoutsDone = true
      root.rebuildModel()
    }
  }

  Process {
    id: switchProc
    command: ["hyprctl", "switchxkblayout", "", "next"]
  }

  Component.onCompleted: {
    if (root.monitor) {
      initialProc.running = true
      socketProc.running = true
    }
  }
  onMonitorChanged: {
    if (root.monitor) {
      initialProc.running = true
      socketProc.running = true
    } else {
      initialProc.running = false
      socketProc.running = false
    }
  }
  Component.onDestruction: socketProc.running = false
}
