// ============================================================
// MprisWidget.qml — віджет медіаплеєра на панелі
// ============================================================
import Quickshell.Services.Mpris
import "../Palette.js" as Palette
import QtQuick
import QtQuick.Layouts


// Віджет медіаплеєра на панелі — назва треку + аудіо-візуалізатор
Item {
  id: root

  signal clicked()

  property string preferredPlayer: "feishin"
  property var player: null
  property var cavBars: [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]

  // Знаходить плеєр за назвою або перший доступний
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

    root.player = target ?? fallback
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

  // Періодичний пошук плеєра (на випадок пізнього підключення)
  Timer {
    interval: 2000; running: true; repeat: true
    onTriggered: root.findAndSetPlayer()
  }

  implicitWidth: root.player ? contentRow.implicitWidth : 0
  implicitHeight: parent?.height ?? 36

  RowLayout {
    id: contentRow
    anchors.fill: parent
    spacing: 4
    visible: root.player != null

    // Іконка play/pause
    Text {
      text: root.player?.isPlaying ? "\uF04B" : "\uF04C"
      color: root.player?.isPlaying ? Palette.green : Palette.fg
      font.family: Palette.font; font.pixelSize: 10
      Layout.alignment: Qt.AlignVCenter
      Behavior on color { ColorAnimation { duration: 220 } }
    }

    // Назва треку (текст, що біжить)
    Text {
      text: root.player?.trackTitle ?? ""
      color: root.player?.isPlaying ? Palette.green : Palette.fg
      font.family: Palette.font; font.pixelSize: 12
      elide: Text.ElideRight
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignVCenter
      Behavior on color { ColorAnimation { duration: 220 } }
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
          color: raw > 0.65 ? Palette.green : (raw > 0.3 ? Palette.audioVolume : Palette.muted)

          Behavior on height {
            NumberAnimation { duration: 130; easing.type: Easing.OutBack; easing.overshoot: 0.6 }
          }
          Behavior on color {
            ColorAnimation { duration: 220 }
          }
        }
      }
    }
  }

// Клік (ПКМ → попап, ЛКМ → play/pause), колесо → prev/next
MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
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
