// ============================================================
// LauncherPopup.qml — лаунчер додатків з пошуком
// ============================================================
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../scripts/LauncherUsage.js" as Usage
import "../core"

// Лаунчер додатків — пошук, список, сортування за частотою запуску
AnimatedPopup {
  id: root

  required property QtObject anchorItem
  required property QtObject window
  palette: window.palette
  appConfig: window.appConfig

  property string searchText: ""
  property var entries: []

  enterScale: 0.9

  implicitWidth: 400
  implicitHeight: 420

  ScriptModel {
    id: appModel
    values: root.entries
  }

  // Фільтрує додатки за пошуком, сортує за частотою запуску
  function filterApps() {
    var all = DesktopEntries.applications.values
    var q = searchText.toLowerCase().trim()
    var result

    if (q === "") {
      result = [...all]
    } else {
      result = []
      for (var i = 0; i < all.length; ++i) {
        var e = all[i]
        if ((e.name && e.name.toLowerCase().includes(q)) ||
            (e.genericName && e.genericName.toLowerCase().includes(q)))
          result.push(e)
      }
    }

    // Сортування: частота запуску → за абеткою
    result.sort(function(a, b) {
      var ca = Usage.getCount(a.id)
      var cb = Usage.getCount(b.id)
      if (ca !== cb) return cb - ca
      return (a.name || "").localeCompare(b.name || "")
    })

    // Плавна зміна списку: затемнення перед оновленням
    listView.opacity = 0.6
    entries = result
    listView.currentIndex = entries.length > 0 ? 0 : -1
    Qt.callLater(function() { listView.opacity = 1 })
  }

  // Запускає додаток та зберігає статистику
  function launchEntry(entry) {
    if (!entry) return
    Usage.record(entry.id)
    entry.execute()
    saveUsage()
    root.visible = false
  }

  // Запускає вибраний елемент списку
  function launchCurrent() {
    var idx = listView.currentIndex
    if (idx >= 0 && idx < entries.length) {
      launchEntry(entries[idx])
    }
  }

  // Файл персистентності статистики запусків — читається при старті,
  // пишеться при кожному запуску додатку
  FileView {
    id: usageFile
    path: Qt.resolvedUrl("../data/launcher-usage.json")
    blockLoading: true
  }

  // Зберігає статистику запусків у файл
  function saveUsage() {
    usageFile.setText(Usage.serialize())
  }

  Component.onCompleted: {
    anchor.window = window
    try { Usage.setData(JSON.parse(usageFile.text() || "{}")) } catch(e) { Usage.setData({}) }
    filterApps()
  }

  onVisibleChanged: {
    if (visible) {
      var scr = window.screen ?? Quickshell.screens[0]
      if (scr) {
        // anchor.rect — координати відносно вікна-якоря (без scr.x/y:
        // вони зміщували попап на другому моніторі)
        anchor.rect = Qt.rect(
          (scr.width - root.width) / 2,
          (scr.height - root.height) / 2,
          root.width, root.height
        )
      }
      Qt.callLater(function() {
        searchField.text = ""
        searchField.forceActiveFocus()
        filterApps()
      })
    }
  }

  ColumnLayout {
    x: 10; y: 10
    width: parent.width - 20
    height: parent.height - 20
    spacing: 8

    // Рядок пошуку
    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      // Іконка пошуку
      Text {
        text: "\uDB82\uDCC7"
        color: window.palette.mutedAlt
        font.family: window.palette.font; font.pixelSize: appConfig.scaled(16)
      }

      // Поле введення
      TextField {
        id: searchField
        Layout.fillWidth: true
        placeholderText: "Search applications..."
        placeholderTextColor: window.palette.gray
        color: window.palette.fg
        font.family: window.palette.font; font.pixelSize: appConfig.scaled(14)
        focus: true
        selectByMouse: true

        background: Rectangle {
          color: window.palette.bg1
          radius: 4
          antialiasing: true
          border.width: 1
          border.color: searchField.activeFocus ? window.palette.green : "transparent"

          Behavior on border.color { ColorAnimation { duration: appConfig.anim(220) } }
        }

        leftPadding: 10
        rightPadding: 10
        topPadding: 7
        bottomPadding: 7

        Keys.onUpPressed: listView.decrementCurrentIndex()
        Keys.onDownPressed: listView.incrementCurrentIndex()
        Keys.onEscapePressed: root.visible = false
        Keys.onReturnPressed: launchCurrent()

        onTextChanged: {
          root.searchText = text
          filterApps()
        }
      }

      
    }

    // Роздільник
    GradientSeparator { midColor: window.palette.bg2 }

    // Список додатків
    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true

      // Затемнення нижнього краю при прокрутці
      Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 24
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
        currentIndex: 0
        visible: root.entries.length > 0
        Behavior on opacity { NumberAnimation { duration: appConfig.anim(80) } }

        model: appModel.values

        delegate: Item {
          required property var modelData
          required property int index

          width: listView.width
          height: 44

          property bool isCurrent: listView.currentIndex === index

          // Тло рядка
          Rectangle {
            anchors.fill: parent
            radius: 8
            antialiasing: true
            color: isCurrent ? window.palette.bg2 : (ma.containsMouse ? window.palette.bg2 : window.palette.bg1)
            opacity: 0.85
            Behavior on color { ColorAnimation { duration: appConfig.anim(120) } }

            // Акцентна смужка для вибраного (fade замість visible)
            Rectangle {
              id: accentBar
              opacity: isCurrent ? 1 : 0
              width: 3
              height: parent.height - 14
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: parent.left
              anchors.leftMargin: 2
              radius: 2
              antialiasing: true
              color: window.palette.green
              Behavior on opacity { NumberAnimation { duration: appConfig.anim(120); easing.type: Easing.OutCubic } }
            }

            RowLayout {
              x: 12; y: 0
              width: parent.width - 18
              height: parent.height
              spacing: 10

              // Іконка додатка
              Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: 8
                antialiasing: true
                color: "transparent"

                IconImage {
                  anchors.fill: parent
                  anchors.margins: 4
                  source: Quickshell.iconPath(modelData.icon, true)
                }
              }

              // Назва + підпис
              ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                Text {
                  text: modelData.name || ""
                  color: isCurrent ? window.palette.green : window.palette.fg
                  Behavior on color { ColorAnimation { duration: appConfig.anim(120) } }
                  font.family: window.palette.font; font.pixelSize: appConfig.scaled(13); font.bold: true
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }

                Text {
                  text: modelData.genericName || ""
                  color: window.palette.mutedAlt
                  font.family: window.palette.font; font.pixelSize: appConfig.scaled(10)
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                  visible: modelData.genericName !== ""
                }
              }
            }
          }

          MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            // Тільки onClicked: подвійний клік не має власного обробника,
            // бо він генерує onClicked двічі + onDoubleClicked — потрійний запуск
            onClicked: {
              listView.currentIndex = index
              launchEntry(modelData)
            }
          }
        }

        highlightMoveDuration: 80
        keyNavigationWraps: true
      }

      // Порожній стан
      ColumnLayout {
        anchors.centerIn: parent
        visible: root.entries.length === 0
        spacing: 4

        Text {
          Layout.alignment: Qt.AlignHCenter
          text: "\uF002"
          color: window.palette.mutedAlt
          font.family: window.palette.font; font.pixelSize: appConfig.scaled(22)
        }

        Text {
          Layout.alignment: Qt.AlignHCenter
          text: root.searchText.trim() === "" ? "No applications found" : "No results for \"" + root.searchText.trim() + "\""
          color: window.palette.mutedAlt
          font.family: window.palette.font; font.pixelSize: appConfig.scaled(12)
        }
      }
    }


  }
}
