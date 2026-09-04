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
        Layout.preferredHeight: 26

        Rectangle {
          anchors.fill: parent
          radius: 5
          color: window.palette.bg1
        }

        Repeater {
          model: root.sessionsModel
          delegate: Rectangle {
            required property var modelData
            readonly property real dayStart: ST.dayStartMs(root.dateStr)
            readonly property real frac0: Math.max(0, Math.min(1, (modelData.start_ms - dayStart) / 86400000))
            readonly property real frac1: Math.max(0, Math.min(1, (modelData.end_ms - dayStart) / 86400000))
            x: frac0 * timelineTrack.width
            width: Math.max((frac1 - frac0) * timelineTrack.width, (frac1 > frac0) ? 2 : 0)
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 3
            anchors.bottomMargin: 3
            radius: 2
            color: modelData.idle ? window.palette.bg2 : root.appColor(modelData.app)
            opacity: segMa.containsMouse ? 1.0 : 0.8
            Behavior on opacity { NumberAnimation { duration: appConfig.anim(120) } }

            MouseArea {
              id: segMa
              anchors.fill: parent
              hoverEnabled: true
              onEntered: {
                var t = ST.formatClock(modelData.start_ms) + "–" + ST.formatClock(modelData.end_ms) + "  "
                if (modelData.idle) {
                  root.hoverInfo = t + "idle"
                } else {
                  var title = ST.cleanTitle(modelData.title)
                  root.hoverInfo = t + modelData.app + (title !== "" ? " • " + title : "")
                }
              }
              onExited: root.hoverInfo = ""
            }
          }
        }
      }

      // Підписи годин
      RowLayout {
        Layout.fillWidth: true
        spacing: 0
        Repeater {
          model: ["00", "06", "12", "18", "24"]
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

      // Рядок ховера сегмента або підказка
      Text {
        Layout.fillWidth: true
        text: root.hoverInfo !== "" ? root.hoverInfo : "Hover a segment for details"
        color: root.hoverInfo !== "" ? window.palette.fg : window.palette.muted
        font.family: window.palette.font
        font.pixelSize: appConfig.scaled(10)
        elide: Text.ElideRight
        opacity: 0.9
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
