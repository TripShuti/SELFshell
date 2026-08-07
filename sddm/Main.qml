// ============================================================
// sddm/Main.qml — екран входу SELFshell.
// Повністю кастомна тема: власні поля/кнопки (LoginField.qml,
// ActionButton.qml) замість вбудованих SddmComponents — стиль
// повністю під контролем. Кольори — з палітри (colors.js),
// фон — current.jpg (оновлюється update-palette.sh).
// Контекст гретера: sddm, userModel, sessionModel.
// ============================================================
import QtQuick 2.15
import "colors.js" as Palette

Rectangle {
  id: root
  width: Screen.width
  height: Screen.height
  color: "black"

  property bool loginFailed: false

  // Шпалера; якщо файла нема — чорний фон
  Image {
    id: wallpaper
    anchors.fill: parent
    source: "current.jpg"
    fillMode: Image.PreserveAspectCrop
    visible: wallpaper.status === Image.Ready
  }

  // Затемнення для читабельності
  Rectangle {
    anchors.fill: parent
    color: "black"
    opacity: 0.35
  }

  // Оновлення годинника щосекунди
  Timer {
    interval: 1000
    repeat: true
    running: true
    onTriggered: timeLabel.text = Qt.formatTime(new Date(), "HH:mm")
  }

  Column {
    id: card
    anchors.centerIn: parent
    width: 340
    spacing: 12
    opacity: 0
    Behavior on opacity { NumberAnimation { duration: 500 } }

    // Великий годинник у стилі лок-скрину
    Text {
      id: timeLabel
      anchors.horizontalCenter: parent.horizontalCenter
      text: Qt.formatTime(new Date(), "HH:mm")
      color: Palette.Colors["textLight"]
      font.family: Palette.Colors["font"]
      font.pixelSize: 84
      font.bold: true
      font.letterSpacing: 2
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: Qt.formatDate(new Date(), "dddd, MMMM d")
      color: Palette.Colors["muted"]
      font.family: Palette.Colors["font"]
      font.pixelSize: 14
      font.letterSpacing: 3
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: "SELFshell"
      color: Palette.Colors["mutedAlt"]
      font.family: Palette.Colors["font"]
      font.pixelSize: 12
      font.letterSpacing: 8
      topPadding: 24
    }

    Item {
      width: 1
      height: 22
    }

    // Лейбли + поля входу
    Text {
      text: "USERNAME"
      color: Palette.Colors["gray"]
      font.family: Palette.Colors["font"]
      font.pixelSize: 10
      font.letterSpacing: 2
      leftPadding: 2
    }

    LoginField {
      id: usernameField
      width: parent.width
      text: userModel.lastUser
      onSubmitted: passwordField.forceActiveFocus()
    }

    Text {
      text: "PASSWORD"
      color: Palette.Colors["gray"]
      font.family: Palette.Colors["font"]
      font.pixelSize: 10
      font.letterSpacing: 2
      leftPadding: 2
      topPadding: 4
    }

    LoginField {
      id: passwordField
      width: parent.width
      echoMode: TextInput.Password
      focus: true
      onSubmitted: doLogin()
    }

    // Повідомлення про помилку — фіксована висота, щоб не зсувати картку
    Text {
      id: errorText
      width: parent.width
      height: 18
      horizontalAlignment: Text.AlignHCenter
      visible: root.loginFailed
      text: "Wrong password. Try again."
      color: Palette.Colors["danger"]
      font.family: Palette.Colors["font"]
      font.pixelSize: 13
    }

    ActionButton {
      id: loginButton
      width: parent.width
      text: "Log In"
      background: Palette.Colors["accent"]
      foreground: Palette.Colors["bg0H"]
      fontSize: 15
      bold: true
      onClicked: doLogin()
    }
  }

  // Хостнейм — дрібний підпис знизу зліва
  Text {
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    anchors.margins: 28
    text: sddm.hostName
    color: Palette.Colors["gray"]
    font.family: Palette.Colors["font"]
    font.pixelSize: 11
    font.letterSpacing: 1
    visible: sddm.hostName !== ""
  }

  // Живлення — справа знизу
  Row {
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.margins: 28
    spacing: 10

    ActionButton {
      text: "Reboot"
      visible: sddm.canReboot
      background: Palette.Colors["baseOverlay"]
      foreground: Palette.Colors["fg"]
      width: 96
      height: 34
      fontSize: 12
      onClicked: sddm.reboot()
    }

    ActionButton {
      text: "Shutdown"
      visible: sddm.canPowerOff
      background: Palette.Colors["baseOverlay"]
      foreground: Palette.Colors["fg"]
      width: 104
      height: 34
      fontSize: 12
      onClicked: sddm.powerOff()
    }
  }

  Connections {
    target: sddm
    function onLoginFailed() {
      root.loginFailed = true
      passwordField.text = ""
      passwordField.forceActiveFocus()
    }
  }

  function doLogin() {
    root.loginFailed = false
    sddm.login(usernameField.text, passwordField.text, sessionModel.lastIndex)
  }

  Component.onCompleted: card.opacity = 1
}
