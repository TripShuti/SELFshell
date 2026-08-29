// ============================================================
// KdeConnectService.qml — обгортка над kcd (Go KDE Connect)
// для battery + ping/ring + share + notification (v1)
// ============================================================
import Quickshell.Io
import QtQuick

// Сервіс телефону: перевіряє наявність kcd, слухає
// `kcd watch --json` (battery/notification/share/device) та
// періодично опитує `kcd devices --json` для початкового стану.
// Живе один екземпляр в shell.qml і прокидається в Bar через window.kdeConnect.
Item {
  id: root
  visible: false

  // --- Публічний стан ---
  property bool installed: false
  property bool daemonRunning: watchProc.running
  property var devices: []
  property var connectedDevice: null
  property string primaryDeviceId: ""
  property string primaryDeviceName: ""
  property bool isReachable: false
  property int batteryCharge: -1
  property bool batteryCharging: false
  property var recentNotifications: [] // [{appName,title,text,deviceId,timestamp}]
  property var shareProgress: null // {file,current,total} або null
  property string lastSharePath: ""
  property string errorText: ""

  // Обмеження історії сповіщень (не роздувати пам'ять)
  readonly property int maxNotifications: 10

  // Чи ввімкнено віджет взагалі (читається з AppConfig в shell.qml)
  property bool enabled: true

  // --- Внутрішнє ---
  property int _watchRestarts: 0

  // Перевірка наявності kcd (kcd --version)
  Process {
    id: installCheck
    command: ["kcd", "--version"]
    stdout: StdioCollector {
      id: installOut
      waitForEnd: true
      onStreamFinished: {
        // exitCode перевіряється в onExited, тут лише текст
      }
    }
    onExited: (code) => {
      root.installed = (code === 0)
      if (root.installed && root.enabled) {
        // одразу опитуємо пристрої і стартуємо watch
        devicesProc.running = true
        watchRestartTimer.stop()
        if (!watchProc.running) watchProc.running = true
        pollTimer.running = true
      } else {
        watchProc.running = false
        pollTimer.running = false
      }
    }
  }

  // Періодичне опитування пристроїв (страховка для початкового стану та
  // якщо watch ще не прислав battery)
  Process {
    id: devicesProc
    stdout: StdioCollector {
      id: devicesOut
      waitForEnd: true
      onStreamFinished: {
        var txt = String(devicesOut.text ?? "").trim()
        if (!txt) return
        try {
          var arr = JSON.parse(txt)
          // kcd devices --json може повернути об'єкт або масив — нормалізуємо
          if (!Array.isArray(arr)) {
            if (arr.devices && Array.isArray(arr.devices)) arr = arr.devices
            else arr = [arr]
          }
          root.devices = arr
          root._updatePrimary()
        } catch (e) {
          console.warn("[kcd] devices parse failed", e, txt.slice(0, 200))
        }
      }
    }
    onExited: (code) => {
      if (code !== 0) {
        // kcd не запущено або daemon не відповідає — не спамимо
      }
    }
  }

  Timer {
    id: pollTimer
    interval: 30000
    repeat: true
    onTriggered: {
      if (root.installed && root.enabled && !devicesProc.running) devicesProc.running = true
    }
  }

  // Живий стрім подій kcd
  Process {
    id: watchProc
    // без --events щоб отримувати все, фільтруємо в QML
    command: ["kcd", "watch", "--json"]
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: data => {
        var line = String(data ?? "").trim()
        if (!line) return
        try {
          var ev = JSON.parse(line)
          root._handleEvent(ev)
        } catch (e) {
          // kcd watch без --json інколи пише текст — ігноруємо
        }
      }
    }
    onStarted: root._watchRestarts = 0
    onExited: (code) => {
      if (!root.enabled || !root.installed) return
      // watch впав (daemon перезапустився тощо) — рестарт з бек-оффом
      if (root._watchRestarts < 5) {
        root._watchRestarts++
        watchRestartTimer.interval = Math.min(1000 * Math.pow(2, root._watchRestarts), 15000)
        watchRestartTimer.restart()
      }
    }
  }

  Timer {
    id: watchRestartTimer
    repeat: false
    onTriggered: {
      if (root.installed && root.enabled) watchProc.running = true
    }
  }

  function _updatePrimary() {
    var devs = root.devices
    var primary = null
    // шукаємо перший Connected, інакше перший Paired
    for (var i = 0; i < devs.length; i++) {
      var d = devs[i]
      if (!d) continue
      // kcd поля можуть бути Connected/connected/ID/id — нормалізуємо
      var connected = d.Connected ?? d.connected ?? d.isConnected ?? false
      if (connected) { primary = d; break }
    }
    if (!primary) {
      for (var j = 0; j < devs.length; j++) {
        var dj = devs[j]
        if (!dj) continue
        var paired = dj.Paired ?? dj.paired ?? dj.isPaired ?? false
        if (paired) { primary = dj; break }
      }
    }
    if (!primary && devs.length > 0) primary = devs[0]
    root.connectedDevice = primary
    if (primary) {
      root.primaryDeviceId = String(primary.ID ?? primary.Id ?? primary.id ?? primary.deviceId ?? "")
      root.primaryDeviceName = String(primary.Name ?? primary.name ?? primary.deviceName ?? primary.DeviceName ?? root.primaryDeviceId)
      root.isReachable = !!(primary.Connected ?? primary.connected ?? false)
      // батарея може бути в самому device об'єкті
      var ch = primary.Battery ?? primary.battery
      if (ch !== undefined && ch !== null) {
        if (typeof ch === "object") {
          if (ch.charge !== undefined) root.batteryCharge = Math.round(ch.charge)
          if (ch.charging !== undefined) root.batteryCharging = !!ch.charging
        } else if (typeof ch === "number") {
          root.batteryCharge = Math.round(ch)
        }
      }
    } else {
      root.primaryDeviceId = ""
      root.primaryDeviceName = ""
      root.isReachable = false
    }
  }

  function _handleEvent(ev) {
    if (!ev || !ev.type) return
    var t = String(ev.type)
    var payload = ev.payload ?? ev.data ?? {}
    var devId = String(ev.deviceId ?? ev.deviceID ?? payload.deviceId ?? "")
    // оновлюємо devices через опитування при зміні підключення
    if (t === "device.connected" || t === "device.disconnected" || t === "device.paired" || t === "device.unpaired" || t === "pair.requested" || t === "pair.accepted") {
      if (!devicesProc.running) devicesProc.running = true
      // pair.requested — можна показати в попапі, але поки просто оновлюємо
      if (t === "device.connected") {
        root.isReachable = true
      } else if (t === "device.disconnected") {
        // якщо це primary — позначити не reachable, повний список оновить poll
        if (!devId || devId === root.primaryDeviceId) root.isReachable = false
      }
      return
    }
    if (t === "battery.update" || t === "battery.threshold") {
      var charge = payload.charge ?? payload.level ?? payload.percentage
      var charging = payload.charging ?? payload.isCharging ?? false
      if (charge !== undefined && charge !== null) root.batteryCharge = Math.round(Number(charge))
      root.batteryCharging = !!charging
      // також оновити primary якщо збігається
      if (devId && devId === root.primaryDeviceId) {
        // вже оновлено
      }
      return
    }
    if (t === "notification" || t === "notification.received") {
      var n = {
        appName: String(payload.appName ?? payload.app ?? "Phone"),
        title: String(payload.title ?? payload.summary ?? ""),
        text: String(payload.text ?? payload.body ?? ""),
        id: String(payload.id ?? payload.key ?? Date.now()),
        deviceId: devId,
        timestamp: ev.timestamp ?? new Date().toISOString()
      }
      var arr = root.recentNotifications.slice()
      arr.unshift(n)
      if (arr.length > root.maxNotifications) arr = arr.slice(0, root.maxNotifications)
      root.recentNotifications = arr
      // показати тост через Bar (сигнал)
      root.notificationReceived(n)
      return
    }
    if (t === "share.progress") {
      root.shareProgress = {
        file: String(payload.file ?? payload.filename ?? ""),
        current: Number(payload.current ?? 0),
        total: Number(payload.total ?? 0)
      }
      return
    }
    if (t === "share.complete" || t === "share.received") {
      root.shareProgress = null
      root.lastSharePath = String(payload.path ?? payload.file ?? "")
      return
    }
  }

  signal notificationReceived(var notif)

  // Публічні дії (викликаються з попапа) — тонкі обгортки, реальні
  // Process-и живуть в попапі, щоб не множити логіку помилок тут.
  // Лишаємо для сумісності, якщо хтось викличе напряму.
  function refresh() {
    if (!devicesProc.running) devicesProc.running = true
  }

  // Життєвий цикл
  Component.onCompleted: {
    // перевірка наявності kcd при старті
    installCheck.running = true
  }
  onEnabledChanged: {
    if (root.enabled) {
      if (!root.installed) installCheck.running = true
      else {
        if (!devicesProc.running) devicesProc.running = true
        if (!watchProc.running) watchProc.running = true
        pollTimer.running = true
      }
    } else {
      watchProc.running = false
      pollTimer.running = false
    }
  }

  // Таймер для повторної перевірки installed якщо спочатку не було
  Timer {
    id: recheckTimer
    interval: 60000
    repeat: true
    running: !root.installed && root.enabled
    onTriggered: installCheck.running = true
  }
}
