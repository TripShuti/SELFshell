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

  // Копіює запис у буфер обміну та закриває попап.
  // Пайп через sh: Process не вміє конвеєрів сам
  function copyEntry(id) {
    copyProc.command = ["sh", "-c", "cliphist decode " + id + " | wl-copy"]
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
    Qt.callLater(root.refresh)
  }

  // Список записів. Формат cliphist list: рядок "{id}\t{перший рядок вмісту}",
  // наступні рядки багаторядкового вмісту йдуть без префікса id
  Process {
    id: listProc
    command: ["cliphist", "list"]

    // Новий запуск — чистий буфер
    onStarted: root.rawList = ""

    stdout: SplitParser {
      splitMarker: "\n"
      onRead: data => {
        root.rawList += (data ?? "") + "\n"
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
        // Модель оновлюється лише при реальній зміні списку — інакше
        // автооновлення таймером скидало б hover/прокрутку на кожен тік
        if (JSON.stringify(out) !== JSON.stringify(root.entries)) {
          root.entries = out
        }
      }
    }
  }

  // Автооновлення: нові копії з'являються в списку, поки попап відкритий
  Timer {
    interval: 2000
    running: root.visible
    onTriggered: root.refresh()
  }

  // Копіювання в буфер обміну (wl-copy)
  Process { id: copyProc }

  // Видалення запису з історії
  Process { id: deleteProc }

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
        font.pixelSize: 9
      }

      Text {
        text: "Clipboard History"
        color: window.palette.gray
        font.family: window.palette.font
        font.pixelSize: 9
        font.bold: true
      }

      Item { Layout.fillWidth: true }

      // Кількість записів
      Text {
        text: root.entries.length + " items"
        color: window.palette.muted
        font.family: window.palette.font
        font.pixelSize: 9
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

          // Тло рядка
          Rectangle {
            anchors.fill: parent
            radius: 6
            antialiasing: true
            color: rowArea.containsMouse ? window.palette.bg2 : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }
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
            font.pixelSize: 11
            elide: Text.ElideRight
          }

          // Кнопка видалення — з'являється на hover рядка
          Rectangle {
            id: delBtn
            anchors { right: parent.right; rightMargin: 5; verticalCenter: parent.verticalCenter }
            width: 20
            height: 20
            radius: 4
            antialiasing: true
            visible: rowArea.containsMouse
            color: delArea.containsMouse ? window.palette.red : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
              anchors.centerIn: parent
              text: "\uF00D"
              color: delArea.containsMouse ? window.palette.bg0H : window.palette.muted
              font.family: window.palette.font
              font.pixelSize: 12
            }

            MouseArea {
              id: delArea
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              hoverEnabled: true
              onClicked: root.deleteEntry(modelData.id)
            }
          }

          // Клік по рядку — копіювання в буфер обміну
          MouseArea {
            id: rowArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: root.copyEntry(modelData.id)
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
          font.pixelSize: 20
        }

        Text {
          Layout.alignment: Qt.AlignHCenter
          text: "Clipboard is empty"
          color: window.palette.mutedAlt
          font.family: window.palette.font
          font.pixelSize: 12
        }
      }
    }
  }
}