// ============================================================
// AudioMixerPopup.qml — мікшер аудіо: пристрої та потоки
// ============================================================
import Quickshell
import Quickshell.Services.Pipewire
import "../"
import "../Palette.js" as Palette
import QtQuick
import QtQuick.Layouts

// Мікшер аудіо — список пристроїв виведення та потоків відтворення
AnimatedPopup {
  id: root

  required property QtObject anchorItem
  required property QtObject window

  implicitWidth: 320
  implicitHeight: layout.implicitHeight + 16

  Component.onCompleted: {
    anchor.window = window
  }

  onVisibleChanged: {
    if (visible) {
      var r = window.itemRect(anchorItem)
      anchor.rect = Qt.rect(r.x, r.y + r.height + 4, implicitWidth, implicitHeight)
    }
  }

  // Тло мікшера
  Rectangle {
    anchors.fill: parent
    radius: 12
    color: Palette.bg0H
    opacity: 0.88
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
      color: Palette.green
      font.family: Palette.font; font.pixelSize: 12; font.bold: true
    }

    // Список аудіо-пристроїв (sinks)
    Repeater {
      model: Pipewire.nodes

      delegate: Item {
        required property PwNode modelData

        visible: modelData.isSink && modelData.audio != null
        height: visible ? 40 : 0
        Layout.fillWidth: true
        clip: true

        RowLayout {
          anchors.fill: parent
          spacing: 6

          // Назва пристрою
          Text {
            text: modelData.description || modelData.name || modelData.nickname
            color: Palette.fg
            font.family: Palette.font; font.pixelSize: 12
            elide: Text.ElideRight
            Layout.preferredWidth: 80
          }

          // Смужка гучності
          Rectangle {
            Layout.fillWidth: true
            height: 6
            radius: 3
            color: Palette.bgAlpha
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
              width: parent.width * Math.min(modelData.audio?.volume ?? 0, 1)
              height: parent.height
              radius: 3
              color: modelData.audio?.muted ? Palette.muted : Palette.green
              Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
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
            color: modelData.audio?.muted ? Palette.red : (hovered ? Palette.hoverBg : Palette.bgAlpha)
            Behavior on color { ColorAnimation { duration: 150 } }
            Text {
              anchors.centerIn: parent
              text: modelData.audio?.muted ? "\uF026" : "\uF028"
              color: modelData.audio?.muted ? Palette.baseOverlay : Palette.fg
              font.family: Palette.font; font.pixelSize: 12
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
            color: Pipewire.defaultAudioSink === modelData ? Palette.green : (hovered ? Palette.hoverBg : Palette.bgAlpha)
            Behavior on color { ColorAnimation { duration: 150 } }
            Text {
              anchors.centerIn: parent
              text: "\uF00C"
              color: Pipewire.defaultAudioSink === modelData ? Palette.baseOverlay : Palette.muted
              font.family: Palette.font; font.pixelSize: 12
            }
            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              onEntered: parent.hovered = true
              onExited: parent.hovered = false
              onClicked: {
                if (modelData.audio) Pipewire.preferredDefaultAudioSink = modelData
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
      color: Palette.green
      opacity: 0.3
    }

    // Заголовок потоків відтворення
    Text {
      text: "Playback Streams"
      color: Palette.green
      font.family: Palette.font; font.pixelSize: 12; font.bold: true
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

        RowLayout {
          anchors.fill: parent
          spacing: 6

          // Назва потоку
          Text {
            text: {
              var n = modelData.nickname || modelData.name || modelData.description
              return n || "Stream"
            }
            color: Palette.fg
            font.family: Palette.font; font.pixelSize: 12
            elide: Text.ElideRight
            Layout.preferredWidth: 80
          }

          // Смужка гучності потоку
          Rectangle {
            Layout.fillWidth: true
            height: 6
            radius: 3
            color: Palette.bgAlpha
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
              width: parent.width * Math.min(modelData.audio?.volume ?? 0, 1)
              height: parent.height
              radius: 3
              color: modelData.audio?.muted ? Palette.muted : Palette.green
              Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
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
            color: modelData.audio?.muted ? Palette.red : (hovered ? Palette.hoverBg : Palette.bgAlpha)
            Behavior on color { ColorAnimation { duration: 150 } }
            Text {
              anchors.centerIn: parent
              text: modelData.audio?.muted ? "\uF026" : "\uF028"
              color: modelData.audio?.muted ? Palette.baseOverlay : Palette.fg
              font.family: Palette.font; font.pixelSize: 12
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
