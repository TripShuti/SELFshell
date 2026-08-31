// ============================================================
// quickshell/core/AppConfig.qml — спільний стан конфігурації панелі (видимість, порядок віджетів) з персистентністю через FileView + JsonAdapter
// ============================================================
import Quickshell.Io
import QtQuick

// Невидимий контейнер — єдиний екземпляр створюється в Bar.qml
// і доступний усім попапам через window.appConfig.
//
// Патерн запозичено з Panacea: усі налаштування живуть в JsonAdapter
// (єдина точка правди — window.appConfig.cfg), збереження —
// writeAdapter() без ручного JSON.stringify.
//
// ВАЖЛИВО: watchChanges навмисно ВИМКНЕНО. У Quickshell 0.3.0 FileView
// має use-after-free в QML-двигуні навколо inotify-watcher: атомарний
// запис файлу (rename — так пише навіть сам writeAdapter через QSaveFile)
// стабільно крашить шел. Тому зовнішні ручні правки config.json
// застосовуються після перезапуску шела, а зміни з UI — одразу (в пам'яті)
// і зберігаються у файл.
Item {
  id: root
  visible: false

  FileView {
    id: configFile
    path: Qt.resolvedUrl("../data/config.json")

    // Типізовані дефолти адаптера — те, що буде записано у файл,
    // якщо ключ відсутній. Назви властивостей = ключі config.json.
    adapter: JsonAdapter {
      id: cfgAdapter

      // --- Видимість віджетів ---
      property bool launcherEnabled: true
      property bool workspacesEnabled: true
      property bool mprisEnabled: true
      property bool clockEnabled: true
      property bool timerEnabled: true
      property bool genshinEnabled: true
      property bool keyboardEnabled: true
      property bool audioEnabled: true
      property bool controlEnabled: true
      property bool clipboardEnabled: false
      // Дефолти співпадають з data/config.json (синхронізовано з поточним
      // користувацьким конфігом; bt/net вимкнені, tray увімкнений)
      property bool btEnabled: false
      property bool netEnabled: false
      property bool trayEnabled: true
      property bool batteryEnabled: false
      property bool kcdEnabled: false
      property bool kcdMuted: false

      // DND — повністю ховає сповіщення (тост, список, звук)
      property bool dndEnabled: false

      // Кастомний шлях до звуку завершення таймера ("" = звук з assets/)
      property string timerSoundPath: ""

      // Улюблений медіа-плеєр (identity у lower case; підстроковний
      // збіг — "spotify", "selfsonic", "chromium" тощо). Спільний для
      // бар-віджета і попапа плеєра
      property string preferredPlayer: "selfsonic"

      // --- Поведінка системи ---
      // Idle-таймаути (секунди). Порядок має бути зростаючим:
      // lock < dpms < suspend, інакше рівні спрацьовуватимуть у несподіваному
      // порядку.
      property int idleLockTimeout: 300
      property int idleDpmsTimeout: 360
      property int idleSuspendTimeout: 900

      // Інкременти змін значень (wheel/клавіші)
      property real audioStep: 0.05
      property int brightnessStep: 5

      // --- Зовнішній вигляд і поведінка бару ---
      property int barHeight: 36
      property int barRadius: 6
      // на якій кромці стоїть панель: "top" | "bottom"
      property string barPos: "top"
      // відступ крайніх пігулок від кромки екрана
      property int edgeMargin: 8
      // внутрішній відступ пігулки
      property int pillPadding: 8
      // зазор між віджетами всередині пігулки
      property int contentSpacing: 4
      // автоскривання: панель їде за кромку і повертається наведенням
      property bool barAutoHide: false
      // приховування пігулок цілком — довільні комбінації
      property bool leftPillEnabled: true
      property bool centerPillEnabled: true
      property bool rightPillEnabled: true

      // --- Зовнішній вигляд: дизайн поза автопалітрою (Appearance) ---
      // Дефолти збігаються з поточними хардкод-значеннями в QML, тож
      // вигляд не змінюється, доки користувач не посуне повзунки.

      // Попапи (база AnimatedPopup — всі 15 вікон)
      property real popupBgOpacity: 0.60
      property real popupBgLighten: 1.15
      property int popupRadius: 14
      property int popupBorderWidth: 1

      // Тост і OSD (автономні поверхні) — стиль як у попапів, без glow
      property int toastRadius: 9
      property real toastLighten: 1.15
      property real toastBgOpacity: 0.90
      property int osdRadius: 10
      property real osdLighten: 1.5
      property real osdBgOpacity: 0.90

      // Бар (пігулки)
      property real barLighten: 1.30
      // множник прозорості фону пігулки (1.0 = колір з палітри як є)
      property real barBgOpacity: 0.70
      // товщина рамки пігулки (0 = без рамки)
      property int barBorderWidth: 1
      // роздільники між віджетами
      property real separatorOpacity: 0.65
      property real separatorGlowOpacity: 0.10

      // Глобальний множник шрифтів/гліфів (1.0 = база)
      property real uiScale: 1.0

      // --- Анімації ---
      // Вимикач усіх анімацій (0-дурації = миттєві зміни)
      property bool animationsEnabled: true
      // Множник тривалостей усіх анімацій (1.0 = база)
      property real animSpeed: 1.0

      // --- Тема ---
      // Режим темінгу: "matugen" — динамічна палітра зі шпалери,
      // "black" — статична монохромна палітра без matugen, шпалери змінюються без регенерації
      property string themeMode: "matugen"

      // --- Порядки віджетів ---
      property var leftOrder: ["launcher", "sep-2", "workspaces", "sep-7", "mpris"]
      property var centerOrder: ["clock", "sep-5", "timer", "sep-6", "genshin", "battery"]
      property var rightOrder: ["tray", "sep-12", "net", "bt", "keyboard", "sep-10", "audio", "sep-11", "control", "clipboard"]
    }
  }

  // Єдина точка правди — адаптер config.json
  readonly property var cfg: cfgAdapter
  function saveToFile() { configFile.writeAdapter() }

  // Масштаб шрифтів/гліфів: усі font.pixelSize у віджетах і попапах
  // домножуються на uiScale через цей хелпер
  function scaled(v) { return v * root.cfg.uiScale }

  // Тривалість анімації з урахуванням глобальних налаштувань:
  // вимкнені анімації (0) або множник швидкості з Appearance.
  // Всі duration у QML обгортаються цим хелпером — біндинг реактивний,
  // зміни animSpeed/animationsEnabled застосовуються на льоту.
  function anim(ms) {
    return root.cfg.animationsEnabled ? Math.round(ms * root.cfg.animSpeed) : 0
  }

  // Фіксований канонічний список усіх віджетів — використовується
  // Settings-попапом для стабільного порядку рядків (не залежить від
  // того, в якій пігулці зараз лежить віджет).
  readonly property var allWidgetNames: [
    "launcher", "workspaces", "mpris", "clock", "timer",
    "genshin", "keyboard", "audio", "battery", "control", "clipboard", "bt", "net", "tray", "kcd"
  ]

  // Порядок ВСЕРЕДИНІ пігулки + приналежність до пігулки визначаються
  // належністю імені до одного з цих трьох масивів. Окремої властивості
  // "xPill" більше не потрібно — пігулка це і є масив, де лежить ім'я.
  // Фабричні дефолти — на випадок відсутнього/порожнього config.json.
  // Містять сепаратори (sep-N) — інакше свіжий клон без config.json
  // рендерив би бар без роздільників. При старті перезаписуються
  // реальними значеннями з config.json (через адаптер).

  function isSep(name) {
    return name === "sep" || String(name).startsWith("sep-")
  }

  function addSep(pillName) {
    var maxId = -1
    var all = [root.cfg.leftOrder, root.cfg.centerOrder, root.cfg.rightOrder]
    for (var a = 0; a < all.length; a++) {
      for (var i = 0; i < all[a].length; i++) {
        var m = String(all[a][i]).match(/^sep-(\d+)$/)
        if (m) maxId = Math.max(maxId, parseInt(m[1]))
      }
    }
    var name = "sep-" + (maxId + 1)
    var arr = pillOrderFor(pillName).slice()
    arr.push(name)
    if (pillName === "left") root.cfg.leftOrder = arr
    else if (pillName === "center") root.cfg.centerOrder = arr
    else root.cfg.rightOrder = arr
  }

  function pillOrderFor(pillName) {
    return pillName === "left" ? root.cfg.leftOrder : pillName === "center" ? root.cfg.centerOrder : root.cfg.rightOrder
  }

  function pillOf(name) {
    if (root.cfg.leftOrder.indexOf(name) !== -1) return "left"
    if (root.cfg.centerOrder.indexOf(name) !== -1) return "center"
    if (root.cfg.rightOrder.indexOf(name) !== -1) return "right"
    return "left"
  }

  // Переносить віджет в іншу пігулку (додається в кінець її списку)
  function moveToPill(name, targetPill) {
    root.cfg.leftOrder = root.cfg.leftOrder.filter(n => n !== name)
    root.cfg.centerOrder = root.cfg.centerOrder.filter(n => n !== name)
    root.cfg.rightOrder = root.cfg.rightOrder.filter(n => n !== name)
    if (targetPill === "left") root.cfg.leftOrder = root.cfg.leftOrder.concat([name])
    else if (targetPill === "center") root.cfg.centerOrder = root.cfg.centerOrder.concat([name])
    else root.cfg.rightOrder = root.cfg.rightOrder.concat([name])
  }

  function moveToPillAt(name, targetPill, targetIndex) {
    root.cfg.leftOrder = root.cfg.leftOrder.filter(n => n !== name)
    root.cfg.centerOrder = root.cfg.centerOrder.filter(n => n !== name)
    root.cfg.rightOrder = root.cfg.rightOrder.filter(n => n !== name)
    var arr = pillOrderFor(targetPill).slice()
    var idx = Math.max(0, Math.min(targetIndex, arr.length))
    arr.splice(idx, 0, name)
    if (targetPill === "left") root.cfg.leftOrder = arr
    else if (targetPill === "center") root.cfg.centerOrder = arr
    else root.cfg.rightOrder = arr
  }

  function cyclePill(name) {
    var pills = ["left", "center", "right"]
    var idx = pills.indexOf(pillOf(name))
    moveToPill(name, pills[(idx + 1) % 3])
  }

  // Пересуває віджет на 1 позицію вгору(-1)/вниз(+1) всередині його
  // поточної пігулки. Межі списку — no-op (нікуди рухати).
  function moveWithinPill(name, direction) {
    var p = pillOf(name)
    var arr = pillOrderFor(p).slice()
    var idx = arr.indexOf(name)
    if (idx === -1) return
    var newIdx = idx + direction
    if (newIdx < 0 || newIdx >= arr.length) return
    var tmp = arr[idx]; arr[idx] = arr[newIdx]; arr[newIdx] = tmp
    if (p === "left") root.cfg.leftOrder = arr
    else if (p === "center") root.cfg.centerOrder = arr
    else root.cfg.rightOrder = arr
  }

  // Заводські значення всього, що правиться в налаштуваннях. Список
  // збігається з дефолтами адаптера, але окрема копія потрібна кнопці
  // «Скинути», щоб повертати рівно заводські значення незалежно від
  // того, що зараз у файлі.
  readonly property var defaultCfg: ({
    launcherEnabled: true, workspacesEnabled: true, mprisEnabled: true,
    clockEnabled: true, timerEnabled: true, genshinEnabled: true,
    keyboardEnabled: true, audioEnabled: true, controlEnabled: true,
    clipboardEnabled: false, btEnabled: false, netEnabled: false,
    trayEnabled: true, batteryEnabled: false, kcdEnabled: false, kcdMuted: false, dndEnabled: false,
    timerSoundPath: "",
    preferredPlayer: "selfsonic",
    idleLockTimeout: 300, idleDpmsTimeout: 360, idleSuspendTimeout: 900,
    audioStep: 0.05, brightnessStep: 5,
    barHeight: 36, barRadius: 6, barPos: "top", edgeMargin: 8,
    pillPadding: 8, contentSpacing: 4, barAutoHide: false,
    leftPillEnabled: true, centerPillEnabled: true, rightPillEnabled: true,
    popupBgOpacity: 0.60, popupBgLighten: 1.15, popupRadius: 14,
    popupBorderWidth: 1,
    toastRadius: 9, toastLighten: 1.15, toastBgOpacity: 0.90,
    osdRadius: 10, osdLighten: 1.5, osdBgOpacity: 0.90,
    barLighten: 1.30,
    barBgOpacity: 0.70, barBorderWidth: 1,
    separatorOpacity: 0.65, separatorGlowOpacity: 0.10,
    uiScale: 1.0,
    animationsEnabled: true, animSpeed: 1.0,
    themeMode: "matugen",
    leftOrder: ["launcher", "sep-2", "workspaces", "sep-7", "mpris"],
    centerOrder: ["clock", "sep-5", "timer", "sep-6", "genshin", "battery"],
    rightOrder: ["tray", "sep-12", "net", "bt", "kcd", "keyboard", "sep-10", "audio", "sep-11", "control", "clipboard"]
  })

  function resetCfg() {
    for (var k in root.defaultCfg) root.cfg[k] = root.defaultCfg[k]
    root.saveToFile()
  }
}
