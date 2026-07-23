// ============================================================
// CalendarPopup.qml — календар з сіткою днів та задачами
// ============================================================
import Quickshell
import Quickshell.Io
import "../"
import "../Palette.js" as Palette
import "../scripts/CalendarTasks.js" as Tasks
import QtQuick
import QtQuick.Layouts

// Календар з сіткою днів та списком задач
AnimatedPopup {
  id: root
  bgOpacity: 0.84  // збережено індивідуальне значення, яке було локально в цьому попапі
  cornerRadius: 8  // теж було індивідуальним значенням цього попапу

  required property QtObject anchorItem
  required property QtObject window

  implicitWidth: 280
  implicitHeight: layout.implicitHeight + 16

  // Поточний місяць/рік та параметри календаря
  property int currentMonth: 0
  property int currentYear: 0
  property int firstDay: 0
  property int daysInMonth: 0
  property int todayDay: 0
  property int todayMonth: 0
  property int todayYear: 0

  property string selectedDate: ""
  property string selectedLabel: ""
  property var dayTasks: []
  property int tasksVersion: 0

  readonly property var monthNames: [
    "Січень", "Лютий", "Березень", "Квітень", "Травень", "Червень",
    "Липень", "Серпень", "Вересень", "Жовтень", "Листопад", "Грудень"
  ]

  readonly property var dayNames: ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Нд"]

  // Функція Томоха — день тижня за датою (0=Нд, 6=Сб)
  function dow(y, m, d) {
    var t = [0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4]
    if (m < 2) y -= 1
    return (y + Math.floor(y/4) - Math.floor(y/100) + Math.floor(y/400) + t[m] + d) % 7
  }

  // Ініціалізація — сьогоднішня дата
  function initDate() {
    var d = new Date()
    todayDay = d.getDate()
    todayMonth = d.getMonth()
    todayYear = d.getFullYear()
    currentMonth = todayMonth
    currentYear = todayYear
    recalc()
  }

  // Перераховує параметри сітки календаря
  function recalc() {
    firstDay = (dow(currentYear, currentMonth, 1) + 6) % 7
    daysInMonth = new Date(currentYear, currentMonth + 1, 0).getDate()
    dayRepeater.model = firstDay + daysInMonth
  }

  // Перехід на попередній місяць
  function prevMonth() {
    currentMonth--
    if (currentMonth < 0) { currentMonth = 11; currentYear-- }
    recalc()
    selectedDate = ""
    dayTasks = []
  }

  // Перехід на наступний місяць
  function nextMonth() {
    currentMonth++
    if (currentMonth > 11) { currentMonth = 0; currentYear++ }
    recalc()
    selectedDate = ""
    dayTasks = []
  }

  // Вибирає дату і завантажує задачі
  function selectDate(day) {
    selectedDate = Tasks.formatDate(currentYear, currentMonth, day)
    selectedLabel = day + " " + monthNames[currentMonth] + " " + currentYear
    dayTasks = Tasks.getTasks(selectedDate)
    taskInput.text = ""
  }

  // Оновлює список задач для вибраної дати
  function refreshTasks() {
    root.tasksVersion++
    if (selectedDate) {
      dayTasks = Tasks.getTasks(selectedDate)
    }
  }

  // Додає нову задачу
  function addTask() {
    if (!selectedDate || !taskInput.text.trim()) return
    Tasks.add(selectedDate, taskInput.text)
    refreshTasks()
    taskInput.text = ""
  }

  // Видаляє задачу за індексом
  function removeTask(index) {
    Tasks.remove(selectedDate, index)
    refreshTasks()
  }

  // Перемикає стан виконання задачі
  function toggleTask(index) {
    Tasks.toggle(selectedDate, index)
    refreshTasks()
  }

  // Зберігає задачі у файл
  function saveTasksJson() {
    var json = Tasks.serialize()
    var escaped = json.replace(/'/g, "'\\''")
    saveProc.command = ["sh", "-c", "echo '" + escaped + "' > $HOME/.config/quickshell/calendar-tasks.json"]
    saveProc.running = true
  }

  // Завантажує задачі при старті
  StdioCollector {
    id: loadCollector
    waitForEnd: true
    onDataChanged: {
      if (loadCollector.text) {
        try { Tasks.setData(JSON.parse(loadCollector.text)) } catch(e) { Tasks.setData({}) }
        root.tasksVersion++
      }
    }
  }

  Process {
    id: loadProc
    command: ["sh", "-c", "cat $HOME/.config/quickshell/calendar-tasks.json"]
    stdout: loadCollector
  }

  Process {
    id: saveProc
    onExited: running = false
  }

  Component.onCompleted: {
    anchor.window = window
    initDate()
    Tasks.setSaveCallback(function() { saveTasksJson() })
    loadProc.running = true
  }

  onVisibleChanged: {
    if (visible) {
      var pos = anchorItem.mapToItem(window.contentItem, 0, 0)
      var popupX = pos.x + (anchorItem.width - implicitWidth) / 2
      anchor.rect = Qt.rect(popupX, pos.y + anchorItem.height + 4, implicitWidth, implicitHeight)
    }
  }


  ColumnLayout {
    id: layout
    x: 8; y: 8
    width: parent.width - 16
    spacing: 4

    // Навігація: попередній / назва місяця / наступний
    RowLayout {
      Layout.fillWidth: true
      spacing: 4

      // Кнопка назад
      Rectangle {
        property bool hovered: false
        width: 26; height: 26; radius: 4
        color: hovered ? Palette.hoverBg : Palette.bgAlpha
        Behavior on color { ColorAnimation { duration: 150 } }
        Text {
          anchors.centerIn: parent
          text: "\uF053"; color: Palette.fg
          font.family: Palette.font; font.pixelSize: 14
        }
        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          onEntered: parent.hovered = true
          onExited: parent.hovered = false
          onClicked: root.prevMonth()
        }
      }

      // Назва місяця та рік
      Text {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: monthNames[currentMonth] + " " + currentYear
        color: Palette.fg; font.family: Palette.font; font.pixelSize: 14; font.bold: true
      }

      // Кнопка вперед
      Rectangle {
        property bool hovered: false
        width: 26; height: 26; radius: 4
        color: hovered ? Palette.hoverBg : Palette.bgAlpha
        Behavior on color { ColorAnimation { duration: 150 } }
        Text {
          anchors.centerIn: parent
          text: "\uF054"; color: Palette.fg
          font.family: Palette.font; font.pixelSize: 14
        }
        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          onEntered: parent.hovered = true
          onExited: parent.hovered = false
          onClicked: root.nextMonth()
        }
      }
    }

    // Назви днів тижня
    RowLayout {
      Layout.fillWidth: true
      spacing: 2
      Repeater {
        model: dayNames
        delegate: Text {
          Layout.fillWidth: true
          Layout.preferredWidth: (root.implicitWidth - 32) / 7
          horizontalAlignment: Text.AlignHCenter
          text: modelData; color: Palette.muted; font.family: Palette.font; font.pixelSize: 12
        }
      }
    }

    // Сітка днів (42 комірки = 6 тижнів)
    GridLayout {
      id: grid
      Layout.fillWidth: true
      columns: 7
      rowSpacing: 2; columnSpacing: 2

      Repeater {
        id: dayRepeater

        delegate: Rectangle {
          required property int index

          readonly property int dayNum: index - root.firstDay + 1
          readonly property bool isInside: dayNum >= 1 && dayNum <= root.daysInMonth
          readonly property bool isToday: isInside && root.currentYear === root.todayYear && root.currentMonth === root.todayMonth && dayNum === root.todayDay
          readonly property string dateStr: isInside ? Tasks.formatDate(root.currentYear, root.currentMonth, dayNum) : ""
          readonly property bool isSelected: isInside && dateStr === root.selectedDate
          readonly property bool hasTasks: isInside && (root.tasksVersion >= 0) && Tasks.hasTasks(dateStr)

          Layout.preferredWidth: (root.implicitWidth - 32) / 7
          Layout.preferredHeight: (root.implicitWidth - 32) / 7
          radius: 4

          // Колір комірки: вибрана → акцент, сьогодні → bg2, інакше прозорий
          color: isSelected ? Palette.accent
               : isToday ? Palette.bg2
               : "transparent"

          ColumnLayout {
            anchors.centerIn: parent
            spacing: 1

            // Число місяця
            Text {
              Layout.alignment: Qt.AlignHCenter
              text: isInside ? dayNum : ""
              color: isSelected ? Palette.bg0H
                   : isToday ? Palette.fg
                   : isInside ? Palette.fg
                   : "transparent"
              font.family: Palette.font; font.pixelSize: 13
            }

            // Точка-індикатор наявності задач
            Rectangle {
              Layout.alignment: Qt.AlignHCenter
              width: 4; height: 4; radius: 2
              color: isSelected ? Palette.bg0H
                   : isToday ? Palette.accent
                   : Palette.accent
              visible: hasTasks
              opacity: 0.7
            }
          }

          MouseArea {
            anchors.fill: parent
            onClicked: {
              if (isInside) {
                root.selectDate(dayNum)
              }
            }
          }
        }
      }
    }

    // --- Секція задач ---
    Rectangle {
      Layout.fillWidth: true
      height: 1
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: "transparent" }
        GradientStop { position: 0.5; color: Palette.bg2 }
        GradientStop { position: 1.0; color: "transparent" }
      }
      Layout.topMargin: 4
      visible: selectedDate !== ""
    }

    // Вибрана дата
    Text {
      text: selectedLabel
      color: Palette.green
      font.family: Palette.font; font.pixelSize: 13; font.bold: true
      visible: selectedDate !== ""
    }

    // Поле додавання задачі + кнопка
    RowLayout {
      Layout.fillWidth: true
      spacing: 4
      visible: selectedDate !== ""

      // Поле введення тексту задачі
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 4
        color: Palette.bg1
        border.width: 1
        border.color: taskInput.activeFocus ? Palette.green : Palette.bg2

        TextInput {
          id: taskInput
          anchors.fill: parent
          anchors.leftMargin: 6
          anchors.rightMargin: 6
          verticalAlignment: Text.AlignVCenter
          color: Palette.fg
          font.family: Palette.font; font.pixelSize: 12
          clip: true

          onAccepted: root.addTask()
        }
      }

      // Кнопка додати
      Rectangle {
        implicitWidth: 30
        implicitHeight: 28
        radius: 4
        color: taskInput.text.trim() !== "" && maAdd.containsMouse ? Palette.green : Palette.bg2
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
          anchors.centerIn: parent
          text: "\u271A"
          color: taskInput.text.trim() !== "" ? Palette.baseOverlay : Palette.gray
          font.family: Palette.font; font.pixelSize: 14
        }

        MouseArea {
          id: maAdd
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.addTask()
        }
      }
    }

    // Список задач для вибраної дати
    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: root.dayTasks.length > 0 ? Math.min(root.dayTasks.length * 30 - 2, 160) : 0
      clip: true
      visible: selectedDate !== ""

      ListView {
        id: taskList
        anchors.fill: parent
        spacing: 2
        interactive: root.dayTasks.length > 5
        model: root.dayTasks

        delegate: Item {
          required property var modelData
          required property int index

          width: taskList.width
          height: 28

          RowLayout {
            anchors.fill: parent
            spacing: 6

            // Чекбокс виконання
            Rectangle {
              width: 16; height: 16; radius: 4
              color: modelData.done ? Palette.green : Palette.bgAlpha
              border.width: 1
              border.color: modelData.done ? Palette.green : Palette.muted
              Layout.alignment: Qt.AlignVCenter

              Text {
                anchors.centerIn: parent
                text: "\u2713"
                color: Palette.baseOverlay
                font.family: Palette.font; font.pixelSize: 10
                visible: modelData.done
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleTask(index)
              }
            }

            // Текст задачі
            Text {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              text: modelData.text
              color: modelData.done ? Palette.muted : Palette.fg
              font.family: Palette.font; font.pixelSize: 12
              elide: Text.ElideRight
              style: modelData.done ? Text.Sunken : Text.Normal
              styleColor: modelData.done ? Palette.muted : "transparent"
              leftPadding: 2

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleTask(index)
              }
            }

            // Кнопка видалення
            Rectangle {
              property bool hovered: false
              width: 22; height: 22; radius: 4
              color: hovered ? Palette.red : Palette.bg2
              Behavior on color { ColorAnimation { duration: 120 } }
              Layout.alignment: Qt.AlignVCenter

              Text {
                anchors.centerIn: parent
                text: "x"
                color: hovered ? Palette.textLight : Palette.fg
                font.family: Palette.font; font.pixelSize: 12; font.bold: true
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: parent.hovered = true
                onExited: parent.hovered = false
                onClicked: root.removeTask(index)
              }
            }
          }
        }
      }
    }
  }
}
