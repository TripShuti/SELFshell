// ============================================================
// quickshell/popups/mpris/PlaylistSection.qml — виїзджаюча секція плейлісту: список треків навколо поточного
// ============================================================
import QtQuick
import QtQuick.Layouts

// Секція плейлісту. Дані черги — з TrackListService (прокидається об'єктом);
// цільову висоту рахує корінь (_updatePlaylistTarget), сюди приходить готове
// sectionHeight. Прокрутка до поточного треку — локальна (_scrollPlaylistToCurrent).
Item {
  id: root

  required property QtObject window
  required property QtObject tracklistService
  required property real sectionHeight
  required property string currentTrackId
  required property bool playlistOpen

  Layout.fillWidth: true
  Layout.preferredHeight: sectionHeight
  visible: sectionHeight > 0
  clip: true

  // NOTE: дубль форматування часу з PlaybackControls — правити обидва
  // (спільний модуль відхилено свідомо: два споживачі не варті нового файлу;
  // якщо з'явиться третій — переглянути).
  function formatTime(secs) {
    if (isNaN(secs) || secs < 0) return "0:00"
    var m = Math.floor(secs / 60)
    var s = Math.floor(secs % 60)
    return m + ":" + (s < 10 ? "0" : "") + s
  }

  // Прокручує список плейлісту до поточного треку.
  // mode: ListView.Beginning — при відкритті/перезавантаженні (поточний зверху),
  // ListView.Visible — при зміні треку (мінімальний скрол, не смикає перегляд)
  function _scrollPlaylistToCurrent(mode) {
    if (!playlistOpen || !playlistList || playlistList.count === 0) return
    var idx = playlistList.currentIndex
    if (idx >= 0) playlistList.positionViewAtIndex(idx, mode ?? ListView.Visible)
  }

  // При відкритті — після завершення анімації висоти фокусуємось на поточному треку
  onPlaylistOpenChanged: {
    if (playlistOpen) playlistScrollTimer.start()
  }

  Timer {
    id: playlistScrollTimer
    interval: 300
    onTriggered: root._scrollPlaylistToCurrent(ListView.Beginning)
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: 4

    // Заголовок секції
    RowLayout {
      Layout.fillWidth: true
      spacing: 6

      Text {
        text: "Playlist"
        color: window.palette.fg
        font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(11); font.bold: true
      }

      Text {
        text: tracklistService.trackIds.length + " tracks"
        color: window.palette.gray
        font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(9)
      }

      Item { Layout.fillWidth: true }

      Text {
        text: "Loading..."
        visible: tracklistService.loading
        color: window.palette.gray
        font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(9)
      }
    }

    // Список треків навколо поточного
    ListView {
      id: playlistList
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: 2
      clip: true
      model: tracklistService.tracks

      // Індекс поточного треку в завантаженому вікні
      currentIndex: {
        var ts = tracklistService.tracks
        for (var i = 0; i < ts.length; ++i) {
          if (ts[i] && ts[i].trackId === currentTrackId) return i
        }
        return -1
      }
      onCurrentIndexChanged: _scrollPlaylistToCurrent(ListView.Visible)
      onModelChanged: {
        hoveredIndex = -1
        // guard: при закритті попапа callLater може виконатись вже після знищення root
        Qt.callLater(function() { if (root) _scrollPlaylistToCurrent(ListView.Beginning) })
      }

      // Індекс треку під курсором. Централізований, бо при ресайклінгу
      // делегатів containsMouse у делегаті залишається застарілим і
      // підсвітка блимає/зависає під час скролу
      property int hoveredIndex: -1
      onMovementStarted: hoveredIndex = -1

      // Порожній стан
      Text {
        anchors.centerIn: parent
        text: "No tracks"
        visible: !tracklistService.loading && parent.count === 0
        color: window.palette.gray
        font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(10)
      }

      delegate: Item {
        required property var modelData
        required property int index

        readonly property bool isCurrent: currentTrackId !== ""
            && modelData && modelData.trackId === currentTrackId

        width: ListView.view.width
        height: 36

        Rectangle {
          anchors.fill: parent
          radius: 5
          color: playlistList.hoveredIndex === index ? window.palette.bg1 : "transparent"

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 8

            Text {
              text: isCurrent ? "\uF04B" : ""
              color: window.palette.green
              font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(9)
              Layout.preferredWidth: 14
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 1

              Text {
                text: modelData?.title ?? "Unknown"
                color: isCurrent ? window.palette.green : window.palette.fg
                font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(12)
                font.bold: isCurrent
                elide: Text.ElideRight
                Layout.fillWidth: true
              }

              Text {
                text: modelData?.artist ?? ""
                visible: (modelData?.artist ?? "") !== ""
                color: window.palette.gray
                font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(11)
                elide: Text.ElideRight
                Layout.fillWidth: true
              }
            }

            Text {
              text: formatTime((modelData?.length ?? 0) / 1000000)
              color: window.palette.gray
              font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(10)
            }
          }

          MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            onEntered: playlistList.hoveredIndex = index
            onExited: if (playlistList.hoveredIndex === index) playlistList.hoveredIndex = -1
            onClicked: tracklistService.goTo(modelData.trackId)
          }
        }
      }
    }
  }
}
