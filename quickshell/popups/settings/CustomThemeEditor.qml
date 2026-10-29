// ============================================================
// quickshell/popups/settings/CustomThemeEditor.qml — редактор усіх кольорів палітри та бібліотеки власних тем.
// ============================================================
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../core"

Item {
  id: root
  required property QtObject sys
  readonly property var ctl: sys.window.customThemes
  readonly property var palette: sys.window.palette
  property string deleteId: ""
  implicitHeight: content.implicitHeight

  ColumnLayout {
    id: content
    width: parent.width
    spacing: 12

    SetLabel { sys: root.sys; text: "Custom themes" }
    Text {
      Layout.fillWidth: true
      text: "Edit every palette color. Wallpaper changes never regenerate a custom theme."
      wrapMode: Text.WordWrap
      color: root.palette.gray
      font.family: root.palette.font
      font.pixelSize: root.sys.ac.scaled(10)
    }

    Repeater {
      model: root.ctl.themes
      delegate: RowLayout {
        required property var modelData
        Layout.fillWidth: true
        Rectangle {
          Layout.preferredWidth: 24
          Layout.preferredHeight: 24
          radius: 4
          color: modelData.colors.accent
          border.width: 1
          border.color: root.palette.outlineVariant
        }
        SetButton {
          sys: root.sys
          text: modelData.name + (root.ctl.activeId === modelData.id && root.sys.cfg.themeMode === "custom" ? " • Active" : "")
          disabled: root.ctl.blocked
          onClicked: { root.deleteId = ""; root.ctl.applySaved(modelData.id) }
        }
        SetButton {
          sys: root.sys
          Layout.fillWidth: false
          Layout.preferredWidth: 74
          text: root.deleteId === modelData.id ? "Delete?" : "Delete"
          disabled: root.ctl.blocked
          onClicked: {
            if (root.deleteId === modelData.id) {
              root.ctl.removeSaved(modelData.id)
              root.deleteId = ""
            } else root.deleteId = modelData.id
          }
        }
      }
    }

    SetButton {
      sys: root.sys
      text: "New theme from current colors"
      disabled: root.ctl.blocked
      onClicked: { root.deleteId = ""; root.ctl.capture() }
    }

    TextField {
      Layout.fillWidth: true
      enabled: !root.ctl.busy
      text: root.ctl.draftName
      placeholderText: "Theme name"
      maximumLength: 80
      color: root.palette.fg
      font.family: root.palette.font
      font.pixelSize: root.sys.ac.scaled(11)
      selectByMouse: true
      onTextEdited: root.ctl.draftName = text
      background: Rectangle { color: root.palette.bg1; radius: 5; border.width: 1; border.color: parent.activeFocus ? root.palette.accent : root.palette.bg2 }
    }

    Text {
      Layout.fillWidth: true
      visible: root.ctl.status !== ""
      text: root.ctl.status
      color: root.ctl.failed ? root.palette.danger : root.palette.accent
      wrapMode: Text.WrapAnywhere
      font.family: root.palette.font
      font.pixelSize: root.sys.ac.scaled(10)
    }
  }
}
