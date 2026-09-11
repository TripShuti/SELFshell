// ============================================================
// quickshell/popups/control/NotificationList.qml — список сповіщень, згрупованих по додатках
// ============================================================
import QtQuick
import QtQuick.Layouts

// Список сповіщень. Модель груп і лічильник — з кореня (rebuildGroups там);
// дії карток — методи самих об'єктів сповіщень, посередництва не треба.
// implicitHeight-трюк (0 без висоти) лишено як був: секція входить
// в implicitHeight попапа.
Item {
  id: root

  required property QtObject window
  required property var groupedModel
  required property int unread

  Layout.fillWidth: true
  Layout.fillHeight: true
  // implicitHeight за замовчуванням 0 (діти заякорені), а секція
  // входить в implicitHeight попапа — без явної висоти список
  // сповіщень схлопнувся б. Зі сповіщеннями — до висоти списку
  // (з обмеженням, далі скрол), без — висота порожнього стану.
  readonly property real notifMaxHeight: 240
  implicitHeight: unread > 0
    ? Math.min(notifColumn.implicitHeight, notifMaxHeight)
    : 46
  Behavior on implicitHeight {
    NumberAnimation { duration: window.appConfig.anim(260); easing.type: Easing.OutCubic }
  }
  clip: true

  Flickable {
    id: notifFlick
    anchors.fill: parent
    visible: unread > 0
    contentWidth: width
    contentHeight: notifColumn.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height

    Column {
      id: notifColumn
      width: parent.width
      spacing: 8

      Repeater {
        model: groupedModel

        delegate: Column {
          required property var modelData
          width: parent.width
          spacing: 3
          // Перевикористання делегата з новою моделлю — перерезолв іконки групи
          onModelDataChanged: groupIconBox._resolveGroupIcon()

          // --- Шапка групи: іконка, назва, кількість, очистити групу ---
          RowLayout {
            width: parent.width
            spacing: 6

            Item {
              id: groupIconBox
              Layout.preferredWidth: 16
              Layout.preferredHeight: 16
              // Імперативний резолв: resolve() мутує кеш резолвера,
              // біндинг з викликом resolve() зациклюється
              property string _res: ""
              function _resolveGroupIcon() {
                var r = iconResolver.resolve(modelData.icon)
                if (r !== "") { _res = r; return }
                // fallback на image першого сповіщення групи (коли appIcon порожній, а image — "telegram")
                var first = modelData.notifs && modelData.notifs.length > 0 ? modelData.notifs[0] : null
                if (first && first.image && String(first.image).startsWith("image://icon/")) {
                  var n = String(first.image).substring("image://icon/".length)
                  if (!n.startsWith("/")) {
                    var rr = iconResolver.resolve(n)
                    if (rr !== "") { _res = rr; return }
                  }
                }
                _res = r
              }
              Component.onCompleted: _resolveGroupIcon()
              Image {
                id: grpIconImg
                anchors.fill: parent
                source: parent._res
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                visible: status === Image.Ready
              }
              Text {
                anchors.fill: parent
                visible: grpIconImg.status !== Image.Ready
                text: {
                  if (modelData.icon === "camera-photo") return "\uF030"
                  if (modelData.icon === "dialog-information") return "\uF05A"
                  return "•"
                }
                color: window.palette.green
                font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(10)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
              }
            }

            Text {
              text: modelData.appName
              color: window.palette.green
              font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(11); font.bold: true
              elide: Text.ElideRight
              Layout.fillWidth: true
            }

            Text {
              text: modelData.notifs.length
              color: window.palette.gray
              font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(10)
            }

            Rectangle {
              implicitWidth: 16; implicitHeight: 16; radius: 8
              color: groupClearArea.containsMouse ? window.palette.red : window.palette.bg1
              Behavior on color { ColorAnimation { duration: window.appConfig.anim(120) } }
              Text {
                anchors.centerIn: parent
                text: "\uF00D"
                color: groupClearArea.containsMouse ? window.palette.bg0H : window.palette.gray
                font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(8)
              }
              MouseArea {
                id: groupClearArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                  for (var i = 0; i < modelData.notifs.length; ++i) {
                    if (modelData.notifs[i]) modelData.notifs[i].dismiss()
                  }
                }
              }
            }
          }

          // --- Сповіщення групи ---
          Repeater {
            model: modelData.notifs

            delegate: Rectangle {
              required property var modelData
              readonly property var notif: modelData
              property bool hovered: false
              // Перевикористання делегата з новою моделлю — перерезолв іконок
              onModelDataChanged: {
                rowIconBox._resolveRowIcon()
                notifImgBox._resolveNotifImg()
              }

              width: notifColumn.width
              height: notifRow.implicitHeight + 10
              radius: 6
              color: hovered ? window.palette.bg2 : window.palette.bg1
              Behavior on color { ColorAnimation { duration: window.appConfig.anim(120) } }

              HoverHandler { onHoveredChanged: parent.hovered = hovered }

              // Акцентна смужка ліворуч
              Rectangle {
                width: 3
                height: parent.height - 8
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 2
                radius: 2
                color: window.palette.yellow
              }

              // Клік по рядку — default-дія сповіщення.
              // MouseArea під контентом, щоб кнопки дій приймали кліки
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  var actions = notif.actions
                  var invoked = false
                  for (var i = 0; i < actions.length; ++i) {
                    if (actions[i].identifier === "default") {
                      actions[i].invoke()
                      invoked = true
                      break
                    }
                  }
                  if (!invoked) notif.dismiss()
                }
              }

              ColumnLayout {
                id: notifRow
                x: 12; y: 5
                width: parent.width - 24
                spacing: 4

                RowLayout {
                  Layout.fillWidth: true
                  spacing: 8

                  // Іконка додатка — файл або тема, з fallback на image (коли appIcon порожній, а image — "telegram")
                  Item {
                    id: rowIconBox
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18
                    // Імперативний резолв: resolve() мутує кеш резолвера,
                    // біндинг з викликом resolve() зациклюється
                    property string _res2: ""
                    function _resolveRowIcon() {
                      var r = iconResolver.resolve(notif.appIcon)
                      if (r !== "") { _res2 = r; return }
                      // fallback: якщо appIcon порожній, а image — "image://icon/telegram", спробуємо резолвити image
                      if (notif.image && String(notif.image).startsWith("image://icon/")) {
                        var n = String(notif.image).substring("image://icon/".length)
                        if (n.startsWith("/")) { _res2 = ""; return } // файл — large image вже покаже його
                        var rr = iconResolver.resolve(n)
                        if (rr !== "") { _res2 = rr; return }
                      }
                      _res2 = r
                    }
                    Component.onCompleted: _resolveRowIcon()
                    Image {
                      id: rowIconImg
                      anchors.fill: parent
                      source: parent._res2
                      fillMode: Image.PreserveAspectFit
                      asynchronous: true
                      visible: status === Image.Ready
                    }
                    Text {
                      anchors.fill: parent
                      visible: rowIconImg.status !== Image.Ready
                      text: {
                        if (notif.appIcon === "camera-photo") return "\uF030"
                        if (notif.appIcon === "dialog-information") return "\uF05A"
                        // якщо image був telegram, покажемо phone glyph як fallback, але _res2 вже спробував org.telegram.desktop
                        return "•"
                      }
                      color: window.palette.green
                      font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(10)
                      horizontalAlignment: Text.AlignHCenter
                      verticalAlignment: Text.AlignVCenter
                    }
                  }

                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                      text: notif.summary
                      color: window.palette.fg
                      font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(12); font.bold: true
                      wrapMode: Text.WordWrap
                      Layout.fillWidth: true
                      maximumLineCount: 2
                      elide: Text.ElideRight
                    }

                    Text {
                      text: notif.body
                      color: window.palette.gray
                      font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(11)
                      wrapMode: Text.WordWrap
                      Layout.fillWidth: true
                      maximumLineCount: 2
                      elide: Text.ElideRight
                      visible: notif.body !== ""
                    }
                  }

                  // Картинка сповіщення — показуємо тільки якщо це валідний файл або існуюча іконка теми
                  // image://icon/telegram з missing іконкою дає checker як Ready, тому перевіряємо через _resolvedIcon
                  Item {
                    id: notifImgBox
                    // Імперативний резолв: resolve() мутує кеш резолвера,
                    // біндинг з викликом resolve() зациклюється
                    property string _imgResolved: ""
                    function _resolveNotifImg() {
                      if (!notif.image) { _imgResolved = ""; return }
                      var src = String(notif.image)
                      // quickshell дає image як "image://icon/<name>" або "file://..." або "/path"
                      if (src.startsWith("image://icon/")) {
                        var name = src.substring("image://icon/".length)
                        if (name === "") { _imgResolved = ""; return }
                        // якщо це шлях до файлу (починається з /), повертаємо file://
                        if (name.startsWith("/")) { _imgResolved = "file://" + name; return }
                        _imgResolved = iconResolver.resolve(name)
                        return
                      }
                      if (src.startsWith("/") || src.startsWith("file://")) {
                        _imgResolved = src.startsWith("file://") ? src : "file://" + src
                        return
                      }
                      // звичайний шлях або іконка
                      _imgResolved = iconResolver.resolve(src)
                    }
                    Component.onCompleted: _resolveNotifImg()
                    visible: _imgResolved !== ""
                    Layout.preferredWidth: 56
                    Layout.preferredHeight: 56
                    Image {
                      id: notifImg
                      anchors.fill: parent
                      source: parent._imgResolved
                      fillMode: Image.PreserveAspectFit
                      asynchronous: true
                      visible: status === Image.Ready
                      clip: true
                      onStatusChanged: if (status === Image.Error) console.warn("[ControlPopup] image load failed:", notif.image, "resolved:", parent._imgResolved, "appIcon:", notif.appIcon)
                    }
                  }

                  // Кнопка закриття сповіщення
                  Rectangle {
                    implicitWidth: 18; implicitHeight: 18; radius: 9
                    color: closeArea.containsMouse ? window.palette.red : window.palette.bg1
                    Behavior on color { ColorAnimation { duration: window.appConfig.anim(120) } }

                    Text {
                      anchors.centerIn: parent
                      text: "\uF00D"
                      color: closeArea.containsMouse ? window.palette.bg0H : window.palette.gray
                      font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(9)
                    }

                    MouseArea {
                      id: closeArea
                      anchors.fill: parent
                      hoverEnabled: true
                      onClicked: notif.dismiss()
                    }
                  }
                }

                // --- Кнопки дій сповіщення (без "default" — він на клік по рядку) ---
                Row {
                  Layout.fillWidth: true
                  spacing: 4
                  visible: {
                    var actions = notif.actions
                    for (var i = 0; i < actions.length; ++i)
                      if (actions[i].identifier !== "default") return true
                    return false
                  }

                  Repeater {
                    model: notif.actions

                    delegate: Rectangle {
                      required property var modelData
                      readonly property var action: modelData
                      visible: action.identifier !== "default"

                      implicitWidth: actionText.implicitWidth + 12
                      height: 20
                      radius: 4
                      color: actionArea.containsMouse ? window.palette.bgAlpha : window.palette.bg2
                      Behavior on color { ColorAnimation { duration: window.appConfig.anim(120) } }

                      Text {
                        id: actionText
                        anchors.centerIn: parent
                        text: action.text
                        color: window.palette.light
                        font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(9)
                      }

                      MouseArea {
                        id: actionArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: action.invoke()
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  // Порожній стан — немає сповіщень
  ColumnLayout {
    anchors.centerIn: parent
    visible: unread === 0
    spacing: 4

    Text {
      Layout.alignment: Qt.AlignHCenter
      text: "\uF0F3"
      color: window.palette.gray
      font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(22)
    }

    Text {
      Layout.alignment: Qt.AlignHCenter
      text: "No notifications"
      color: window.palette.gray
      font.family: window.palette.font; font.pixelSize: window.appConfig.scaled(12)
    }
  }
}
