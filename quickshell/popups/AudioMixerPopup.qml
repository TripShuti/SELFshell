// ============================================================
// AudioMixerPopup.qml — мікшер аудіо: пристрої та потоки
// ============================================================
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../core"
import QtQuick
import QtQuick.Layouts

// Мікшер аудіо — список пристроїв виведення та потоків відтворення
AnimatedPopup {
  id: root

  required property QtObject anchorItem
  required property QtObject window
  palette: window.palette
  appConfig: window.appConfig

  implicitWidth: 320
  implicitHeight: layout.implicitHeight + 16

  popupWindow: window
  anchorTarget: anchorItem

  Component.onCompleted: {
    anchor.window = window
  }

  onVisibleChanged: {
    if (visible) root.positionUnderAnchor()
  }

  // Перенесення граючих потоків на новий default sink.
  // Pipewire.preferredDefaultAudioSink міняє дефолт тільки для нових
  // sink-inputs — існуючі лишаються на старому sink.
  Process {
    id: _moveStreamsProc
  }

  // Список пристроїв міняє висоту — пере-позиціонуємо, інакше попап
  // виходить за межі anchor-позиції (той самий патерн, що в MprisPopup)
  onImplicitHeightChanged: {
    if (visible) root.positionUnderAnchor()
  }


  ColumnLayout {
    id: layout
    x: 8
    y: 8
    width: parent.width - 16
    spacing: 8

    // Заголовок пристроїв виведення
    Text {
      text: "Output Devices"
      color: window.palette.green
      font.family: window.palette.font; font.pixelSize: appConfig.scaled(12); font.bold: true
    }

    // Список аудіо-пристроїв (sinks)
    Repeater {
      model: Pipewire.nodes

      delegate: Item {
        required property PwNode modelData

        // !isStream: внутрішній playback-стрім ladspa/filiter-модулів
        // (напр. EQ sink) має той самий description і дублювався у списку
        visible: modelData.isSink && !modelData.isStream && modelData.audio != null
        height: visible ? 40 : 0
        Layout.fillWidth: true
        clip: true

        // Fade-in при появі нового пристрою (делегат живе стільки ж,
        // скільки вузол у моделі)
        opacity: 0
        NumberAnimation on opacity { to: 1; duration: appConfig.anim(150); easing.type: Easing.OutCubic }

        RowLayout {
          anchors.fill: parent
          spacing: 6

          // Назва пристрою
          Text {
            text: modelData.description || modelData.name || modelData.nickname
            color: window.palette.fg
            font.family: window.palette.font; font.pixelSize: appConfig.scaled(12)
            elide: Text.ElideRight
            Layout.preferredWidth: 80
          }

          // Смужка гучності
          Rectangle {
            Layout.fillWidth: true
            height: 6
            radius: 3
            color: window.palette.bgAlpha
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
              width: parent.width * Math.min(modelData.audio?.volume ?? 0, 1)
              height: parent.height
              radius: 3
              color: modelData.audio?.muted ? window.palette.muted : window.palette.green
              Behavior on width { NumberAnimation { duration: appConfig.anim(150); easing.type: Easing.OutCubic } }
            }

            // Зміна гучності кліком
            MouseArea {
              anchors.fill: parent
              onPressed: mouse => {
                if (modelData.audio) {
                  modelData.audio.volume = Math.max(0, Math.min(mouse.x / width, 1))
                }
              }
            }
          }

          // Кнопка приглушення (mute)
          Rectangle {
            property bool hovered: false
            width: 24; height: 24; radius: 4
            color: modelData.audio?.muted ? window.palette.red : (hovered ? window.palette.hoverBg : window.palette.bgAlpha)
            Behavior on color { ColorAnimation { duration: appConfig.anim(150) } }
            Text {
              anchors.centerIn: parent
              text: modelData.audio?.muted ? "\uF026" : "\uF028"
              color: modelData.audio?.muted ? window.palette.baseOverlay : window.palette.fg
              font.family: window.palette.font; font.pixelSize: appConfig.scaled(12)
            }
            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              onEntered: parent.hovered = true
              onExited: parent.hovered = false
              onClicked: {
                if (modelData.audio) modelData.audio.muted = !modelData.audio.muted
              }
            }
          }

          // Кнопка вибору пристрою за замовчуванням
          Rectangle {
            property bool hovered: false
            width: 24; height: 24; radius: 4
            color: Pipewire.defaultAudioSink === modelData ? window.palette.green : (hovered ? window.palette.hoverBg : window.palette.bgAlpha)
            Behavior on color { ColorAnimation { duration: appConfig.anim(150) } }
            Text {
              anchors.centerIn: parent
              text: "\uF00C"
              color: Pipewire.defaultAudioSink === modelData ? window.palette.baseOverlay : window.palette.muted
              font.family: window.palette.font; font.pixelSize: appConfig.scaled(12)
            }
            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              onEntered: parent.hovered = true
              onExited: parent.hovered = false
              onClicked: {
                if (!modelData.audio) return
                if (Pipewire.defaultAudioSink === modelData) return
                Pipewire.preferredDefaultAudioSink = modelData
                // Pipewire.preferredDefaultAudioSink міняє дефолт тільки для нових
                // потоків. Якщо EQ увімкнений (default == SELFshell_EQ),
                // треба перелінкувати вихід filter-chain на вибраний хардвар,
                // інакше — перенести існуючі sink-inputs
                if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.name === "SELFshell_EQ") {
                  _moveStreamsProc.command = ["bash", "-c",
                    "SRC=$(pw-link -o 2>/dev/null | grep 'output.filter-chain' | head -1 | cut -d: -f1); " +
                    "[ -z \"$SRC\" ] && exit 0; " +
                    "T=\"" + modelData.name + "\"; " +
                    "for O in $(pactl list short sinks 2>/dev/null | grep -v 'SELFshell_EQ' | cut -f2); do " +
                    "  pw-link -d \"$SRC:output_FL\" \"$O:playback_FL\" 2>/dev/null || true; " +
                    "  pw-link -d \"$SRC:output_FR\" \"$O:playback_FR\" 2>/dev/null || true; " +
                    "done; " +
                    "pw-link \"$SRC:output_FL\" \"$T:playback_FL\" 2>/dev/null || true; " +
                    "pw-link \"$SRC:output_FR\" \"$T:playback_FR\" 2>/dev/null || true"
                  ]
                } else {
                  _moveStreamsProc.command = ["bash", "-c",
                    "T=\"" + modelData.name + "\"; pactl list short sink-inputs 2>/dev/null | cut -f1 | xargs -r -n1 -I{} pactl move-sink-input {} \"$T\""]
                }
                _moveStreamsProc.running = true
              }
            }
          }
        }

        PwObjectTracker {
          objects: [modelData]
        }
      }
    }

    // Роздільник
    Rectangle {
      Layout.fillWidth: true
      height: 1
      color: window.palette.green
      opacity: 0.3
    }

    // Заголовок потоків відтворення
    Text {
      text: "Playback Streams"
      color: window.palette.green
      font.family: window.palette.font; font.pixelSize: appConfig.scaled(12); font.bold: true
    }

    // Список аудіо-потоків (streams)
    Repeater {
      model: Pipewire.nodes

      delegate: Item {
        required property PwNode modelData

        visible: modelData.isStream && modelData.audio != null
        height: visible ? 36 : 0
        Layout.fillWidth: true
        clip: true

        // Fade-in при появі нового потоку (див. sinks вище)
        opacity: 0
        NumberAnimation on opacity { to: 1; duration: appConfig.anim(150); easing.type: Easing.OutCubic }

        RowLayout {
          anchors.fill: parent
          spacing: 6

          // Назва потоку
          Text {
            text: {
              var n = modelData.nickname || modelData.name || modelData.description
              return n || "Stream"
            }
            color: window.palette.fg
            font.family: window.palette.font; font.pixelSize: appConfig.scaled(12)
            elide: Text.ElideRight
            Layout.preferredWidth: 80
          }

          // Смужка гучності потоку
          Rectangle {
            Layout.fillWidth: true
            height: 6
            radius: 3
            color: window.palette.bgAlpha
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
              width: parent.width * Math.min(modelData.audio?.volume ?? 0, 1)
              height: parent.height
              radius: 3
              color: modelData.audio?.muted ? window.palette.muted : window.palette.green
              Behavior on width { NumberAnimation { duration: appConfig.anim(150); easing.type: Easing.OutCubic } }
            }

            MouseArea {
              anchors.fill: parent
              onPressed: mouse => {
                if (modelData.audio) {
                  modelData.audio.volume = Math.max(0, Math.min(mouse.x / width, 1))
                }
              }
            }
          }

          // Кнопка приглушення потоку
          Rectangle {
            property bool hovered: false
            width: 24; height: 24; radius: 4
            color: modelData.audio?.muted ? window.palette.red : (hovered ? window.palette.hoverBg : window.palette.bgAlpha)
            Behavior on color { ColorAnimation { duration: appConfig.anim(150) } }
            Text {
              anchors.centerIn: parent
              text: modelData.audio?.muted ? "\uF026" : "\uF028"
              color: modelData.audio?.muted ? window.palette.baseOverlay : window.palette.fg
              font.family: window.palette.font; font.pixelSize: appConfig.scaled(12)
            }
            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              onEntered: parent.hovered = true
              onExited: parent.hovered = false
              onClicked: {
                if (modelData.audio) modelData.audio.muted = !modelData.audio.muted
              }
            }
          }
        }

        PwObjectTracker {
          objects: [modelData]
        }
      }
    }
  }

}
