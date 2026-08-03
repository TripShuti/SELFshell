// ============================================================
// MprisPopup.qml — медіаплеєр: трек, керування, візуалізатор
// ============================================================
import Quickshell.Services.Mpris
import "../core"
import "../services"
import QtQuick
import QtQuick.Layouts

// Попап медіаплеєра — поточний трек, керування, візуалізатор
AnimatedPopup {
  id: root

  required property QtObject anchorItem
  required property QtObject window
  palette: window.palette

  implicitWidth: 400
  implicitHeight: layout.implicitHeight + 4
  transformOrigin: Item.Top

  property string preferredPlayer: "selfsonic"
  property var player: null
  property var cavBars: [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]

  property bool artError: false

  // Стабілізований artUrl: 
  // metadata push (~2/с), тож trackArtUrl міняється постійно, і без
  // стабілізації Image перезавантажував би HTTP-картинку при кожному push.
  // Оновлюємо source лише коли змінився сам трек (ключ — URL без токена);
  // оновлення робить findAndSetPlayer (викликається таймером кожні 2с).
  property string _artUrl: ""
  property string _lastArtKey: ""

  function _artKeyOf(url) {
    return url.replace(/[?&](s|t)=[^&]*/g, "")
  }

  // --- Плейліст ---
  property bool playlistOpen: false
  property real playlistHeight
  property real playlistTarget: 0

  // Ім'я плеєра для TrackListService (з identity, інакше dbusName)
  readonly property string _servicePlayer: {
    var p = root.player
    if (!p) return ""
    var ident = (p.identity ?? "").toLowerCase()
    return ident !== "" ? ident : (p.dbusName ?? "")
  }

  // Поточний trackid з метаданих плеєра.
  // Quickshell віддає mpris:trackid як QVariant(QDBusObjectPath) і String()
  // перетворює його в "QVariant(QDBusObjectPath, QDBusObjectPath(\"...\"))".
  // Витягуємо чистий шлях регуляркою (формат Qt), інакше — fallback.
  readonly property string _currentTrackId: {
    var p = root.player
    if (!p || !p.metadata) return ""
    var id = p.metadata["mpris:trackid"]
    if (!id) return ""
    var m = String(id).match(/QDBusObjectPath\("([^"]+)"\)/)
    return m ? m[1] : String(id)
  }

  // Сервіс MPRIS TrackList (список треків через scripts/tracklist.py)
  TrackListService {
    id: tracklistService
    playerName: root._servicePlayer
    active: root.visible

    onTracksChanged: root._updatePlaylistTarget()
  }

  // Періодичне оновлення списку, поки плейліст відкритий
  Timer {
    interval: 20000
    running: root.visible && root.playlistOpen
    repeat: true
    onTriggered: tracklistService.refresh()
  }

  // Рахує цільову висоту секції плейлісту (заголовок + список)
  function _updatePlaylistTarget() {
    var rows = Math.min(tracklistService.tracks.length, 10)
    var listHeight = rows * 36 + Math.max(0, rows - 1) * 2
    root.playlistTarget = 26 + listHeight
  }

  // Прокручує список плейлісту до поточного треку.
  // mode: ListView.Beginning — при відкритті/перезавантаженні (поточний зверху),
  // ListView.Visible — при зміні треку (мінімальний скрол, не смикає перегляд)
  function _scrollPlaylistToCurrent(mode) {
    if (!root.playlistOpen || !playlistList || playlistList.count === 0) return
    var idx = playlistList.currentIndex
    if (idx >= 0) playlistList.positionViewAtIndex(idx, mode ?? ListView.Visible)
  }

  function _updateAnchor() {
    if (!root.visible) return
    root.positionUnderAnchor()
  }

  popupWindow: window
  anchorTarget: anchorItem

  Component.onCompleted: {
    anchor.window = window
  }

  onVisibleChanged: {
    if (visible) root.positionUnderAnchor()
  }

  // Знаходить плеєр за назвою або перший доступний.
  // Не перезаписує player, якщо той самий об'єкт — інакше таймер
  // періодичного пошуку спамив би перепризначенням.
  function findAndSetPlayer() {
    var target = null
    var fallback = null

    for (var i = 0; i < playerRepeater.count; ++i) {
      var del = playerRepeater.itemAt(i)
      if (!del || !del.modelData) continue
      if (!fallback && del.modelData.trackTitle) fallback = del.modelData
      if (del.playerName.indexOf(root.preferredPlayer) >= 0) {
        target = del.modelData
        break
      }
    }

    var best = target ?? fallback
    if (root.player !== best) root.player = best

    // Стабілізація artUrl: не чіпаємо source, поки змінюється лише auth-токен
    var raw = root.player?.trackArtUrl ?? ""
    var key = root._artKeyOf(raw)
    if (key !== root._lastArtKey) {
      root._lastArtKey = key
      root._artUrl = raw
    }
  }

  // Стежить за появою/зникненням плеєрів Mpris
  Repeater {
    id: playerRepeater
    model: Mpris.players

    delegate: Item {
      required property var modelData
      required property int index

      readonly property string playerName: (modelData.identity ?? modelData.dbusName ?? "").toLowerCase()

      Component.onCompleted: root.findAndSetPlayer()
      Component.onDestruction: Qt.callLater(root.findAndSetPlayer)
    }
  }

  // Періодичний пошук плеєра. Крутиться ЗАВЖДИ: Mpris-модель наповнюється
  // асинхронно (плеєри під'єднуються по одному), тож fallback (напр. mpv без
  // artUrl/TrackList) може виграти спочатку. Постійний таймер підхоплює
  // preferredPlayer, щойно той з'явиться в моделі.
  Timer {
    interval: 2000
    running: true
    repeat: true
    onTriggered: root.findAndSetPlayer()
  }

  // Позиція плеєра не реактивна: Quickshell emitи positionChanged лише на
  // нелінійні зміни (seek/зміна треку). Інтерполяція позиції (Position +
  // таймстемп) дрейфує і може випередити реальний стан, тож часті ретрансляції
  // дають бар "повний". Оновлюємо не частіше ніж раз на секунду; смужка
  // сама клемпить значення до довжини треку.
  Timer {
    interval: 1000
    running: root.player?.isPlaying ?? false
    repeat: true
    onTriggered: {
      if (root.player) root.player.positionChanged()
    }
  }

  // Форматує секунди в "m:ss"
  function formatTime(secs) {
    if (isNaN(secs) || secs < 0) return "0:00"
    var m = Math.floor(secs / 60)
    var s = Math.floor(secs % 60)
    return m + ":" + (s < 10 ? "0" : "") + s
  }

  // Плавне встановлення гучності за позицією миші на треку
  function _setVolumeFrom(track, mouse) {
    if (!root.player) return
    var ratio = mouse.x / track.width
    root.player.volume = Math.max(0, Math.min(ratio, 1))
  }

  // Плавна перемотка за позицією миші на треку прогресу
  function _seekFrom(track, mouse) {
    if (!root.player?.canSeek) return
    var ratio = Math.max(0, Math.min(mouse.x / track.width, 1))
    root.player.position = ratio * root.player.length
  }

  // Якщо плеєр зник — закриваємо секцію плейлісту
  onPlayerChanged: {
    if (!root.player) root.playlistOpen = false
  }

  // При відкритті — після завершення анімації висоти фокусуємось на поточному треку
  onPlaylistOpenChanged: {
    if (root.playlistOpen) playlistScrollTimer.start()
  }

  Timer {
    id: playlistScrollTimer
    interval: 300
    onTriggered: root._scrollPlaylistToCurrent(ListView.Beginning)
  }

  // Анімована висота секції плейлісту; вікно підлаштовується кожен кадр
  playlistHeight: root.playlistOpen ? root.playlistTarget : 0
  Behavior on playlistHeight {
    NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
  }
  onPlaylistHeightChanged: root._updateAnchor()


  ColumnLayout {
    id: layout
    anchors.fill: parent
    anchors.leftMargin: 8
    anchors.rightMargin: 8
    anchors.topMargin: 0
    anchors.bottomMargin: 13
    spacing: 6


    // Роздільник
    GradientSeparator {
      midColor: window.palette.bg2
      Layout.fillWidth: true
      Layout.preferredHeight: 5
    }

    // Аудіо-візуалізатор (cava) — на самому верху, під усіма елементами
    RowLayout {
      Layout.fillWidth: true
      height: 24
      spacing: 2
      visible: root.player != null

      Repeater {
        model: 28

        delegate: Rectangle {
          required property int index

          Layout.fillWidth: true
          Layout.alignment: Qt.AlignBottom

          readonly property real raw: root.cavBars[index] ?? 0
          readonly property real vheight: Math.max(2, raw * 24)
          readonly property real ratio: raw

          height: vheight
          radius: 1
          color: ratio > 0.7 ? window.palette.green :
                 ratio > 0.4 ? window.palette.purple :
                 window.palette.gray

          // Тільки Behavior on height: ColorAnimation тут рестартувала б
          // ~28 разів на кожен кадр cava (30 fps)
          Behavior on height {
            NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 0.6 }
          }
        }
      }
    }

    // Інформація про трек + обкладинка
    RowLayout {
      Layout.fillWidth: true
      spacing: 8
      visible: root.player != null

      // Обкладинка альбому
      Rectangle {
        width: 80; height: 80; radius: 1
        color: window.palette.bg1
        border.width: 1
        border.color: root.player?.isPlaying ? window.palette.green : window.palette.bg2
        Behavior on border.color { ColorAnimation { duration: 200 } }

        Image {
          id: artImg
          anchors.fill: parent
          anchors.margins: 1
          source: root._artUrl
          visible: root.player != null && root._artUrl !== "" && !root.artError
          fillMode: Image.PreserveAspectCrop
          onStatusChanged: {
            if (status === Image.Error) root.artError = true
            else if (status === Image.Ready) root.artError = false
          }
          onSourceChanged: root.artError = false
        }

        // Заглушка якщо немає обкладинки
        Text {
          anchors.centerIn: parent
          text: "\uF025"
          color: window.palette.gray
          font.family: window.palette.font; font.pixelSize: 28
          visible: root.player == null || root._artUrl === "" || artImg.status === Image.Error
        }

        // Індикатор відтворення
        Rectangle {
          visible: root.player?.isPlaying ?? false
          width: 10; height: 10; radius: 5
          color: window.palette.green
          border.width: 2
          border.color: window.palette.bg0H
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          anchors.margins: -2

          SequentialAnimation on opacity {
            running: root.player?.isPlaying ?? false
            loops: Animation.Infinite
            NumberAnimation { to: 0.4; duration: 700 }
            NumberAnimation { to: 1.0; duration: 700 }
          }
        }
      }

      // Назва треку, виконавець, альбом
      ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: 4

        Text {
          text: root.player?.trackTitle ?? "No track"
          color: root.player?.isPlaying ? window.palette.green : window.palette.fg
          font.family: window.palette.font; font.pixelSize: 14; font.bold: true
          elide: Text.ElideRight
          Layout.fillWidth: true
          wrapMode: Text.WordWrap
          maximumLineCount: 2
        }

        Text {
          text: root.player?.trackArtist ?? ""
          color: window.palette.fg
          font.family: window.palette.font; font.pixelSize: 11
          elide: Text.ElideRight
          Layout.fillWidth: true
          visible: root.player != null && root.player.trackArtist !== ""
        }

        Text {
          text: root.player?.trackAlbum ?? ""
          color: window.palette.gray
          font.family: window.palette.font; font.pixelSize: 10
          elide: Text.ElideRight
          Layout.fillWidth: true
          visible: root.player != null && root.player.trackAlbum !== ""
        }
      }

    }

    // Кнопки керування — по центру, як у типових плеєрах
    RowLayout {
      Layout.fillWidth: true
      spacing: 10
      Layout.alignment: Qt.AlignHCenter
      visible: root.player != null

      // Попередній трек
      Rectangle {
        property bool hovered: false
        width: 28; height: 28; radius: 14
        color: hovered ? window.palette.bg2 : window.palette.bg1
        Behavior on color { ColorAnimation { duration: 150 } }
        Text {
          anchors.centerIn: parent
          text: "\uF04A"
          color: window.palette.fg; font.family: window.palette.font; font.pixelSize: 12
        }
        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          onEntered: parent.hovered = true
          onExited: parent.hovered = false
          onClicked: root.player?.previous()
        }
      }

      // Відтворення / Пауза
      Rectangle {
        property bool hovered: false
        width: 36; height: 36; radius: 18
        color: window.palette.green
        border.width: hovered ? 2 : 0
        border.color: window.palette.fg
        Behavior on color { ColorAnimation { duration: 150 } }
        Text {
          anchors.centerIn: parent
          text: root.player?.isPlaying ? "\uF04C" : "\uF04B"
          color: window.palette.bg0H; font.family: window.palette.font; font.pixelSize: 14
        }
        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          onEntered: parent.hovered = true
          onExited: parent.hovered = false
          onClicked: root.player?.togglePlaying()
        }
      }

      // Наступний трек
      Rectangle {
        property bool hovered: false
        width: 28; height: 28; radius: 14
        color: hovered ? window.palette.bg2 : window.palette.bg1
        Behavior on color { ColorAnimation { duration: 150 } }
        Text {
          anchors.centerIn: parent
          text: "\uF04E"
          color: window.palette.fg; font.family: window.palette.font; font.pixelSize: 12
        }
        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          onEntered: parent.hovered = true
          onExited: parent.hovered = false
          onClicked: root.player?.next()
        }
      }
    }

    // Вторинні елементи: гучність зліва, shuffle/loop/playlist справа
    RowLayout {
      Layout.fillWidth: true
      spacing: 4
      visible: root.player != null

      // Гучність — компактний блок зліва
      RowLayout {
        Layout.alignment: Qt.AlignVCenter
        spacing: 6
        visible: root.player?.volumeSupported ?? false

        Text {
          text: "\uF028"
          color: window.palette.gray
          font.family: window.palette.font; font.pixelSize: 9
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
            width: parent.width * Math.min(root.player?.volume ?? 0, 1)
            height: parent.height
            radius: 1.5
            color: window.palette.green
          }

          // Ручка — круглий індикатор поточної гучності
          Rectangle {
            width: 8; height: 8; radius: 4
            color: window.palette.fg
            x: Math.min(Math.max(parent.width * Math.min(root.player?.volume ?? 0, 1) - width / 2, 0), parent.width - width)
            y: (parent.height - height) / 2
          }

          // Drag: ведення миші після натискання змінює гучність плавно
          MouseArea {
            anchors.fill: parent
            onPressed: mouse => root._setVolumeFrom(volTrack, mouse)
            onPositionChanged: mouse => {
              if (pressed) root._setVolumeFrom(volTrack, mouse)
            }
          }
        }
      }

      Item { Layout.fillWidth: true }

      // Кнопка перемішування
      Rectangle {
        property bool hovered: false
        width: 20; height: 20; radius: 4
        color: root.player?.shuffle ? window.palette.green : (hovered ? window.palette.bg2 : "transparent")
        Behavior on color { ColorAnimation { duration: 150 } }
        Text {
          anchors.centerIn: parent
          text: "\uF074"
          color: root.player?.shuffle ? window.palette.bg0H : window.palette.gray
          font.family: window.palette.font; font.pixelSize: 10
        }
        visible: root.player != null && root.player.shuffleSupported
        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          onEntered: parent.hovered = true
          onExited: parent.hovered = false
          onClicked: { if (root.player) root.player.shuffle = !root.player.shuffle }
        }
      }

      // Кнопка повтору (None / Playlist / Track)
      Rectangle {
        property bool hovered: false
        width: 20; height: 20; radius: 4
        color: root.player?.loopState !== MprisLoopState.None ? window.palette.green : (hovered ? window.palette.bg2 : "transparent")
        Behavior on color { ColorAnimation { duration: 150 } }
        Text {
          anchors.centerIn: parent
          text: root.player?.loopState === MprisLoopState.Track ? "\uF01E" : "\uF0E2"
          color: root.player?.loopState !== MprisLoopState.None ? window.palette.bg0H : window.palette.gray
          font.family: window.palette.font; font.pixelSize: 10
        }
        visible: root.player != null && root.player.loopSupported
        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          onEntered: parent.hovered = true
          onExited: parent.hovered = false
          onClicked: {
            if (!root.player) return
            if (root.player.loopState === MprisLoopState.None)
              root.player.loopState = MprisLoopState.Playlist
            else if (root.player.loopState === MprisLoopState.Playlist)
              root.player.loopState = MprisLoopState.Track
            else
              root.player.loopState = MprisLoopState.None
          }
        }
      }

      // Кнопка плейлісту (виїзджаюча секція)
      Rectangle {
        property bool hovered: false
        width: 20; height: 20; radius: 4
        color: root.playlistOpen ? window.palette.green : (hovered ? window.palette.bg2 : "transparent")
        Behavior on color { ColorAnimation { duration: 150 } }
        Text {
          anchors.centerIn: parent
          text: "\uF03A"
          color: root.playlistOpen ? window.palette.bg0H : window.palette.gray
          font.family: window.palette.font; font.pixelSize: 10
        }
        visible: root.player != null && tracklistService.supported
        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          onEntered: parent.hovered = true
          onExited: parent.hovered = false
          onClicked: root.playlistOpen = !root.playlistOpen
        }
      }
    }

    // Смужка прогресу
    RowLayout {
      id: progRow
      Layout.fillWidth: true
      spacing: 4
      visible: root.player != null && root.player.lengthSupported

      // Поточний час (клемпимо дрейф інтерполяції позиції до довжини)
      Text {
        text: formatTime(Math.min(root.player?.position ?? 0, root.player?.length ?? 0))
        color: window.palette.gray
        font.family: window.palette.font; font.pixelSize: 9
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
          readonly property real _ratio: Math.min(Math.max((root.player?.position ?? 0) / (root.player?.length ?? 1), 0), 1)
          width: parent.width * _ratio
          color: root.player?.isPlaying ? window.palette.green : window.palette.gray
          height: parent.height; radius: 2.5
          Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.Linear } }
        }

        // Повзунок при наведенні
        Rectangle {
          visible: progArea.containsMouse
          width: 10; height: 10; radius: 5
          color: window.palette.yellow
          anchors.verticalCenter: parent.verticalCenter
          x: Math.min(Math.max(progArea.mouseX - 5, 0), parent.width - 10)
        }

        // Drag: ведення миші після натискання перемотує трек плавно
        MouseArea {
          id: progArea
          anchors.fill: parent
          hoverEnabled: true
          onPressed: mouse => root._seekFrom(progTrack, mouse)
          onPositionChanged: mouse => {
            if (pressed) root._seekFrom(progTrack, mouse)
          }
        }
      }

      // Загальна довжина
      Text {
        text: formatTime(root.player?.length ?? 0)
        color: window.palette.gray
        font.family: window.palette.font; font.pixelSize: 9
      }
    }

    // Плейліст (виїзджаюча секція зі списком треків)
    // Layout.preferredHeight замість height: явний height не враховується
    // в implicitHeight ColumnLayout, і вікно попапа не росте
    Item {
      id: playlistSection
      Layout.fillWidth: true
      Layout.preferredHeight: root.playlistHeight
      visible: root.playlistHeight > 0
      clip: true

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
            font.family: window.palette.font; font.pixelSize: 11; font.bold: true
          }

          Text {
            text: tracklistService.trackIds.length + " tracks"
            color: window.palette.gray
            font.family: window.palette.font; font.pixelSize: 9
          }

          Item { Layout.fillWidth: true }

          Text {
            text: "Loading..."
            visible: tracklistService.loading
            color: window.palette.gray
            font.family: window.palette.font; font.pixelSize: 9
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
              if (ts[i] && ts[i].trackId === root._currentTrackId) return i
            }
            return -1
          }
          onCurrentIndexChanged: root._scrollPlaylistToCurrent(ListView.Visible)
          onModelChanged: {
            hoveredIndex = -1
            // guard: при закритті попапа callLater може виконатись вже після знищення root
            Qt.callLater(function() { if (root) root._scrollPlaylistToCurrent(ListView.Beginning) })
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
            font.family: window.palette.font; font.pixelSize: 10
          }

          delegate: Item {
            required property var modelData
            required property int index

            readonly property bool isCurrent: root._currentTrackId !== ""
                && modelData && modelData.trackId === root._currentTrackId

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
                  font.family: window.palette.font; font.pixelSize: 9
                  Layout.preferredWidth: 14
                }

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 1

                  Text {
                    text: modelData?.title ?? "Unknown"
                    color: isCurrent ? window.palette.green : window.palette.fg
                    font.family: window.palette.font; font.pixelSize: 11
                    font.bold: isCurrent
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                  }

                  Text {
                    text: modelData?.artist ?? ""
                    visible: (modelData?.artist ?? "") !== ""
                    color: window.palette.gray
                    font.family: window.palette.font; font.pixelSize: 9
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                  }
                }

                Text {
                  text: root.formatTime((modelData?.length ?? 0) / 1000000)
                  color: window.palette.gray
                  font.family: window.palette.font; font.pixelSize: 9
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

    // Порожній стан — немає плеєра
    ColumnLayout {
      Layout.fillWidth: true
      Layout.topMargin: 24
      Layout.bottomMargin: 24
      spacing: 4
      visible: root.player == null

      Text {
        Layout.alignment: Qt.AlignHCenter
        text: "\uF001"
        color: window.palette.gray
        font.family: window.palette.font; font.pixelSize: 22
      }

      Text {
        Layout.alignment: Qt.AlignHCenter
        text: "No player detected"
        color: window.palette.gray
        font.family: window.palette.font; font.pixelSize: 12
      }
    }
  }
}
