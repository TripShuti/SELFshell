// ============================================================
// NotifToast.qml — спливаюче сповіщення (тост)
// ============================================================
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
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
  property var toastNotification: null
  property QtObject anchorWindow: null
  property bool muted: false
  readonly property QtObject palette: anchorWindow ? anchorWindow.palette : null
  readonly property QtObject appConfig: anchorWindow ? anchorWindow.appConfig : null

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

  // Зовнішнє сяйво навколо тоста. Вписано ВСЕРЕДИНІ поверхні
  // (margins: 1, а не -3): Wayland-поверхня має розмір рівно контейнера,
  // і будь-який виступ за межі обрізається під прямим кутом (той самий
  // баг, що був у AnimatedPopup).
  Rectangle {
    anchors.fill: container
    anchors.margins: 1
    radius: container.radius - 1
    color: "transparent"
    border.width: 1
    border.color: anchorWindow.palette.green
    opacity: container.opacity * (appConfig ? appConfig.cfg.toastGlowOpacity : 0.2)
    scale: container.scale
  }

  // Контейнер сповіщення
  Rectangle {
    id: container
    width: parent.width
    implicitHeight: toastLayout.implicitHeight + 16
    radius: appConfig ? appConfig.cfg.toastRadius : 6
    border.width: 1
    border.color: anchorWindow.palette.green
    opacity: 0
    scale: 0.85
    clip: true
    gradient: Gradient {
      orientation: Gradient.Vertical
      GradientStop { position: 0.0; color: Qt.lighter(anchorWindow.palette.bg0H, appConfig ? appConfig.cfg.toastLighten : 1.16) }
      GradientStop { position: 1.0; color: anchorWindow.palette.bg0H }
    }

    // Підсвітка верхнього краю
    Rectangle {
      anchors { top: parent.top; left: parent.left; right: parent.right }
      height: 1
      color: anchorWindow.palette.hoverOverlay
    }

  ColumnLayout {
    id: toastLayout
    // z вище за загальний MouseArea (клік по тосту = default дія) —
    // інакше той перехоплює кліки по кнопках дій і запускає default
    z: 1
    x: 10; y: 8
    width: parent.width - 20
    spacing: 3

    // Назва додатка з іконкою
    RowLayout {
      spacing: 6
      visible: root.toastAppName !== ""
      height: 20

      IconImage {
        Layout.preferredWidth: 16
        Layout.preferredHeight: 16
        source: Quickshell.iconPath(root.toastAppIcon, true)
      }

      Text {
        text: root.toastAppName
        color: anchorWindow.palette.green
        font.family: anchorWindow.palette.font; font.pixelSize: appConfig.scaled(13); font.bold: true
      }
    }

    // Заголовок сповіщення
    Text {
      text: root.toastSummary
      color: anchorWindow.palette.fg
      font.family: anchorWindow.palette.font; font.pixelSize: appConfig.scaled(13); font.bold: true
      wrapMode: Text.WordWrap
      Layout.fillWidth: true
      maximumLineCount: 2
      elide: Text.ElideRight
    }

    // Тіло сповіщення
    Text {
      text: root.toastBody
      color: anchorWindow.palette.gray
      font.family: anchorWindow.palette.font; font.pixelSize: appConfig.scaled(12)
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
          color: actionArea.containsMouse ? anchorWindow.palette.bgAlpha : anchorWindow.palette.bg2
          Behavior on color { ColorAnimation { duration: appConfig ? appConfig.anim(120) : 120 } }

          Text {
            id: actionText
            anchors.centerIn: parent
            text: modelData.text
            color: anchorWindow.palette.light
            font.family: anchorWindow.palette.font; font.pixelSize: appConfig.scaled(9)
          }

          MouseArea {
            id: actionArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              modelData.invoke()
              root.dismiss()
            }
          }
        }
      }
    }
  }

  // Лівий клік — переходить до дії/програми, що викликала сповіщення.
  // Правий клік — просто закриває тост, без виклику дії.
  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onEntered: { if (autoCloseTimer.running) autoCloseTimer.stop() }
    onExited: autoCloseTimer.restart()
    onClicked: (mouse) => {
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
  }
}
