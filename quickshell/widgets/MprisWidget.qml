// ============================================================
// quickshell/widgets/MprisWidget.qml — віджет медіаплеєра на панелі
// ============================================================
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts


// Віджет медіаплеєра на панелі — назва треку + аудіо-візуалізатор
Item {
  id: root

  required property QtObject window
  signal clicked()

  // Улюблений плеєр — спільний з попапом (config.json → preferredPlayer)
  readonly property string preferredPlayer: window.appConfig.cfg.preferredPlayer
  property var player: null
  property var cavBars: [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]

  // Hover-стан для фідбеку (HoverText-рецепт: колір + масштаб)
  property bool hovered: false

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
  }

  // Стежить за появою/зникненням плеєрів Mpris
  Repeater {
    id: playerRepeater
    model: Mpris.players

    delegate: Item {
      required property var modelData

      readonly property string playerName: (modelData.identity ?? modelData.dbusName ?? "").toLowerCase()

      Component.onCompleted: root.findAndSetPlayer()
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

  implicitWidth: root.player ? contentRow.implicitWidth : 0
  implicitHeight: parent?.height ?? 36

  // Максимальна ширина назви треку — інакше elide не має межі і довга
  // назва роздуває центральну пігулку на всю ширину
  readonly property real maxTrackWidth: 220

  RowLayout {
    id: contentRow
    anchors.fill: parent
    spacing: 4
    visible: root.player != null

    // Іконка play/pause
    Text {
      text: root.player?.isPlaying ? "\uF04B" : "\uF04C"
      color: root.player?.isPlaying ? window.palette.green
           : root.hovered ? window.palette.green
           : window.palette.fg
      font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(10)
      Layout.alignment: Qt.AlignVCenter
      scale: root.hovered ? 1.15 : 1.0
      Behavior on color { ColorAnimation { duration: window.appConfig.anim(220) } }
      Behavior on scale {
        NumberAnimation { duration: window.appConfig.anim(120); easing.type: Easing.OutBack; easing.overshoot: 2.5 }
      }
    }

    // Назва треку (текст, що біжить)
    Text {
      text: root.player?.trackTitle ?? ""
      color: root.player?.isPlaying ? window.palette.green
           : root.hovered ? window.palette.green
           : window.palette.fg
      font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(12)
      elide: Text.ElideRight
      Layout.fillWidth: true
      Layout.maximumWidth: root.maxTrackWidth
      Layout.alignment: Qt.AlignVCenter
      Behavior on color { ColorAnimation { duration: window.appConfig.anim(220) } }
    }

    // Аудіо-візуалізатор (cava) — 28 смужок
    Row {
      spacing: 2
      Layout.alignment: Qt.AlignVCenter
      height: 20
      visible: root.player?.isPlaying ?? false

      Repeater {
        model: 28

        delegate: Rectangle {
          required property int index

          readonly property real raw: root.cavBars[index]
          width: 2
          height: Math.max(2, raw * 20)
          radius: 1
          anchors.bottom: parent.bottom
          color: raw > 0.65 ? window.palette.green : (raw > 0.3 ? window.palette.audioVolume : window.palette.muted)

          // Тільки Behavior on height: кольорова анімація тут прибирає
          // ~28 рестартів ColorAnimation на кожен кадр cava (30 fps)
          Behavior on height {
            NumberAnimation { duration: window.appConfig.anim(130); easing.type: Easing.OutBack; easing.overshoot: 0.6 }
          }
        }
      }
    }
  }

  // Клік (ПКМ → попап, ЛКМ → play/pause), колесо → prev/next
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    hoverEnabled: true
    onEntered: root.hovered = true
    onExited: root.hovered = false
    onClicked: mouse => {
      if (mouse.button === Qt.RightButton)
        root.clicked()
      else
        root.player?.togglePlaying()
    }
    onWheel: wheel => {
      if (!root.player) return
      if (wheel.angleDelta.y > 0) {
        root.player.previous()
      } else if (wheel.angleDelta.y < 0) {
        root.player.next()
      }
    }
  }
}
