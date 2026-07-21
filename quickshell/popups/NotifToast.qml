// ============================================================
// NotifToast.qml — спливаюче сповіщення (тост)
// ============================================================
import Quickshell
import "../Palette.js" as Palette
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


  color: "transparent"
  implicitWidth: 280
  implicitHeight: container.implicitHeight
  grabFocus: false


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
  }

  // Анімація закриття
  function dismiss() {
    if (exitAnim.running) return
    exitAnim.start()
  }

  // Анімація появи — прозорість + масштаб + зсув
  ParallelAnimation {
    id: enterAnim
    NumberAnimation { target: container; property: "opacity"; from: 0; to: 1; duration: 220; easing.type: Easing.OutCubic }
    NumberAnimation { target: container; property: "scale"; from: 0.85; to: 1.0; duration: 350; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
    NumberAnimation { target: container; property: "x"; from: 32; to: 0; duration: 350; easing.type: Easing.OutCubic }
  }

  // Анімація зникнення
  SequentialAnimation {
    id: exitAnim
    ParallelAnimation {
      NumberAnimation { target: container; property: "opacity"; to: 0; duration: 120; easing.type: Easing.OutCubic }
      NumberAnimation { target: container; property: "scale"; to: 0.85; duration: 120; easing.type: Easing.InCubic }
    }
    ScriptAction { script: root.visible = false }
  }

  // Автоматичне закриття через 4 секунди
  Timer {
    id: autoCloseTimer
    interval: 4000
    onTriggered: root.dismiss()
  }

  // Зовнішнє сяйво навколо тоста
  Rectangle {
    anchors.fill: container
    anchors.margins: -3
    radius: container.radius + 3
    color: "transparent"
    border.width: 1
    border.color: Palette.green
    opacity: container.opacity * 0.2
    scale: container.scale
  }

  // Контейнер сповіщення
  Rectangle {
    id: container
    width: parent.width
    implicitHeight: toastLayout.implicitHeight + 16
    radius: 6
    border.width: 1
    border.color: Palette.green
    opacity: 0
    scale: 0.85
    clip: true
    color: Palette.bg0H

    // Підсвітка верхнього краю
    Rectangle {
      anchors { top: parent.top; left: parent.left; right: parent.right }
      height: 1
      color: Palette.hoverOverlay
    }

ColumnLayout {
  id: toastLayout
  x: 10; y: 8
  width: parent.width - 20
  spacing: 3

  // Назва додатка
  Text {
    text: root.toastAppName
    color: Palette.green
    font.family: Palette.font; font.pixelSize: 16; font.bold: true
    visible: root.toastAppName !== ""
  }

  // Заголовок сповіщення
  Text {
    text: root.toastSummary
    color: Palette.fg
    font.family: Palette.font; font.pixelSize: 13; font.bold: true
    wrapMode: Text.WordWrap
    Layout.fillWidth: true
    maximumLineCount: 2
    elide: Text.ElideRight
  }

  // Тіло сповіщення
  Text {
    text: root.toastBody
    color: Palette.gray
    font.family: Palette.font; font.pixelSize: 12
    wrapMode: Text.WordWrap
    Layout.fillWidth: true
    maximumLineCount: 3
    elide: Text.ElideRight
    visible: root.toastBody !== ""
  }
}

// Клік по сповіщенню — виконує дію або закриває
MouseArea {
  anchors.fill: parent
  hoverEnabled: true
  onEntered: { if (autoCloseTimer.running) autoCloseTimer.stop() }
  onExited: autoCloseTimer.restart()
  onClicked: {
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
