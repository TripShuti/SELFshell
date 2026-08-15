// ============================================================
// core/PillBar.qml — пігулка з градієнтом, сяйвом і Repeater-ом віджетів
// ============================================================
import QtQuick
import QtQuick.Layouts

Item {
  id: root

  required property QtObject appConfig
  required property QtObject palette
  required property var orderModel
  required property var widgetComponents
  required property var needsFillHeight
  required property var registerActive

  property real radius: 4
  property real padding: 8
  property real contentSpacing: 4
  property real glowSize: 0
  property real glowOpacity: 0.1
  // наскільки верх градієнта світліший за низ (1.0 = суцільний колір)
  property real lighten: 1.30
  // множник прозорості фону (1.0 = колір з палітри як є)
  property real bgOpacity: 1.0
  // товщина рамки пігулки (0 = без рамки)
  property real borderWidth: 0

  implicitWidth: row.implicitWidth + 2 * root.padding

  Rectangle {
    anchors.fill: bg
    anchors.margins: -root.glowSize
    radius: bg.radius + root.glowSize
    color: "transparent"
    border.width: 1
    border.color: root.palette.hoverBg
    opacity: root.glowOpacity
  }

  Rectangle {
    id: bg
    anchors.fill: parent
    radius: root.radius
    color: root.palette.bgAlpha
    border.width: root.borderWidth
    border.color: root.palette.outlineVariant
    opacity: root.bgOpacity

    gradient: Gradient {
      orientation: Gradient.Vertical
      GradientStop { position: 0.0; color: Qt.lighter(root.palette.baseOverlay, root.lighten) }
      GradientStop { position: 1.0; color: root.palette.bgAlpha }
    }
  }

  RowLayout {
    id: row
    x: root.padding
    anchors.verticalCenter: parent.verticalCenter
    spacing: root.contentSpacing

    Repeater {
      model: root.orderModel.filter(name => root.appConfig.isSep(name) || root.appConfig.cfg[name + "Enabled"])
      delegate: RowLayout {
        required property string modelData
        spacing: 4

        Loader {
          Layout.alignment: Qt.AlignVCenter
          Layout.fillHeight: root.needsFillHeight(modelData)
          sourceComponent: root.widgetComponents[modelData]
          onLoaded: root.registerActive(modelData, item)
          visible: !root.appConfig.isSep(modelData)
        }

        Separator {
          Layout.alignment: Qt.AlignVCenter
          pal: root.palette
          lineOpacity: root.appConfig.cfg.separatorOpacity
          glowOpacity: root.appConfig.cfg.separatorGlowOpacity
          visible: root.appConfig.isSep(modelData)
        }
      }
    }
  }
}