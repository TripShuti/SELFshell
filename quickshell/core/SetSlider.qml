// ============================================================
// core/SetSlider.qml — повзунок налаштувань з підписом і значенням
// ============================================================
import QtQuick
import QtQuick.Layouts

// Підпис ліворуч, значення праворуч, доріжка на всю ширину під ними.
// Значення змінюється і перетягуванням, і одиночним кліком по доріжці.
ColumnLayout {
  id: sl

  required property QtObject sys
  property string label: ""
  property string sub: ""
  property real from: 0
  property real to: 100
  property real step: 1
  property real value: 0
  property string suffix: ""
  // скільки знаків після коми показувати у значенні
  property int decimals: 0
  signal moved(real value)

  Layout.fillWidth: true
  spacing: 6

  RowLayout {
    Layout.fillWidth: true
    spacing: 8

    Text {
      Layout.fillWidth: true
      text: sl.label
      color: sl.sys.palette.fg
      elide: Text.ElideRight
      font.family: sl.sys.palette.font
      font.pixelSize: 10
    }
    Text {
      text: sl.value.toFixed(sl.decimals) + (sl.suffix ? " " + sl.suffix : "")
      color: sl.sys.palette.gray
      font.family: sl.sys.palette.font
      font.pixelSize: 10
    }
  }

  Item {
    id: bar
    Layout.fillWidth: true
    implicitHeight: 18

    // Реальна ширина діапазону. Math.max(1, ...) тут НЕ можна: для
    // діапазонів менших за 1 (opacity-слайдери 0..0.4, 0.5..1.0 тощо)
    // span ставав 1, і значення насичувалося на максимумі ще на половині
    // треку. Захищаємось лише від ділення на нуль при from === to.
    readonly property real span: (sl.to - sl.from) !== 0 ? (sl.to - sl.from) : 0.0001
    readonly property real frac: Math.max(0, Math.min(1, (sl.value - sl.from) / span))

    function pick(px) {
      var f = Math.max(0, Math.min(1, px / Math.max(1, bar.width)))
      var raw = sl.from + f * bar.span
      var snapped = Math.round(raw / sl.step) * sl.step
      sl.moved(Math.max(sl.from, Math.min(sl.to, snapped)))
    }

    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width
      height: 6
      radius: 3
      color: sl.sys.palette.bg2

      Rectangle {
        width: parent.width * bar.frac
        height: parent.height
        radius: parent.radius
        color: sl.sys.palette.accent
        // Під час драгу Behavior вимкнено — ручка йде за курсором миттєво,
        // анімація лишається лише для зовнішніх змін значення
        Behavior on width { enabled: !grab.pressed; NumberAnimation { duration: sl.sys.ac.anim(120); easing.type: Easing.OutCubic } }
      }
    }

    // Кружок ручки не виходить за краї доріжки: на мінімумі й максимумі
    // він упирається в них, а не звисає половиною назовні.
    Rectangle {
      width: 14
      height: 14
      radius: 7
      anchors.verticalCenter: parent.verticalCenter
      x: Math.max(0, Math.min(bar.width - width, bar.width * bar.frac - width / 2))
      color: sl.sys.palette.accent
      border.width: 2
      border.color: Qt.lighter(sl.sys.palette.accent, 1.3)
      Behavior on x { enabled: !grab.pressed; NumberAnimation { duration: sl.sys.ac.anim(120); easing.type: Easing.OutCubic } }
    }

    // Зона натискання ширша за доріжку: влучити в шестипіксельну смужку
    // мишею складно. Координату переводимо в систему доріжки — інакше
    // розширення зсувало б значення на свою ж ширину.
    MouseArea {
      id: grab
      anchors.fill: parent
      anchors.margins: -6
      cursorShape: Qt.PointingHandCursor
      // Перетягування ручки належить повзунку цілком: без цього
      // прокрутка сторінки відбирала жест на першому ж вертикальному
      // тремтінні руки, і повзунок завмирав на місці.
      preventStealing: true
      onPressed: function(mouse) { bar.pick(mouse.x + grab.x) }
      onPositionChanged: function(mouse) { if (pressed) bar.pick(mouse.x + grab.x) }
    }
  }

  // Необов'язковий підпис-підказка під доріжкою
  Text {
    Layout.fillWidth: true
    visible: sl.sub !== ""
    text: sl.sub
    color: sl.sys.palette.gray
    wrapMode: Text.WordWrap
    font.family: sl.sys.palette.font
    font.pixelSize: 9
  }
}
