// ============================================================
// quickshell/monitors/SelfTrackMonitor.qml — монітор трекера часу: опитує selftrack export, тримає моделі дня
// ============================================================
import Quickshell
import Quickshell.Io
import "../scripts/SelfTrack.js" as ST
import QtQuick

Item {
  id: root

  required property QtObject appConfig

  // Вибрана дата (YYYY-MM-DD), за дефолтом сьогодні
  property string dateStr: _todayStr()
  property int dayActiveMs: 0
  property int dayIdleMs: 0
  property int weekMs: 0
  property string weekLabel: ""
  property int monthMs: 0
  property string monthLabel: ""
  property var appsModel: []
  property var sessionsModel: []
  property var pagesModel: []
  property string pageApp: ""
  property bool loading: false
  // Старт видимого оновлення — щоб спінер встиг обернутись хоча б раз,
  // гасіння loading затримуємо до мінімальних 700мс (export локальний
  // і проходить за ~50мс, інакше видно лише смикання)
  property real _refreshStartMs: 0

  function _finishLoading() {
    var wait = 700 - (Date.now() - root._refreshStartMs)
    if (wait > 0) {
      loadingMinTimer.interval = wait
      loadingMinTimer.restart()
    } else {
      root.loading = false
    }
  }
  property string errorText: ""

  // Активний час СЬОГОДНІ — незалежний від вибраної в попапі дати,
  // щоб віджет завжди показував поточний день
  property int todayActiveMs: 0

  // Короткий текст для віджета бару
  readonly property string todayText: ST.formatShort(root.todayActiveMs)

  function _todayStr() {
    return ST.todayStr()
  }

  function _isToday() {
    return root.dateStr === root._todayStr()
  }

  // Зсув дати на N днів (для навігації в попапі)
  function shiftDate(days) {
    var p = root.dateStr.split("-")
    var d = new Date(parseInt(p[0]), parseInt(p[1]) - 1, parseInt(p[2]))
    d.setDate(d.getDate() + days)
    root.dateStr = d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0")
    root.pageApp = ""
    root.pagesModel = []
    root.refresh()
  }

  function goToday() {
    root.dateStr = root._todayStr()
    root.pageApp = ""
    root.pagesModel = []
    root.refresh()
  }

  // Основне оновлення: день + тиждень + місяць + застосунки + сесії
  function refresh() {
    if (!root.monitorEnabled) return
    if (fetchProc.running) return
    root.loading = true
    root.errorText = ""
    root._refreshStartMs = Date.now()
    loadingMinTimer.stop()
    fetchProc._todayOnly = false
    fetchProc.command = ["selftrack", "export", "--date", root.dateStr]
    fetchProc.running = true
  }

  // Тихе оновлення лічильника віджета (тільки сьогодні, без чіпання
  // вибраної в попапі дати) — викликається поллером коли дивляться минуле
  function refreshToday() {
    if (!root.monitorEnabled) return
    if (fetchProc.running) return
    fetchProc._todayOnly = true
    fetchProc.command = ["selftrack", "export", "--date", root._todayStr()]
    fetchProc.running = true
  }

  // Підвантаження сторінок застосунку (ліниво, по кліку)
  function refreshPages(app) {
    if (fetchPagesProc.running) return
    // Повторний клік по розкритому — згорнути
    if (root.pageApp === app) {
      root.pageApp = ""
      root.pagesModel = []
      return
    }
    fetchPagesProc.command = ["selftrack", "export", "--date", root.dateStr, "--app", app]
    fetchPagesProc._wantApp = app
    fetchPagesProc.running = true
  }

  function collapsePages() {
    root.pageApp = ""
    root.pagesModel = []
  }

  function _applyExport(obj) {
    if (typeof obj !== "object" || obj === null) return
    // Лічильник віджета оновлюємо тільки сьогоднішніми даними, інакше
    // перегляд минулої дати ламав би цифру в барі
    if (obj.date === root._todayStr() && obj.day) {
      root.todayActiveMs = obj.day.active_ms
    }
    root.dayActiveMs = obj.day ? obj.day.active_ms : 0
    root.dayIdleMs = obj.day ? obj.day.idle_ms : 0
    root.weekMs = obj.week ? obj.week.active_ms : 0
    root.weekLabel = obj.week ? (obj.week.from + " – " + obj.week.to) : ""
    root.monthMs = obj.month ? obj.month.active_ms : 0
    root.monthLabel = obj.month ? root.dateStr.substring(0, 7) : ""
    root.appsModel = obj.apps ? obj.apps : []
    root.sessionsModel = obj.sessions ? obj.sessions : []
  }

  // Старт: перше оновлення після завантаження конфіга (той самий
  // патерн що в GenshinMonitor — в onCompleted cfg ще дефолтний)
  Timer {
    interval: 1500
    running: true
    repeat: false
    onTriggered: if (root.monitorEnabled) root.refresh()
  }

  // Живе оновлення раз на хвилину: сьогоднішній день — повністю,
  // минула дата в попапі лишається статичною, але лічильник віджета
  // (сьогодні) оновлюється завжди
  Timer {
    id: pollTimer
    interval: 60000
    running: root.monitorEnabled
    repeat: true
    onTriggered: {
      if (root._isToday()) root.refresh()
      else root.refreshToday()
    }
  }

  // Дотягує спінер до мінімальних 700мс (див. _finishLoading)
  Timer {
    id: loadingMinTimer
    repeat: false
    onTriggered: root.loading = false
  }

  Process {
    id: fetchProc
    property bool _todayOnly: false
    stdout: StdioCollector {
      id: fetchCollector
      waitForEnd: true
      onStreamFinished: {
        var text = fetchCollector.text.trim()
        // Прапорець не скидаємо тут — onExited читає його для того
        // самого запуску; новий запуск виставить його заново
        var todayOnly = fetchProc._todayOnly
        if (text === "") {
          if (!todayOnly) root.errorText = "Empty response"
        } else {
          try {
            var obj = JSON.parse(text)
            if (todayOnly) {
              if (obj.date === root._todayStr() && obj.day) root.todayActiveMs = obj.day.active_ms
            } else {
              root._applyExport(obj)
            }
          } catch (e) {
            if (!todayOnly) root.errorText = "Parse error"
          }
        }
        // Тихе фонове оновлення гасне одразу, видиме — через мінімальний спін
        if (todayOnly) root.loading = false
        else root._finishLoading()
      }
    }
    onExited: (code) => {
      running = false
      if (fetchProc._todayOnly) {
        root.loading = false
      } else {
        if (code !== 0 && root.errorText === "") root.errorText = "selftrack failed (" + code + ")"
        if (root.loading) root._finishLoading()
      }
    }
  }

  Process {
    id: fetchPagesProc
    property string _wantApp: ""
    stdout: StdioCollector {
      id: pagesCollector
      waitForEnd: true
      onStreamFinished: {
        var text = pagesCollector.text.trim()
        if (text === "") return
        try {
          var obj = JSON.parse(text)
          // Застосунок могли перемкнути поки йшов запит — показуємо
          // тільки якщо збігається з запитаним
          if (obj.page_app === fetchPagesProc._wantApp) {
            root.pageApp = obj.page_app ? obj.page_app : ""
            root.pagesModel = obj.pages ? obj.pages : []
          }
        } catch (e) {
          console.warn("[SelfTrack] pages parse fail", e)
        }
      }
    }
    onExited: running = false
  }

  property bool monitorEnabled: appConfig ? appConfig.cfg.selftrackEnabled : false
  onMonitorEnabledChanged: {
    if (monitorEnabled) {
      root.refresh()
      pollTimer.running = true
    } else {
      pollTimer.running = false
      fetchProc.running = false
      fetchPagesProc.running = false
    }
  }
}
