// ============================================================
// quickshell/core/PillBar.qml — пігулка з градієнтом і Repeater-ом віджетів
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
  required property var unregisterActive

  property real radius: 4
  property real padding: 8
  property real contentSpacing: 4
  property real lighten: 1.30
  property real bgOpacity: 1.0
  property real borderWidth: 0
  property color _pillBase: palette ? palette.bgAlpha : "#9934302a"
  property color _pillTop: palette ? Qt.lighter(palette.baseOverlay, lighten) : "#9934302a"

  Behavior on lighten { NumberAnimation { duration: appConfig.anim(150); easing.type: Easing.OutCubic } }
  Behavior on bgOpacity { NumberAnimation { duration: appConfig.anim(150); easing.type: Easing.OutCubic } }
  Behavior on borderWidth { NumberAnimation { duration: appConfig.anim(150); easing.type: Easing.OutCubic } }
  Behavior on radius { NumberAnimation { duration: appConfig.anim(150); easing.type: Easing.OutCubic } }

  implicitWidth: row.implicitWidth + 2 * root.padding
  implicitHeight: root.height

  Rectangle {
    id: bg
    anchors.centerIn: parent
    width: row.implicitWidth + 2 * root.padding
    height: parent.height
    radius: root.radius
    color: "transparent"
    border.width: root.borderWidth
    // Робимо бордер більш контрастним — без множення на bgOpacity, інакше при bgOpacity 0.85 бордер 0.34 альфи майже непомітний на темному фоні
    border.color: root.palette.outlineVariant
    antialiasing: true
    smooth: true
    gradient: Gradient {
      orientation: Gradient.Vertical
      GradientStop { position: 0.0; color: Qt.rgba(root._pillTop.r, root._pillTop.g, root._pillTop.b, root._pillTop.a * root.bgOpacity) }
      GradientStop { position: 1.0; color: Qt.rgba(root._pillBase.r, root._pillBase.g, root._pillBase.b, root._pillBase.a * root.bgOpacity) }
    }
  }

  RowLayout {
    id: row
    x: root.padding
    anchors.verticalCenter: parent.verticalCenter
    spacing: root.contentSpacing

    Repeater {
      model: root.orderModel
      delegate: RowLayout {
        required property string modelData
        readonly property bool _isSep: root.appConfig.isSep(modelData)
        readonly property bool _shouldShow: _isSep || !!root.appConfig.cfg[modelData + "Enabled"]
        visible: _shouldShow
        spacing: 4
        // Невидимі делегати не займають місце в RowLayout
        Layout.preferredWidth: _shouldShow ? rowInner.implicitWidth : 0
        Layout.preferredHeight: _shouldShow ? rowInner.implicitHeight : 0

        RowLayout {
          id: rowInner
          spacing: 0
          Loader {
            Layout.alignment: Qt.AlignVCenter
            Layout.fillHeight: typeof root.needsFillHeight === "function" ? root.needsFillHeight(modelData) : false
            sourceComponent: root.widgetComponents[modelData] ?? null
            active: !_isSep
            asynchronous: true
            visible: !_isSep && status === Loader.Ready
            onLoaded: root.registerActive(modelData, item)
            Component.onDestruction: root.unregisterActive(modelData)
          }

          Separator {
            Layout.alignment: Qt.AlignVCenter
            pal: root.palette
            lineOpacity: root.appConfig.cfg.separatorOpacity
            glowOpacity: root.appConfig.cfg.separatorGlowOpacity
            visible: _isSep
          }
        }
      }
    }
  }
}
