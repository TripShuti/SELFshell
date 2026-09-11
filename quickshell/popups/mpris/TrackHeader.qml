// ============================================================
// quickshell/popups/mpris/TrackHeader.qml — шапка плеєра: обкладинка, пігулка вибору плеєра, мета треку
// ============================================================
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

// Шапка плеєра. Вибраний плеєр і URL арту — з кореня; стан помилки арту —
// локальний. Пігулка лише перемикає playerSelOpen кореня (сам оверлей
// дропдауна лишається в корені — z-обмеження вкладених Pill).
RowLayout {
  id: root

  required property QtObject window
  required property var player
  required property string artUrl
  required property bool playerSelOpen
  signal togglePlayerSel()

  property bool artError: false
  // Пігулка для позиціонування оверлея дропдауна в корені (id всередину
  // компонента ззовні не видно, тому віддаємо аліас)
  property alias pill: playerPill
  Layout.fillWidth: true
  spacing: 8
  visible: player != null

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
      border.color: player?.isPlaying ? window.palette.green : window.palette.bg2
      Behavior on border.color { ColorAnimation { duration: window.appConfig.anim(200) } }

    Image {
      id: artImg
      anchors.fill: parent
      anchors.margins: 1
      source: artUrl
      visible: player != null && artUrl !== "" && !artError
      fillMode: Image.PreserveAspectCrop
      onStatusChanged: {
        if (status === Image.Error) artError = true
        else if (status === Image.Ready) artError = false
      }
      onSourceChanged: artError = false
    }

    // Заглушка якщо немає обкладинки
    Text {
      anchors.centerIn: parent
      text: "\uF025"
      color: window.palette.gray
      font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(28)
      visible: player == null || artUrl === "" || artImg.status === Image.Error
    }

    // Індикатор відтворення
    Rectangle {
      visible: player?.isPlaying ?? false
      width: 10; height: 10; radius: 5
      color: window.palette.green
      border.width: 2
      border.color: window.palette.bg0H
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.margins: -2

      SequentialAnimation on opacity {
        running: player?.isPlaying ?? false
        loops: Animation.Infinite
        NumberAnimation { to: 0.4; duration: window.appConfig.anim(700) }
        NumberAnimation { to: 1.0; duration: window.appConfig.anim(700) }
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
          text: window.appConfig.cfg.preferredPlayer !== "" ? window.appConfig.cfg.preferredPlayer : (player?.identity ?? "No player")
          color: playerSelOpen ? window.palette.green : window.palette.fg
          font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(11)
          font.bold: playerSelOpen
          elide: Text.ElideRight
          Layout.fillWidth: true
          Behavior on color { ColorAnimation { duration: window.appConfig.anim(120) } }
        }

        Text {
          text: playerSelOpen ? "\uF077" : "\uF078"
          color: playerSelOpen ? window.palette.green : window.palette.mutedAlt
          font.family: window.palette.font; font.pixelSize: 8
          Behavior on color { ColorAnimation { duration: window.appConfig.anim(120) } }
        }
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.togglePlayerSel()
      }
    }
  }

  // Назва треку, виконавець, альбом
  ColumnLayout {
    Layout.fillWidth: true
    Layout.alignment: Qt.AlignVCenter
    spacing: 4

    Text {
      text: player?.trackTitle ?? "No track"
      color: player?.isPlaying ? window.palette.green : window.palette.fg
      font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(14); font.bold: true
      elide: Text.ElideRight
      Layout.fillWidth: true
      wrapMode: Text.WordWrap
      maximumLineCount: 2
    }

    Text {
      text: player?.trackArtist ?? ""
      color: window.palette.fg
      font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(12)
      elide: Text.ElideRight
      Layout.fillWidth: true
      visible: player != null && player.trackArtist !== ""
    }

    Text {
      text: player?.trackAlbum ?? ""
      color: window.palette.gray
      font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(10)
      elide: Text.ElideRight
      Layout.fillWidth: true
      visible: player != null && player.trackAlbum !== ""
    }
  }

}
