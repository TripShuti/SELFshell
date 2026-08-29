// ============================================================
// NotifToast.qml — спливаюче сповіщення (тост)
// ============================================================
import Quickshell
import Quickshell.Io
import "../core"
import QtQuick
import QtQuick.Layouts

// Спливаюче сповіщення (тост) — показується у правому верхньому куті
PopupWindow {
  id: root

  property string toastAppName: ""
  property string toastSummary: ""
  property string toastBody: ""
  property string toastAppIcon: ""
  property string toastImage: ""
  property var toastNotification: null
  property QtObject anchorWindow: null
  property bool muted: false
  property bool isPhone: false
  readonly property QtObject palette: anchorWindow ? anchorWindow.palette : null
  readonly property QtObject appConfig: anchorWindow ? anchorWindow.appConfig : null

  IconResolver { id: iconResolver }

  readonly property string resolvedIcon: iconResolver.resolve(root.toastAppIcon)
  readonly property string resolvedImage: iconResolver.resolve(root.toastImage)

  // Є дії, окрім default (default — на клік по тосту)
  readonly property bool hasActions: {
    if (!root.toastNotification) return false
    var actions = root.toastNotification.actions
    for (var i = 0; i < actions.length; ++i)
      if (actions[i].identifier !== "default") return true
    return false
  }


  color: "transparent"
  implicitWidth: 280
  implicitHeight: container.implicitHeight
  grabFocus: false

  // Звук сповіщення. Резолвиться відносно розташування ЦЬОГО .qml-файлу
  // (Qt.resolvedUrl), а не через хардкоджений $HOME-шлях — так працює
  // однаково незалежно від того, чи конфіг лежить в іменованій підпапці
  // (~/.config/quickshell/SELFshell/) чи прямо в базовій
  // (~/.config/quickshell/). Process.command НЕ проходить через shell,
  // тож "$HOME" в аргументі сам собою не розгортався б без sh -c-обгортки.
  readonly property string soundFile: Qt.resolvedUrl("../assets/sounds/notif.ogg").toString().replace("file://", "")

  Process {
    id: soundProc
    command: ["pw-play", root.soundFile]
    onExited: (exitCode) => {
      if (exitCode !== 0) console.warn("NotifToast: pw-play failed (code " + exitCode + ") for " + root.soundFile)
    }
  }
  function playSound() {
    soundProc.running = false
    soundProc.running = true
  }

  // Показує сповіщення з анімацією
  function showNotif(notif) {
    root.toastAppName = notif.appName ?? ""
    root.toastSummary = notif.summary ?? ""
    root.toastBody = notif.body ?? ""
    root.toastAppIcon = notif.appIcon ?? ""
    root.toastImage = notif.image ?? ""
    root.isPhone = !!(notif.isPhone ?? (String(notif.appName ?? "").startsWith("Phone •")))
    root.toastNotification = notif
    if (root.anchorWindow) {
      root.anchor.window = root.anchorWindow
      var w = root.anchorWindow.screen?.geometry?.width ?? 1920
      root.anchor.rect = Qt.rect(w - 292, 40, 280, 0)
    }
    root.visible = true
    root.show()
  }

  // Анімація появи
  function show() {
    if (autoCloseTimer.running) autoCloseTimer.stop()
    if (exitAnim.running) exitAnim.stop()
    container.opacity = 0
    container.scale = 0.85
    container.x = 32
    enterAnim.start()
    autoCloseTimer.restart()
    if (!root.muted) playSound()
  }

  // Анімація закриття
  function dismiss() {
    if (exitAnim.running) return
    exitAnim.start()
  }

  // Анімація появи — прозорість + масштаб + зсув
  ParallelAnimation {
    id: enterAnim
    NumberAnimation { target: container; property: "opacity"; from: 0; to: 1; duration: appConfig ? appConfig.anim(220) : 220; easing.type: Easing.OutCubic }
    NumberAnimation { target: container; property: "scale"; from: 0.85; to: 1.0; duration: appConfig ? appConfig.anim(350) : 350; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
    NumberAnimation { target: container; property: "x"; from: 32; to: 0; duration: appConfig ? appConfig.anim(350) : 350; easing.type: Easing.OutCubic }
  }

  // Анімація зникнення
  SequentialAnimation {
    id: exitAnim
    ParallelAnimation {
      NumberAnimation { target: container; property: "opacity"; to: 0; duration: appConfig ? appConfig.anim(120) : 120; easing.type: Easing.OutCubic }
      NumberAnimation { target: container; property: "scale"; to: 0.85; duration: appConfig ? appConfig.anim(120) : 120; easing.type: Easing.InCubic }
    }
    ScriptAction { script: root.visible = false }
  }

  // Автоматичне закриття через 4 секунди
  Timer {
    id: autoCloseTimer
    interval: 4000
    onTriggered: root.dismiss()
  }

  // Контейнер — bg2 + opacity як у попапів, щоб не був чорним
  Rectangle {
    id: container
    width: parent.width
    implicitHeight: toastLayout.implicitHeight + 16
    radius: appConfig ? appConfig.cfg.toastRadius : 9
    border.width: 1
    border.color: root.palette ? root.palette.bg2 : "#525256"
    opacity: 0
    scale: 0.85
    clip: true
    property color _base: root.palette ? root.palette.bg2 : "#525256"
    property color _top: Qt.lighter(_base, appConfig ? appConfig.cfg.toastLighten : 1.15)
    property real bgOpacity: appConfig ? appConfig.cfg.toastBgOpacity : 0.90
    gradient: Gradient {
      orientation: Gradient.Vertical
      GradientStop { position: 0.0; color: Qt.rgba(container._top.r, container._top.g, container._top.b, container.bgOpacity) }
      GradientStop { position: 1.0; color: Qt.rgba(container._base.r, container._base.g, container._base.b, container.bgOpacity) }
    }

    // Hover для паузи автозакриття — працює навіть над кнопками
    HoverHandler {
      id: hoverHandler
      onHoveredChanged: {
        if (hovered) autoCloseTimer.stop()
        else autoCloseTimer.restart()
      }
    }
    // Клік по фону тоста — default-дія (під контентом, щоб кнопки були вище)
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: function(mouse) {
        if (mouse.button === Qt.RightButton) {
          root.dismiss()
          return
        }
        if (root.toastNotification) {
          var actions = root.toastNotification.actions
          var defaultAction = null
          for (var i = 0; i < actions.length; ++i) {
            if (actions[i].identifier === "default") {
              defaultAction = actions[i]
              break
            }
          }
          if (defaultAction) {
            defaultAction.invoke()
          } else {
            root.toastNotification.dismiss()
          }
        }
        root.dismiss()
      }
    }

    // Підсвітка верхнього краю — як у AnimatedPopup (градієнт щоб не різала кути)
    Rectangle {
      anchors { top: parent.top; left: parent.left; right: parent.right }
      height: 1
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: "transparent" }
        GradientStop { position: 0.5; color: root.palette ? root.palette.hoverOverlay : "#14ffffff" }
        GradientStop { position: 1.0; color: "transparent" }
      }
    }

  ColumnLayout {
    id: toastLayout
    // Поверх default-MouseArea, щоб кнопки дій приймали кліки
    z: 1
    x: 10; y: 8
    width: parent.width - 20
    spacing: 3

    // Назва додатка з іконкою — для phone показуємо іконку додатку + fallback glyph
    RowLayout {
      spacing: 6
      visible: root.toastAppName !== ""
      Layout.fillWidth: true

      Item {
        Layout.preferredWidth: 16
        Layout.preferredHeight: 16

        Image {
          id: iconImg
          anchors.fill: parent
          // toastImage — фото сповіщення (Notification.image) має пріоритет, але перевіряємо на missing
          source: root.resolvedImage !== "" ? root.resolvedImage : root.resolvedIcon
          fillMode: Image.PreserveAspectFit
          asynchronous: true
          visible: status === Image.Ready
          // Звичайний Image, не IconImage — не падає на кривих SVG,
          // просто виставляє status: Error і ми ловимо це нижче
        }

        Text {
          anchors.fill: parent
          visible: iconImg.status !== Image.Ready
          text: {
            if (root.isPhone) return "\uF10B"
            if (root.toastAppIcon === "camera-photo") return "\uF030"
            if (root.toastAppIcon === "dialog-information") return "\uF05A"
            return "•"
          }
          color: root.palette ? root.palette.green : "#8aa9fc"
          font.family: root.palette ? root.palette.font : "sans-serif"
          font.pixelSize: root.appConfig ? root.appConfig.scaled(12) : 12
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }
      }

      Text {
        text: root.toastAppName
        color: root.palette ? root.palette.mutedAlt : "#aaaaaa"
        font.family: root.palette ? root.palette.font : "sans-serif"
        font.pixelSize: root.appConfig ? root.appConfig.scaled(11) : 11
        elide: Text.ElideRight
        Layout.fillWidth: true
        verticalAlignment: Text.AlignVCenter
      }
    }

    // Заголовок сповіщення
    Text {
      text: root.toastSummary
      color: root.palette ? root.palette.fg : "#ede0d4"
      font.family: root.palette ? root.palette.font : "sans-serif"; font.pixelSize: root.appConfig ? root.appConfig.scaled(13) : 13; font.bold: true
      wrapMode: Text.WordWrap
      Layout.fillWidth: true
      maximumLineCount: 2
      elide: Text.ElideRight
    }

    // Тіло сповіщення
    Text {
      text: root.toastBody
      color: root.palette ? root.palette.gray : "#888888"
      font.family: root.palette ? root.palette.font : "sans-serif"; font.pixelSize: root.appConfig ? root.appConfig.scaled(12) : 12
      wrapMode: Text.WordWrap
      Layout.fillWidth: true
      maximumLineCount: 3
      elide: Text.ElideRight
      visible: root.toastBody !== ""
    }

    // Кнопки дій сповіщення (без "default" — він на клік по тосту)
    Row {
      Layout.fillWidth: true
      Layout.topMargin: 2
      spacing: 4
      visible: root.hasActions

      Repeater {
        model: root.toastNotification ? root.toastNotification.actions : []

        delegate: Rectangle {
          required property var modelData
          visible: modelData.identifier !== "default"

          implicitWidth: actionText.implicitWidth + 12
          height: 20
          radius: 4
          color: actionArea.containsMouse ? (root.palette ? root.palette.bgAlpha : "#3a3733") : (root.palette ? root.palette.bg2 : "#4a4640")
          Behavior on color { ColorAnimation { duration: root.appConfig ? root.appConfig.anim(120) : 120 } }

          Text {
            id: actionText
            anchors.centerIn: parent
            text: modelData.text
            color: root.palette ? root.palette.light : "#ede0d4"
            font.family: root.palette ? root.palette.font : "sans-serif"; font.pixelSize: root.appConfig ? root.appConfig.scaled(9) : 9
          }

          MouseArea {
            id: actionArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: autoCloseTimer.stop()
            onExited: autoCloseTimer.restart()
            onClicked: {
              modelData.invoke()
              root.dismiss()
            }
          }
        }
      }
    }
  }
  } // container
}
