// ============================================================
// sddm/Main.qml — екран входу SELFshell (повна тема SDDM)
// Кольори — з палітри (colors.js, генерується update-palette.py),
// фон — current.jpg (оновлюється update-palette.sh)
// API перевірено за src/greeter + components/2.0 репозиторію SDDM
// ============================================================
import QtQuick 2.15
import SddmComponents 2.0
import "colors.js" as Palette

Rectangle {
  id: root
  width: Screen.width
  height: Screen.height
  color: "black"

  property bool loginFailed: false

  // Шпалера з папки теми; якщо файла нема — лишається чорний фон
  Image {
    id: wallpaper
    anchors.fill: parent
    source: "current.jpg"
    fillMode: Image.PreserveAspectCrop
    visible: wallpaper.status === Image.Ready
  }

  // Легке затемнення для читабельності полів
  Rectangle {
    anchors.fill: parent
    color: "black"
    opacity: 0.35
  }

  Column {
    anchors.centerIn: parent
    width: 360
    spacing: 10

    // Годинник у стилі лок-скрину
    Clock {
      anchors.horizontalCenter: parent.horizontalCenter
      color: Palette.Colors["textLight"]
      timeFont.pixelSize: 60
      timeFont.bold: true
      timeFont.family: Palette.Colors["font"]
      dateFont.pixelSize: 14
      dateFont.family: Palette.Colors["font"]
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: "SELFshell"
      color: Palette.Colors["muted"]
      font.pixelSize: 13
      font.family: Palette.Colors["font"]
    }

    Item {
      width: 1
      height: 16
    }

    // Ім'я користувача — префілл останнім залогіненим
    TextBox {
      id: usernameEntry
      width: parent.width
      height: 42
      text: userModel.lastUser
      font.pixelSize: 15
      font.family: Palette.Colors["font"]
      color: Palette.Colors["bgAlpha"]
      textColor: Palette.Colors["fg"]
      borderColor: "transparent"
      focusColor: Palette.Colors["accent"]
      hoverColor: Palette.Colors["accent"]
      radius: 6
      Keys.onPressed: {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          passwordEntry.forceActiveFocus()
          event.accepted = true
        }
      }
    }

    PasswordBox {
      id: passwordEntry
      width: parent.width
      height: 42
      focus: true
      font.pixelSize: 15
      font.family: Palette.Colors["font"]
      color: Palette.Colors["bgAlpha"]
      textColor: Palette.Colors["fg"]
      borderColor: "transparent"
      focusColor: Palette.Colors["accent"]
      hoverColor: Palette.Colors["accent"]
      radius: 6
      Keys.onPressed: {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          doLogin()
          event.accepted = true
        }
      }
    }

    // Повідомлення про невірний пароль (висота зарезервована)
    Text {
      id: errorText
      width: parent.width
      height: 18
      horizontalAlignment: Text.AlignHCenter
      visible: root.loginFailed
      text: "Wrong password. Try again."
      color: Palette.Colors["danger"]
      font.pixelSize: 13
      font.family: Palette.Colors["font"]
    }

    Button {
      id: loginButton
      width: parent.width
      height: 42
      text: "Log In"
      font.pixelSize: 15
      font.family: Palette.Colors["font"]
      font.bold: true
      color: Palette.Colors["accent"]
      textColor: Palette.Colors["bg0H"]
      onClicked: doLogin()
    }
  }

  // Живлення (перезавантаження/вимкнення)
  Row {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 26
    spacing: 10

    Button {
      text: "Reboot"
      visible: sddm.canReboot
      font.pixelSize: 13
      font.family: Palette.Colors["font"]
      color: Palette.Colors["bgAlpha"]
      textColor: Palette.Colors["fg"]
      onClicked: sddm.reboot()
    }

    Button {
      text: "Shutdown"
      visible: sddm.canPowerOff
      font.pixelSize: 13
      font.family: Palette.Colors["font"]
      color: Palette.Colors["bgAlpha"]
      textColor: Palette.Colors["fg"]
      onClicked: sddm.powerOff()
    }
  }

  Connections {
    target: sddm
    function onLoginSucceeded() {
      // сесія стартує, greeter закриється сам
    }
    function onLoginFailed() {
      root.loginFailed = true
      passwordEntry.text = ""
      passwordEntry.forceActiveFocus()
    }
  }

  function doLogin() {
    root.loginFailed = false
    sddm.login(usernameEntry.text, passwordEntry.text, sessionModel.lastIndex)
  }
}
