// ============================================================
// AudioWidget.qml — віджет гучності на панелі
// ============================================================
import Quickshell.Services.Pipewire
import "../core"
import QtQuick


// Віджет гучності на панелі — смужка, клік для мьюта, колесо для зміни
Item {
  id: root

  required property QtObject window
  signal clicked()

  implicitWidth: 120
  implicitHeight: parent?.height ?? 36

  property PwNode sink: Pipewire.defaultAudioSink
  property PwNodeAudio audio: sink ? sink.audio : null
  property bool hovered: false

  visible: Pipewire.ready && sink != null

  MouseArea {
    id: ma
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    onEntered: root.hovered = true
    onExited: root.hovered = false

    // Нормалізована позиція кліку (0..1) з захистом від нульової ширини —
    // інакше клік по віджету ширини 0 (перший кадр анімації пігулки)
    // діленням на нуль поставив би гучність на 100%
    function ratio(mouse) {
      return ma.width > 0 ? Math.max(0, Math.min(mouse.x / ma.width, 1)) : 0
    }

    // Зміна гучності кліком або перетягуванням
    onPressed: mouse => {
      if (mouse.button === Qt.LeftButton && root.audio) {
        root.audio.volume = ratio(mouse)
      }
    }

    onPositionChanged: mouse => {
      if ((pressedButtons & Qt.LeftButton) && root.audio) {
        root.audio.volume = ratio(mouse)
      }
    }

    onClicked: mouse => {
      if (mouse.button === Qt.RightButton) {
        root.clicked()
      } else if (mouse.button === Qt.MiddleButton) {
        if (root.audio) {
          root.audio.muted = !root.audio.muted
        }
      }
    }

    // Регулювання колесом
    onWheel: wheel => {
      if (root.audio) {
        // angleDelta.y === 0 (рідкісний горизонтальний скрол) — ігноруємо
        var step = wheel.angleDelta.y > 0 ? window.appConfig.audioStep : wheel.angleDelta.y < 0 ? -window.appConfig.audioStep : 0
        if (step !== 0)
          root.audio.volume = Math.max(0, Math.min(root.audio.volume + step, 1))
      }
    }
  }

  PwObjectTracker {
    objects: [root.sink]
  }

  // Смужка гучності
  Rectangle {
    anchors {
      left: parent.left
      right: parent.right
      verticalCenter: parent.verticalCenter
    }
    height: root.hovered ? 8 : 6
    radius: height / 2
    color: window.palette.bgAlpha
    clip: true

    Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    // Заповнення з градієнтом
    Rectangle {
      width: parent.width * Math.min(root.audio?.volume ?? 0, 1)
      height: parent.height
      radius: parent.radius

      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: window.palette.audioVolume }
        GradientStop { position: 1.0; color: root.audio?.muted ? window.palette.muted : window.palette.green }
      }

      Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }
  }
}
