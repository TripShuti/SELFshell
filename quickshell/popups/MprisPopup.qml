// ============================================================
// quickshell/popups/MprisPopup.qml — медіаплеєр: трек, керування, візуалізатор
// ============================================================
import Quickshell.Services.Mpris
import "../core"
import "../services"
import "mpris"
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
  property real eqHeight
  // цільова висота виїзду (сама секція — в mpris/EqSection)
  readonly property real eqTarget: 216

  AudioEq { id: audioEq }
  // Аліас для прокидання в секції: `audioEq: audioEq` замкнулось би саме
  // на себе (required-властивість компонента перекриває id попапа —
  // та сама пастка, що Svc-суфікси в shell.qml).
  readonly property QtObject audioEqSvc: audioEq

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
  // Аліас для прокидання в секції (див. коментар біля audioEqSvc вище).
  readonly property QtObject tracklistSvc: tracklistService

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
      // onDestruction з Qt.callLater тут був зайвим: гард if (root) не рятує —
      // сам ідентифікатор root не резолвиться в знищеному скоупі
      // (ReferenceError during delayed evaluation), а переобрання плеєра
      // і так робить 2-секундний поллер вище (той самий патерн що в MprisWidget)
    }
  }

  // Періодичний пошук плеєра — тільки коли попап видимий, інакше Bar керує вибором
  Timer {
    interval: 2000
    running: root.visible
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

  // Якщо плеєр зник — закриваємо секцію плейлісту
  onPlayerChanged: {
    if (!root.player) root.playlistOpen = false
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
    TrackHeader {
      window: root
      player: root.player
      artUrl: root._artUrl
      playerSelOpen: root.playerSelOpen
      onTogglePlayerSel: root.playerSelOpen = !root.playerSelOpen
    }

    // Керування відтворенням: кнопки, гучність/shuffle/loop, прогрес (див. mpris/PlaybackControls)
    PlaybackControls {
      window: root
      player: root.player
      tracklistSupported: tracklistService.supported
      playlistOpen: root.playlistOpen
      eqOpen: root.eqOpen
      onTogglePlaylist: root.playlistOpen = !root.playlistOpen
      onToggleEq: root.eqOpen = !root.eqOpen
    }


    // Плейліст (виїзджаюча секція зі списком треків)
    // Layout.preferredHeight замість height: явний height не враховується
    // в implicitHeight ColumnLayout, і вікно попапа не росте
    PlaylistSection {
      window: root
      tracklistService: tracklistSvc
      sectionHeight: root.playlistHeight
      currentTrackId: root._currentTrackId
      playlistOpen: root.playlistOpen
    }

    // Еквалайзер (виїзджаюча секція; системний, не прив'язаний до плеєра)
    EqSection {
      window: root
      audioEq: audioEqSvc
      sectionHeight: root.eqHeight
      eqTarget: root.eqTarget
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
