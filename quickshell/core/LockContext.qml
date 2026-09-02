// ============================================================
// quickshell/core/LockContext.qml — PAM авторизація та стан блокування
// ============================================================
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

  // Лок-аут після failThreshold невдалих спроб (анти-брутфорс):
  // tryUnlock() не стартує PAM, поки lockoutRemaining > 0.
  property int failThreshold: 3
  property int lockoutSeconds: 30
  property int lockoutRemaining: 0

  signal unlocked()
  signal failed()

  Timer {
    interval: 1000
    repeat: true
    running: root.lockoutRemaining > 0
    onTriggered: root.lockoutRemaining = Math.max(0, root.lockoutRemaining - 1)
  }

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
    if (lockoutRemaining > 0) return
    if (unlockInProgress) return
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
    configDirectory: Qt.resolvedUrl("../pam").toString().replace("file://", "")
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
        if (root.failCount >= root.failThreshold)
          root.lockoutRemaining = root.lockoutSeconds
        root.failed()
      }
      root.unlockInProgress = false
    }
  }
}
