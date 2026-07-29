import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

Scope {
  id: root

  property bool locked: false
  property string currentText: ""
  property bool unlockInProgress: false
  property bool showFailure: false
  property int failCount: 0
  property string userName: ""

  signal unlocked()
  signal failed()

  onCurrentTextChanged: showFailure = false

  onLockedChanged: {
    if (locked) {
      currentText = ""
      unlockInProgress = false
      showFailure = false
    }
  }

  function tryUnlock() {
    if (currentText === "") return
    unlockInProgress = true
    pam.start()
  }

  StdioCollector {
    id: userCollector
    waitForEnd: true
    onDataChanged: {
      if (text) root.userName = text.trim()
    }
  }

  Process {
    id: userProc
    command: ["whoami"]
    stdout: userCollector
    running: true
    onExited: running = false
  }

  PamContext {
    id: pam
    configDirectory: "pam"
    config: "password.conf"

    onPamMessage: {
      if (responseRequired) respond(root.currentText)
    }

    onCompleted: result => {
      if (result == PamResult.Success) {
        failCount = 0
        root.currentText = ""
        root.unlocked()
      } else {
        root.currentText = ""
        root.showFailure = true
        root.failCount++
        root.failed()
      }
      root.unlockInProgress = false
    }
  }
}
