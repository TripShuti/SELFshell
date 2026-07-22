// ============================================================
// MprisPopup.qml — медіаплеєр: трек, керування, візуалізатор
// ============================================================
import Quickshell.Services.Mpris
import "../"
import "../Palette.js" as Palette
import QtQuick
import QtQuick.Layouts

// Попап медіаплеєра — поточний трек, керування, візуалізатор
AnimatedPopup {
  id: root

  required property QtObject anchorItem
  required property QtObject window

  implicitWidth: 400
  implicitHeight: layout.implicitHeight + 4
  transformOrigin: Item.Top

  property string preferredPlayer: "feishin"
  property var player: null
  property var cavBars: [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]

  property bool artError: false

  property real currentPosition: 0
  property real currentLength: 0

  // Періодичне опитування позиції (MPRIS не гарантує регулярних оновлень Position)
  Timer {
    interval: 1000
    running: root.player?.isPlaying ?? false
    repeat: true
    onTriggered: {
      currentPosition = root.player?.position ?? 0
      currentLength = root.player?.length ?? 1
    }
  }

  onPlayerChanged: {
    currentPosition = root.player?.position ?? 0
    currentLength = root.player?.length ?? 1
  }

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

  // Форматує секунди в "m:ss"
  function formatTime(secs) {
    if (isNaN(secs) || secs < 0) return "0:00"
    var m = Math.floor(secs / 60)
    var s = Math.floor(secs % 60)
    return m + ":" + (s < 10 ? "0" : "") + s
  }

  Component.onCompleted: {
    anchor.window = window
  }

  onVisibleChanged: {
    if (visible) {
      var r = window.itemRect(anchorItem)
      anchor.rect = Qt.rect(r.x, r.y + r.height + 4, implicitWidth, implicitHeight)
    }
  }

  // Тло попапа
  Rectangle {
    anchors.fill: parent
    radius: 14
    color: Palette.bg0H
    opacity: 0.94
    border.width: 1
    border.color: Palette.bg2
  }

  ColumnLayout {
    id: layout
    anchors.fill: parent
    anchors.leftMargin: 8
    anchors.rightMargin: 8
    anchors.topMargin: 0
    anchors.bottomMargin: 13
    spacing: 6

    // Заголовок
    RowLayout {
      Layout.fillWidth: true
      Layout.topMargin: 5
      spacing: 6

      // Іконка
      Text {
        text: "\uF001"
        color: Palette.green
        font.family: Palette.font; font.pixelSize: 12
      }

      Text {
        text: "Now Playing"
        color: Palette.green
        font.family: Palette.font; font.pixelSize: 14; font.bold: true
      }

      Item { Layout.fillWidth: true }

      // Бейдж з назвою плеєра
      Rectangle {
        visible: root.player != null && root.player.identity !== ""
        radius: 8
        color: Palette.bg1
        implicitWidth: idLabel.implicitWidth + 16
        implicitHeight: 18

        Text {
          id: idLabel
          anchors.centerIn: parent
          text: root.player?.identity ?? ""
          color: Palette.gray
          font.family: Palette.font; font.pixelSize: 9
        }
      }
    }

    // Роздільник
    Rectangle {
      Layout.fillWidth: true
      height: 1
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: "transparent" }
        GradientStop { position: 0.5; color: Palette.bg2 }
        GradientStop { position: 1.0; color: "transparent" }
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
        color: Palette.bg1
        border.width: 1
        border.color: root.player?.isPlaying ? Palette.green : Palette.bg2
        Behavior on border.color { ColorAnimation { duration: 200 } }

        Image {
          id: artImg
          anchors.fill: parent
          anchors.margins: 1
          source: root.player?.trackArtUrl ?? ""
          visible: root.player != null && root.player.trackArtUrl !== "" && !root.artError
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
          color: Palette.gray
          font.family: Palette.font; font.pixelSize: 28
          visible: root.player == null || root.player.trackArtUrl === "" || artImg.status === Image.Error
        }

        // Індикатор відтворення
        Rectangle {
          visible: root.player?.isPlaying ?? false
          width: 10; height: 10; radius: 5
          color: Palette.green
          border.width: 2
          border.color: Palette.bg0H
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
          color: root.player?.isPlaying ? Palette.green : Palette.fg
          font.family: Palette.font; font.pixelSize: 14; font.bold: true
          elide: Text.ElideRight
          Layout.fillWidth: true
          wrapMode: Text.WordWrap
          maximumLineCount: 2
        }

        Text {
          text: root.player?.trackArtist ?? ""
          color: Palette.fg
          font.family: Palette.font; font.pixelSize: 11
          elide: Text.ElideRight
          Layout.fillWidth: true
          visible: root.player != null && root.player.trackArtist !== ""
        }

        Text {
          text: root.player?.trackAlbum ?? ""
          color: Palette.gray
          font.family: Palette.font; font.pixelSize: 10
          elide: Text.ElideRight
          Layout.fillWidth: true
          visible: root.player != null && root.player.trackAlbum !== ""
        }
      }

    }

    // Перемішування та повтор
    RowLayout {
      Layout.fillWidth: true
      spacing: 4
      Layout.alignment: Qt.AlignRight
      visible: root.player != null

      // Кнопка перемішування
      Rectangle {
        property bool hovered: false
        width: 20; height: 20; radius: 4
        color: root.player?.shuffle ? Palette.green : (hovered ? Palette.bg2 : "transparent")
        Behavior on color { ColorAnimation { duration: 150 } }
        Text {
          anchors.centerIn: parent
          text: "\uF074"
          color: root.player?.shuffle ? Palette.bg0H : Palette.gray
          font.family: Palette.font; font.pixelSize: 10
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
        color: root.player?.loopState !== MprisLoopState.None ? Palette.green : (hovered ? Palette.bg2 : "transparent")
        Behavior on color { ColorAnimation { duration: 150 } }
        Text {
          anchors.centerIn: parent
          text: root.player?.loopState === MprisLoopState.Track ? "\uF01E" : "\uF0E2"
          color: root.player?.loopState !== MprisLoopState.None ? Palette.bg0H : Palette.gray
          font.family: Palette.font; font.pixelSize: 10
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
    }

    // Смужка прогресу
    RowLayout {
      id: progRow
      Layout.fillWidth: true
      spacing: 4
      visible: root.player != null && root.player.lengthSupported

      // Поточний час
      Text {
        text: formatTime(root.currentPosition)
        color: Palette.gray
        font.family: Palette.font; font.pixelSize: 9
      }

      // Трек прогресу
      Rectangle {
        id: progTrack
        Layout.fillWidth: true
        height: 5; radius: 2.5
        color: Palette.bg1
        Layout.alignment: Qt.AlignVCenter

        // Заповнення
        Rectangle {
          width: {
            var len = root.currentLength
            var pos = root.currentPosition
            if (len <= 0 || isNaN(len) || isNaN(pos)) return 0
            return parent.width * Math.min(pos / len, 1)
          }
          color: root.player?.isPlaying ? Palette.green : Palette.gray
          height: parent.height; radius: 2.5
          Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.Linear } }
        }

        // Повзунок при наведенні
        Rectangle {
          visible: progArea.containsMouse
          width: 10; height: 10; radius: 5
          color: Palette.yellow
          anchors.verticalCenter: parent.verticalCenter
          x: Math.min(Math.max(progArea.mouseX - 5, 0), parent.width - 10)
        }

        MouseArea {
          id: progArea
          anchors.fill: parent
          hoverEnabled: true
          onClicked: mouse => {
            if (root.player?.canSeek) {
              var pos = (mouse.x / width) * root.player.length
              root.player.position = pos
              root.currentPosition = pos
            }
          }
        }
      }

      // Загальна довжина
      Text {
        text: formatTime(root.currentLength)
        color: Palette.gray
        font.family: Palette.font; font.pixelSize: 9
      }
    }

    // Аудіо-візуалізатор (cava)
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
          color: ratio > 0.7 ? Palette.green :
                 ratio > 0.4 ? Palette.purple :
                 Palette.gray

          Behavior on color { ColorAnimation { duration: 220 } }
          Behavior on height {
            NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 0.6 }
          }
        }
      }
    }

    // Кнопки керування
    RowLayout {
      Layout.fillWidth: true
      spacing: 10
      Layout.alignment: Qt.AlignHCenter
      visible: root.player != null

      Item { Layout.fillWidth: true }

      // Попередній трек
      Rectangle {
        property bool hovered: false
        width: 28; height: 28; radius: 14
        color: hovered ? Palette.bg2 : Palette.bg1
        Behavior on color { ColorAnimation { duration: 150 } }
        Text {
          anchors.centerIn: parent
          text: "\uF04A"
          color: Palette.fg; font.family: Palette.font; font.pixelSize: 12
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
        color: Palette.green
        border.width: hovered ? 2 : 0
        border.color: Palette.fg
        Behavior on color { ColorAnimation { duration: 150 } }
        Text {
          anchors.centerIn: parent
          text: root.player?.isPlaying ? "\uF04C" : "\uF04B"
          color: Palette.bg0H; font.family: Palette.font; font.pixelSize: 14
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
        color: hovered ? Palette.bg2 : Palette.bg1
        Behavior on color { ColorAnimation { duration: 150 } }
        Text {
          anchors.centerIn: parent
          text: "\uF04E"
          color: Palette.fg; font.family: Palette.font; font.pixelSize: 12
        }
        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          onEntered: parent.hovered = true
          onExited: parent.hovered = false
          onClicked: root.player?.next()
        }
      }

      Item { Layout.fillWidth: true }
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
        color: Palette.gray
        font.family: Palette.font; font.pixelSize: 22
      }

      Text {
        Layout.alignment: Qt.AlignHCenter
        text: "No player detected"
        color: Palette.gray
        font.family: Palette.font; font.pixelSize: 12
      }
    }
  }
}
