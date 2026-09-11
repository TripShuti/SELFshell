// ============================================================
// quickshell/popups/mpris/EqSection.qml — виїзджаюча секція еквалайзера: статус, пресети, слайдери смуг і контекстне меню
// ============================================================
import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../scripts/EqPresets.js" as EqPresets

// Секція еквалайзера (системна, не прив'язана до плеєра).
// Стан смуг і пресетів живе в AudioEq — сюди прокидається об'єктом;
// висотою керує корінь попапа через sectionHeight (анімація і _updateAnchor там).
Item {
  id: root

  required property QtObject window
  required property QtObject audioEq
  required property real sectionHeight
  required property real eqTarget
  // ім'я пресета в режимі перейменування (запускається з контекстного
  // меню; чип малює TextInput замість назви)
  property string renameTarget: ""

  Layout.fillWidth: true
  Layout.preferredHeight: sectionHeight
  visible: sectionHeight > 0
  clip: true

  ColumnLayout {
    anchors.fill: parent
    spacing: 6

    // Заголовок: назва + стан + тумблер
    RowLayout {
      Layout.fillWidth: true
      spacing: 6

      Text {
        text: "Equalizer"
        color: window.palette.fg
        font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(11); font.bold: true
      }

      Text {
        text: {
          if (!audioEq.pluginInstalled) return "swh-plugins not installed"
          if (audioEq.error !== "") return audioEq.error
          if (audioEq.busy) return "..."
          return audioEq.enabled ? "on" : "off"
        }
        color: {
          if (!audioEq.pluginInstalled || audioEq.error !== "") return window.palette.danger
          return window.palette.gray
        }
        font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(9)
      }

      Item { Layout.fillWidth: true }

      // новий пресет з поточних смуг: "new", "new2", "new3"…
      Rectangle {
        property bool hovered: false
        width: 18; height: 18; radius: 4
        color: hovered ? window.palette.bg2 : "transparent"
        Behavior on color { ColorAnimation { duration: window.appConfig.anim(120) } }

        Text {
          anchors.centerIn: parent
          text: "+"
          color: parent.hovered ? window.palette.fg : window.palette.gray
          font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(11)
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: audioEq.createPreset()
        }
      }

      ToggleSwitch {
        checked: audioEq.enabled
        enabled: audioEq.pluginInstalled && !audioEq.busy
        palette: window.palette
        appConfig: window.appConfig
        checkedColor: window.palette.green
        trackWidth: 28; trackHeight: 16; knobSize: 12
        Layout.alignment: Qt.AlignVCenter
        onToggled: function(v) { v ? audioEq.enable() : audioEq.disable() }
      }
    }

    // Пресети: горизонтальний скрол. Порядок: запінені (хронологія
    // пінів) → вбудовані → користувацькі.
    // Right-click на чипі — контекстне меню (pin/rename/save/delete).
    Flickable {
      Layout.fillWidth: true
      height: 20
      contentWidth: chipRow.implicitWidth
      contentHeight: 20
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      // як і тогл увімкнення вище: поки триває enable-ланцюг, пресет
      // чекає (applyPreset йде через той самий _setParamProc)
      enabled: !audioEq.busy

      Row {
        id: chipRow
        spacing: 4

        Repeater {
          model: {
            // pinned спочатку — у хронології пінів
            var out = []
            for (var p = 0; p < audioEq.pinned.length; p++)
              if (audioEq.chipExists(audioEq.pinned[p]))
                out.push(audioEq.pinned[p])
            var all = EqPresets.all()
            for (var n in all)
              if (audioEq.deletedBuiltins.indexOf(n) === -1 &&
                  audioEq.pinned.indexOf(n) === -1 &&
                  audioEq.userPresets[n] === undefined)
                out.push(n)
            for (var u in audioEq.userPresets)
              if (audioEq.pinned.indexOf(u) === -1) out.push(u)
            return out
          }

          delegate: Rectangle {
            id: chip
            required property var modelData
            property bool hovered: false
            readonly property bool active: audioEq.preset === modelData
            readonly property bool pinnedChip: audioEq.isPinned(modelData)
            // цей чип перейменовується (Rename у контекстному меню):
            // Text ховається, TextInput замість нього
            readonly property bool renaming:
                  renameTarget === modelData

            width: chipText.implicitWidth + 14 + (pinMark.visible ? 12 : 0)
            height: 20
            radius: 10
            color: active ? window.palette.green
                 : (hovered ? window.palette.bg2 : window.palette.bg1)
            Behavior on color { ColorAnimation { duration: window.appConfig.anim(120) } }

            Row {
              anchors.centerIn: parent
              spacing: 4
              visible: !chip.renaming

              // мітка запіненого пресета
              Text {
                id: pinMark
                visible: chip.pinnedChip
                text: "\uF08D"
                color: chip.active ? window.palette.bg0H : window.palette.accent
                font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(9)
              }

              Text {
                id: chipText
                text: chip.modelData
                color: chip.active ? window.palette.bg0H : window.palette.muted
                font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(9)
              }
            }

            // поле rename — пряма дитина чіпа (в Row воно ставало
            // третім елементом і виїжджало за межі чіпа)
            TextInput {
              id: renameInput
              anchors.centerIn: parent
              visible: chip.renaming
              width: Math.min(90, chip.width - 12)
              color: window.palette.fg
              font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(9)
              clip: true
              onVisibleChanged: {
                if (visible) { text = chip.modelData; forceActiveFocus(); selectAll() }
              }
              onAccepted: {
                var t = text.trim()
                if (t !== "" && t !== chip.modelData)
                  audioEq.renamePreset(chip.modelData, t)
                renameTarget = ""
              }
              Keys.onEscapePressed: renameTarget = ""
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              acceptedButtons: Qt.LeftButton | Qt.RightButton
              onEntered: chip.hovered = true
              onExited: chip.hovered = false
              onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton)
                  eqCtxMenu.openFor(chip.modelData,
                                    chip.mapToItem(root, 0, 0))
                else
                  audioEq.applyPreset(chip.modelData)
              }
            }
          }
        }
      }
    }

    // 15 вертикальних слайдерів смуг (20px + spacing 4 = влазить
    // у ширину попапа без скролу)
    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      spacing: 4
      // слайдери мовчать поки busy (той самий _setParamProc); швидкий
      // drag поза busy зливається чергою _bandsDirty в AudioEq
      enabled: !audioEq.busy
      opacity: audioEq.busy ? 0.5 : 1.0

      Repeater {
        model: audioEq.bandCount

        VertSlider {
          id: vs
          required property int index
          value: audioEq.bands[index] ?? 0
          from: -12; to: 12; step: 1
          label: EqPresets.bandLabels[index] ?? ""
          trackColor: window.palette.bg2
          fillColor: window.palette.accent
          knobColor: window.palette.textLight
          labelColor: window.palette.gray
          fontFamily: window.palette.font
          fontPx: window.appConfig.scaled(8)
          implicitWidth: 20
          implicitHeight: 130
          onMoved: v => audioEq.setBand(index, v)

          Connections {
            target: audioEq
            function onBandsChanged() {
              // після фіксу VertSlider біндинг не рветься, але лишаємо
              // імперативний апдейт для сумісності; ?? 0 — масив теоретично
              // може бути коротшим (старий ручний eq.json), без фолбеку
              // "Cannot assign [undefined] to double" на кожен слайдер
              if (!vs.dragging) vs.value = audioEq.bands[index] ?? 0
            }
          }
        }
      }
    }
  }

    // Контекстне меню пресета (right-click)
    Rectangle {
      id: eqCtxMenu
      visible: ctxName !== ""
      z: 50
      width: 150
      height: ctxCol.implicitHeight + 8
      radius: 6
      color: window.palette.bg1
      border.width: 1
      border.color: window.palette.bg2

      property string ctxName: ""
      readonly property bool ctxIsUser: audioEq.userPresets[ctxName] !== undefined

      function openFor(name, pos) {
        ctxName = name
        width = 150
        // кламп від eqTarget: висота секції анімована (після відкриття
        // вона ще їде від 0), і меню затискалось би у верхню частину
        // поверх чипів
        x = Math.max(2, Math.min(pos.x, root.width - width - 4))
        y = Math.max(2, Math.min(pos.y + 16, eqTarget - height - 4))
      }

      function close() {
        ctxCloseTimer.stop()
        ctxName = ""
      }

      Timer {
        id: ctxCloseTimer
        interval: 2000
        running: eqCtxMenu.visible
        repeat: false
        onTriggered: eqCtxMenu.close()
      }

      // курсор над меню — скидання автозакриття (пасивний хендлер,
      // кліки по пунктах не блокує)
      HoverHandler {
        onHoveredChanged: if (hovered) ctxCloseTimer.restart()
      }

      ColumnLayout {
        id: ctxCol
        anchors.fill: parent
        anchors.margins: 4
        spacing: 0

        Repeater {
          model: [
            { id: "pin",   label: audioEq.isPinned(eqCtxMenu.ctxName) ? "Unpin" : "Pin" },
            { id: "rename", label: "Rename" },
            { id: "save",  label: "Save changes" },
            { id: "delete", label: "Delete", danger: true }
          ]

          delegate: Rectangle {
            required property var modelData
            property bool hovered: false

            Layout.fillWidth: true
            implicitHeight: 20
            radius: 4
            color: hovered ? window.palette.bg2 : "transparent"
            Behavior on color { ColorAnimation { duration: window.appConfig.anim(100) } }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: parent.left
              anchors.leftMargin: 8
              text: parent.modelData.label
              color: parent.modelData.danger && parent.hovered
                     ? window.palette.danger : window.palette.fg
              font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(10)
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                var act = parent.modelData.id
                if (act === "pin") audioEq.togglePin(eqCtxMenu.ctxName)
                else if (act === "rename") {
                  renameTarget = eqCtxMenu.ctxName
                }
                else if (act === "save") audioEq.saveChangesTo(eqCtxMenu.ctxName)
                else if (act === "delete") audioEq.deletePreset(eqCtxMenu.ctxName)
                eqCtxMenu.close()
              }
            }
          }
        }
      }
    }

    // Оверлей закриття контекстного меню (тільки поки меню відкрите)
    MouseArea {
      anchors.fill: parent
      z: 49
      visible: eqCtxMenu.visible
      onClicked: eqCtxMenu.close()
      onWheel: (wheel) => { eqCtxMenu.close(); wheel.accepted = false }
    }
}
