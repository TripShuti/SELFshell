// ============================================================
// GenshinPopup.qml — детальна інформація Genshin Impact
// ============================================================
import Quickshell
import Quickshell.Io
import "../"
import "../Palette.js" as Palette
import QtQuick
import QtQuick.Layouts

// Попап Genshin Impact — смола, дейліки, боси, чекін
AnimatedPopup {
  id: root
  bgOpacity: 0.94  // збережено індивідуальне значення, яке було локально в цьому попапі
  cornerRadius: 6  // теж було індивідуальним значенням цього попапу

  required property QtObject anchorItem
  required property QtObject window

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


  // Парсить деталі з tooltip, перевіряє статус чекіну
  function parseTooltip(tip) {
    if (!tip) return []
    var lines = tip.split("\n")
    var result = []
    for (var i = 0; i < lines.length; ++i) {
      if (lines[i].trim() !== "") {
        if (lines[i].indexOf("Чекін") !== 0) {
          result.push({ text: lines[i] })
        } else {
          root.isSigned = lines[i].indexOf("✓") >= 0
        }
      }
    }
    return result
  }

  Component.onCompleted: {
    root.anchor.window = root.window
    parseTooltip(root.details)
  }

  onDetailsChanged: {
    parseTooltip(root.details)
  }

  onVisibleChanged: {
    if (visible) {
      var r = window.itemRect(anchorItem)
      anchor.rect = Qt.rect(r.x, r.y + r.height + 4, implicitWidth, implicitHeight)
      signBtn.text = "Чекін"
      signFeedback.text = ""
      signBtn.enabled = true
      signSpinner.visible = false
    }
  }

  // Процес чекіну (окремий запуск, не заважає фоновому оновленню)
  Process {
    id: signProc
    command: ["sh", "-c", "python3 $HOME/.config/quickshell/scripts/genshin_stats.py sign"]

    stdout: SplitParser {
      splitMarker: "\n"

      onRead: data => {
        var text = (data ?? "").trim()
        if (text === "") return

        try {
          var obj = JSON.parse(text)
          signBtn.text = obj.ok ? "✓" : "✗"
          signFeedback.text = obj.msg
          signFeedback.color = obj.ok ? Palette.green : Palette.red
        } catch (e) {
          signFeedback.text = "Помилка: " + e
          signFeedback.color = Palette.red
        }
        signBtn.enabled = true
        signSpinner.visible = false
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
        color: Palette.green
        font.family: Palette.font; font.pixelSize: 13; font.bold: true
      }

      Item { Layout.fillWidth: true }

      RowLayout {
        spacing: 4

        // Кнопка ручного оновлення
        Rectangle {
          id: refreshBtn
          implicitWidth: 20; implicitHeight: 20; radius: 6
          color: refreshArea.containsMouse ? Palette.bg2 : Palette.bg1
          enabled: root.refreshStatus !== "loading"
          Layout.alignment: Qt.AlignVCenter
          Behavior on color { ColorAnimation { duration: 120 } }

          Text {
            id: refreshIcon
            anchors.centerIn: parent
            text: "⟳"
            font.family: Palette.font; font.pixelSize: 13
            color: root.refreshStatus === "error" ? Palette.red
                 : root.refreshStatus === "ok" ? Palette.green
                 : Palette.gray
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
          color: root.resinClass === "critical" ? Palette.red : Palette.green
          font.family: Palette.font; font.pixelSize: 13
          font.bold: true
        }
      }
    }

    // Фідбек оновлення
    Text {
      id: refreshFeedback
      visible: root.refreshMessage !== ""
      text: root.refreshMessage
      color: root.refreshStatus === "error" ? Palette.red : Palette.green
      font.family: Palette.font; font.pixelSize: 10
      opacity: visible ? 1 : 0
      Layout.alignment: Qt.AlignRight
      Behavior on opacity { NumberAnimation { duration: 200 } }
    }

    // Роздільник
    Rectangle {
      Layout.fillWidth: true
      height: 1
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: "transparent" }
        GradientStop { position: 0.5; color: Palette.bg2 }
        GradientStop { position: 1.0; color: "transparent" }
      }
    }

    // Сітка деталей
    GridLayout {
      columns: 2
      columnSpacing: 10
      rowSpacing: 3

      Repeater {
        model: parseTooltip(root.details)

        delegate: Text {
          required property var modelData
          text: modelData.text
          color: Palette.fg
          font.family: Palette.font; font.pixelSize: 12
          wrapMode: Text.NoWrap
          elide: Text.ElideRight
          Layout.fillWidth: true
          Layout.maximumWidth: (layout.width - 10) / 2
        }
      }
    }

    // Роздільник
    Rectangle {
      Layout.fillWidth: true
      height: 1
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: "transparent" }
        GradientStop { position: 0.5; color: Palette.bg2 }
        GradientStop { position: 1.0; color: "transparent" }
      }
    }

    // Секція чекіну
    RowLayout {
      spacing: 8
      Layout.fillWidth: true

      // Статус чекіну
      Rectangle {
        implicitWidth: checkinLabel.implicitWidth + 20
        implicitHeight: 22
        radius: 6
        color: root.isSigned ? Qt.rgba(Palette.green.r, Palette.green.g, Palette.green.b, 0.15) : Palette.bg1

        Text {
          id: checkinLabel
          anchors.centerIn: parent
          text: root.isSigned ? "\uF00C Чекін" : "\uF00D Чекін"
          color: root.isSigned ? Palette.green : Palette.gray
          font.family: Palette.font; font.pixelSize: 11
        }
      }

      // Спінер під час чекіну
      Text {
        id: signSpinner
        text: "⟳"
        color: Palette.green
        font.family: Palette.font; font.pixelSize: 12; font.bold: true
        visible: false
        Layout.alignment: Qt.AlignVCenter

        RotationAnimator on rotation {
          running: signSpinner.visible
          loops: Animation.Infinite
          from: 0; to: 360
          duration: 900
        }
      }

      Item { Layout.fillWidth: true }

      // Кнопка "Чекін"
      Rectangle {
        id: signBtn
        implicitWidth: 72
        implicitHeight: 24
        radius: 6
        color: signBtn.enabled ? (signArea.containsMouse ? Palette.bg2 : Palette.bg1) : Palette.bg1
        Behavior on color { ColorAnimation { duration: 120 } }

        property string text: "Чекін"

        Text {
          anchors.centerIn: parent
          text: parent.text
          color: parent.enabled ? Palette.fg : Palette.gray
          font.family: Palette.font; font.pixelSize: 11
        }

        MouseArea {
          id: signArea
          anchors.fill: parent
          enabled: signBtn.enabled
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            signBtn.enabled = false
            signBtn.text = "..."
            signSpinner.visible = true
            signFeedback.text = ""
            signProc.running = true
          }
        }
      }
    }

    // Результат чекіну
    Text {
      id: signFeedback
      font.family: Palette.font; font.pixelSize: 11
      wrapMode: Text.WordWrap
      Layout.fillWidth: true
      lineHeight: 1.3
      visible: text !== ""
    }
  }
}
