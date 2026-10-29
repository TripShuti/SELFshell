// ============================================================
// quickshell/popups/settings/ThemePreview.qml — перегляд палітри на прикладах панелі, картки та станів.
// ============================================================
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../core"

Rectangle {
  id: root
  required property QtObject sys
  readonly property var ctl: sys.window.customThemes
  readonly property var palette: sys.window.palette
  readonly property var ac: sys.ac
  readonly property color selectedColor: c(ctl.selectedKey)
  implicitHeight: content.implicitHeight + 28
  radius: 8
  color: c("bg0H")
  border.width: 1
  border.color: c("outlineVariant")

  function c(key) {
    var value = ctl.draft[key] ?? ""
    return /^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(value) ? value : palette[key]
  }

  function channel(index, value) {
    var color = root.selectedColor
    var values = [Math.round(color.r * 255), Math.round(color.g * 255), Math.round(color.b * 255), Math.round(color.a * 255)]
    values[index] = Math.round(value)
    function hex(v) { return v.toString(16).padStart(2, "0") }
    ctl.setColor(ctl.selectedKey, "#" + (values[3] === 255 ? "" : hex(values[3])) + hex(values[0]) + hex(values[1]) + hex(values[2]))
  }

  ColumnLayout {
    id: content
    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
    spacing: 10

    RowLayout {
      Layout.fillWidth: true
      Text {
        text: "Theme preview"
        color: root.c("fg")
        font.family: root.palette.font
        font.pixelSize: root.ac.scaled(11)
        font.bold: true
      }
      Text {
        Layout.fillWidth: true
        text: root.ctl.draftName
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignRight
        color: root.c("gray")
        font.family: root.palette.font
        font.pixelSize: root.ac.scaled(10)
      }
    }

    Rectangle {
      Layout.fillWidth: true
      implicitHeight: root.ac.scaled(32)
      radius: 5
      color: root.c("bg1")
      RowLayout {
        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
        spacing: 8
        Text { text: "1"; color: root.c("accent"); font.family: root.palette.font; font.pixelSize: root.ac.scaled(11) }
        Text { text: "2  3"; color: root.c("muted"); font.family: root.palette.font; font.pixelSize: root.ac.scaled(11) }
        Rectangle { width: 1; height: 14; color: root.c("sepBg") }
        Text { Layout.fillWidth: true; text: "Artist — Track"; elide: Text.ElideRight; color: root.c("widgetFg"); font.family: root.palette.font; font.pixelSize: root.ac.scaled(10) }
        Text { text: "12:45"; color: root.c("textLight"); font.family: root.palette.font; font.pixelSize: root.ac.scaled(10) }
        Rectangle {
          Layout.preferredWidth: 62
          height: 5
          radius: 3
          color: root.c("bgAlpha")
          Rectangle { width: parent.width * 0.7; height: parent.height; radius: 3; color: root.c("audioVolume") }
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: 8
      Rectangle {
        objectName: "notificationPreview"
        Layout.fillWidth: true
        Layout.minimumWidth: root.ac.scaled(200)
        Layout.preferredWidth: root.ac.scaled(320)
        implicitHeight: Math.max(root.ac.scaled(86), card.implicitHeight + 24)
        radius: 5
        color: root.c("bgLayer")
        border.width: 1
        border.color: root.c("bg2")
        ColumnLayout {
          id: card
          anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
          spacing: 6
          Text { Layout.fillWidth: true; elide: Text.ElideRight; text: "Notification title"; color: root.c("fg"); font.family: root.palette.font; font.pixelSize: root.ac.scaled(11); font.bold: true }
          Text { Layout.fillWidth: true; elide: Text.ElideRight; text: "Message and secondary text"; color: root.c("mutedAlt"); font.family: root.palette.font; font.pixelSize: root.ac.scaled(9) }
          Row {
            spacing: 12
            Repeater {
              model: [{key: "green", text: "Success"}, {key: "yellow", text: "Warning"}, {key: "danger", text: "Error"}]
              Text { required property var modelData; text: modelData.text; color: root.c(modelData.key); font.family: root.palette.font; font.pixelSize: root.ac.scaled(9) }
            }
          }
        }
      }
      ColumnLayout {
        objectName: "actionPreview"
        Layout.fillWidth: false
        Layout.minimumWidth: root.ac.scaled(150)
        Layout.preferredWidth: root.ac.scaled(150)
        Layout.maximumWidth: root.ac.scaled(150)
        spacing: 5
        Rectangle {
          Layout.fillWidth: true
          implicitHeight: root.ac.scaled(34)
          radius: 4
          color: root.c("accent")
          Text { anchors.centerIn: parent; text: "Primary action"; color: root.c("bg0H"); font.family: root.palette.font; font.pixelSize: root.ac.scaled(9); font.bold: true }
        }
        Rectangle {
          Layout.fillWidth: true
          implicitHeight: root.ac.scaled(34)
          radius: 4
          color: root.c("bg2")
          border.width: 1
          border.color: root.c("outlineVariant")
          Text { anchors.centerIn: parent; text: "Secondary action"; color: root.c("fg"); font.family: root.palette.font; font.pixelSize: root.ac.scaled(10) }
        }
      }
    }

    RowLayout {
          Layout.fillWidth: true
          spacing: 8
          Repeater {
            model: [{key: "baseOverlay", overlay: "softOverlay", text: "Default"}, {key: "hoverBg", overlay: "hoverOverlay", text: "Hover"}, {key: "bg2", overlay: "pressOverlay", text: "Pressed"}]
            Rectangle {
              required property var modelData
              Layout.fillWidth: true
              implicitHeight: root.ac.scaled(32)
              radius: 3
              color: root.c(modelData.key)
              Rectangle { anchors.fill: parent; radius: parent.radius; color: root.c(parent.modelData.overlay) }
              Text { anchors.centerIn: parent; text: parent.modelData.text; color: root.c("light"); font.family: root.palette.font; font.pixelSize: root.ac.scaled(10) }
            }
          }
        }

    RowLayout {
      Layout.fillWidth: true
      spacing: 2
      Repeater {
        model: root.palette.colorKeys
        Rectangle {
          id: swatch
          required property string modelData
          Layout.fillWidth: true
          implicitHeight: 18
          color: root.c(modelData)
          border.width: root.ctl.selectedKey === modelData ? 1 : 0
          border.color: root.c("bright")
          ToolTip.visible: hover.containsMouse
          ToolTip.text: modelData + " " + root.ctl.draft[modelData]
          MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.ctl.selectedKey = swatch.modelData }
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: 8
      // Шахівниця під зразком робить alpha видимою навіть для кольору фону.
      Rectangle {
        Layout.preferredWidth: 30
        implicitHeight: 24
        color: "#eeeeee"
        Repeater {
          model: 6
          Rectangle { required property int index; x: (index % 3) * 10; y: Math.floor(index / 3) * 12; width: 10; height: 12; color: (index % 2) ? "#888888" : "#eeeeee" }
        }
        Rectangle { anchors.fill: parent; color: root.c(root.ctl.selectedKey) }
      }
      Text {
        Layout.fillWidth: true
        text: root.ctl.selectedKey
        elide: Text.ElideRight
        color: root.c("fg")
        font.family: root.palette.font
        font.pixelSize: root.ac.scaled(10)
      }
      TextField {
        Layout.preferredWidth: 116
        enabled: !root.ctl.busy
        text: root.ctl.draft[root.ctl.selectedKey] ?? ""
        validator: RegularExpressionValidator { regularExpression: /^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/ }
        maximumLength: 9
        selectByMouse: true
        color: acceptableInput ? root.palette.fg : root.palette.danger
        font.family: root.palette.font
        font.pixelSize: root.ac.scaled(10)
        onTextEdited: root.ctl.setColor(root.ctl.selectedKey, text)
        background: Rectangle { color: root.palette.bg1; radius: 4; border.width: 1; border.color: parent.activeFocus ? root.palette.accent : root.palette.bg2 }
        ToolTip.visible: hovered
        ToolTip.text: "#RRGGBB or #AARRGGBB (alpha first)"
      }
      Text { text: "Aa"; color: root.c(root.ctl.selectedKey); font.family: root.palette.font; font.pixelSize: root.ac.scaled(16); font.bold: true }
    }

    GridLayout {
      Layout.fillWidth: true
      columns: 2
      columnSpacing: 16
      rowSpacing: 0
      Repeater {
        model: ["R", "G", "B", "A"]
        RowLayout {
          required property int index
          required property string modelData
          readonly property int channelValue: Math.round([root.selectedColor.r, root.selectedColor.g, root.selectedColor.b, root.selectedColor.a][index] * 255)
          Layout.fillWidth: true
          spacing: 5
          Text { text: parent.modelData; color: root.palette.fg; font.family: root.palette.font; font.pixelSize: root.ac.scaled(10) }
          Slider {
            id: slider
            Layout.fillWidth: true
            implicitHeight: 24
            enabled: !root.ctl.busy
            from: 0; to: 255; stepSize: 1
            value: parent.channelValue
            onMoved: root.channel(parent.index, value)
            background: Rectangle {
              x: slider.leftPadding
              y: slider.topPadding + (slider.availableHeight - height) / 2
              width: slider.availableWidth
              height: 4
              radius: 2
              color: root.palette.bg2
              Rectangle { width: slider.visualPosition * parent.width; height: parent.height; radius: 2; color: root.palette.accent }
            }
            handle: Rectangle {
              x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
              y: slider.topPadding + (slider.availableHeight - height) / 2
              width: 10; height: 10; radius: 5
              color: root.palette.fg
            }
          }
          Text { Layout.preferredWidth: 26; text: parent.channelValue; horizontalAlignment: Text.AlignRight; color: root.palette.gray; font.family: root.palette.font; font.pixelSize: root.ac.scaled(10) }
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      SetButton { sys: root.sys; text: "Save"; disabled: root.ctl.blocked || !root.ctl.valid; onClicked: root.ctl.save(false) }
      SetButton { sys: root.sys; text: "Save as copy"; disabled: root.ctl.blocked || !root.ctl.valid; onClicked: root.ctl.save(true) }
      SetButton { sys: root.sys; text: "Save and apply"; disabled: root.ctl.blocked || !root.ctl.valid; onClicked: root.ctl.apply() }
    }
  }
}
