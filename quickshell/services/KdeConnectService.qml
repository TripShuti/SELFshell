// ============================================================
// quickshell/services/KdeConnectService.qml — обгортка над kcd (Go KDE Connect) для battery + ping/ring + share + notification (v1)
// ============================================================
import Quickshell
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
  property bool isPaired: false
  property int batteryCharge: -1
  property bool batteryCharging: false
  property var recentNotifications: [] // [{appName,title,text,deviceId,timestamp}]
  property var shareProgress: null // {file,current,total} або null
  property string lastSharePath: ""
  property string lastClipboard: ""
  property var sftpVolumes: []
  property string sftpMountPoint: ""
  property string sftpInfo: ""
  property var lastPhoneNotif: null // для дедупу з NotificationServer (kcd notify-send)
  property double lastPhoneNotifTime: 0
  property var pendingPairRequest: null // {deviceId, deviceName, timestamp} — запит з телефону
  signal pairRequested(var req)
  signal pairFinished(var result)

  // SFTP mount dir — читаємо з kcd.toml, без хардкоду ~/Downloads/kcd/mnt
  property string sftpMountDir: ""
  property string sftpMountDirDisplay: {
    if (sftpMountDir === "") return "~/Downloads/kcd/mnt"
    var home = String(Quickshell.env("HOME") ?? "")
    if (home && sftpMountDir.startsWith(home)) return "~" + sftpMountDir.substring(home.length)
    return sftpMountDir
  }
  FileView {
    id: kcdConfigFile
    path: (String(Quickshell.env("HOME") ?? "") !== "" ? String(Quickshell.env("HOME")) : "/home/trip") + "/.config/kcd/kcd.toml"
    blockLoading: true
    onLoaded: root._parseSftpMountDir()
    onLoadFailed: function(err) {
      if (String(err) !== "1") console.warn("[kcd] kcd.toml load failed", err)
      root._parseSftpMountDir()
    }
  }
  function _parseSftpMountDir() {
    var txt = String(kcdConfigFile.text() ?? "")
    var m = txt.match(/\[sftp\][\s\S]*?mount_dir\s*=\s*["']([^"']+)["']/)
    var home = String(Quickshell.env("HOME") ?? "/home/trip")
    if (m && m[1]) {
      var dir = String(m[1]).trim()
      if (dir.startsWith("~/")) dir = home + dir.substring(1)
      else if (dir.startsWith("$HOME")) dir = dir.replace("$HOME", home)
      else if (!dir.startsWith("/")) dir = home + "/" + dir
      root.sftpMountDir = dir
      return
    }
    var dm = txt.match(/download_dir\s*=\s*["']([^"']+)["']/)
    if (dm && dm[1]) {
      var d = String(dm[1]).trim()
      if (d.startsWith("~/")) d = home + d.substring(1)
      root.sftpMountDir = d.replace(/\/$/, "") + "/mnt"
      return
    }
    root.sftpMountDir = home + "/Downloads/kcd/mnt"
  }

  // Обмеження історії сповіщень (не роздувати пам'ять)
  readonly property int maxNotifications: 10

  // Дедуп-мапа для сповіщень: hash(normalized app|title|text|device) → час останнього показу (ms)
  // Потрібна бо kcd інколи шле дублікати при реконекті/watch-рестарті з різними id та старими timestamp
  property var _notifSeen: ({})

  // Чи ввімкнено віджет взагалі (читається з AppConfig в shell.qml)
  property bool enabled: true
  property bool dnd: false

  // --- Внутрішнє ---
  property int _watchRestarts: 0

  // Перевірка наявності kcd (kcd --version)
  Process {
    id: installCheck
    command: ["kcd", "--version"]
    stdout: StdioCollector {
      id: installOut
      waitForEnd: true
    }
    onExited: (code) => {
      root.installed = (code === 0)
      if (root.installed && root.enabled) {
        devicesProc.command = ["kcd", "devices", "--json"]
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
    command: ["kcd", "devices", "--json"]
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
  }

  Timer {
    id: pollTimer
    interval: 30000
    repeat: true
    onTriggered: {
      if (root.installed && root.enabled && !devicesProc.running) {
        devicesProc.command = ["kcd", "devices", "--json"]
        devicesProc.running = true
      }
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
    onStarted: {
      // стабільний запуск 60с скидає лічильник падінь — щоб 5 швидких крашів не застрягали назавжди,
      // але й щоб не скидати одразу (інакше ліміт 5 ніколи не спрацює)
      watchStableTimer.restart()
    }
    onExited: (code) => {
      watchStableTimer.stop()
      if (!root.enabled || !root.installed) return
      // watch впав (daemon перезапустився тощо) — рестарт з бек-оффом
      if (root._watchRestarts < 5) {
        root._watchRestarts++
        watchRestartTimer.interval = Math.min(1000 * Math.pow(2, root._watchRestarts), 15000)
        watchRestartTimer.restart()
      } else {
        console.warn("[kcd] watch gave up after 5 restarts, will retry in 60s")
        watchStableTimer.interval = 60000
        watchStableTimer.restart()
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

  Timer {
    id: watchStableTimer
    interval: 60000
    repeat: false
    onTriggered: {
      if (root._watchRestarts !== 0) console.log("[kcd] watch stable 60s — reset restarts")
      root._watchRestarts = 0
      // якщо watch був у стані give-up (5 падінь) — пробуємо знову
      if (root.enabled && root.installed && !watchProc.running) {
        watchProc.running = true
      }
    }
  }

  function _updatePrimary() {
    var devs = root.devices
    var primary = null
    // 1. Paired + Connected — ідеальний primary
    for (var i = 0; i < devs.length; i++) {
      var d = devs[i]
      if (!d) continue
      var st1 = String(d.state ?? d.State ?? "").toUpperCase()
      var paired1 = st1 === "PAIRED" || !!(d.Paired ?? d.paired ?? d.isPaired)
      var connected1 = !!(d.Connected ?? d.connected ?? d.isConnected ?? false) || st1 === "CONNECTED"
      if (paired1 && connected1) { primary = d; break }
    }
    // 2. Paired (навіть якщо offline) — краще ніж UNPAIRED+Connected
    if (!primary) {
      for (var j = 0; j < devs.length; j++) {
        var dj = devs[j]
        if (!dj) continue
        var st2 = String(dj.state ?? dj.State ?? "").toUpperCase()
        var paired2 = st2 === "PAIRED" || !!(dj.Paired ?? dj.paired ?? dj.isPaired)
        if (paired2) { primary = dj; break }
      }
    }
    // 3. Будь-який Connected (навіть UNPAIRED) — покажемо як "Unpaired, needs pair"
    if (!primary) {
      for (var k = 0; k < devs.length; k++) {
        var dk = devs[k]
        if (!dk) continue
        var connected3 = !!(dk.Connected ?? dk.connected ?? dk.isConnected ?? false) || String(dk.state ?? "").toUpperCase() === "CONNECTED"
        if (connected3) { primary = dk; break }
      }
    }
    if (!primary && devs.length > 0) primary = devs[0]
    root.connectedDevice = primary
    if (primary) {
      root.primaryDeviceId = String(primary.ID ?? primary.Id ?? primary.id ?? primary.deviceId ?? "")
      root.primaryDeviceName = String(primary.Name ?? primary.name ?? primary.deviceName ?? primary.DeviceName ?? root.primaryDeviceId)
      var st = String(primary.state ?? primary.State ?? "")
      var isConn = !!(primary.Connected ?? primary.connected ?? false)
      if (!isConn && st.toUpperCase() === "CONNECTED") isConn = true
      var isPa = st.toUpperCase() === "PAIRED" || !!(primary.Paired ?? primary.paired ?? primary.isPaired)
      // якщо state порожній, fallback на paired flag
      if (st === "" && !isPa) isPa = !!(primary.Paired ?? primary.paired)
      root.isPaired = isPa
      root.isReachable = isPa && isConn
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
      root.isPaired = false
      root.isReachable = false
    }
  }

  function _handleEvent(ev) {
    if (!ev || !ev.type) return
    var t = String(ev.type)
    var payload = ev.payload ?? ev.data ?? {}
    var devId = String(ev.deviceId ?? ev.deviceID ?? payload.deviceId ?? payload.id ?? "")
    // Запит на парування з телефону — показуємо попап (phone-initiated pairing)
    if (t === "pair.requested" && devId) {
      var reqName = String(payload.name ?? payload.deviceName ?? payload.appName ?? devId)
      root.pendingPairRequest = { deviceId: devId, deviceName: reqName, timestamp: ev.timestamp ?? new Date().toISOString() }
      root.pairRequested(root.pendingPairRequest)
      if (!devicesProc.running) {
        devicesProc.command = ["kcd", "devices", "--json"]
        devicesProc.running = true
      }
      return
    }
    if ((t === "pair.accepted" || t === "pair.rejected") && devId) {
      if (root.pendingPairRequest && root.pendingPairRequest.deviceId === devId) {
        root.pendingPairRequest = null
        root.pairFinished({ deviceId: devId, accepted: t === "pair.accepted" })
      }
      if (!devicesProc.running) {
        devicesProc.command = ["kcd", "devices", "--json"]
        devicesProc.running = true
      }
      return
    }
    // оновлюємо devices через опитування при зміні підключення
    if (t === "device.connected" || t === "device.disconnected" || t === "device.paired" || t === "device.unpaired") {
      if (t === "device.paired" && devId) {
        // при успішному паруванні чистимо pending
        if (root.pendingPairRequest && root.pendingPairRequest.deviceId === devId) {
          root.pendingPairRequest = null
          root.pairFinished({ deviceId: devId, accepted: true })
        }
        if (!root.primaryDeviceId) {
          root.primaryDeviceId = devId
          root.primaryDeviceName = String(payload.name ?? payload.deviceName ?? devId)
        }
        if (devId === root.primaryDeviceId || !root.primaryDeviceId) {
          root.isPaired = true
          root.isReachable = true
        }
      } else if (t === "device.unpaired" && devId) {
        if (devId === root.primaryDeviceId) {
          root.isPaired = false
          root.isReachable = false
        }
      } else if (t === "device.connected" && devId) {
        // Не ставимо isReachable напряму — дочекаємося poll, щоб перевірити paired
        // UNPAIRED+Connected не має бути reachable
        if (!root.primaryDeviceId) {
          root.primaryDeviceId = devId
          root.primaryDeviceName = String(payload.name ?? payload.deviceName ?? devId)
          // тимчасово isReachable лишаємо як isPaired (false для UNPAIRED), poll виправить
          root.isReachable = root.isPaired
        }
      } else if (t === "device.disconnected") {
        if (!devId || devId === root.primaryDeviceId || root.primaryDeviceId === "") root.isReachable = false
      }
      if (!devicesProc.running) {
        devicesProc.command = ["kcd", "devices", "--json"]
        devicesProc.running = true
      }
      return
    }
    if (t === "battery.update" || t === "battery.threshold") {
      var charge = payload.charge ?? payload.level ?? payload.percentage
      var charging = payload.charging ?? payload.isCharging ?? false
      if (charge !== undefined && charge !== null) root.batteryCharge = Math.round(Number(charge))
      root.batteryCharging = !!charging
      // якщо прийшла батарея — девайс точно reachable, але тільки якщо це primary або primary ще не вибраний
      // і тільки якщо paired (UNPAIRED+Connected не має бути reachable)
      if (root.batteryCharge >= 0) {
        if ((!devId || devId === root.primaryDeviceId || !root.primaryDeviceId) && root.isPaired) root.isReachable = true
      }
      if (devId && !root.primaryDeviceId) {
        root.primaryDeviceId = devId
        root.primaryDeviceName = String(payload.name ?? devId)
      }
      return
    }
    if (t === "notification" || t === "notification.received") {
      // payload.icon може бути шляхом до кешованого файлу (kcd fetch_icons) або іменем
      var iconSrc = String(payload.icon ?? payload.appIcon ?? payload.iconPath ?? "")
      // Стабільний ключ Android-нотифікації (0|org.telegram... ) — не змінюється при реплеї,
      // на відміну від requestReplyId/UUID який kcd генерує новий при кожному watch-рестарті — його не використовуємо
      var stableKey = String(payload.key ?? payload.tag ?? "")
      var nid = String(payload.id ?? stableKey ?? "")
      // Нормалізуємо текст для дедупу: trim + схлопуємо пробіли/переведення рядків
      function _norm(s) { return String(s ?? "").trim().replace(/\s+/g, " ") }
      var normTitle = _norm(payload.title ?? payload.summary ?? "")
      var normText = _norm(payload.text ?? payload.body ?? "")
      var normApp = _norm(payload.appName ?? payload.app ?? "Phone")
      // kcd інколи шле одне й те саме сповіщення повторно (при реконекті, при watch рестарті) — дедуплікуємо
      // Зберігаємо останнє для дедупу з NotificationServer (kcd notify-send дублює)
      var _n = {
        appName: normApp,
        title: normTitle,
        text: normText,
        id: nid !== "" ? nid : String(Date.now()) + "_" + Math.random().toString(36).slice(2,6),
        key: stableKey,
        icon: iconSrc,
        deviceId: devId,
        timestamp: ev.timestamp ?? new Date().toISOString(),
        _arrival: Date.now()
      }
      root.lastPhoneNotif = _n
      root.lastPhoneNotifTime = Date.now()
      // Зберігаємо в історію навіть при muted (глушимо тільки тост), інакше попап порожній при muted
      // Дедуп: 0) по stableKey (якщо є) — якщо key вже в історії і контент той же → реплей → ігнор
      //        якщо key той же але контент новий → це справжнє оновлення, лишаємо як нове (не оновлюємо існуючу, "залишити як є")
      //        1) по id (якщо не fallback) — завжди, 2) по нормалізованому контенту без часового ліміту
      // Контент-дедуп без вікна: kcd реплеїть весь pending set при кожному новому повідомленні (62мс пачка),
      // тому будь-який повтор того ж app|title|text має ігноруватись поки нотифікація не canceled на телефоні
      var arr = root.recentNotifications.slice()
      var isDup = false
      var now = Date.now()
      // 0) stableKey-дедуп (пріоритет)
      if (!isDup && stableKey !== "") {
        for (var k = 0; k < arr.length; k++) {
          var ek = arr[k]
          var ekKey = String(ek.key ?? "")
          // старі записи до міграції зберігалися з id==key, перевіряємо обидва
          if ((ekKey !== "" && ekKey === stableKey) || (ekKey === "" && ek.id === stableKey)) {
            if (_norm(ek.title) === normTitle && _norm(ek.text) === normText && _norm(ek.appName) === normApp && ek.deviceId === devId) {
              isDup = true
            }
            // якщо контент інший — це не дублікат, а нове сповіщення з тим же key (напр. оновлений summary)
            // "залишити як є" — не оновлюємо існуючу, просто додаємо нову
            break
          }
        }
      }
      // 1) id-дедуп (тільки для реальних id kcd, fallback з "_" — ігноруємо)
      if (!isDup && _n.id.indexOf("_") === -1) {
        for (var i = 0; i < arr.length; i++) {
          if (arr[i].id === _n.id) { isDup = true; break }
        }
      }
      // 2) контент-дедуп по нормалізованому хешу без часового ліміту
      // kcd шле весь active set при кожному новому повідомленні — тому будь-який повтор того ж контенту,
      // навіть через хвилини після Clear, має ігноруватись поки не canceled. Хеш живе в _notifSeen до canceled.
      if (!isDup) {
        var hash = normApp + "|" + normTitle + "|" + normText + "|" + devId
        if (root._notifSeen[hash] !== undefined) {
          isDup = true
        } else {
          // fallback: лінійний скан по історії (на випадок якщо хеш-мапа була скинута)
          for (var i = 0; i < arr.length; i++) {
            var ex = arr[i]
            // порівнюємо нормалізовано
            if (_norm(ex.appName) === normApp && _norm(ex.title) === normTitle && _norm(ex.text) === normText && ex.deviceId === _n.deviceId) {
              isDup = true
              break
            }
          }
        }
        if (!isDup) {
          // додаємо в мапу без часового чищення — чиститься тільки при canceled
          var copy = Object.assign({}, root._notifSeen)
          copy[hash] = now
          root._notifSeen = copy
        }
      }
      if (!isDup) {
        arr.unshift(_n)
        if (arr.length > root.maxNotifications) arr = arr.slice(0, root.maxNotifications)
        root.recentNotifications = arr
      } else {
        // console.log("[kcd] dup suppressed", _n.appName, _n.title.slice(0,20), "key", stableKey.slice(0,20))
      }
      // DND: тільки попап, нікуди більше (тост/звук/ControlCenter) — recent вже додано
      if (root.dnd) return
      if (isDup) return
      // показати тост через Bar (сигнал) — тільки для нових і не в DND
      root.notificationReceived(_n)
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
    // Clipboard — телефон прислав буфер (або підтвердження push)
    if (t.indexOf("clipboard") !== -1) {
      var clipTxt = String(payload.content ?? payload.text ?? payload.clipboard ?? payload.data ?? "")
      if (clipTxt) {
        root.lastClipboard = clipTxt.slice(0, 500)
        if (root.dnd) return
        // показуємо тост, щоб було видно що прийшло (тільки якщо не DND — тільки попап лишає lastClipboard)
        root.notificationReceived({ appName: "Clipboard", title: "From phone", text: clipTxt.slice(0, 80), appIcon: "edit-paste", isPhone: true, actions: [] })
      }
      return
    }
    // SFTP — томи / монтування / інфо
    if (t.indexOf("sftp") !== -1) {
      if (payload.volumes && Array.isArray(payload.volumes)) root.sftpVolumes = payload.volumes
      else if (payload.volume) root.sftpVolumes = [payload.volume]
      else if (Array.isArray(payload)) root.sftpVolumes = payload
      if (payload.mountPoint) root.sftpMountPoint = String(payload.mountPoint)
      if (payload.path) root.sftpMountPoint = String(payload.path)
      if (payload.info) root.sftpInfo = String(payload.info)
      else root.sftpInfo = JSON.stringify(payload).slice(0, 200)
      return
    }
    // Notification dismissed on phone — прибираємо з історії
    if (t === "notification.canceled" || t === "notification.cancelled") {
      var cancelId = String(payload.id ?? payload.requestReplyId ?? payload.key ?? "")
      var cancelKey = String(payload.key ?? "")
      if (cancelId || cancelKey) {
        // знаходимо що видаляємо, щоб почистити _notifSeen
        var toRemove = []
        for (var ci = 0; ci < root.recentNotifications.length; ci++) {
          var cn = root.recentNotifications[ci]
          var nid = String(cn.id ?? "")
          var nkey = String(cn.key ?? "")
          if ((cancelId && nid === cancelId) || (cancelKey && nkey === cancelKey) || (cancelKey && nid === cancelKey)) toRemove.push(cn)
        }
        var filtered = root.recentNotifications.filter(n => {
          var nid2 = String(n.id ?? "")
          var nkey2 = String(n.key ?? "")
          if (cancelId && nid2 === cancelId) return false
          if (cancelKey && nkey2 === cancelKey) return false
          if (cancelKey && nid2 === cancelKey) return false
          return true
        })
        if (filtered.length !== root.recentNotifications.length) {
          root.recentNotifications = filtered
          // чистимо хеш-мапу дедупу для видалених, щоб той же контент міг знову показатись після dismiss
          if (toRemove.length > 0) {
            var copy2 = Object.assign({}, root._notifSeen)
            for (var ri = 0; ri < toRemove.length; ri++) {
              var rn = toRemove[ri]
              var h = String(rn.appName ?? "").trim().replace(/\s+/g, " ") + "|" + String(rn.title ?? "").trim().replace(/\s+/g, " ") + "|" + String(rn.text ?? "").trim().replace(/\s+/g, " ") + "|" + String(rn.deviceId ?? "")
              if (copy2[h] !== undefined) delete copy2[h]
              // також видаляємо за key, якщо раптом хеш інший
              var hk = String(rn.key ?? "")
              if (hk && copy2[hk] !== undefined) delete copy2[hk]
            }
            root._notifSeen = copy2
          }
        }
      }
      return
    }
    // Share text/url — телефон прислав текст або лінк
    if (t === "share.text" || t === "share.url") {
      var shareTxt = String(payload.text ?? payload.url ?? "")
      if (shareTxt) {
        root.lastClipboard = shareTxt.slice(0, 500)
        if (!root.dnd) root.notificationReceived({ appName: "Share", title: t === "share.url" ? "Link from phone" : "Text from phone", text: shareTxt.slice(0, 120), appIcon: "edit-paste", isPhone: true, actions: [] })
      }
      return
    }
    // Telephony — дзвінки
    if (t.indexOf("telephony") !== -1) {
      var contact = String(payload.contactName ?? payload.phoneNumber ?? "")
      var phoneNum = String(payload.phoneNumber ?? "")
      var teleTitle = t === "telephony.ringing" ? "Incoming call" : (t === "telephony.missed" ? "Missed call" : (t === "telephony.talking" ? "Call in progress" : "Call ended"))
      var teleText = contact || phoneNum
      if (t === "telephony.ringing" || t === "telephony.missed") {
        if (!root.dnd) root.notificationReceived({ appName: "Phone", title: teleTitle, text: teleText, appIcon: "call-start", isPhone: true, actions: [] })
      }
      return
    }
    // Пінг
    if (t === "ping.received" || t === "ping") {
      if (!root.dnd) root.notificationReceived({ appName: "Ping", title: "Ping received", text: devId ? devId.slice(0,8) : "", appIcon: "dialog-information", isPhone: true, actions: [] })
      return
    }
    // Інші події ігноруємо (mpris/connectivity/volume/sms обробляються вище або не потрібні)
    // Розкоментуй для дебагу нових типів kcd:
    // console.log("[kcd] unhandled event: " + t + " " + JSON.stringify(payload).slice(0, 180))
  }

  signal notificationReceived(var notif)

  // Публічні дії (викликаються з попапа) — тонкі обгортки, реальні
  // Process-и живуть в попапі, щоб не множити логіку помилок тут.
  // Лишаємо для сумісності, якщо хтось викличе напряму.
  function refresh() {
    if (!devicesProc.running) {
      devicesProc.command = ["kcd", "devices", "--json"]
      devicesProc.running = true
    }
  }

  // Життєвий цикл
  Component.onCompleted: {
    // перевірка наявності kcd при старті
    installCheck.running = true
    // підвантажуємо mount_dir з kcd.toml
    if (kcdConfigFile) kcdConfigFile.reload()
  }
  onEnabledChanged: {
    if (root.enabled) {
      if (!root.installed) installCheck.running = true
      else {
        if (!devicesProc.running) {
          devicesProc.command = ["kcd", "devices", "--json"]
          devicesProc.running = true
        }
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
