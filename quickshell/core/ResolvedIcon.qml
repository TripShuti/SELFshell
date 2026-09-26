// ============================================================
// quickshell/core/ResolvedIcon.qml — іконка теми з гліф-фолбеком
// ============================================================
import QtQuick

// Імперативний резолв через IconResolver (resolve() мутує кеш — виклик
// з біндинга зациклюється) + Image з фолбек-гліфом. Замінює однакові
// Item-блоки в аудіо-картках.
Item {
  id: root

  property string iconName: ""
  property string fallbackGlyph: ""
  property color glyphColor: "#ede0d4"
  property real glyphSize: 12
  property QtObject palette: null
  // Опційно: для scaled() розміру гліфа
  property QtObject appConfig: null

  IconResolver { id: resolver }

  property string _res: ""
  onIconNameChanged: root._res = resolver.resolve(root.iconName)
  Component.onCompleted: root._res = resolver.resolve(root.iconName)

  Image {
    anchors.fill: parent
    source: root._res
    fillMode: Image.PreserveAspectFit
    asynchronous: true
    visible: status === Image.Ready
  }

  Text {
    anchors.centerIn: parent
    visible: root._res === ""
    text: root.fallbackGlyph
    color: root.glyphColor
    font.family: root.palette?.font ?? "JetBrainsMonoNL Nerd Font"
    font.pixelSize: root.appConfig ? root.appConfig.scaled(root.glyphSize) : root.glyphSize
  }
}
