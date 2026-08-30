// ============================================================
// popups/audio/StreamCard.qml — картка потоку (Playback/Recording)
// з іконкою, слайдером, вибором пристрою та кнопкою закриття
// ============================================================
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../scripts/AudioMixerUtils.js" as AudioUtils

Item {
  id: root

  required property QtObject window
  required property PwNode streamNode
  property bool isPlayback: true // true=Playback (sink), false=Recording (source)
  // дані з pactl для мапінгу поток → пристрій
  property var sinkInputsInfo: []
  property var sourceOutputsInfo: []
  property var sinkPortMap: ({})
  property var sourcePortMap: ({})
  // кеш O(1) з AudioMixerPopup.qml:sinkNameMap/sourceNameMap
  property var sinkNameMap: ({})
  property var sourceNameMap: ({})
  property var sinkDescMap: ({})
  property var sourceDescMap: ({})
  // фільтровані списки пристроїв для комбо (щоб не ітерувати всі Pipewire.nodes всередині кожного делегата)
  property var sinkDevices: []
  property var sourceDevices: []

  signal moveStream(string serial, string targetName)
  signal destroyStream(string objectId)

  Layout.fillWidth: true
  implicitHeight: card.implicitHeight
  visible: {
    var n = root.streamNode
    if (!n || !n.audio) return false
    if (!n.isStream) return false
    if (root.isPlayback) {
      if (!n.isSink) return false
    } else {
      if (n.isSink) return false
    }
    // showVirtual фільтр — передається через window? поки всередині через root.window.appConfig? краще зовнішній фільтр
    return true
  }

  property bool showVirtualOverride: false
  // зовнішній контроль видимості — батько вже фільтрує, тут тільки для прозорості

  property bool devMenuOpen: false

  IconResolver { id: iconResolver }

  Rectangle {
    id: card
    width: parent.width
    implicitHeight: col.implicitHeight + 12
    radius: 6
    color: window.palette.bg1
    border.width: 1
    border.color: window.palette.bg2

    ColumnLayout {
      id: col
      anchors.fill: parent
      anchors.margins: 6
      spacing: 6

      // Шапка: іконка + назва + закриття
      RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Item {
          Layout.preferredWidth: 22
          Layout.preferredHeight: 22
          property string _res: {
            var icon = root.isPlayback
              ? (streamNode.properties["application.icon-name"] || streamNode.properties["application.name"] || "")
              : (streamNode.properties["application.icon-name"] || "")
            if (icon !== "") {
              var r = iconResolver.resolve(icon)
              if (r !== "") return r
              var r2 = iconResolver.resolve(icon.toLowerCase())
              if (r2 !== "") return r2
            }
            return ""
          }
          Image {
            anchors.fill: parent
            source: parent._res
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            visible: status === Image.Ready
          }
          Text {
            anchors.centerIn: parent
            visible: parent._res === ""
            text: root.isPlayback ? "\uF028" : "\uF130"
            color: root.isPlayback ? window.palette.gray : window.palette.red
            font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(11)
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 1
          Text {
            text: {
              var app = streamNode.properties["application.name"] || streamNode.properties["node.name"] || streamNode.nickname || streamNode.description || (root.isPlayback ? "Stream" : "Recording")
              return app
            }
            color: window.palette.fg
            font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(11); font.bold: true
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
          Text {
            text: {
              if (root.isPlayback) {
                var m = streamNode.properties["media.name"] || ""
                var app = streamNode.properties["application.name"] || ""
                if (m !== "" && m !== app) return m
                var d = streamNode.description || ""
                if (d !== "" && d !== app) return d
                return ""
              } else {
                return streamNode.properties["media.name"] || ""
              }
            }
            color: window.palette.gray
            font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(9)
            elide: Text.ElideRight
            Layout.fillWidth: true
            visible: text !== ""
          }
        }

        Rectangle {
          property bool hovered: false
          width: 22; height: 22; radius: 4
          color: hovered ? window.palette.red : window.palette.bgAlpha
          Behavior on color { ColorAnimation { duration: window.appConfig.anim(120) } }
          Text {
            anchors.centerIn: parent
            text: "\uF00D"
            color: parent.hovered ? window.palette.baseOverlay : window.palette.muted
            font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(10)
          }
          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: parent.hovered = true
            onExited: parent.hovered = false
            onClicked: {
              var oid = streamNode.properties["object.id"]
              if (!oid) return
              root.destroyStream(String(oid))
            }
          }
        }
      }

      // Слайдер — тепер напряму PwNode, без копії real (фікс багу 100%→0)
      AudioSlider {
        window: root.window
        node: streamNode
        activeColor: root.isPlayback ? window.palette.green : window.palette.red
        isInput: !root.isPlayback
      }

      // Вибір пристрою
      RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Text {
          text: root.isPlayback ? "on:" : "from:"
          color: window.palette.gray
          font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(9)
        }
        Rectangle {
          Layout.fillWidth: true
          implicitHeight: 22
          radius: 4
          color: root.devMenuOpen ? window.palette.bg2 : window.palette.bgAlpha
          border.width: 1; border.color: window.palette.bg2
          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 6; anchors.rightMargin: 6
            spacing: 4
            Text {
              text: {
                var serial = streamNode.properties ? String(streamNode.properties["object.serial"] || "") : ""
                var cur = ""
                if (root.isPlayback) {
                  cur = (serial && root.sinkNameMap[serial]) ? root.sinkNameMap[serial] : AudioUtils.sinkNameForStream(streamNode, root.sinkInputsInfo, root.sinkPortMap, Pipewire.nodes ? Pipewire.nodes.values : null)
                  if (cur !== "") return (cur && root.sinkDescMap[cur]) ? root.sinkDescMap[cur] : AudioUtils.sinkDescription(cur, root.sinkPortMap, Pipewire.nodes ? Pipewire.nodes.values : null)
                  if (Pipewire.defaultAudioSink) return Pipewire.defaultAudioSink.description || Pipewire.defaultAudioSink.name
                  return "Unknown device"
                } else {
                  cur = (serial && root.sourceNameMap[serial]) ? root.sourceNameMap[serial] : AudioUtils.sourceNameForStream(streamNode, root.sourceOutputsInfo, root.sourcePortMap, Pipewire.nodes ? Pipewire.nodes.values : null)
                  if (cur !== "") return (cur && root.sourceDescMap[cur]) ? root.sourceDescMap[cur] : AudioUtils.sourceDescription(cur, root.sourcePortMap, Pipewire.nodes ? Pipewire.nodes.values : null)
                  if (Pipewire.defaultAudioSource) return Pipewire.defaultAudioSource.description || Pipewire.defaultAudioSource.name
                  return "Unknown source"
                }
              }
              color: window.palette.fg
              font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(9)
              elide: Text.ElideRight
              Layout.fillWidth: true
            }
            Text { text: root.devMenuOpen ? "\uF077" : "\uF078"; color: window.palette.gray; font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(8) }
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.devMenuOpen = !root.devMenuOpen
          }
        }
      }

      ColumnLayout {
        visible: root.devMenuOpen
        Layout.fillWidth: true
        spacing: 2
        Repeater {
          model: root.isPlayback ? root.sinkDevices : root.sourceDevices
          delegate: Item {
            required property var modelData
            Layout.fillWidth: true
            Layout.preferredHeight: 22
            clip: true
            Rectangle {
              anchors.fill: parent
              radius: 4
              color: {
                var serial2 = root.streamNode.properties ? String(root.streamNode.properties["object.serial"] || "") : ""
                var cur2 = root.isPlayback
                  ? ((serial2 && root.sinkNameMap[serial2]) ? root.sinkNameMap[serial2] : AudioUtils.sinkNameForStream(root.streamNode, root.sinkInputsInfo, root.sinkPortMap, Pipewire.nodes ? Pipewire.nodes.values : null))
                  : ((serial2 && root.sourceNameMap[serial2]) ? root.sourceNameMap[serial2] : AudioUtils.sourceNameForStream(root.streamNode, root.sourceOutputsInfo, root.sourcePortMap, Pipewire.nodes ? Pipewire.nodes.values : null))
                if (cur2 === modelData.name) return window.palette.green
                if (devMa.containsMouse) return window.palette.bg2
                return window.palette.bgAlpha
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left; anchors.leftMargin: 8
                anchors.right: parent.right; anchors.rightMargin: 8
                text: modelData.description || modelData.nickname || modelData.name
                color: {
                  var serial3 = root.streamNode.properties ? String(root.streamNode.properties["object.serial"] || "") : ""
                  var cur3 = root.isPlayback
                    ? ((serial3 && root.sinkNameMap[serial3]) ? root.sinkNameMap[serial3] : AudioUtils.sinkNameForStream(root.streamNode, root.sinkInputsInfo, root.sinkPortMap, Pipewire.nodes ? Pipewire.nodes.values : null))
                    : ((serial3 && root.sourceNameMap[serial3]) ? root.sourceNameMap[serial3] : AudioUtils.sourceNameForStream(root.streamNode, root.sourceOutputsInfo, root.sourcePortMap, Pipewire.nodes ? Pipewire.nodes.values : null))
                  if (cur3 === modelData.name) return window.palette.baseOverlay
                  return window.palette.fg
                }
                font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(9)
                elide: Text.ElideRight
              }
              MouseArea {
                id: devMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  var serial = root.streamNode.properties["object.serial"]
                  if (!serial) return
                  root.moveStream(String(serial), modelData.name)
                  root.devMenuOpen = false
                }
              }
            }
            PwObjectTracker { objects: [modelData] }
          }
        }
      }
    }
  }

  PwObjectTracker { objects: [streamNode] }
}
