// ============================================================
// MprisPopup.qml — медіаплеєр: трек, керування, візуалізатор
// ============================================================
import Quickshell.Services.Mpris
import "../core"
import "../services"
import "../scripts/EqPresets.js" as EqPresets
import QtQuick
import QtQuick.Layouts

// Попап медіаплеєра — поточний трек, керування, візуалізатор
AnimatedPopup {
  id: root

  required property QtObject anchorItem
  required property QtObject window
  palette: window.palette
  appConfig: window.appConfig

  implicitWidth: 400
  implicitHeight: layout.implicitHeight + 4
  transformOrigin: Item.Top

  // Улюблений плеєр — спільний з бар-віджетом, персистентний (config.json).
  // Змінюється селектором вгорі попапа
  readonly property string preferredPlayer: window.appConfig.cfg.preferredPlayer

  // --- Вибір плеєра (розгортається список на самому верху) ---
  property bool playerSelOpen: false
  property real playerSelHeight
  readonly property real playerSelTarget: Mpris.players.values.length * 26 + 4
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

  // --- Еквалайзер (секція поруч із плейлістом) ---
  property bool eqOpen: false
  // ім'я пресета в режимі перейменування (запускається з контекстного
  // меню; чип малює TextInput замість назви)
  property string renameTarget: ""
  property real eqHeight
  // header + чипи + рядок save/rename + слайдери з підписами
  readonly property real eqTarget: 216

  AudioEq { id: audioEq }

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
    // playlistOpen навмисно НЕ скидається: розгорнутий плейліст має
    // лишатися розгорнутим між відкриттями попапа
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

      readonly property string playerName: (modelData.identity ?? modelData.dbusName ?? "").toLowerCase()

      Component.onCompleted: root.findAndSetPlayer()
      // guard як у _scrollPlaylistToCurrent: callLater може виконатись
      // вже після знищення root
      Component.onDestruction: Qt.callLater(function() { if (root) root.findAndSetPlayer() })
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
    NumberAnimation { duration: appConfig.anim(260); easing.type: Easing.OutCubic }
  }
  onPlaylistHeightChanged: root._updateAnchor()

  // Анімована висота секції еквалайзера
  eqHeight: root.eqOpen ? root.eqTarget : 0
  Behavior on eqHeight {
    NumberAnimation { duration: appConfig.anim(260); easing.type: Easing.OutCubic }
  }
  onEqHeightChanged: root._updateAnchor()

  playerSelHeight: root.playerSelOpen ? root.playerSelTarget : 0
  Behavior on playerSelHeight {
    NumberAnimation { duration: appConfig.anim(260); easing.type: Easing.OutCubic }
  }
  onPlayerSelHeightChanged: root._updateAnchor()


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
            NumberAnimation { duration: appConfig.anim(140); easing.type: Easing.OutBack; easing.overshoot: 0.6 }
          }
        }
      }
    }

    // Інформація про трек + обкладинка
    RowLayout {
      Layout.fillWidth: true
      spacing: 8
      visible: root.player != null

      // Ліва колонка: обкладинка + пігулка вибору плеєра під нею
      ColumnLayout {
        spacing: 4
        Layout.alignment: Qt.AlignTop

        // Обкладинка альбому (не клікабельна)
        Rectangle {
          id: artCover
          width: 80; height: 80; radius: 1
          color: window.palette.bg1
          border.width: 1
          border.color: root.player?.isPlaying ? window.palette.green : window.palette.bg2
          Behavior on border.color { ColorAnimation { duration: appConfig.anim(200) } }

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
          font.family: window.palette.font; font.pixelSize: appConfig.scaled(28)
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
            NumberAnimation { to: 0.4; duration: appConfig.anim(700) }
            NumberAnimation { to: 1.0; duration: appConfig.anim(700) }
          }
        }
      }

        // Пігулка вибору плеєра — під обкладинкою, показує поточний preferredPlayer
        // мінімалістично: без фону/обводки, лише текст + іконка дропдауна
        Rectangle {
          id: playerPill
          Layout.preferredWidth: 80
          Layout.preferredHeight: 18
          Layout.alignment: Qt.AlignHCenter
          color: "transparent"
          visible: Mpris.players.values.length > 0

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            spacing: 4

            Text {
              text: root.preferredPlayer !== "" ? root.preferredPlayer : (root.player?.identity ?? "No player")
              color: root.playerSelOpen ? window.palette.green : window.palette.fg
              font.family: window.palette.font; font.pixelSize: appConfig.scaled(11)
              font.bold: root.playerSelOpen
              elide: Text.ElideRight
              Layout.fillWidth: true
              Behavior on color { ColorAnimation { duration: appConfig.anim(120) } }
            }

            Text {
              text: root.playerSelOpen ? "\uF077" : "\uF078"
              color: root.playerSelOpen ? window.palette.green : window.palette.mutedAlt
              font.family: window.palette.font; font.pixelSize: 8
              Behavior on color { ColorAnimation { duration: appConfig.anim(120) } }
            }
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.playerSelOpen = !root.playerSelOpen
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
          font.family: window.palette.font; font.pixelSize: appConfig.scaled(14); font.bold: true
          elide: Text.ElideRight
          Layout.fillWidth: true
          wrapMode: Text.WordWrap
          maximumLineCount: 2
        }

        Text {
          text: root.player?.trackArtist ?? ""
          color: window.palette.fg
          font.family: window.palette.font; font.pixelSize: appConfig.scaled(11)
          elide: Text.ElideRight
          Layout.fillWidth: true
          visible: root.player != null && root.player.trackArtist !== ""
        }

        Text {
          text: root.player?.trackAlbum ?? ""
          color: window.palette.gray
          font.family: window.palette.font; font.pixelSize: appConfig.scaled(10)
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
        Behavior on color { ColorAnimation { duration: appConfig.anim(150) } }
        Text {
          anchors.centerIn: parent
          text: "\uF04A"
          color: window.palette.fg; font.family: window.palette.font; font.pixelSize: appConfig.scaled(12)
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
        Behavior on color { ColorAnimation { duration: appConfig.anim(150) } }
        Text {
          anchors.centerIn: parent
          text: root.player?.isPlaying ? "\uF04C" : "\uF04B"
          color: window.palette.bg0H; font.family: window.palette.font; font.pixelSize: appConfig.scaled(14)
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
        Behavior on color { ColorAnimation { duration: appConfig.anim(150) } }
        Text {
          anchors.centerIn: parent
          text: "\uF04E"
          color: window.palette.fg; font.family: window.palette.font; font.pixelSize: appConfig.scaled(12)
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
    // EQ кнопка — системна, лишається видимою навіть без плеєра
    RowLayout {
      Layout.fillWidth: true
      spacing: 4

      // Гучність — компактний блок зліва
      RowLayout {
        Layout.alignment: Qt.AlignVCenter
        spacing: 6
        visible: root.player?.volumeSupported ?? false

        Text {
          text: "\uF028"
          color: window.palette.gray
          font.family: window.palette.font; font.pixelSize: appConfig.scaled(9)
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
            Behavior on width { enabled: !maVol.pressed; NumberAnimation { duration: appConfig.anim(120); easing.type: Easing.OutCubic } }
          }

          // Ручка — круглий індикатор поточної гучності
          Rectangle {
            width: 8; height: 8; radius: 4
            color: window.palette.fg
            x: Math.min(Math.max(parent.width * Math.min(root.player?.volume ?? 0, 1) - width / 2, 0), parent.width - width)
            y: (parent.height - height) / 2
            Behavior on x { enabled: !maVol.pressed; NumberAnimation { duration: appConfig.anim(120); easing.type: Easing.OutCubic } }
          }

          // Drag: ведення миші після натискання змінює гучність плавно
          MouseArea {
            id: maVol
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
        Behavior on color { ColorAnimation { duration: appConfig.anim(150) } }
        Text {
          anchors.centerIn: parent
          text: "\uF074"
          color: root.player?.shuffle ? window.palette.bg0H : window.palette.gray
          font.family: window.palette.font; font.pixelSize: appConfig.scaled(10)
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
        Behavior on color { ColorAnimation { duration: appConfig.anim(150) } }
        Text {
          anchors.centerIn: parent
          text: root.player?.loopState === MprisLoopState.Track ? "\uF01E" : "\uF0E2"
          color: root.player?.loopState !== MprisLoopState.None ? window.palette.bg0H : window.palette.gray
          font.family: window.palette.font; font.pixelSize: appConfig.scaled(10)
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
        Behavior on color { ColorAnimation { duration: appConfig.anim(150) } }
        Text {
          anchors.centerIn: parent
          text: "\uF03A"
          color: root.playlistOpen ? window.palette.bg0H : window.palette.gray
          font.family: window.palette.font; font.pixelSize: appConfig.scaled(10)
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

      // Кнопка еквалайзера (виїзджаюча секція; EQ системний, працює
      // незалежно від плеєра)
      Rectangle {
        property bool hovered: false
        width: 20; height: 20; radius: 4
        color: root.eqOpen ? window.palette.green : (hovered ? window.palette.bg2 : "transparent")
        Behavior on color { ColorAnimation { duration: appConfig.anim(150) } }
        Text {
          anchors.centerIn: parent
          text: "\uF1DE"
          color: root.eqOpen ? window.palette.bg0H : window.palette.gray
          font.family: window.palette.font; font.pixelSize: appConfig.scaled(10)
        }
        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          onEntered: parent.hovered = true
          onExited: parent.hovered = false
          onClicked: root.eqOpen = !root.eqOpen
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
        font.family: window.palette.font; font.pixelSize: appConfig.scaled(9)
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
          Behavior on width { NumberAnimation { duration: appConfig.anim(300); easing.type: Easing.Linear } }
        }

        // Повзунок при наведенні (fade замість visible)
        Rectangle {
          opacity: progArea.containsMouse ? 1 : 0
          width: 10; height: 10; radius: 5
          color: window.palette.yellow
          anchors.verticalCenter: parent.verticalCenter
          x: Math.min(Math.max(progArea.mouseX - 5, 0), parent.width - 10)
          Behavior on opacity { NumberAnimation { duration: appConfig.anim(120); easing.type: Easing.OutCubic } }
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
        font.family: window.palette.font; font.pixelSize: appConfig.scaled(9)
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
            font.family: window.palette.font; font.pixelSize: appConfig.scaled(11); font.bold: true
          }

          Text {
            text: tracklistService.trackIds.length + " tracks"
            color: window.palette.gray
            font.family: window.palette.font; font.pixelSize: appConfig.scaled(9)
          }

          Item { Layout.fillWidth: true }

          Text {
            text: "Loading..."
            visible: tracklistService.loading
            color: window.palette.gray
            font.family: window.palette.font; font.pixelSize: appConfig.scaled(9)
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
            font.family: window.palette.font; font.pixelSize: appConfig.scaled(10)
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
                  font.family: window.palette.font; font.pixelSize: appConfig.scaled(9)
                  Layout.preferredWidth: 14
                }

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 1

                  Text {
                    text: modelData?.title ?? "Unknown"
                    color: isCurrent ? window.palette.green : window.palette.fg
                    font.family: window.palette.font; font.pixelSize: appConfig.scaled(11)
                    font.bold: isCurrent
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                  }

                  Text {
                    text: modelData?.artist ?? ""
                    visible: (modelData?.artist ?? "") !== ""
                    color: window.palette.gray
                    font.family: window.palette.font; font.pixelSize: appConfig.scaled(9)
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                  }
                }

                Text {
                  text: root.formatTime((modelData?.length ?? 0) / 1000000)
                  color: window.palette.gray
                  font.family: window.palette.font; font.pixelSize: appConfig.scaled(9)
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

    // Еквалайзер (виїзджаюча секція; системний, не прив'язаний до плеєра)
    Item {
      id: eqSection
      Layout.fillWidth: true
      Layout.preferredHeight: root.eqHeight
      visible: root.eqHeight > 0
      clip: true

      ColumnLayout {
        anchors.fill: parent
        spacing: 6

        // Заголовок: назва + стан + тумблер
        RowLayout {
          Layout.fillWidth: true
          spacing: 6

          Text {
            text: "Equalizer"
            color: window.palette.fg
            font.family: window.palette.font; font.pixelSize: appConfig.scaled(11); font.bold: true
          }

          Text {
            text: {
              if (!audioEq.pluginInstalled) return "swh-plugins not installed"
              if (audioEq.error !== "") return audioEq.error
              if (audioEq.busy) return "..."
              return audioEq.enabled ? "on" : "off"
            }
            color: {
              if (!audioEq.pluginInstalled || audioEq.error !== "") return window.palette.danger
              return window.palette.gray
            }
            font.family: window.palette.font; font.pixelSize: appConfig.scaled(9)
          }

          Item { Layout.fillWidth: true }

          // новий пресет з поточних смуг: "new", "new2", "new3"…
          Rectangle {
            property bool hovered: false
            width: 18; height: 18; radius: 4
            color: hovered ? window.palette.bg2 : "transparent"
            Behavior on color { ColorAnimation { duration: appConfig.anim(120) } }

            Text {
              anchors.centerIn: parent
              text: "+"
              color: parent.hovered ? window.palette.fg : window.palette.gray
              font.family: window.palette.font; font.pixelSize: appConfig.scaled(11)
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: audioEq.createPreset()
            }
          }

          ToggleSwitch {
            checked: audioEq.enabled
            enabled: audioEq.pluginInstalled && !audioEq.busy
            palette: window.palette
            appConfig: window.appConfig
            checkedColor: window.palette.green
            trackWidth: 28; trackHeight: 16; knobSize: 12
            Layout.alignment: Qt.AlignVCenter
            onToggled: v => v ? audioEq.enable() : audioEq.disable()
          }
        }

        // Пресети: горизонтальний скрол. Порядок: запінені (хронологія
        // пінів) → вбудовані → користувацькі.
        // Right-click на чипі — контекстне меню (pin/rename/save/delete).
        Flickable {
          Layout.fillWidth: true
          height: 20
          contentWidth: chipRow.implicitWidth
          contentHeight: 20
          clip: true
          boundsBehavior: Flickable.StopAtBounds

          Row {
            id: chipRow
            spacing: 4

            Repeater {
              model: {
                // pinned спочатку — у хронології пінів
                var out = []
                for (var p = 0; p < audioEq.pinned.length; p++)
                  if (audioEq.chipExists(audioEq.pinned[p]))
                    out.push(audioEq.pinned[p])
                var all = EqPresets.all()
                for (var n in all)
                  if (audioEq.deletedBuiltins.indexOf(n) === -1 &&
                      audioEq.pinned.indexOf(n) === -1 &&
                      audioEq.userPresets[n] === undefined)
                    out.push(n)
                for (var u in audioEq.userPresets)
                  if (audioEq.pinned.indexOf(u) === -1) out.push(u)
                return out
              }

              delegate: Rectangle {
                id: chip
                required property var modelData
                property bool hovered: false
                readonly property bool active: audioEq.preset === modelData
                readonly property bool pinnedChip: audioEq.isPinned(modelData)
                // цей чип перейменовується (Rename у контекстному меню):
                // Text ховається, TextInput замість нього
                readonly property bool renaming:
                      root.renameTarget === modelData

                width: chipText.implicitWidth + 14 + (pinMark.visible ? 12 : 0)
                height: 20
                radius: 10
                color: active ? window.palette.green
                     : (hovered ? window.palette.bg2 : window.palette.bg1)
                Behavior on color { ColorAnimation { duration: appConfig.anim(120) } }

                Row {
                  anchors.centerIn: parent
                  spacing: 4
                  visible: !chip.renaming

                  // мітка запіненого пресета
                  Text {
                    id: pinMark
                    visible: chip.pinnedChip
                    text: "\uF08D"
                    color: chip.active ? window.palette.bg0H : window.palette.accent
                    font.family: window.palette.font; font.pixelSize: appConfig.scaled(8)
                  }

                  Text {
                    id: chipText
                    text: chip.modelData
                    color: chip.active ? window.palette.bg0H : window.palette.muted
                    font.family: window.palette.font; font.pixelSize: appConfig.scaled(9)
                  }
                }

                // поле rename — пряма дитина чіпа (в Row воно ставало
                // третім елементом і виїжджало за межі чіпа)
                TextInput {
                  id: renameInput
                  anchors.centerIn: parent
                  visible: chip.renaming
                  width: Math.min(90, chip.width - 12)
                  color: window.palette.fg
                  font.family: window.palette.font; font.pixelSize: appConfig.scaled(9)
                  clip: true
                  onVisibleChanged: {
                    if (visible) { text = chip.modelData; forceActiveFocus(); selectAll() }
                  }
                  onAccepted: {
                    var t = text.trim()
                    if (t !== "" && t !== chip.modelData)
                      audioEq.renamePreset(chip.modelData, t)
                    root.renameTarget = ""
                  }
                  Keys.onEscapePressed: root.renameTarget = ""
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  acceptedButtons: Qt.LeftButton | Qt.RightButton
                  onEntered: chip.hovered = true
                  onExited: chip.hovered = false
                  onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton)
                      eqCtxMenu.openFor(chip.modelData,
                                        chip.mapToItem(eqSection, 0, 0))
                    else
                      audioEq.applyPreset(chip.modelData)
                  }
                }
              }
            }
          }
        }

        // 15 вертикальних слайдерів смуг (20px + spacing 4 = влазить
        // у ширину попапа без скролу)
        RowLayout {
          Layout.alignment: Qt.AlignHCenter
          spacing: 4

          Repeater {
            model: audioEq.bandCount

            VertSlider {
              required property int index
              value: audioEq.bands[index] ?? 0
              from: -12; to: 12; step: 1
              label: EqPresets.bandLabels[index] ?? ""
              trackColor: window.palette.bg2
              fillColor: window.palette.accent
              knobColor: window.palette.textLight
              labelColor: window.palette.gray
              fontFamily: window.palette.font
              fontPx: appConfig.scaled(8)
              implicitWidth: 20
              implicitHeight: 130
              onMoved: v => audioEq.setBand(index, v)

              Connections {
                target: audioEq
                function onBandsChanged() {
                  // біндинг value руйнується після першого drag —
                  // оновлюємо імперативно, крім активного drag
                  if (!vs.dragging) vs.value = audioEq.bands[index]
                }
              }

              id: vs
            }
          }
        }
      }

        // Контекстне меню пресета (right-click)
        Rectangle {
          id: eqCtxMenu
          visible: ctxName !== ""
          z: 50
          width: 150
          height: ctxCol.implicitHeight + 8
          radius: 6
          color: window.palette.bg1
          border.width: 1
          border.color: window.palette.bg2

          property string ctxName: ""
          readonly property bool ctxIsUser: audioEq.userPresets[ctxName] !== undefined

          function openFor(name, pos) {
            ctxName = name
            width = 150
            // кламп від eqTarget: eqSection.height — анімована поточна
            // висота (після відкриття секції вона ще їде від 0), і меню
            // затискалось у верхню частину поверх чипів
            x = Math.max(2, Math.min(pos.x, eqSection.width - width - 4))
            y = Math.max(2, Math.min(pos.y + 16, root.eqTarget - height - 4))
          }

          function close() {
            ctxCloseTimer.stop()
            ctxName = ""
          }

          Timer {
            id: ctxCloseTimer
            interval: 2000
            running: eqCtxMenu.visible
            repeat: false
            onTriggered: eqCtxMenu.close()
          }

          // курсор над меню — скидання автозакриття (пасивний хендлер,
          // кліки по пунктах не блокує)
          HoverHandler {
            onHoveredChanged: if (hovered) ctxCloseTimer.restart()
          }

          ColumnLayout {
            id: ctxCol
            anchors.fill: parent
            anchors.margins: 4
            spacing: 0

            Repeater {
              model: [
                { id: "pin",   label: audioEq.isPinned(eqCtxMenu.ctxName) ? "Unpin" : "Pin" },
                { id: "rename", label: "Rename" },
                { id: "save",  label: "Save changes" },
                { id: "delete", label: "Delete", danger: true }
              ]

              delegate: Rectangle {
                required property var modelData
                property bool hovered: false

                Layout.fillWidth: true
                implicitHeight: 20
                radius: 4
                color: hovered ? window.palette.bg2 : "transparent"
                Behavior on color { ColorAnimation { duration: appConfig.anim(100) } }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.left: parent.left
                  anchors.leftMargin: 8
                  text: parent.modelData.label
                  color: parent.modelData.danger && parent.hovered
                         ? window.palette.danger : window.palette.fg
                  font.family: window.palette.font; font.pixelSize: appConfig.scaled(9)
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    var act = parent.modelData.id
                    if (act === "pin") audioEq.togglePin(eqCtxMenu.ctxName)
                    else if (act === "rename") {
                      root.renameTarget = eqCtxMenu.ctxName
                    }
                    else if (act === "save") audioEq.saveChangesTo(eqCtxMenu.ctxName)
                    else if (act === "delete") audioEq.deletePreset(eqCtxMenu.ctxName)
                    eqCtxMenu.close()
                  }
                }
              }
            }
          }
        }

        // Оверлей закриття контекстного меню (тільки поки меню відкрите)
        MouseArea {
          anchors.fill: parent
          z: 49
          visible: eqCtxMenu.visible
          onClicked: eqCtxMenu.close()
          onWheel: (wheel) => { eqCtxMenu.close(); wheel.accepted = false }
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
        font.family: window.palette.font; font.pixelSize: appConfig.scaled(22)
      }

      Text {
        Layout.alignment: Qt.AlignHCenter
        text: "No player detected"
        color: window.palette.gray
        font.family: window.palette.font; font.pixelSize: appConfig.scaled(12)
      }
    }
  }

  // Вибір плеєра — випадає прямо з пігулки під обкладинкою, не розтягує попап (overlay)
  Rectangle {
    id: playerDropdown
    visible: root.playerSelHeight > 0
    z: 60
    width: 160
    height: root.playerSelHeight
    radius: 6
    color: window.palette.bg1
    border.width: 1
    border.color: window.palette.bg2
    clip: true
    // пігулка всередині layout (x:8,y:8), мапимо відносно layout і додаємо зсув layout
    x: layout.x + playerPill.mapToItem(layout, 0, 0).x
    y: layout.y + playerPill.mapToItem(layout, 0, playerPill.height + 4).y

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 4
      spacing: 2

      Repeater {
        // унікальні identity (кілька інстансів chromium = один запис)
        model: {
          var seen = {}
          var out = []
          var players = Mpris.players.values
          for (var i = 0; i < players.length; i++) {
            var id = players[i].identity ?? ""
            var key = id.toLowerCase()
            if (id === "" || seen[key]) continue
            seen[key] = true
            out.push({ identity: id, key: key })
          }
          return out
        }

        delegate: Rectangle {
          required property var modelData
          property bool hovered: false
          readonly property bool active:
                root.player?.identity?.toLowerCase() === modelData.key

          Layout.fillWidth: true
          height: 24
          radius: 5
          color: active ? window.palette.bg2
               : (hovered ? window.palette.bg1 : "transparent")
          Behavior on color { ColorAnimation { duration: appConfig.anim(120) } }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 6

            Text {
              text: active ? "\uF00C" : ""
              color: window.palette.green
              font.family: window.palette.font; font.pixelSize: appConfig.scaled(9)
              Layout.preferredWidth: 12
            }

            Text {
              text: modelData.identity
              color: active ? window.palette.green : window.palette.fg
              font.family: window.palette.font; font.pixelSize: appConfig.scaled(10)
              font.bold: active
              elide: Text.ElideRight
              Layout.fillWidth: true
            }
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: parent.hovered = true
            onExited: parent.hovered = false
            onClicked: {
              window.appConfig.cfg.preferredPlayer = modelData.key
              window.appConfig.saveToFile()
              root.findAndSetPlayer()
              root.playerSelOpen = false
            }
          }
        }
      }
    }
  }

  // Оверлей закриття дропдауна (клік поза пігулкою/дропдауном)
  MouseArea {
    anchors.fill: parent
    z: 59
    visible: root.playerSelOpen
    onClicked: root.playerSelOpen = false
    onWheel: (wheel) => { root.playerSelOpen = false; wheel.accepted = false }
  }
}
