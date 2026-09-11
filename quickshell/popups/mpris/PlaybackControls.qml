// ============================================================
// quickshell/popups/mpris/PlaybackControls.qml — керування відтворенням: кнопки, гучність, shuffle/loop, прогрес
// ============================================================
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

// Кнопки плеєра, вторинний ряд (гучність/shuffle/loop/перемикачі секцій)
// і смужка прогресу. Плеєр прокидається об'єктом (усі дії — прямі виклики
// його методів/властивостей); стани секцій — значення+сигнал, бо висотами
// керує корінь. MprisLoopState видимий через QML-імпорт (на відміну від .js).
ColumnLayout {
  id: root

  required property QtObject window
  required property var player
  required property bool tracklistSupported
  required property bool playlistOpen
  signal togglePlaylist()
  required property bool eqOpen
  signal toggleEq()

  Layout.fillWidth: true
  spacing: 6

  // NOTE: дубль форматування часу з PlaylistSection — правити обидва
  // (спільний модуль відхилено свідомо: два споживачі не варті нового файлу;
  // якщо з'явиться третій — переглянути).
  function formatTime(secs) {
    if (isNaN(secs) || secs < 0) return "0:00"
    var m = Math.floor(secs / 60)
    var s = Math.floor(secs % 60)
    return m + ":" + (s < 10 ? "0" : "") + s
  }

  // Плавне встановлення гучності за позицією миші на треку
  function _setVolumeFrom(track, mouse) {
    if (!player) return
    var ratio = mouse.x / track.width
    player.volume = Math.max(0, Math.min(ratio, 1))
  }

  // Плавна перемотка за позицією миші на треку прогресу
  function _seekFrom(track, mouse) {
    if (!player?.canSeek) return
    var ratio = Math.max(0, Math.min(mouse.x / track.width, 1))
    player.position = ratio * player.length
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: 10
    Layout.alignment: Qt.AlignHCenter
    visible: player != null

    // Попередній трек
    Rectangle {
      property bool hovered: false
      width: 28; height: 28; radius: 14
      color: hovered ? window.palette.bg2 : window.palette.bg1
      Behavior on color { ColorAnimation { duration: window.appConfig.anim(150) } }
      Text {
        anchors.centerIn: parent
        text: "\uF04A"
        color: window.palette.fg; font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(12)
      }
      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: parent.hovered = true
        onExited: parent.hovered = false
        onClicked: player?.previous()
      }
    }

    // Відтворення / Пауза
    Rectangle {
      property bool hovered: false
      width: 36; height: 36; radius: 18
      color: window.palette.green
      border.width: hovered ? 2 : 0
      border.color: window.palette.fg
      Behavior on color { ColorAnimation { duration: window.appConfig.anim(150) } }
      Text {
        anchors.centerIn: parent
        text: player?.isPlaying ? "\uF04C" : "\uF04B"
        color: window.palette.bg0H; font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(14)
      }
      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: parent.hovered = true
        onExited: parent.hovered = false
        onClicked: player?.togglePlaying()
      }
    }

    // Наступний трек
    Rectangle {
      property bool hovered: false
      width: 28; height: 28; radius: 14
      color: hovered ? window.palette.bg2 : window.palette.bg1
      Behavior on color { ColorAnimation { duration: window.appConfig.anim(150) } }
      Text {
        anchors.centerIn: parent
        text: "\uF04E"
        color: window.palette.fg; font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(12)
      }
      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: parent.hovered = true
        onExited: parent.hovered = false
        onClicked: player?.next()
      }
    }
  }

  // Вторинні елементи: гучність зліва, shuffle/loop/playlist справа
  // EQ кнопка — системна, лишається видимою навіть без плеєра
  RowLayout {
    Layout.fillWidth: true
    spacing: 4

    // Гучність — компактний блок зліва
    RowLayout {
      Layout.alignment: Qt.AlignVCenter
      spacing: 6
      visible: player?.volumeSupported ?? false

      Text {
        text: "\uF028"
        color: window.palette.gray
        font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(9)
      }

      // Тонкий трек з круглою ручкою, як у типових плеєрах
      Rectangle {
        id: volTrack
        Layout.preferredWidth: 84
        height: 4
        radius: 1.5
        color: window.palette.bgAlpha
        Layout.alignment: Qt.AlignVCenter

        Rectangle {
          width: parent.width * Math.min(player?.volume ?? 0, 1)
          height: parent.height
          radius: 1.5
          color: window.palette.green
          Behavior on width { enabled: !maVol.pressed; NumberAnimation { duration: window.appConfig.anim(120); easing.type: Easing.OutCubic } }
        }

        // Ручка — круглий індикатор поточної гучності
        Rectangle {
          width: 8; height: 8; radius: 4
          color: window.palette.fg
          x: Math.min(Math.max(parent.width * Math.min(player?.volume ?? 0, 1) - width / 2, 0), parent.width - width)
          y: (parent.height - height) / 2
          Behavior on x { enabled: !maVol.pressed; NumberAnimation { duration: window.appConfig.anim(120); easing.type: Easing.OutCubic } }
        }

        // Drag: ведення миші після натискання змінює гучність плавно
        MouseArea {
          id: maVol
          anchors.fill: parent
          onPressed: mouse => _setVolumeFrom(volTrack, mouse)
          onPositionChanged: mouse => {
            if (pressed) _setVolumeFrom(volTrack, mouse)
          }
        }
      }
    }

    Item { Layout.fillWidth: true }

    // Кнопка перемішування
    Rectangle {
      property bool hovered: false
      width: 20; height: 20; radius: 4
      color: player?.shuffle ? window.palette.green : (hovered ? window.palette.bg2 : "transparent")
      Behavior on color { ColorAnimation { duration: window.appConfig.anim(150) } }
      Text {
        anchors.centerIn: parent
        text: "\uF074"
        color: player?.shuffle ? window.palette.bg0H : window.palette.gray
        font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(10)
      }
      visible: player != null && player.shuffleSupported
      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: parent.hovered = true
        onExited: parent.hovered = false
        onClicked: { if (player) player.shuffle = !player.shuffle }
      }
    }

    // Кнопка повтору (None / Playlist / Track)
    Rectangle {
      property bool hovered: false
      width: 20; height: 20; radius: 4
      color: player?.loopState !== MprisLoopState.None ? window.palette.green : (hovered ? window.palette.bg2 : "transparent")
      Behavior on color { ColorAnimation { duration: window.appConfig.anim(150) } }
      Text {
        anchors.centerIn: parent
        text: player?.loopState === MprisLoopState.Track ? "\uF01E" : "\uF0E2"
        color: player?.loopState !== MprisLoopState.None ? window.palette.bg0H : window.palette.gray
        font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(10)
      }
      visible: player != null && player.loopSupported
      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: parent.hovered = true
        onExited: parent.hovered = false
        onClicked: {
          if (!player) return
          if (player.loopState === MprisLoopState.None)
            player.loopState = MprisLoopState.Playlist
          else if (player.loopState === MprisLoopState.Playlist)
            player.loopState = MprisLoopState.Track
          else
            player.loopState = MprisLoopState.None
        }
      }
    }

    // Кнопка плейлісту (виїзджаюча секція)
    Rectangle {
      property bool hovered: false
      width: 20; height: 20; radius: 4
      color: playlistOpen ? window.palette.green : (hovered ? window.palette.bg2 : "transparent")
      Behavior on color { ColorAnimation { duration: window.appConfig.anim(150) } }
      Text {
        anchors.centerIn: parent
        text: "\uF03A"
        color: playlistOpen ? window.palette.bg0H : window.palette.gray
        font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(10)
      }
      visible: player != null && tracklistSupported
      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: parent.hovered = true
        onExited: parent.hovered = false
        onClicked: root.togglePlaylist()
      }
    }

    // Кнопка еквалайзера (виїзджаюча секція; EQ системний, працює
    // незалежно від плеєра)
    Rectangle {
      property bool hovered: false
      width: 20; height: 20; radius: 4
      color: eqOpen ? window.palette.green : (hovered ? window.palette.bg2 : "transparent")
      Behavior on color { ColorAnimation { duration: window.appConfig.anim(150) } }
      Text {
        anchors.centerIn: parent
        text: "\uF1DE"
        color: eqOpen ? window.palette.bg0H : window.palette.gray
        font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(10)
      }
      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: parent.hovered = true
        onExited: parent.hovered = false
        onClicked: root.toggleEq()
      }
    }
  }

  // Смужка прогресу
  RowLayout {
    id: progRow
    Layout.fillWidth: true
    spacing: 4
    visible: player != null && player.lengthSupported

    // Поточний час (клемпимо дрейф інтерполяції позиції до довжини)
    Text {
      text: formatTime(Math.min(player?.position ?? 0, player?.length ?? 0))
      color: window.palette.gray
      font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(9)
    }

    // Трек прогресу
    Rectangle {
      id: progTrack
      Layout.fillWidth: true
      height: 6; radius: 2.5
      color: window.palette.bg1
      Layout.alignment: Qt.AlignVCenter

      // Заповнення; позиція Quickshell інтерполюється і може вийти за межі
      // довжини — клемпимо ratio, щоб бар ніколи не був "повний" через дрейф
      Rectangle {
        readonly property real _ratio: Math.min(Math.max((player?.position ?? 0) / (player?.length ?? 1), 0), 1)
        width: parent.width * _ratio
        color: player?.isPlaying ? window.palette.green : window.palette.gray
        height: parent.height; radius: 2.5
        Behavior on width { NumberAnimation { duration: window.appConfig.anim(300); easing.type: Easing.Linear } }
      }

      // Повзунок при наведенні (fade замість visible)
      Rectangle {
        opacity: progArea.containsMouse ? 1 : 0
        width: 10; height: 10; radius: 5
        color: window.palette.yellow
        anchors.verticalCenter: parent.verticalCenter
        x: Math.min(Math.max(progArea.mouseX - 5, 0), parent.width - 10)
        Behavior on opacity { NumberAnimation { duration: window.appConfig.anim(120); easing.type: Easing.OutCubic } }
      }

      // Drag: ведення миші після натискання перемотує трек плавно
      MouseArea {
        id: progArea
        anchors.fill: parent
        hoverEnabled: true
        onPressed: mouse => _seekFrom(progTrack, mouse)
        onPositionChanged: mouse => {
          if (pressed) _seekFrom(progTrack, mouse)
        }
      }
    }

    // Загальна довжина
    Text {
      text: formatTime(player?.length ?? 0)
      color: window.palette.gray
      font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(9)
    }
  }
}
