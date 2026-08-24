// ============================================================
// ClipboardPopup.qml — історія буфера обміну (cliphist)
// ============================================================
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../core"

// Відкривається SUPER+SHIFT+V (IpcHandler "clipboard" у Bar.qml).
// Список записів cliphist; клік по рядку — копіювання повного вмісту
// в буфер через wl-copy, кнопка з правого боку — видалення запису.
AnimatedPopup {
  id: root

  required property QtObject window
  required property QtObject anchorItem
  palette: window.palette
  appConfig: window.appConfig

  popupWindow: window
  anchorTarget: anchorItem

  implicitWidth: 400
  implicitHeight: 340

  // Готова модель рядків: [{ id, text }] — id для cliphist decode/delete-index
  property var entries: []
  // Накопичувач сирого виводу: SplitParser віддає дані шматками (по рядку чи
  // кількома), тому парсимо ВЕСЬ накопичений буфер на кожен onRead — інакше
  // модель перезаписувалась би лише останнім рядком і в списку був би 1 запис
  property string rawList: ""

  Component.onCompleted: { anchor.window = window }

  onVisibleChanged: {
    if (visible) {
      root.positionUnderAnchor()
      root.refresh()
    }
  }

  // Перечитує історію з cliphist
  function refresh() {
    listProc.running = true
  }

  // Парсить накопичений вивід cliphist list і оновлює модель, якщо список
  // реально змінився. Формат рядка: "{id}\t{перший рядок вмісту}", наступні
  // рядки багаторядкового вмісту йдуть без префікса id
  function applyRawList() {
    var text = root.rawList
    if (text === "") return
    var out = []
    var current = null
    var lines = text.split("\n")
    for (var i = 0; i < lines.length; ++i) {
      var line = lines[i]
      var tab = line.indexOf("\t")
      if (tab >= 0) {
        current = { id: line.slice(0, tab), text: line.slice(tab + 1) }
        out.push(current)
      } else if (current !== null) {
        current.text += "\n" + line
      }
    }
    for (var j = out.length - 1; j >= 0; --j) {
      out[j].text = out[j].text.replace(/\s+/g, " ").trim()
      if (out[j].text === "") out.splice(j, 1)
    }
    console.log("Clipboard: parsed " + out.length + " entries")
    if (JSON.stringify(out) !== JSON.stringify(root.entries)) {
      // Зберігаємо прокрутку: нова модель наслідує позицію
      var y = listView.contentY
      root.entries = out
      listView.contentY = y
    }
  }

  // Копіює запис у буфер обміну та закриває попап.
  // Пайп через sh: Process не вміє конвеєрів сам
  function copyEntry(id) {
    // wl-copy живе доки його витіснять з clipboard — якщо попап закрити
    // і відкрити знову, copyProc ще "running" і друге копіювання було б
    // проігнороване. Тому пайплайн фонует: sh одразу виходить, wl-copy
    // працює самостійно, а попередній примірник гине новий (власність
    // на clipboard переходить)
    copyProc.command = ["sh", "-c",
      "cliphist decode " + id + " | nohup wl-copy >/dev/null 2>&1 &"]
    copyProc.running = true
    root.close()
  }

  // Видаляє запис з історії та оновлює список.
  // cliphist delete приймає id через stdin (по рядку). Пайп через sh:
  // він закриває stdin після printf → cliphist отримує EOF; нативний
  // stdinEnabled/QML не закриває пайп, і cliphist висів би на читанні
  function deleteEntry(id) {
    deleteProc.command = ["sh", "-c", "printf '%s\\n' " + id + " | cliphist delete"]
    deleteProc.running = true
    // список оновлюється в deleteProc.onExited — callLater стреляв раніше
    // за завершення delete, і запис "відроджувався" до наступного циклу
  }

  // Список записів. Парсинг — ЛИШЕ після завершення процесу: SplitParser
  // віддає дані шматками, і оновлення моделі на кожен шматок змушувало б
  // список "блимати" (скидання hover/фокусу) при автооновленні кожні 2 с
  Process {
    id: listProc
    command: ["cliphist", "list"]

    // Новий запуск — чистий буфер; парсинг по завершенні (onExited — сигнал)
    onStarted: root.rawList = ""
    onExited: (exitCode, exitStatus) => {
      if (exitCode === 0) root.applyRawList()
    }

    stdout: SplitParser {
      splitMarker: "\n"
      onRead: data => { root.rawList += (data ?? "") + "\n" }
    }
  }

  // Автооновлення: нові копії з'являються в списку, поки попап відкритий
  Timer {
    interval: 2000
    running: root.visible
    repeat: true // без цього список оновлювався один раз за відкриття
    onTriggered: root.refresh()
  }

  // Копіювання в буфер обміну (wl-copy)
  Process { id: copyProc }

  // Видалення запису з історії
  Process {
    id: deleteProc
    onExited: root.refresh()
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 10
    spacing: 6

    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      Text {
        text: "\uF0EA"
        color: window.palette.gray
        font.family: window.palette.font
        font.pixelSize: appConfig.scaled(9)
      }

      Text {
        text: "Clipboard History"
        color: window.palette.gray
        font.family: window.palette.font
        font.pixelSize: appConfig.scaled(9)
        font.bold: true
      }

      Item { Layout.fillWidth: true }

      // Кількість записів
      Text {
        text: root.entries.length + " items"
        color: window.palette.muted
        font.family: window.palette.font
        font.pixelSize: appConfig.scaled(9)
      }
    }

    GradientSeparator { midColor: window.palette.bg2 }

    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true

      // Затемнення нижнього краю при прокрутці
      Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 18
        gradient: Gradient {
          GradientStop { position: 0.0; color: "transparent" }
          GradientStop { position: 1.0; color: window.palette.softOverlay }
        }
        visible: listView.contentHeight > listView.height
      }

      ListView {
        id: listView
        anchors.fill: parent
        clip: true
        spacing: 2
        model: root.entries

        delegate: Item {
          required property var modelData
          required property int index

          width: listView.width
          height: 30

          // Тло рядка — активне і коли курсор над кнопкою ✕ (та перехоплює hover)
          Rectangle {
            anchors.fill: parent
            radius: 6
            antialiasing: true
            color: (rowArea.containsMouse || delArea.containsMouse) ? window.palette.bg2 : "transparent"
            Behavior on color { ColorAnimation { duration: appConfig.anim(120) } }
          }

          // Перший рядок вмісту запису
          Text {
            anchors {
              left: parent.left; leftMargin: 12
              right: delBtn.left; rightMargin: 6
              verticalCenter: parent.verticalCenter
            }
            text: modelData.text
            color: window.palette.fg
            font.family: window.palette.font
            font.pixelSize: appConfig.scaled(11)
            elide: Text.ElideRight
          }

          // Клік по рядку — копіювання в буфер обміну (найнижчий шар)
          MouseArea {
            id: rowArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: root.copyEntry(modelData.id)
          }

          // Кнопка видалення — з'являється на hover рядка, поверх rowArea.
          // visible враховує hover САМОЇ кнопки: коли курсор над ✕, верхній
          // MouseArea перехоплює в rowArea його containsMouse стає false —
          // залежність лише від rowArea робила б кнопку невидимою і вона б
          // блимала (зникала саме в момент наведення на неї)
          Rectangle {
            id: delBtn
            z: 1
            anchors { right: parent.right; rightMargin: 3; verticalCenter: parent.verticalCenter }
            width: 24
            height: 24
            radius: 6
            antialiasing: true
            // Fade замість visible: прозора кнопка не має перехоплювати кліки
            opacity: (rowArea.containsMouse || delArea.containsMouse) ? 1 : 0
            scale: (rowArea.containsMouse || delArea.containsMouse) ? 1 : 0.6
            color: delArea.containsMouse ? window.palette.red : "transparent"
            Behavior on color { ColorAnimation { duration: appConfig.anim(120) } }
            Behavior on opacity { NumberAnimation { duration: appConfig.anim(120); easing.type: Easing.OutCubic } }
            Behavior on scale {
              NumberAnimation { duration: appConfig.anim(120); easing.type: Easing.OutBack; easing.overshoot: 1.5 }
            }

            Text {
              anchors.centerIn: parent
              text: "\uF00D"
              color: delArea.containsMouse ? window.palette.bg0H : window.palette.muted
              font.family: window.palette.font
              font.pixelSize: appConfig.scaled(13)
            }

            MouseArea {
              id: delArea
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              hoverEnabled: true
              enabled: rowArea.containsMouse || delArea.containsMouse
              onClicked: root.deleteEntry(modelData.id)
            }
          }
        }
      }

      // Порожній стан — історія ще порожня
      ColumnLayout {
        anchors.centerIn: parent
        visible: root.entries.length === 0
        spacing: 4

        Text {
          Layout.alignment: Qt.AlignHCenter
          text: "\uF328"
          color: window.palette.mutedAlt
          font.family: window.palette.font
          font.pixelSize: appConfig.scaled(20)
        }

        Text {
          Layout.alignment: Qt.AlignHCenter
          text: "Clipboard is empty"
          color: window.palette.mutedAlt
          font.family: window.palette.font
          font.pixelSize: appConfig.scaled(12)
        }
      }
    }
  }
}