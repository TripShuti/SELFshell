// ============================================================
// quickshell/core/LockSurface.qml — UI екрану блокування на один монітор
// ============================================================
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io

// Поверхня блокування для одного монітора.
// Інстанціюється WlSessionLock через WlSessionLockSurface.
Rectangle {
  id: root

  required property QtObject context
  required property QtObject palette
  // Опційно: для глобального множника тривалостей анімацій
  property QtObject appConfig: null

  // current.<ext> генерується локально (update-palette.sh) і не в git —
  // шлях шукаємо через update-palette.py current, на свіжому клоні
  // fallback на трековану заглушку wp1.jpg
  readonly property string paletteScriptPath: Qt.resolvedUrl("../scripts/update-palette.py").toString().replace("file://", "")
  readonly property string wallpaperFallback: Qt.resolvedUrl("../wp/wp1.jpg")
  property string wallpaperSource: wallpaperFallback

  // Розкладка клавіатури (як KeyboardLayoutWidget в барі): показ + ЛКМ next,
  // ПКМ — інлайн-список для прямого вибору. Логіка скопійована з віджета/
  // попапа, бо LockSurface живе в WlSessionLock і не має доступу до Bar.
  property string kbLayout: "US"
  property bool kbHovered: false
  property bool kbListOpen: false
  property string kbInitialBuf: ""
  property string kbNextBuf: ""
  property string kbMenuDevsBuf: ""
  property string kbMenuLayoutsBuf: ""
  property string kbMainKeyboard: ""
  property string kbActiveKeymap: ""
  property var kbRawCodes: []
  property var kbLayoutsModel: []
  property bool kbMenuDevsDone: false
  property bool kbMenuLayoutsDone: false

  readonly property string kbDisplayText: {
    var l = root.kbLayout
    if (l.indexOf("Ukrainian") >= 0) return "UA"
    if (l.indexOf("Russian") >= 0) return "RU"
    if (l.indexOf("German") >= 0) return "DE"
    if (l.indexOf("French") >= 0) return "FR"
    if (l.indexOf("(UK)") >= 0) return "UK"
    if (l.indexOf("English") >= 0 || l.indexOf("(US)") >= 0) return "US"
    var first = String(l).split(/[\s(-]+/)[0] ?? ""
    return first.slice(0, 3).toUpperCase()
  }

  function kbLayoutLabel(code) {
    var map = {
      us: "US", ua: "UA", ru: "RU", de: "DE", fr: "FR", gb: "GB", uk: "UK",
      es: "ES", it: "IT", pl: "PL", cz: "CZ", se: "SE", fi: "FI", no: "NO",
      tr: "TR", il: "IL", br: "BR", pt: "PT", nl: "NL", be: "BE", ch: "CH",
      jp: "JP", kr: "KR", cn: "CN"
    }
    var key = String(code).toLowerCase().split(/[\s(-]+/)[0]
    return map[key] || String(code).toUpperCase()
  }

  function kbActiveIndex(activeKeymap, codes) {
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

  function kbRebuildModel() {
    if (!root.kbMenuDevsDone || !root.kbMenuLayoutsDone) return
    var idx = root.kbActiveIndex(root.kbActiveKeymap, root.kbRawCodes)
    var out = []
    for (var i = 0; i < root.kbRawCodes.length; ++i) {
      out.push({ label: root.kbLayoutLabel(root.kbRawCodes[i]), active: i === idx })
    }
    root.kbLayoutsModel = out
  }

  function kbRefreshMenu() {
    root.kbMenuDevsDone = false
    root.kbMenuLayoutsDone = false
    root.kbMenuDevsBuf = ""
    root.kbMenuLayoutsBuf = ""
    kbMenuDevsProc.running = true
    kbMenuLayoutsProc.running = true
  }

  function kbPickKeyboard(obj) {
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

  // Отримує шлях шпалери для lock-скріна (current-lock.jpg або фолбек).
  // Читаємо через onDataChanged колектора (як у WallpaperPopup): у
  // onExited текст ще може бути неповним — тоді зостається wp1.jpg.
  Process {
    id: curProc
    stdout: curCollector
    command: ["python3", root.paletteScriptPath, "current"]
  }

  StdioCollector {
    id: curCollector
    waitForEnd: true
    onDataChanged: {
      var p = curCollector.text.trim()
      if (p)
        root.wallpaperSource = "file://" + p
    }
  }

  // Поточна розкладка при старті (як initialProc у KeyboardLayoutWidget)
  Process {
    id: kbInitialProc
    command: ["hyprctl", "devices", "-j"]
    onStarted: root.kbInitialBuf = ""
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: data => {
        root.kbInitialBuf += (data ?? "")
        var obj = null
        try { obj = JSON.parse(root.kbInitialBuf) } catch (e) {}
        if (obj === null) return
        root.kbInitialBuf = ""
        var kb = root.kbPickKeyboard(obj)
        if (kb !== null) {
          root.kbLayout = kb.active_keymap
          root.kbActiveKeymap = kb.active_keymap
        }
      }
    }
  }

  // Стеження за зміною розкладки через Hyprland socket (як socketProc у віджеті)
  Process {
    id: kbSocketProc
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
            root.kbLayout = name
            root.kbActiveKeymap = name
            root.kbRebuildModel()
          }
        }
      }
    }
  }

  // ЛКМ — next розкладка: ім'я main-клавіатури, потім switchxkblayout next
  Process {
    id: kbNextProc
    command: ["hyprctl", "devices", "-j"]
    onStarted: root.kbNextBuf = ""
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: data => {
        root.kbNextBuf += (data ?? "")
        var obj = null
        try { obj = JSON.parse(root.kbNextBuf) } catch (e) {}
        if (obj === null) return
        root.kbNextBuf = ""
        var mainName = ""
        var keyboards = obj.keyboards ?? []
        for (var i = 0; i < keyboards.length; ++i) {
          if (keyboards[i].main === true) { mainName = keyboards[i].name; break }
        }
        if (mainName === "" && keyboards.length > 0) mainName = keyboards[0].name
        if (mainName !== "") {
          kbSwitchProc.command = ["hyprctl", "switchxkblayout", mainName, "next"]
          kbSwitchProc.running = true
        }
      }
    }
  }

  // ПКМ — інлайн-список: main-клавіатура + активна розкладка
  Process {
    id: kbMenuDevsProc
    command: ["hyprctl", "devices", "-j"]
    onStarted: root.kbMenuDevsBuf = ""
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: data => {
        root.kbMenuDevsBuf += (data ?? "")
        var obj = null
        try { obj = JSON.parse(root.kbMenuDevsBuf) } catch (e) {}
        if (obj === null) return
        root.kbMenuDevsBuf = ""
        var keyboards = obj.keyboards ?? []
        for (var i = 0; i < keyboards.length; ++i) {
          if (keyboards[i].main === true) {
            root.kbMainKeyboard = keyboards[i].name
            root.kbActiveKeymap = keyboards[i].active_keymap ?? ""
            break
          }
        }
        if (root.kbMainKeyboard === "" && keyboards.length > 0) {
          root.kbMainKeyboard = keyboards[0].name
          root.kbActiveKeymap = keyboards[0].active_keymap ?? ""
        }
        root.kbMenuDevsDone = true
        root.kbRebuildModel()
      }
    }
  }

  // ПКМ — інлайн-список: коди розкладок з input:kb_layout
  Process {
    id: kbMenuLayoutsProc
    command: ["hyprctl", "getoption", "input:kb_layout", "-j"]
    onStarted: root.kbMenuLayoutsBuf = ""
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: data => {
        root.kbMenuLayoutsBuf += (data ?? "")
        var obj = null
        try { obj = JSON.parse(root.kbMenuLayoutsBuf) } catch (e) {}
        if (obj === null) return
        root.kbMenuLayoutsBuf = ""
        var codes = String(obj.str ?? "").split(",")
        var out = []
        for (var i = 0; i < codes.length; ++i) {
          var code = codes[i].trim()
          if (code !== "") out.push(code)
        }
        root.kbRawCodes = out
        root.kbMenuLayoutsDone = true
        root.kbRebuildModel()
      }
    }
  }

  Process {
    id: kbSwitchProc
    command: ["hyprctl", "switchxkblayout", "", "next"]
  }

  Component.onCompleted: {
    curProc.running = true
    kbInitialProc.running = true
    kbSocketProc.running = true
    entranceAnim.start()
  }
  Component.onDestruction: kbSocketProc.running = false

  color: "#000000"

  // М'яка поява елементів при блокуванні: годинник → користувач+пароль →
  // кнопки живлення. Швидка і стримана (групи по 200ms з паузою 60ms).
  function _d(ms) { return root.appConfig ? root.appConfig.anim(ms) : ms }

  SequentialAnimation {
    id: entranceAnim
    ParallelAnimation {
      NumberAnimation { target: clockText; property: "opacity"; from: 0; to: 1; duration: root._d(200); easing.type: Easing.OutCubic }
      NumberAnimation { target: dateText; property: "opacity"; from: 0; to: 1; duration: root._d(200); easing.type: Easing.OutCubic }
      NumberAnimation { target: clockText; property: "scale"; from: 0.98; to: 1; duration: root._d(200); easing.type: Easing.OutCubic }
    }
    PauseAnimation { duration: root._d(60) }
    ParallelAnimation {
      NumberAnimation { target: userText; property: "opacity"; from: 0; to: 1; duration: root._d(200); easing.type: Easing.OutCubic }
      NumberAnimation { target: passwordLayout; property: "opacity"; from: 0; to: 1; duration: root._d(200); easing.type: Easing.OutCubic }
      NumberAnimation { target: passwordLayout; property: "scale"; from: 0.97; to: 1; duration: root._d(200); easing.type: Easing.OutCubic }
    }
    PauseAnimation { duration: root._d(60) }
    ParallelAnimation {
      NumberAnimation { target: powerRow; property: "opacity"; from: 0; to: 1; duration: root._d(200); easing.type: Easing.OutCubic }
      NumberAnimation { target: kbBadge; property: "opacity"; from: 0; to: 1; duration: root._d(200); easing.type: Easing.OutCubic }
    }
  }

  SystemClock {
    id: clock
    precision: SystemClock.Seconds
  }

  // Фокус: клік на будь-якій ділянці екрана форсує фокус
  // на полі пароля (необхідно для багатомоніторних конфігурацій)
  MouseArea {
    anchors.fill: parent
    onClicked: {
      root.kbListOpen = false
      hiddenInput.forceActiveFocus()
    }
  }

  // Шпалера як фон з блюром
  Image {
    id: wallpaperImg
    anchors.fill: parent
    source: root.wallpaperSource
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    cache: false
    onStatusChanged: {
      if (status === Image.Error && source !== root.wallpaperFallback)
        source = root.wallpaperFallback
    }
  }

  FastBlur {
    anchors.fill: parent
    source: wallpaperImg
    radius: 16
    transparentBorder: true
    // Кешуємо блюр у шарі — без layer 3 монітори = 3× full-screen blur 60fps
    layer.enabled: true
    layer.smooth: true
  }

  // Затемнення поверх блюра
  Rectangle {
    anchors.fill: parent
    color: "#000000"
    opacity: 0.35
  }

  Text {
    id: clockText
    anchors {
      horizontalCenter: parent.horizontalCenter
      top: parent.top
      topMargin: 120
    }
    text: Qt.formatDateTime(clock.date, "HH:mm")
    color: root.palette.textLight
    font.family: root.palette.font
    font.pixelSize: 120
    font.weight: Font.Normal
    style: Text.Outline
    styleColor: "#40000000"
  }

  Text {
    id: dateText
    anchors {
      horizontalCenter: parent.horizontalCenter
      top: clockText.bottom
      topMargin: 8
    }
    text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
    color: root.palette.muted
    font.family: root.palette.font
    font.pixelSize: 24
    style: Text.Outline
    styleColor: "#30000000"
  }

  Text {
    id: userText
    anchors {
      horizontalCenter: parent.horizontalCenter
      bottom: passwordLayout.top
      bottomMargin: 32
    }
    text: root.context.userName
    color: root.palette.fg
    font.family: root.palette.font
    font.pixelSize: 20
    opacity: 0.8
  }

  ColumnLayout {
    id: passwordLayout
    anchors {
      horizontalCenter: parent.horizontalCenter
      top: parent.verticalCenter
      topMargin: -12
    }
    spacing: 8

    Rectangle {
      id: inputBg
      // Єдина дитина колонки — поле завжди строго по центру; бейдж
      // розкладки живе всередині (якори до parent валідні). z щоб меню
      // розкладки перекривало текст помилки під полем.
      z: 2
      // Розширюється під довгий пароль миттєво (без Behavior: анімована
      // ширина відставала від точок і вони на мить обрізались). Далі
      // максимуму точки скроляться через dotsViewport, краї цілі (clip).
      implicitWidth: Math.max(280, Math.min(dotsRow.implicitWidth + 56, 560, Math.max(0, root.width - 220)))
      implicitHeight: 46
      radius: 23
      // Без clip: бейдж — дитина inputBg поза його межами, різати його
      // не можна; точки ріже dotsViewport з власним clip нижче
      color: root.palette.bg0H
      opacity: hiddenInput.activeFocus ? 0.7 : 0.5
      border.width: hiddenInput.activeFocus ? 1 : 0
      border.color: root.palette.mutedAlt
      Behavior on opacity { NumberAnimation { duration: root._d(200) } }

      // Прихований TextInput — тільки приймає введення (echoMode Password щоб не
      // світився в accessibility/clipboard, ImhHiddenText + SensitiveData)
      TextInput {
        id: hiddenInput
        anchors.fill: parent
        color: "transparent"
        echoMode: TextInput.Password
        inputMethodHints: Qt.ImhHiddenText | Qt.ImhSensitiveData
        passwordCharacter: " "
        focus: true
        enabled: !root.context.unlockInProgress && root.context.lockoutRemaining === 0

        onTextChanged: root.context.currentText = text
        onAccepted: root.context.tryUnlock()
      }
      // Синхронізація назад: коли LockContext очищає currentText
      // (при lock/fail/success), скидаємо текст поля
      Connections {
        target: root.context
        function onCurrentTextChanged() {
          if (hiddenInput.text !== root.context.currentText)
            hiddenInput.text = root.context.currentText
        }
      }

      // Анімовані точки замість символів. В'юпорт з полями + автоскрол
      // до хвоста: поки влазять — по центру, довший пароль — видно
      // останні символи, краї пігулки не розриваються (clip на inputBg).
      Item {
        id: dotsViewport
        anchors.fill: parent
        anchors.leftMargin: 28
        anchors.rightMargin: 28
        clip: true

        Row {
          id: dotsRow
          spacing: 6
          anchors.verticalCenter: parent.verticalCenter
          x: Math.min((parent.width - width) / 2, parent.width - width)
          Behavior on x { NumberAnimation { duration: root._d(150); easing.type: Easing.OutCubic } }

          Repeater {
            model: hiddenInput.text.length

            delegate: Text {
              text: "\u25CF"
              color: root.palette.textLight
              font.family: root.palette.font
              font.pixelSize: 12

              NumberAnimation on scale { from: 0; to: 1; duration: root._d(400); easing.type: Easing.OutCubic }
              NumberAnimation on opacity { from: 0; to: 1; duration: root._d(350) }
            }
          }
        }
      }

      // Бейдж розкладки праворуч від поля (дитина inputBg — якори до
      // parent валідні). ЛКМ — next (як віджет в барі), ПКМ — інлайн-
      // список. Кліки повертають фокус паролю вручну.
      Item {
        id: kbBadge
        anchors {
          left: parent.right
          verticalCenter: parent.verticalCenter
          leftMargin: 10
        }
        width: kbPill.implicitWidth
        height: kbPill.implicitHeight
        opacity: 0

        Rectangle {
          id: kbPill
          anchors.centerIn: parent
          implicitWidth: kbText.implicitWidth + 30
          implicitHeight: 34
          radius: 17
          color: root.palette.bg0H
          opacity: kbMouse.containsMouse ? 0.85 : 0.6
          border.width: kbMouse.containsMouse ? 1 : 0
          border.color: root.palette.mutedAlt
          Behavior on opacity { NumberAnimation { duration: root._d(150) } }

          Text {
            id: kbText
            anchors.centerIn: parent
            text: root.kbDisplayText
            color: root.kbHovered ? root.palette.green : root.palette.textLight
            font.family: root.palette.font
            font.pixelSize: 14
            scale: root.kbHovered ? 1.08 : 1.0
            Behavior on color { ColorAnimation { duration: root._d(220) } }
            Behavior on scale {
              NumberAnimation { duration: root._d(120); easing.type: Easing.OutBack; easing.overshoot: 2.5 }
            }
          }

          MouseArea {
            id: kbMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true
            onEntered: root.kbHovered = true
            onExited: root.kbHovered = false
            onClicked: mouse => {
              if (mouse.button === Qt.LeftButton) {
                root.kbListOpen = false
                kbNextProc.running = true
              } else {
                if (root.kbListOpen) {
                  root.kbListOpen = false
                } else {
                  root.kbRefreshMenu()
                  root.kbListOpen = true
                }
              }
              hiddenInput.forceActiveFocus()
            }
          }
        }

        Rectangle {
          id: kbMenu
          anchors {
            top: kbPill.bottom
            right: kbPill.right
            topMargin: 8
          }
          width: 140
          height: kbMenuCol.implicitHeight + 16
          radius: 10
          color: root.palette.bg0H
          opacity: 0.95
          border.width: 1
          border.color: root.palette.mutedAlt
          visible: root.kbListOpen && root.kbLayoutsModel.length > 0

          Column {
            id: kbMenuCol
            anchors {
              left: parent.left
              right: parent.right
              top: parent.top
              topMargin: 8
              leftMargin: 6
              rightMargin: 6
            }
            spacing: 2

            Repeater {
              model: root.kbLayoutsModel

              delegate: Rectangle {
                required property var modelData
                required property int index
                readonly property bool isActive: modelData.active

                width: kbMenuCol.width
                height: 28
                radius: 6
                color: kbRowArea.containsMouse ? root.palette.bg2 : "transparent"
                Behavior on color { ColorAnimation { duration: root._d(120) } }

                Text {
                  anchors {
                    left: parent.left
                    leftMargin: 10
                    verticalCenter: parent.verticalCenter
                  }
                  text: modelData.label
                  color: isActive ? root.palette.green : root.palette.fg
                  font.family: root.palette.font
                  font.pixelSize: 12
                  font.bold: isActive
                }

                Rectangle {
                  opacity: isActive ? 1 : 0
                  anchors {
                    right: parent.right
                    rightMargin: 10
                    verticalCenter: parent.verticalCenter
                  }
                  width: 6
                  height: 6
                  radius: 3
                  color: root.palette.green
                  Behavior on opacity { NumberAnimation { duration: root._d(150); easing.type: Easing.OutCubic } }
                }

                MouseArea {
                  id: kbRowArea
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  hoverEnabled: true
                  onClicked: {
                    if (root.kbMainKeyboard !== "") {
                      kbSwitchProc.command = ["hyprctl", "switchxkblayout", root.kbMainKeyboard, String(index)]
                      kbSwitchProc.running = true
                    }
                    root.kbListOpen = false
                    hiddenInput.forceActiveFocus()
                  }
                }
              }
            }
          }
        }
      }
    }

    Text {
      id: failureText
      Layout.alignment: Qt.AlignHCenter
      visible: root.context.showFailure
      text: root.context.lockoutRemaining > 0
        ? "Too many attempts. Try again in " + root.context.lockoutRemaining + "s"
        : "Incorrect password"
      color: root.palette.danger
      font.family: root.palette.font
      font.pixelSize: 14
      opacity: visible ? 1 : 0

      Behavior on opacity { NumberAnimation { duration: root._d(200) } }

      Timer {
        running: root.context.showFailure
        interval: 3000
        onTriggered: root.context.showFailure = false
      }
    }

    // Повідомлення "Unlocking..." поки PAM обробляє пароль
    Text {
      Layout.alignment: Qt.AlignHCenter
      visible: root.context.unlockInProgress
      text: "Unlocking..."
      color: root.palette.muted
      font.family: root.palette.font
      font.pixelSize: 13
    }
  }

  RowLayout {
    id: powerRow
    anchors {
      horizontalCenter: parent.horizontalCenter
      bottom: parent.bottom
      bottomMargin: 60
    }
    spacing: 24

    property var actions: [
      { icon: "\uF186", tooltip: "Suspend", cmd: ["/usr/bin/systemctl", "suspend"] },
      { icon: "\uF021", tooltip: "Reboot", cmd: ["/usr/bin/systemctl", "reboot"] },
      { icon: "\uF011", tooltip: "Shutdown", cmd: ["/usr/bin/systemctl", "poweroff"] }
    ]

    Repeater {
      model: parent.actions

      delegate: Item {
        required property var modelData
        readonly property var act: modelData

        implicitWidth: 56
        implicitHeight: 56

        Rectangle {
          anchors.fill: parent
          radius: 14
          color: btnArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
          Behavior on color { ColorAnimation { duration: root._d(150) } }

          Text {
            anchors.centerIn: parent
            text: act.icon
            color: btnArea.containsMouse ? root.palette.textLight : root.palette.mutedAlt
            font.family: root.palette.font
            font.pixelSize: 24
            Behavior on color { ColorAnimation { duration: root._d(150) } }
          }

          MouseArea {
            id: btnArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              powerProc.command = act.cmd
              powerProc.running = true
            }
          }
        }
      }
    }
  }

  Process {
    id: powerProc
    onExited: running = false
  }
}
