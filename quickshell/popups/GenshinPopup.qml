// ============================================================
// GenshinPopup.qml — детальна інформація Genshin Impact
// ============================================================
import Quickshell
import Quickshell.Io
import "../core"
import QtQuick
import QtQuick.Layouts

// Попап Genshin Impact — смола, дейліки, боси, чекін
AnimatedPopup {
  id: root

  required property QtObject anchorItem
  required property QtObject window
  palette: window.palette
  appConfig: window.appConfig

  implicitWidth: 400
  implicitHeight: layout.implicitHeight + 16
  transformOrigin: Item.Top

  // Дані з GenshinMonitor (прокидаються через Bar.qml)
  property string resinText: "\uF737 0/200"
  property string resinClass: "normal"
  property string details: ""
  property bool isSigned: false

  // Статус ручного оновлення
  property string refreshStatus: "idle"
  property string refreshMessage: ""
  signal refreshRequested()

  // Іконка смоли (PNG замість гліфа)
  property string resinIconSource: "../assets/resin2.png"

  // Текст без гліфа, якщо є іконка
  readonly property string resinDisplayText: resinIconSource !== ""
    ? resinText.replace(/^\S+\s*/, "")
    : resinText


  // Парсить деталі з tooltip, перевіряє статус чекіну.
  // Має side-effect (isSigned), тож викликається один раз на зміну details.
  function parseTooltip(tip) {
    if (!tip) return []
    var lines = tip.split("\n")
    var result = []
    for (var i = 0; i < lines.length; ++i) {
      if (lines[i].trim() !== "") {
        if (lines[i].indexOf("Check-in") !== 0) {
          result.push({ text: lines[i] })
        } else {
          root.isSigned = lines[i].indexOf("✓") >= 0
        }
      }
    }
    return result
  }

  // Кеш розпарсених деталей — Repeater читає його, а не викликає
  // parseTooltip повторно (подвійний парсинг при кожному оновленні)
  property var detailsModel: []

  popupWindow: window
  anchorTarget: anchorItem

  Component.onCompleted: {
    root.anchor.window = root.window
    root.detailsModel = parseTooltip(root.details)
  }

  onDetailsChanged: {
    root.detailsModel = parseTooltip(root.details)
  }

  onVisibleChanged: {
    if (visible) {
      root.positionUnderAnchor()
      // Скидаємо фідбек і розблоковуємо кнопку тільки якщо чекін не
      // триває (попап могли закрити й відкрити під час signProc)
      if (!signProc.running) {
        signFeedback.text = ""
        signBtn.enabled = true
      }
    }
  }

  // Процес чекіну (окремий запуск, не заважає фоновому оновленню)
  Process {
    id: signProc
    command: ["python3", scriptPath, "sign"]

    readonly property string scriptPath: Qt.resolvedUrl("../scripts/genshin_stats.py").toString().replace("file://", "")

    // Чи отримали вивід (результат оброблено) — якщо процес впав без
    // stdout, onExited відновлює кнопку
    property bool _signHandled: false

    stdout: SplitParser {
      splitMarker: "\n"

      onRead: data => {
        var text = (data ?? "").trim()
        if (text === "") return

        signProc._signHandled = true
        try {
          var obj = JSON.parse(text)
          signFeedback.text = obj.msg
          signFeedback.color = obj.ok ? window.palette.green : window.palette.red
          // Оновлюємо індикатор одразу, не чекаючи наступного синку
          if (obj.ok) root.isSigned = true
        } catch (e) {
          signFeedback.text = "Error: " + e
          signFeedback.color = window.palette.red
        }
        signBtn.enabled = true
      }
    }

    onExited: {
      // Python вмер без виводу (помилка запуску тощо) — повертаємо кнопку,
      // інакше вона лишилась би вимкненою назавжди
      if (!signProc._signHandled) {
        signBtn.enabled = true
        signFeedback.text = "Check-in failed"
        signFeedback.color = window.palette.red
      }
    }
  }


  ColumnLayout {
    id: layout
    x: 10; y: 10
    width: parent.width - 20
    spacing: 6

    // Заголовок + смола + кнопка оновлення
    RowLayout {
      spacing: 8
      Layout.fillWidth: true

      Text {
        text: "Genshin Impact"
        color: window.palette.green
        font.family: window.palette.font; font.pixelSize: appConfig.scaled(13); font.bold: true
      }

      Item { Layout.fillWidth: true }

      RowLayout {
        spacing: 4

        // Кнопка ручного оновлення
        Rectangle {
          id: refreshBtn
          implicitWidth: 20; implicitHeight: 20; radius: 6
          color: refreshArea.containsMouse ? window.palette.bg2 : window.palette.bg1
          enabled: root.refreshStatus !== "loading"
          Layout.alignment: Qt.AlignVCenter
          Behavior on color { ColorAnimation { duration: 120 } }

          Text {
            id: refreshIcon
            anchors.centerIn: parent
            text: "⟳"
            font.family: window.palette.font; font.pixelSize: appConfig.scaled(13)
            color: root.refreshStatus === "error" ? window.palette.red
                 : root.refreshStatus === "ok" ? window.palette.green
                 : window.palette.gray
            Behavior on color { ColorAnimation { duration: 200 } }

            RotationAnimator on rotation {
              running: root.refreshStatus === "loading"
              loops: Animation.Infinite
              from: 0; to: 360
              duration: 800
            }
          }

          MouseArea {
            id: refreshArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: root.refreshStatus !== "loading"
            onClicked: root.refreshRequested()
          }
        }

        // Кнопка-індикатор чекіну (суміщена: показує статус і запускає чекін)
        Rectangle {
          id: signBtn
          implicitWidth: Math.max(signLabel.implicitWidth + 20, 80)
          implicitHeight: 22
          radius: 6
          enabled: !signProc.running
          color: root.isSigned && !signProc.running
            ? Qt.rgba(window.palette.green.r, window.palette.green.g, window.palette.green.b, 0.15)
            : signArea.containsMouse ? window.palette.bg2 : window.palette.bg1
          Layout.alignment: Qt.AlignVCenter
          Behavior on color { ColorAnimation { duration: 120 } }

          Text {
            id: signLabel
            anchors.centerIn: parent
            text: signProc.running
              ? "⟳"
              : root.isSigned ? "\uF00C Check-in" : "\uF00D Check-in"
            color: signProc.running
              ? window.palette.green
              : root.isSigned ? window.palette.green : window.palette.gray
            font.family: window.palette.font; font.pixelSize: appConfig.scaled(11)
            Behavior on color { ColorAnimation { duration: 200 } }

            RotationAnimator on rotation {
              running: signProc.running
              loops: Animation.Infinite
              from: 0; to: 360
              duration: 900
              // Скидаємо кут при зупинці — інакше текст лишається
              // перевернутим і виходить за межі кнопки
              onRunningChanged: {
                if (!running) signLabel.rotation = 0
              }
            }
          }

          MouseArea {
            id: signArea
            anchors.fill: parent
            enabled: signBtn.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              signProc._signHandled = false
              signBtn.enabled = false
              signFeedback.text = ""
              signProc.running = true
            }
          }
        }

        // Іконка смоли
        Image {
          source: root.resinIconSource
          visible: root.resinIconSource !== ""
          Layout.preferredWidth: 20
          Layout.preferredHeight: 20
          smooth: true
          mipmap: true
          fillMode: Image.PreserveAspectFit
        }

        // Текст смоли
        Text {
          text: root.resinDisplayText
          color: root.resinClass === "critical" ? window.palette.red : window.palette.green
          font.family: window.palette.font; font.pixelSize: appConfig.scaled(13)
          font.bold: true
        }
      }
    }

    // Фідбек оновлення
    Text {
      id: refreshFeedback
      visible: root.refreshMessage !== ""
      text: root.refreshMessage
      color: root.refreshStatus === "error" ? window.palette.red : window.palette.green
      font.family: window.palette.font; font.pixelSize: appConfig.scaled(10)
      opacity: visible ? 1 : 0
      Layout.alignment: Qt.AlignRight
      Behavior on opacity { NumberAnimation { duration: 200 } }
    }

    // Роздільник
    GradientSeparator { midColor: window.palette.bg2 }

    // Сітка деталей
    GridLayout {
      columns: 2
      columnSpacing: 10
      rowSpacing: 3

      Repeater {
        model: root.detailsModel

        delegate: Text {
          required property var modelData
          text: modelData.text
          color: window.palette.fg
          font.family: window.palette.font; font.pixelSize: appConfig.scaled(13)
          wrapMode: Text.NoWrap
          elide: Text.ElideRight
          Layout.fillWidth: true
          Layout.maximumWidth: (layout.width - 10) / 2
        }
      }
    }

    // Роздільник
    GradientSeparator { midColor: window.palette.bg2 }

    // Результат чекіну
    Text {
      id: signFeedback
      font.family: window.palette.font; font.pixelSize: appConfig.scaled(11)
      wrapMode: Text.WordWrap
      Layout.fillWidth: true
      lineHeight: 1.3
      visible: text !== ""
    }
  }
}
