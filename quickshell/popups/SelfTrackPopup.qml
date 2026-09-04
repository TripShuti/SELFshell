// ============================================================
// quickshell/popups/SelfTrackPopup.qml — попап трекера часу: саммарі, таймлайн доби, застосунки зі сторінками
// ============================================================
import Quickshell
import "../core"
import "../scripts/SelfTrack.js" as ST
import QtQuick
import QtQuick.Layouts

// Центрований попап (як AudioMixerPopup) — паритет з selftrack tui плюс смуга таймлайну 00–24
AnimatedPopup {
  id: root

  required property QtObject window
  palette: window.palette
  appConfig: window.appConfig

  // Єдиний резолвер іконок шела (з Bar.qml) — повертає "" якщо іконки
  // нема в темі, тоді показуємо літеру-заглушку
  property QtObject iconResolver: null

  implicitWidth: 540
  // Висота за контентом (список розтягує, порожнечі знизу нема),
  // з кепом щоб влізти в екран — далі список скролиться всередині
  implicitHeight: Math.min(layout.implicitHeight + 20, root.screenH - 120)
  enterScale: 0.75
  slideDistance: 6
  transformOrigin: Item.Center

  // Дані з SelfTrackMonitor (прокидаються через Bar.qml)
  property string dateStr: ""
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
  property string errorText: ""

  signal prevDay()
  signal nextDay()
  signal goToday()
  signal refreshRequested()
  signal pagesRequested(string app)

  // Інформація про сегмент під курсором (таймлайн)
  property string hoverInfo: ""

  // Зум таймлайну — довільне вікно часу (як на мапі): зсув від початку
  // доби + довжина. Огляд доби: start 0, len 86400000. Колесо зумить
  // відносно курсора, клік в огляді стрибає в годину, клік в зумі центрує.
  // Скидається при зміні дати
  property real zoomStartMs: 0
  property real zoomLenMs: 86400000
  readonly property bool zoomed: root.zoomLenMs < 86400000
  onDateStrChanged: zoomReset()

  function zoomReset() {
    root.zoomStartMs = 0
    root.zoomLenMs = 86400000
  }  // Колесо: вгору — ближче (мінімум 1 хв), вниз — далі (максимум доба), якір — курсор
  function wheelZoom(frac, up) {
    var dayLen = 86400000
    var minLen = 60000
    if (up && root.zoomLenMs <= minLen) return
    if (!up && root.zoomLenMs >= dayLen) return
    var newLen = Math.max(minLen, Math.min(dayLen, root.zoomLenMs * (up ? 1 / 1.3 : 1.3)))
    var tCursor = root.zoomStartMs + frac * root.zoomLenMs
    root.zoomStartMs = Math.max(0, Math.min(dayLen - newLen, tCursor - frac * newLen))
    root.zoomLenMs = newLen
    if (newLen >= dayLen) root.zoomReset()
  }
  // Клік: в огляді — стрибок у годину, в зумі — центрування вікна на кліку
  function stripClickAt(frac) {
    var dayLen = 86400000
    if (root.zoomLenMs >= dayLen) {
      var h = Math.max(0, Math.min(23, Math.floor(frac * 24)))
      root.zoomStartMs = h * 3600000
      root.zoomLenMs = 3600000
    } else {
      var rel = root.zoomStartMs + frac * root.zoomLenMs
      root.zoomStartMs = Math.max(0, Math.min(dayLen - root.zoomLenMs, rel - root.zoomLenMs / 2))
    }
  }
  // Сесія під позицією курсору на треку: шукаємо в ДАНИХ, а не ховеримо
  // прямокутники — 2px-сегменти під сусідами інакше ніколи не ховеряться.
  // З кількох перекритих беремо найкоротшу (найточнішу), при рівності — пізнішу
  function hoverAt(x) {
    var frac = Math.max(0, Math.min(1, x / timelineTrack.width))
    var base = ST.dayStartMs(root.dateStr)
    var t = base + root.zoomStartMs + frac * root.zoomLenMs
    var best = null
    var count = 0
    for (var i = 0; i < root.sessionsModel.length; i++) {
      var s = root.sessionsModel[i]
      if (s.start_ms <= t && t < s.end_ms) {
        count++
        if (!best || (s.end_ms - s.start_ms) < (best.end_ms - best.start_ms)) best = s
      }
    }
    if (!best) {
      root.hoverInfo = ST.formatClock(t) + "  — no data —"
      return
    }
    var txt = ST.formatClock(best.start_ms) + "–" + ST.formatClock(best.end_ms) + "  "
    if (best.idle) {
      txt += "idle"
    } else {
      var title = ST.cleanTitle(best.title)
      txt += best.app + (title !== "" ? " • " + title : "")
    }
    if (count > 1) txt += "  (+" + (count - 1) + " overlapping)"
    root.hoverInfo = txt
  }
  // Підписи шкали: рівномірно 5 міток по вікні, з секундами на глибині ≤5 хв
  function tickLabels() {
    if (root.zoomLenMs >= 86400000) return ["00", "06", "12", "18", "24"]
    var base = ST.dayStartMs(root.dateStr)
    var showSec = root.zoomLenMs <= 300000
    var labels = []
    for (var i = 0; i <= 4; i++) {
      var t = base + root.zoomStartMs + root.zoomLenMs * i / 4
      labels.push(showSec ? ST.formatClockS(t) : ST.formatClock(t))
    }
    return labels
  }
  // Діапазон вікна для підпису (14:05–14:35)
  function zoomRangeText() {
    var base = ST.dayStartMs(root.dateStr)
    return ST.formatClock(base + root.zoomStartMs) + "–" + ST.formatClock(base + root.zoomStartMs + root.zoomLenMs)
  }

  // Палітра смуги таймлайну та барів (імена полів window.palette)
  readonly property var appColors: ["green", "blue", "yellow", "purple", "orange", "aqua"]

  function appColor(app) {
    return window.palette[root.appColors[ST.appColorIndex(app, root.appColors.length)]]
  }

  readonly property int screenW: window ? window.screen.width : 1920
  readonly property int screenH: window ? window.screen.height : 1080

  function recenter() {
    anchor.rect = Qt.rect(
      (screenW - root.implicitWidth) / 2,
      (screenH - root.implicitHeight) / 2,
      root.implicitWidth,
      root.implicitHeight
    )
  }

  Component.onCompleted: {
    anchor.window = window
  }

  // Дані приїжджають асинхронно після відкриття — перецентровуємо
  // під нову висоту, інакше контент обріжеться якорем
  onAppsModelChanged: if (visible) recenter()
  onPagesModelChanged: if (visible) recenter()
  onPageAppChanged: if (visible) recenter()

  onVisibleChanged: {
    if (visible) {
      anchor.edges = PopupAnchor.None
      anchor.gravity = PopupAnchor.None
      root.recenter()
      root.hoverInfo = ""
      root.refreshRequested()
    } else {
      // Закриття скидає на поточну дату — наступне відкриття
      // завжди показує сьогодні, а не залишок навігації
      if (root.dateStr !== ST.todayStr()) root.goToday()
    }
  }

  ColumnLayout {
    id: layout
    x: 10
    y: 10
    width: parent.width - 20
    spacing: 8

    // --- Заголовок: навігація по днях + оновлення ---
    RowLayout {
      Layout.fillWidth: true
      spacing: 4

      Text {
        text: "Time Tracking"
        color: window.palette.green
        font.family: window.palette.font
        font.pixelSize: appConfig.scaled(13)
        font.bold: true
      }

      Item { Layout.fillWidth: true }

      // Кнопка "попередній день"
      Rectangle {
        implicitWidth: 24
        implicitHeight: 24
        radius: 6
        color: navPrevMa.containsMouse ? window.palette.bg2 : window.palette.bg1
        Behavior on color { ColorAnimation { duration: appConfig.anim(120) } }
        Text {
          anchors.centerIn: parent
          text: "‹"
          color: window.palette.fg
          font.family: window.palette.font
          font.pixelSize: appConfig.scaled(16)
        }
        MouseArea {
          id: navPrevMa
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.prevDay()
        }
      }

      // Дата (клік — повернутись на сьогодні)
      Text {
        text: root.dateStr
        color: window.palette.fg
        font.family: window.palette.font
        font.pixelSize: appConfig.scaled(12)
        font.bold: true
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.goToday()
        }
      }

      // Кнопка "наступний день"
      Rectangle {
        implicitWidth: 24
        implicitHeight: 24
        radius: 6
        color: navNextMa.containsMouse ? window.palette.bg2 : window.palette.bg1
        Behavior on color { ColorAnimation { duration: appConfig.anim(120) } }
        Text {
          anchors.centerIn: parent
          text: "›"
          color: window.palette.fg
          font.family: window.palette.font
          font.pixelSize: appConfig.scaled(16)
        }
        MouseArea {
          id: navNextMa
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.nextDay()
        }
      }

      // Кнопка оновлення
      Rectangle {
        implicitWidth: 24
        implicitHeight: 24
        radius: 6
        color: refreshMa.containsMouse ? window.palette.bg2 : window.palette.bg1
        Behavior on color { ColorAnimation { duration: appConfig.anim(120) } }
        Text {
          anchors.centerIn: parent
          text: "⟳"
          color: window.palette.gray
          font.family: window.palette.font
          font.pixelSize: appConfig.scaled(13)
          RotationAnimator on rotation {
            running: root.loading
            loops: Animation.Infinite
            from: 0
            to: 360
            duration: appConfig.anim(800)
          }
        }
        MouseArea {
          id: refreshMa
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.refreshRequested()
        }
      }
    }

    // --- Саммарі: день / idle / тиждень / місяць ---
    GridLayout {
      Layout.fillWidth: true
      columns: 2
      columnSpacing: 8
      rowSpacing: 4

      Text {
        text: "Day  " + ST.formatDur(root.dayActiveMs)
        color: window.palette.fg
        font.family: window.palette.font
        font.pixelSize: appConfig.scaled(14)
        font.bold: true
        Layout.fillWidth: true
      }
      Text {
        text: "Idle  " + ST.formatDur(root.dayIdleMs)
        color: window.palette.muted
        font.family: window.palette.font
        font.pixelSize: appConfig.scaled(13)
        horizontalAlignment: Text.AlignRight
        Layout.fillWidth: true
      }
      Text {
        text: "Week  " + ST.formatDur(root.weekMs)
        color: window.palette.muted
        font.family: window.palette.font
        font.pixelSize: appConfig.scaled(12)
        Layout.fillWidth: true
      }
      Text {
        text: "Month  " + ST.formatDur(root.monthMs)
        color: window.palette.muted
        font.family: window.palette.font
        font.pixelSize: appConfig.scaled(12)
        horizontalAlignment: Text.AlignRight
        Layout.fillWidth: true
      }
    }

    GradientSeparator { midColor: window.palette.bg2 }

    // --- Смуга таймлайну доби 00–24 ---
    ColumnLayout {
      Layout.fillWidth: true
      spacing: 2

      Item {
        id: timelineTrack
        Layout.fillWidth: true
        Layout.preferredHeight: 34

        Rectangle {
          anchors.fill: parent
          radius: 5
          color: window.palette.bg1
        }

        Repeater {
          model: root.sessionsModel
          delegate: Rectangle {
            required property var modelData
            readonly property real winStart: ST.dayStartMs(root.dateStr) + root.zoomStartMs
            readonly property real winLen: root.zoomLenMs
            readonly property real frac0: Math.max(0, Math.min(1, (modelData.start_ms - winStart) / winLen))
            readonly property real frac1: Math.max(0, Math.min(1, (modelData.end_ms - winStart) / winLen))
            x: frac0 * timelineTrack.width
            width: Math.max((frac1 - frac0) * timelineTrack.width, (frac1 > frac0) ? 2 : 0)
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 3
            anchors.bottomMargin: 3
            radius: 2
            color: modelData.idle ? window.palette.bg2 : root.appColor(modelData.app)
            opacity: 0.85
          }
        }

        // Єдиний хендлер треку: ховер (позиційний, видно навіть перекриті
        // сегменти), колесо (зум відносно курсора) і drag-to-pan.
        // Клік без руху — стрибок у годину / центрування (stripClickAt)
        MouseArea {
          id: trackHoverMa
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor
          property real _pressX: 0
          property real _pressStartMs: 0
          property bool _dragging: false
          onEntered: root.hoverAt(mouseX)
          onPositionChanged: (mouse) => {
            root.hoverAt(mouseX)
            if (pressed && Math.abs(mouse.x - _pressX) > 4) _dragging = true
            if (_dragging) {
              var dayLen = 86400000
              root.zoomStartMs = Math.max(0, Math.min(dayLen - root.zoomLenMs, _pressStartMs - (mouse.x - _pressX) / timelineTrack.width * root.zoomLenMs))
            }
          }
          onPressed: (mouse) => {
            _pressX = mouse.x
            _pressStartMs = root.zoomStartMs
            _dragging = false
          }
          onReleased: (mouse) => {
            if (!_dragging) root.stripClickAt(mouse.x / timelineTrack.width)
            _dragging = false
          }
          onExited: root.hoverInfo = ""
          onWheel: (wheel) => {
            if (wheel.angleDelta.y === 0) return
            root.wheelZoom(wheel.x / timelineTrack.width, wheel.angleDelta.y > 0)
          }
        }
      }

      // Підписи шкали (доба або чверті години в зумі)
      RowLayout {
        Layout.fillWidth: true
        spacing: 0
        Repeater {
          model: root.tickLabels()
          delegate: Text {
            required property var modelData
            required property int index
            text: modelData
            color: window.palette.muted
            font.family: window.palette.font
            font.pixelSize: appConfig.scaled(9)
            Layout.fillWidth: true
            horizontalAlignment: index === 0 ? Text.AlignLeft : (index === 4 ? Text.AlignRight : Text.AlignHCenter)
          }
        }
      }

      // Рядок ховера + діапазон вікна (керування — drag/wheel/click по смузі)
      RowLayout {
        Layout.fillWidth: true
        spacing: 4

        Text {
          Layout.fillWidth: true
          text: root.hoverInfo !== "" ? root.hoverInfo
            : (root.zoomed ? "Drag to move • Wheel to zoom • Click to center" : "Hover for details • Wheel to zoom • Drag to move")
          color: root.hoverInfo !== "" ? window.palette.fg : window.palette.muted
          font.family: window.palette.font
          font.pixelSize: appConfig.scaled(10)
          elide: Text.ElideRight
          opacity: 0.9
        }

        // Діапазон вікна (тільки в зумі)
        Text {
          visible: root.zoomed
          text: root.zoomRangeText()
          color: window.palette.green
          font.family: window.palette.font
          font.pixelSize: appConfig.scaled(10)
          font.bold: true
        }
      }
    }

    GradientSeparator { midColor: window.palette.bg2 }

    // --- Стани: завантаження / помилка / порожньо ---
    Text {
      visible: root.loading && root.appsModel.length === 0
      text: "Loading…"
      color: window.palette.muted
      font.family: window.palette.font
      font.pixelSize: appConfig.scaled(12)
    }
    Text {
      visible: root.errorText !== ""
      text: root.errorText
      color: window.palette.red
      font.family: window.palette.font
      font.pixelSize: appConfig.scaled(12)
    }
    Text {
      visible: !root.loading && root.errorText === "" && root.appsModel.length === 0
      text: "No data for this day."
      color: window.palette.muted
      font.family: window.palette.font
      font.pixelSize: appConfig.scaled(12)
    }

    // --- Список застосунків з барами та сторінками ---
    // Висота рівно за контентом (кеп 320 — далі скрол): ніякого
    // порожнього місця під коротким списком
    Flickable {
      Layout.fillWidth: true
      Layout.preferredHeight: Math.min(appCol.implicitHeight, 320)
      contentWidth: width
      contentHeight: appCol.implicitHeight
      boundsBehavior: Flickable.StopAtBounds
      interactive: contentHeight > height
      clip: true

      Column {
        id: appCol
        width: parent.width
        spacing: 6

        Repeater {
          model: root.appsModel
          delegate: Column {
            required property var modelData
            width: appCol.width
            spacing: 3

            readonly property bool expanded: root.pageApp === modelData.app
            // Іконка тільки якщо резолвер реально знайшов її в темі.
            // Напряму image://icon/<app> не використовуємо: для відсутніх
            // іконок провайдер малює битий фіолетовий квадрат замість Error.
            // Імперативно (не біндингом): resolve() мутує кеш резолвера,
            // біндинг на ньому зациклюється
            property string iconSrc: ""
            function _resolveIcon() {
              iconSrc = root.iconResolver ? root.iconResolver.resolve(modelData.app) : ""
            }
            Component.onCompleted: _resolveIcon()
            onModelDataChanged: _resolveIcon()

            // Рядок застосунку
            Rectangle {
              width: parent.width
              height: 30
              radius: 6
              color: rowMa.containsMouse ? window.palette.hoverBg : "transparent"
              Behavior on color { ColorAnimation { duration: appConfig.anim(120) } }

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 4
                anchors.rightMargin: 4
                spacing: 8

                // Іконка з фолбеком на першу літеру
                Item {
                  Layout.preferredWidth: 20
                  Layout.preferredHeight: 20
                  Layout.alignment: Qt.AlignVCenter
                  Image {
                    id: appIcon
                    anchors.fill: parent
                    source: iconSrc
                    smooth: true
                    mipmap: true
                    fillMode: Image.PreserveAspectFit
                    visible: iconSrc !== "" && status !== Image.Error
                  }
                  Text {
                    anchors.centerIn: parent
                    visible: iconSrc === "" || appIcon.status === Image.Error
                    text: String(modelData.app).substring(0, 1).toUpperCase()
                    color: root.appColor(modelData.app)
                    font.family: window.palette.font
                    font.pixelSize: appConfig.scaled(13)
                    font.bold: true
                  }
                }

                Text {
                  text: (expanded ? "▾ " : "▸ ") + modelData.app
                  color: window.palette.fg
                  font.family: window.palette.font
                  font.pixelSize: appConfig.scaled(13)
                  Layout.fillWidth: true
                  elide: Text.ElideRight
                }
                Text {
                  text: ST.formatDur(modelData.ms)
                  color: window.palette.fg
                  font.family: window.palette.font
                  font.pixelSize: appConfig.scaled(12)
                }
                Text {
                  text: modelData.pct.toFixed(1) + "%"
                  color: window.palette.muted
                  font.family: window.palette.font
                  font.pixelSize: appConfig.scaled(11)
                  Layout.preferredWidth: 52
                  horizontalAlignment: Text.AlignRight
                }
              }

              MouseArea {
                id: rowMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.pagesRequested(modelData.app)
              }
            }

            // Бар відсотка
            Rectangle {
              width: parent.width
              height: 4
              radius: 2
              color: window.palette.bg1
              Rectangle {
                width: parent.width * Math.min(1, modelData.pct / 100)
                height: parent.height
                radius: 2
                color: root.appColor(modelData.app)
              }
            }

            // Сторінки застосунку (ліниве підвантаження)
            Column {
              width: parent.width
              spacing: 2
              visible: expanded

              Repeater {
                model: expanded ? root.pagesModel : []
                delegate: RowLayout {
                  required property var modelData
                  width: appCol.width
                  spacing: 8

                  Text {
                    text: "  └ " + ST.cleanTitle(modelData.app)
                    color: window.palette.muted
                    font.family: window.palette.font
                    font.pixelSize: appConfig.scaled(11)
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                  }
                  Text {
                    text: ST.formatDur(modelData.ms)
                    color: window.palette.muted
                    font.family: window.palette.font
                    font.pixelSize: appConfig.scaled(11)
                  }
                  Text {
                    text: modelData.pct.toFixed(1) + "%"
                    color: window.palette.muted
                    font.family: window.palette.font
                    font.pixelSize: appConfig.scaled(10)
                    Layout.preferredWidth: 52
                    horizontalAlignment: Text.AlignRight
                  }
                }
              }
            }
          }
        }
      }
    }

    // --- Футер ---
    Text {
      text: "Click an app for pages • Date label jumps to today"
      color: window.palette.muted
      font.family: window.palette.font
      font.pixelSize: appConfig.scaled(10)
      opacity: 0.7
    }
  }
}
