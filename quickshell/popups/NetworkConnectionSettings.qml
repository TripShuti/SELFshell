// ============================================================
// NetworkConnectionSettings.qml — налаштування IPv4, DNS,
// безпеки Wi-Fi через nmcli
// ============================================================
import Quickshell
import Quickshell.Io
import "../"
import "../Palette.js" as Palette
import QtQuick
import QtQuick.Layouts

// Налаштування мережевого з'єднання — IPv4, DNS, безпека Wi-Fi
// Працює через nmcli (con mod + con up)
AnimatedPopup {
  id: root

  required property QtObject window

  // Мережа: Wi-Fi об'єкт з .name, .known, .connected, .security
  // або Ethernet: { name: <iface>, connected: bool }
  property var network: null

  // "wifi" або "ethernet"
  property string connKind: "wifi"
  // Ім'я інтерфейсу (wlan0, enp6s0 тощо)
  property string deviceName: ""

  implicitWidth: 420
  implicitHeight: 360
  enterScale: 0.75
  slideDistance: 6
  transformOrigin: Item.Center

  // Внутрішній стан
  property string connectionName: ""
  property bool resolved: false
  property string statusMessage: ""
  property bool statusIsError: false
  // true, коли резолвимо профіль за SSID (а не за активним пристроєм) —
  // потрібно, щоб правильно розпарсити вивід resolveConnProcess
  property bool resolvingBySsid: false
  // Кількість профілів NetworkManager, знайдених з однаковим SSID (дублікати)
  property int duplicateProfileCount: 0

  property int activeTab: 0

  // IPv4
  property bool ipv4Manual: false
  property string ipv4Address: ""
  property string ipv4Prefix: "24"
  property string ipv4Gateway: ""

  // DNS
  property bool dnsManual: false
  property string dnsServers: ""

  // Security (тільки wifi)
  property string keyMgmt: ""
  property bool changingPassword: false
  property string newPassword: ""

  // Автопідключення для цього конкретного профілю (не для всього пристрою)
  property bool autoconnect: true
  property bool autoconnectPending: false

  readonly property var tabNames: connKind === "ethernet" ? ["IPv4", "DNS"] : ["IPv4", "DNS", "Security"]

  // Екранування для shell
  function escapeShell(str) {
    return "'" + String(str).replace(/'/g, "'\\''") + "'";
  }

  // Витягує значення після першого ":"
  function extractResolvedName(text) {
    var t = String(text).trim();
    var idx = t.indexOf(":");
    if (idx >= 0) return t.substring(idx + 1).trim();
    return t;
  }

  // Скидає стан при відкритті
  function resetState() {
    connectionName = "";
    resolved = false;
    statusMessage = "";
    statusIsError = false;
    changingPassword = false;
    newPassword = "";
    activeTab = 0;
    autoconnectPending = false;
    resolvingBySsid = false;
    duplicateProfileCount = 0;
  }

  onVisibleChanged: {
    if (visible) {
      anchor.edges = PopupAnchor.None
      anchor.gravity = PopupAnchor.None
      anchor.rect = Qt.rect(
        (window.screen.width - implicitWidth) / 2,
        (window.screen.height - implicitHeight) / 2,
        implicitWidth,
        implicitHeight
      )
      resetState();
      startResolve();
    }
  }

  // Крок 1: знайти ім'я профілю NetworkManager
  function startResolve() {
    if (!network) return;

    // Активне з'єднання — беремо профіль з пристрою
    if (connKind === "ethernet" || network.connected) {
      if (!deviceName) {
        statusMessage = "Невідомий мережевий інтерфейс";
        statusIsError = true;
        resolved = true;
        return;
      }
      resolvingBySsid = false;
      resolveConnProcess.command = ["nmcli", "-t", "-f", "GENERAL.CONNECTION", "dev", "show", deviceName];
      resolveConnProcess.running = true;
      return;
    }

    // Збережена, але зараз не підключена Wi-Fi мережа — шукаємо профіль(і) за SSID.
    // Якщо колись підключався до цієї мережі кількома шляхами (nmcli/GUI/повторний
    // конект після "forget"), NetworkManager міг створити ДЕКІЛЬКА профілів з тим
    // самим SSID ("MyWifi", "MyWifi 1", ...). Беремо не перший-ліпший, а той,
    // яким реально користувались останнім (за connection.timestamp).
    if (network.name) {
      resolvingBySsid = true;
      resolveConnProcess.command = ["bash", "-c",
        "SSID=" + escapeShell(network.name) + "; " +
        "nmcli -t -f NAME,TYPE con show | awk -F: '$2==\"802-11-wireless\"{print $1}' | " +
        "while IFS= read -r c; do " +
        "s=$(nmcli -t -f 802-11-wireless.ssid con show \"$c\" 2>/dev/null); s=${s#*:}; " +
        "if [ \"$s\" = \"$SSID\" ]; then " +
        "ts=$(nmcli -t -f connection.timestamp con show \"$c\" 2>/dev/null); ts=${ts#*:}; " +
        "echo \"${ts:-0}|$c\"; " +
        "fi; " +
        "done | sort -t'|' -k1,1nr"
      ];
      resolveConnProcess.running = true;
    }
  }

  Component.onCompleted: anchor.window = window

  // --- Процеси nmcli ---

  // Крок 1 (продовження): отримуємо ім'я з'єднання
  Process {
    id: resolveConnProcess
    stdout: StdioCollector {
      onStreamFinished: {
        var name = "";
        root.duplicateProfileCount = 0;

        if (root.resolvingBySsid) {
          // Формат: "timestamp|connName" по одному на рядок, найновіший — перший
          // (список вже відсортований у самому bash-скрипті через sort -k1,1nr)
          var lines = text.split("\n").filter(l => l.trim().length > 0);
          root.duplicateProfileCount = lines.length;
          if (lines.length > 0) {
            var idx = lines[0].indexOf("|");
            name = idx >= 0 ? lines[0].substring(idx + 1).trim() : lines[0].trim();
          }
        } else {
          name = root.extractResolvedName(text);
        }

        if (name.length > 0 && name !== "--") {
          root.connectionName = name;
          fetchSettingsProcess.command = ["nmcli", "-t", "-f",
            "ipv4.method,ipv4.addresses,ipv4.gateway,ipv4.dns,ipv4.ignore-auto-dns,802-11-wireless-security.key-mgmt,connection.autoconnect",
            "con", "show", name];
          fetchSettingsProcess.running = true;
        } else {
          root.statusMessage = "Не вдалося знайти профіль з'єднання NetworkManager для цієї мережі";
          root.statusIsError = true;
          root.resolved = true;
        }
      }
    }
  }

  // Крок 2: витягнути поточні налаштування
  Process {
    id: fetchSettingsProcess
    stdout: StdioCollector {
      onStreamFinished: {
        var lines = text.split("\n");
        for (var i = 0; i < lines.length; i++) {
          var line = lines[i];
          if (!line) continue;
          var idx = line.indexOf(":");
          if (idx < 0) continue;
          var key = line.substring(0, idx);
          var val = line.substring(idx + 1);

          if (key === "ipv4.method") {
            root.ipv4Manual = (val === "manual");
          } else if (key === "ipv4.addresses" && val.length > 0) {
            var parts = val.split("/");
            root.ipv4Address = parts[0] || "";
            root.ipv4Prefix = parts[1] || "24";
          } else if (key === "ipv4.gateway") {
            root.ipv4Gateway = val;
          } else if (key === "ipv4.dns") {
            root.dnsServers = val;
          } else if (key === "ipv4.ignore-auto-dns") {
            root.dnsManual = (val === "yes");
          } else if (key === "802-11-wireless-security.key-mgmt") {
            root.keyMgmt = val || "none (Open)";
          } else if (key === "connection.autoconnect") {
            root.autoconnect = (val !== "no");
          }
        }
        root.resolved = true;
      }
    }
  }

  // Крок 3: застосувати IPv4 + DNS через nmcli con mod
  Process {
    id: applyProcess
    onExited: (exitCode, exitStatus) => {
      if (exitCode === 0) {
        reactivateProcess.command = ["nmcli", "con", "up", root.connectionName];
        reactivateProcess.running = true;
      } else {
        root.statusMessage = "Помилка nmcli con mod (код " + exitCode + ")";
        root.statusIsError = true;
      }
    }
  }

  // Крок 4: перезастосувати з'єднання
  Process {
    id: reactivateProcess
    onExited: (exitCode, exitStatus) => {
      if (exitCode === 0) {
        root.statusMessage = "Застосовано";
        root.statusIsError = false;
      } else {
        root.statusMessage = "Налаштування збережено, але reconnect не вдався (код " + exitCode + ")";
        root.statusIsError = true;
      }
    }
  }

  // Зміна пароля Wi-Fi
  Process {
    id: passwordProcess
    onExited: (exitCode, exitStatus) => {
      if (exitCode === 0) {
        reactivateProcess.command = ["nmcli", "con", "up", root.connectionName];
        reactivateProcess.running = true;
        root.changingPassword = false;
        root.newPassword = "";
      } else {
        root.statusMessage = "Не вдалося змінити пароль (код " + exitCode + ")";
        root.statusIsError = true;
      }
    }
  }

  // Автопідключення — вмикається/вимикається миттєво, без кнопки Apply
  Process {
    id: autoconnectProcess
    onExited: (exitCode, exitStatus) => {
      root.autoconnectPending = false;
      if (exitCode === 0) {
        root.statusMessage = root.autoconnect ? "Автопідключення увімкнено" : "Автопідключення вимкнено";
        root.statusIsError = false;
      } else {
        // Відкат UI, якщо nmcli не спрацював
        root.autoconnect = !root.autoconnect;
        root.statusMessage = "Не вдалося змінити автопідключення (код " + exitCode + ")";
        root.statusIsError = true;
      }
    }
  }

  // Перемикає автопідключення для цього конкретного профілю з'єднання
  function toggleAutoconnect() {
    if (autoconnectPending || connectionName.length === 0) return;
    autoconnect = !autoconnect;
    autoconnectPending = true;
    statusMessage = "Застосовую...";
    statusIsError = false;
    autoconnectProcess.command = ["nmcli", "con", "mod", connectionName, "connection.autoconnect", autoconnect ? "yes" : "no"];
    autoconnectProcess.running = true;
  }

  // Формує команду nmcli для застосування IPv4 та DNS
  function applyIpv4AndDns() {
    var args = ["con", "mod", connectionName];

    if (ipv4Manual) {
      args.push("ipv4.method", "manual");
      args.push("ipv4.addresses", ipv4Address + "/" + ipv4Prefix);
      args.push("ipv4.gateway", ipv4Gateway);
    } else {
      args.push("ipv4.method", "auto");
      args.push("ipv4.gateway", "");
    }

    if (dnsManual) {
      args.push("ipv4.dns", dnsServers);
      args.push("ipv4.ignore-auto-dns", "yes");
    } else {
      args.push("ipv4.dns", "");
      args.push("ipv4.ignore-auto-dns", "no");
    }

    statusMessage = "Застосовую...";
    statusIsError = false;
    applyProcess.command = ["nmcli"].concat(args);
    applyProcess.running = true;
  }

  // Застосовує новий пароль Wi-Fi
  function applyPassword() {
    if (newPassword.length < 8) {
      statusMessage = "Пароль має бути не менше 8 символів";
      statusIsError = true;
      return;
    }
    statusMessage = "Змінюю пароль...";
    statusIsError = false;
    passwordProcess.command = ["nmcli", "con", "mod", connectionName, "wifi-sec.psk", newPassword];
    passwordProcess.running = true;
  }

  // --- Інтерфейс ---
  Rectangle {
    anchors.fill: parent
    radius: 12
    color: Palette.bg0H
    opacity: 0.88
  }

  ColumnLayout {
    x: 12
    y: 12
    width: parent.width - 24
    height: parent.height - 24
    spacing: 10

    // Заголовок
    RowLayout {
      Layout.fillWidth: true
      Text {
        text: "Налаштування: " + (root.network ? root.network.name : "")
        color: Palette.accent
        font.family: Palette.font; font.pixelSize: 16; font.bold: true
        Layout.fillWidth: true
        elide: Text.ElideRight
      }
      Rectangle {
        width: 24; height: 24; radius: 4
        color: Palette.bgLayer
        Text { anchors.centerIn: parent; text: "\u2716"; color: Palette.mutedAlt; font.family: Palette.font; font.pixelSize: 11 }
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.visible = false
        }
      }
    }

    // Стан завантаження
    Text {
      visible: !root.resolved
      text: "Шукаю профіль з'єднання..."
      color: Palette.mutedAlt
      font.family: Palette.font; font.pixelSize: 12
    }

    // Попередження: знайдено кілька профілів NetworkManager з однаковим SSID.
    // Це трапляється після повторних "forget"+reconnect чи підключення через
    // різні застосунки — беремо найновіший за connection.timestamp, але варто
    // прибрати зайві профілі вручну (nmcli con delete "<ім'я>"), щоб уникнути
    // плутанини надалі.
    Text {
      Layout.fillWidth: true
      visible: root.resolved && root.duplicateProfileCount > 1
      text: "⚠ Знайдено " + root.duplicateProfileCount + " профілі NetworkManager з таким SSID. Використовую найновіший (\"" + root.connectionName + "\"). Варто видалити зайві через nmcli con delete."
      color: Palette.yellow
      font.family: Palette.font; font.pixelSize: 10
      wrapMode: Text.WordWrap
    }

    // Автопідключення — застосовується миттєво, незалежно від активної вкладки
    RowLayout {
      Layout.fillWidth: true
      spacing: 8
      visible: root.resolved && root.connectionName.length > 0

      Text {
        text: "Автопідключення"
        color: Palette.textLight
        font.family: Palette.font; font.pixelSize: 12
        Layout.fillWidth: true
      }

      Rectangle {
        id: autoconnectToggleBg
        property bool isHovered: false
        width: 36; height: 22; radius: 11
        opacity: root.autoconnectPending ? 0.6 : 1
        color: root.autoconnect ? Palette.widgetFg : Palette.bg2
        Behavior on color { ColorAnimation { duration: 150 } }
        border.width: isHovered ? 1 : 0
        border.color: Palette.hoverOverlay
        Behavior on border.width { NumberAnimation { duration: 120 } }

        Rectangle {
          x: root.autoconnect ? parent.width - width - 2 : 2
          width: 18; height: 18; radius: 9
          color: root.autoconnect ? Palette.bg1 : Palette.gray
          anchors.verticalCenter: parent.verticalCenter
          Behavior on x { NumberAnimation { duration: 150 } }
          Behavior on color { ColorAnimation { duration: 150 } }
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          enabled: !root.autoconnectPending
          onEntered: autoconnectToggleBg.isHovered = true
          onExited: autoconnectToggleBg.isHovered = false
          onClicked: root.toggleAutoconnect()
        }
      }
    }

    // Вкладки
    RowLayout {
      Layout.fillWidth: true
      spacing: 4
      visible: root.resolved && root.connectionName.length > 0

      Repeater {
        model: root.tabNames
        delegate: Rectangle {
          required property string modelData
          required property int index
          implicitWidth: tabLabel.implicitWidth + 20; height: 26; radius: 4
          color: root.activeTab === index ? Palette.accent : Palette.bgLayer
          Text {
            id: tabLabel
            anchors.centerIn: parent
            text: modelData
            color: root.activeTab === index ? Palette.bgLayer : Palette.textLight
            font.family: Palette.font; font.pixelSize: 11; font.bold: root.activeTab === index
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.activeTab = index
          }
        }
      }
    }

    // Вміст вкладок
    ColumnLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: 8
      visible: root.resolved && root.connectionName.length > 0

      // --- IPv4 ---
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 8
        visible: root.activeTab === 0

        RowLayout {
          spacing: 8
          Text { text: "Метод:"; color: Palette.mutedAlt; font.family: Palette.font; font.pixelSize: 12 }
          Rectangle {
            implicitWidth: autoLabel.implicitWidth + 16; height: 22; radius: 4
            color: !root.ipv4Manual ? Palette.accent : Palette.bgLayer
            Text { id: autoLabel; anchors.centerIn: parent; text: "Auto (DHCP)"; color: !root.ipv4Manual ? Palette.bgLayer : Palette.textLight; font.family: Palette.font; font.pixelSize: 10 }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.ipv4Manual = false }
          }
          Rectangle {
            implicitWidth: manLabel.implicitWidth + 16; height: 22; radius: 4
            color: root.ipv4Manual ? Palette.accent : Palette.bgLayer
            Text { id: manLabel; anchors.centerIn: parent; text: "Manual"; color: root.ipv4Manual ? Palette.bgLayer : Palette.textLight; font.family: Palette.font; font.pixelSize: 10 }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.ipv4Manual = true }
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 6
          visible: root.ipv4Manual

          LabeledField {
            label: "Address"
            text: root.ipv4Address
            onTextEdited: (t) => root.ipv4Address = t
          }
          LabeledField {
            label: "Prefix (CIDR, напр. 24)"
            text: root.ipv4Prefix
            onTextEdited: (t) => root.ipv4Prefix = t
          }
          LabeledField {
            label: "Gateway"
            text: root.ipv4Gateway
            onTextEdited: (t) => root.ipv4Gateway = t
          }
        }
      }

      // --- DNS ---
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 8
        visible: root.activeTab === 1

        RowLayout {
          spacing: 8
          Text { text: "DNS:"; color: Palette.mutedAlt; font.family: Palette.font; font.pixelSize: 12 }
          Rectangle {
            implicitWidth: autoDnsLabel.implicitWidth + 16; height: 22; radius: 4
            color: !root.dnsManual ? Palette.accent : Palette.bgLayer
            Text { id: autoDnsLabel; anchors.centerIn: parent; text: "Automatic"; color: !root.dnsManual ? Palette.bgLayer : Palette.textLight; font.family: Palette.font; font.pixelSize: 10 }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.dnsManual = false }
          }
          Rectangle {
            implicitWidth: manDnsLabel.implicitWidth + 16; height: 22; radius: 4
            color: root.dnsManual ? Palette.accent : Palette.bgLayer
            Text { id: manDnsLabel; anchors.centerIn: parent; text: "Manual"; color: root.dnsManual ? Palette.bgLayer : Palette.textLight; font.family: Palette.font; font.pixelSize: 10 }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.dnsManual = true }
          }
        }

        LabeledField {
          Layout.fillWidth: true
          label: "DNS сервери (через кому)"
          text: root.dnsServers
          visible: root.dnsManual
          onTextEdited: (t) => root.dnsServers = t
        }
      }

      // --- Security (тільки Wi-Fi) ---
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 8
        visible: root.activeTab === 2 && root.connKind !== "ethernet"

        RowLayout {
          spacing: 6
          Text { text: "Тип безпеки:"; color: Palette.mutedAlt; font.family: Palette.font; font.pixelSize: 12 }
          Text { text: root.keyMgmt; color: Palette.textLight; font.family: Palette.font; font.pixelSize: 12; font.bold: true }
        }

        // Кнопка зміни пароля
        Rectangle {
          Layout.fillWidth: true
          implicitHeight: pwLabel.implicitHeight + 12
          radius: 4
          color: Palette.bgLayer
          visible: !root.changingPassword

          Text {
            id: pwLabel
            anchors.centerIn: parent
            text: "Змінити пароль"
            color: Palette.textLight
            font.family: Palette.font; font.pixelSize: 12
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.changingPassword = true
          }
        }

        // Поле нового пароля
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 6
          visible: root.changingPassword

          Rectangle {
            Layout.fillWidth: true
            height: 30; radius: 6
            color: Palette.bgLayer
            border.width: 1; border.color: Palette.accent

            TextInput {
              anchors.fill: parent
              anchors.margins: 8
              color: Palette.textLight
              font.family: Palette.font; font.pixelSize: 12
              echoMode: TextInput.Password
              text: root.newPassword
              onTextEdited: root.newPassword = text
            }
          }

          RowLayout {
            spacing: 8
            Rectangle {
              implicitWidth: 90; height: 24; radius: 4
              color: Palette.accent
              Text { anchors.centerIn: parent; text: "Зберегти пароль"; color: Palette.bgLayer; font.family: Palette.font; font.pixelSize: 10; font.bold: true }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.applyPassword() }
            }
            Rectangle {
              implicitWidth: 70; height: 24; radius: 4
              color: Palette.bgLayer
              Text { anchors.centerIn: parent; text: "Скасувати"; color: Palette.mutedAlt; font.family: Palette.font; font.pixelSize: 10 }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.changingPassword = false; root.newPassword = ""; }
              }
            }
          }
        }

        Item { Layout.fillHeight: true }

        // Кнопка "Забути мережу"
        Rectangle {
          Layout.fillWidth: true
          implicitHeight: forgetLabel.implicitHeight + 12
          radius: 4
          color: Palette.bgLayer

          Text {
            id: forgetLabel
            anchors.centerIn: parent
            text: "Забути мережу"
            color: Palette.danger
            font.family: Palette.font; font.pixelSize: 12
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (root.network && typeof root.network.forget === "function") {
                root.network.forget();
              }
              root.visible = false;
            }
          }
        }
      }
    }

    // Статус виконання
    Text {
      Layout.fillWidth: true
      visible: root.statusMessage.length > 0
      text: root.statusMessage
      color: root.statusIsError ? Palette.danger : Palette.accent
      font.family: Palette.font; font.pixelSize: 11
      wrapMode: Text.WordWrap
    }

    // Кнопка "Apply"
    RowLayout {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignRight
      spacing: 8
      visible: root.resolved && root.connectionName.length > 0 && !(root.activeTab === 2 && root.connKind !== "ethernet")

      Rectangle {
        implicitWidth: 70; height: 26; radius: 4
        color: Palette.accent
        Text { anchors.centerIn: parent; text: "Apply"; color: Palette.bgLayer; font.family: Palette.font; font.pixelSize: 11; font.bold: true }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.applyIpv4AndDns() }
      }
    }
  }

  // Компонент: поле з підписом
  component LabeledField: ColumnLayout {
    property string label: ""
    property string text: ""
    signal textEdited(string t)

    Layout.fillWidth: true
    spacing: 2

    Text {
      text: label
      color: Palette.mutedAlt
      font.family: Palette.font; font.pixelSize: 10
    }
    Rectangle {
      Layout.fillWidth: true
      height: 28; radius: 6
      color: Palette.bgLayer
      border.width: 1; border.color: Palette.accent

      TextInput {
        anchors.fill: parent
        anchors.margins: 8
        color: Palette.textLight
        font.family: Palette.font; font.pixelSize: 12
        text: parent.parent.text
        onTextEdited: parent.parent.textEdited(text)
      }
    }
  }
}
