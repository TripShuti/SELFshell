// ============================================================
// quickshell/popups/audio/ConfigCard.qml — картка карти з вибором профілю
// ============================================================
import QtQuick
import QtQuick.Layouts
import "../../core"

Rectangle {
  id: root

  required property QtObject window
  required property var cardData // елемент cardsModel
  property bool profileMenuOpen: false

  signal profilePicked(string cardName, string profileId)

  Layout.fillWidth: true
  implicitHeight: col.implicitHeight + 12
  radius: 6
  color: window.palette.bg1
  border.width: 1; border.color: window.palette.bg2

  IconResolver { id: iconResolver }

  ColumnLayout {
    id: col
    anchors.fill: parent
    anchors.margins: 6
    spacing: 6

    RowLayout {
      Layout.fillWidth: true
      spacing: 6
      Item {
        Layout.preferredWidth: 22; Layout.preferredHeight: 22
        property string _res: {
          var n = cardData.properties ? cardData.properties["device.icon_name"] : "audio-card-analog-pci"
          return iconResolver.resolve(n)
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
          text: "\uF109"
          color: window.palette.gray
          font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(12)
        }
      }
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        Text {
          text: cardData.properties ? (cardData.properties["device.description"] || cardData.name) : cardData.name
          color: window.palette.fg
          font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(10); font.bold: true
          elide: Text.ElideRight
          Layout.fillWidth: true
        }
        Text {
          text: cardData.name
          color: window.palette.gray
          font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(8)
          elide: Text.ElideRight
          Layout.fillWidth: true
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: 6
      Text {
        text: "Profile:"
        color: window.palette.gray
        font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(9)
        Layout.preferredWidth: 50
      }
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 24
        radius: 4
        color: root.profileMenuOpen ? window.palette.bg2 : window.palette.bgAlpha
        border.width: 1; border.color: window.palette.bg2
        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 6; anchors.rightMargin: 6
          spacing: 4
          Text {
            text: {
              var ap = root.cardData.active_profile
              var profs = root.cardData.profiles
              if (profs && profs[ap]) return profs[ap].description
              return ap || "—"
            }
            color: window.palette.fg
            font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(9)
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
          Text { text: root.profileMenuOpen ? "\uF077" : "\uF078"; color: window.palette.gray; font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(8) }
        }
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.profileMenuOpen = !root.profileMenuOpen
        }
      }
    }

    ColumnLayout {
      visible: root.profileMenuOpen
      Layout.fillWidth: true
      spacing: 2
      Repeater {
        model: {
          var profs = cardData.profiles
          if (!profs) return []
          var arr = []
          for (var k in profs) arr.push({ id: k, desc: profs[k].description, avail: profs[k].available, prio: profs[k].priority })
          arr.sort(function(a,b){ return b.prio - a.prio })
          return arr
        }
        delegate: Rectangle {
          required property var modelData
          Layout.fillWidth: true
          implicitHeight: 24
          radius: 4
          property bool isActive: root.cardData.active_profile === modelData.id
          color: isActive ? window.palette.green : (ma3.containsMouse ? window.palette.bg2 : window.palette.bgAlpha)
          opacity: modelData.avail ? 1 : 0.5
          Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left; anchors.leftMargin: 8
            anchors.right: parent.right; anchors.rightMargin: 8
            text: modelData.desc + (modelData.avail ? "" : " (unavailable)")
            color: isActive ? window.palette.baseOverlay : window.palette.fg
            font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(9)
            elide: Text.ElideRight
          }
          MouseArea {
            id: ma3
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.profilePicked(root.cardData.name, modelData.id)
              root.profileMenuOpen = false
            }
          }
        }
      }
    }
  }
}
