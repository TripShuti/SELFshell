// ============================================================
// settings/AboutSection.qml — розділ About: версія шела, версії
// компонентів, перевірка оновлень, дані про машину, посилання на проєкт
// ============================================================
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../core"

Item {
  id: root
  required property QtObject sys

  readonly property var cfg: sys.cfg
  readonly property var ac: sys.ac
  readonly property var window: sys.window

  implicitWidth: parent?.width ?? 0
  implicitHeight: col.implicitHeight

  // Статичні файли (VERSION, os-release) читаються FileView; версії
  // програм — одноразовими Process-запитами (патерн ControlPopup з ddcutil).
  // Непідключені інструменти дають порожній рядок і показують "—".
  ColumnLayout {
    id: col
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    spacing: 12

    SetCard {
      sys: root.sys
      SetLabel { sys: root.sys; text: "SELFshell" }

      VersionRow { label: "Version"; value: root.shellVersion }
      VersionRow {
        label: "Updates"
        value: root.updateAvailable
               ? "v" + root.remoteVersion + " available (selfshell update)"
               : (root.upToDate ? "up to date" : "")
        valueColor: root.updateAvailable ? root.window.palette.danger : root.window.palette.mutedAlt
      }

      // Посилання на проєкт — клікабельне, без явного URL у тексті,
      // щоб рядок не розтягувався
      RowLayout {
        Layout.fillWidth: true
        spacing: 4

        Text {
          text: "Project"
          color: root.window.palette.fg
          font.family: root.window.palette.font
          font.pixelSize: window.appConfig.scaled(10)
          Layout.fillWidth: true
        }

        Text {
          id: projectLink
          text: "github.com/TripShuti/SELFshell"
          color: linkMouse.containsMouse ? Qt.lighter(root.window.palette.accent, 1.25) : root.window.palette.accent
          font.family: root.window.palette.font
          font.pixelSize: window.appConfig.scaled(10)
          font.underline: linkMouse.containsMouse
          elide: Text.ElideRight
          Layout.alignment: Qt.AlignRight
          Behavior on color { ColorAnimation { duration: root.ac.anim(120) } }

          MouseArea {
            id: linkMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Qt.openUrlExternally("https://github.com/TripShuti/SELFshell")
          }
        }
      }

      VersionRow { label: "Hyprland"; value: hyprProbe.value }
      VersionRow { label: "Quickshell"; value: qsProbe.value }
      VersionRow { label: "Kitty"; value: kittyProbe.value }
      VersionRow { label: "Yazi"; value: yaziProbe.value }
    }

    SetCard {
      sys: root.sys
      SetLabel { sys: root.sys; text: "System" }

      VersionRow { label: "OS"; value: root.osName }
      VersionRow { label: "Kernel"; value: kernelProbe.value }
    }
  }

  // --- Версія шела: VERSION у корені quickshell/ (файл статичний,
  // watchChanges не потрібен) ---
  FileView {
    id: versionFile
    path: Qt.resolvedUrl("../../VERSION")
    onDataChanged: root.shellVersion = versionFile.text().trim()
    onLoaded: root.shellVersion = versionFile.text().trim()
  }
  property string shellVersion: ""

  // --- Актуальність: порівнюємо встановлену версію з main (raw GitHub).
  // curl — вже залежність (selfshell update); офлайн/без curl → порожньо
  // і рядок Updates просто не показує статус ---
  readonly property string remoteVersion: remoteProbe.value
  readonly property bool upToDate: root.shellVersion !== "" && root.remoteVersion !== "" && root.shellVersion === root.remoteVersion
  readonly property bool updateAvailable: root.shellVersion !== "" && root.remoteVersion !== "" && root.isNewer(root.remoteVersion, root.shellVersion)

  function isNewer(a, b) {
    var pa = a.split(".").map(Number)
    var pb = b.split(".").map(Number)
    for (var i = 0; i < 3; i++) {
      var x = pa[i] || 0
      var y = pb[i] || 0
      if (x !== y) return x > y
    }
    return false
  }

  // --- Ім'я ОС: один рядок PRETTY_NAME з /etc/os-release ---
  FileView {
    id: osReleaseFile
    path: Qt.resolvedUrl("/etc/os-release")
    onDataChanged: root.parseOsRelease()
    onLoaded: root.parseOsRelease()
  }
  property string osName: ""

  function parseOsRelease() {
    var m = osReleaseFile.text().match(/^PRETTY_NAME="?([^"\n]+)"?/m)
    if (m) root.osName = m[1].trim()
  }

  // --- Одноразові запити версій: проба стартує на створенні секції,
  // результат підхоплюється StdioCollector за повним рядком виводу ---
  component VersionProbe: Item {
    id: probe
    required property var command
    required property var pattern
    readonly property string value: probe._value
    property string _value: ""

    StdioCollector {
      id: collector
      waitForEnd: true
      onDataChanged: {
        var m = collector.text.match(probe.pattern)
        if (m) probe._value = m[1].trim()
      }
    }

    Process {
      command: probe.command
      stdout: collector
      // Процеси не стартують самі по собі — тільки явний running: true
      // (патерн ControlPopup з ddcutil)
      running: true
    }
  }

  VersionProbe { id: hyprProbe; command: ["hyprctl", "version"]; pattern: /Hyprland (\S+)/ }
  VersionProbe { id: qsProbe; command: ["qs", "--version"]; pattern: /Quickshell (\S+)/ }
  VersionProbe { id: kittyProbe; command: ["kitty", "--version"]; pattern: /kitty (\S+)/ }
  VersionProbe { id: yaziProbe; command: ["yazi", "--version"]; pattern: /yazi (\S+)/i }
  VersionProbe { id: kernelProbe; command: ["uname", "-r"]; pattern: /(.+)/ }
  VersionProbe { id: remoteProbe; command: ["curl", "-fsSL", "https://raw.githubusercontent.com/TripShuti/SELFshell/main/quickshell/VERSION"]; pattern: /(\d+\.\d+\.\d+)/ }

  // Рядок "назва — значення" для списку версій; порожнє значення
  // означає непідключений компонент і показується як "—"
  component VersionRow: RowLayout {
    id: row
    required property string label
    required property string value
    property color valueColor: root.window.palette.mutedAlt
    spacing: 4
    Layout.fillWidth: true

    Text {
      text: row.label
      color: root.window.palette.fg
      font.family: root.window.palette.font
      font.pixelSize: window.appConfig.scaled(10)
      Layout.fillWidth: true
    }

    Text {
      text: row.value || "\u2014"
      color: row.valueColor
      font.family: root.window.palette.font
      font.pixelSize: window.appConfig.scaled(10)
      elide: Text.ElideRight
      Layout.alignment: Qt.AlignRight
    }
  }
}