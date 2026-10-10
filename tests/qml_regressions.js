// ============================================================
// tests/qml_regressions.js — регресійні перевірки логіки QML без системних побічних ефектів
// ============================================================
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const base = path.resolve(__dirname, "../quickshell");
function source(file) { return fs.readFileSync(path.join(base, file), "utf8"); }
function method(file, name, ctx) {
  const match = source(file).match(new RegExp("^  function " + name + "\\(([^)]*)\\) \\{\\n([\\s\\S]*?)^  \\}", "m"));
  assert.ok(match, file + ": " + name);
  return new Function("ctx", "with (ctx) { return function(" + match[1] + ") {" + match[2] + "}; }")(ctx);
}
function handler(file, id, event, ctx) {
  const section = source(file).split("id: " + id)[1];
  assert.ok(section, id);
  const match = section.match(new RegExp("^( +)" + event + ": \\{\\n([\\s\\S]*?)^\\1\\}", "m"));
  assert.ok(match, id + ": " + event);
  return new Function("ctx", "with (ctx) {" + match[2] + "}").bind(null, ctx);
}
let checks = 0;
function test(name, fn) { fn(); checks++; console.log("PASS: " + name); }

test("Brightness: first read, external changes and stale writes", () => {
  const root = { brightness: -1, _sent: -2, _writeGeneration: 0 };
  const ctx = { root, getBrightnessProc: { generation: 0 }, setBrightnessProc: { running: false },
    setDebounce: { running: false }, brightnessCollector: { text: "current value = 40, max value = 100" } };
  Object.defineProperty(ctx, "brightness", { get() { return root.brightness; }, set(value) { root.brightness = value; } });
  const read = handler("popups/control/BrightnessSection.qml", "brightnessCollector", "onDataChanged", ctx);
  read(); assert.equal(root.brightness, 40); assert.equal(root._sent, 40);
  ctx.brightnessCollector.text = "current value = 60, max value = 100";
  read(); assert.equal(root.brightness, 60); assert.equal(root._sent, 60);
  root._writeGeneration++;
  ctx.brightnessCollector.text = "current value = 20, max value = 100";
  read(); assert.equal(root.brightness, 60);
});

test("Screenshot: immediate second click is debounced", () => {
  const root = { _lastShotTimeFull: 0, _lastShotTimeRegion: 0 };
  const click = method("popups/ControlPopup.qml", "shotDebouncedClick", { root, Date });
  assert.equal(click("full"), false); assert.equal(click("full"), true);
  assert.equal(click("region"), false);
  assert.match(source("popups/ControlPopup.qml"), /property real _lastShotTimeFull/);
});

test("Battery: recover at 20%, charging above threshold, re-arm notification", () => {
  let saves = 0, restores = 0, notifications = 0;
  const root = { percent: -1, state: "", lowNotified: false, appConfig: { cfg: { autoPowerSaver: true, dndEnabled: false } },
    powerSvc: { setProfile() { saves++; }, restoreManual() { restores++; } }, lowBattery() { notifications++; } };
  Object.defineProperties(root, { charging: { get() { return this.state === "charging"; } },
    low: { get() { return this.percent >= 0 && this.percent <= 15 && !this.charging; } } });
  root.updatePowerState = method("services/BatteryService.qml", "updatePowerState", { root });
  const apply = method("services/BatteryService.qml", "applyInfo", { root });
  const info = (pct, state = "discharging") => apply("state: " + state + "\npercentage: " + pct + "%\n");
  info(14); info(16); info(20);
  assert.equal(saves, 1); assert.equal(restores, 1); assert.equal(root.lowNotified, false);
  info(14); assert.equal(notifications, 2);
  info(18); info(18, "charging"); assert.equal(restores, 2);
});

test("SelfTrack: latest date is queued and old exports/pages are rejected", () => {
  const root = { monitorEnabled: true, dateStr: "2026-10-10", _pagesGeneration: 2 };
  const fetchProc = { running: true, _date: "2026-10-09", _todayOnly: false };
  method("monitors/SelfTrackMonitor.qml", "refresh", { root, fetchProc })();
  assert.equal(root._refreshPending, true);
  handler("monitors/SelfTrackMonitor.qml", "fetchCollector", "onStreamFinished", { root, fetchProc })();
  const ctx = { root, fetchPagesProc: { _date: "2026-10-09", _generation: 1, _wantApp: "Browser" },
    pagesCollector: { text: JSON.stringify({ page_app: "Browser", pages: ["old"] }) } };
  handler("monitors/SelfTrackMonitor.qml", "pagesCollector", "onStreamFinished", ctx)();
  assert.equal(root.pageApp, undefined);
});

test("TrackList: busy metadata fetch queues the latest IDs; old player is ignored", () => {
  const root = { trackIds: ["new"], _generation: 3, playerName: "player", script: "tracklist.py", _metaCap: 200 };
  const metaProc = { running: true };
  const fetch = method("services/TrackListService.qml", "_fetchAll", { root, metaProc });
  fetch(); assert.equal(root._metaPending, true);
  metaProc.running = false; fetch();
  assert.equal(metaProc.command.at(-1), "new"); assert.equal(metaProc.generation, 3);
  root.active = true; metaProc.generation = 2;
  handler("services/TrackListService.qml", "metaCollector", "onStreamFinished", { root, metaProc })();
  assert.equal(root.tracks, undefined);
});

test("Network: old profile resolution cannot update a reopened dialog", () => {
  const root = { visible: true, requestGeneration: 2 };
  handler("popups/NetworkConnectionSettingsPopup.qml", "resolveConnProcess", "onStreamFinished",
    { root, resolveConnProcess: { generation: 1 } })();
  assert.equal(root.connectionName, undefined);
});

test("EQ: matching config still restarts PipeWire when sink is absent", () => {
  let content = "";
  const root = { pluginPath: "/plugin.so", _confRestartPending: false };
  const ctx = { root, _zeroControls: () => "", _confFile: { text: () => content, setText(value) { content = value; } },
    _pwRestartProc: { running: false } };
  const ensure = method("core/AudioEq.qml", "_ensureConf", ctx);
  ensure(); root._confRestartPending = true; ensure();
  assert.equal(ctx._pwRestartProc.running, true); assert.equal(root._confRestartPending, false);
});

test("Calendar: independent imports retain their own save callback", () => {
  const vm = require("node:vm");
  const a = {}, b = {};
  vm.createContext(a); vm.createContext(b);
  vm.runInContext(source("scripts/CalendarTasks.js"), a);
  vm.runInContext(source("scripts/CalendarTasks.js"), b);
  let saved = 0;
  b.setSaveCallback(() => saved++); a.clearSaveCallback(); b.add("2026-10-10", "Task");
  assert.equal(saved, 1); assert.doesNotMatch(source("scripts/CalendarTasks.js"), /\.pragma library/);
});
test("EQ: missing node invalidates the old ID and replacement restores routing", () => {
  const root = { enabled: true, busy: false, _graphEqNodeId: -1, _eqNodeId: 37 };
  const proc = { running: false };
  const sync = method("core/AudioEq.qml", "syncEqNode", { root, _getDefaultSinkProc: proc });
  sync(); assert.equal(root._eqNodeId, -1); assert.equal(proc.running, false);
  root._graphEqNodeId = 82;
  sync(); assert.equal(root._eqNodeId, 82); assert.equal(proc.running, true); assert.equal(root.busy, true);
  proc.running = false; root.busy = false;
  sync(); assert.equal(proc.running, false);
  root.enabled = false; root._graphEqNodeId = 90;
  sync(); assert.equal(proc.running, false);
});

test("EQ: graph change while relinking queues another run", () => {
  let scheduled = 0;
  const root = { enabled: true, busy: false, _relinkPending: false };
  const ctx = { root, relinkDelay: { restart() { scheduled++; } }, _relinkProc: { running: true } };
  root.scheduleRelink = method("core/AudioEq.qml", "scheduleRelink", ctx);
  const run = method("core/AudioEq.qml", "runRelink", ctx);
  root.scheduleRelink(); run(); assert.equal(root._relinkPending, true);
  handler("core/AudioEq.qml", "_relinkProc", "onExited", ctx)();
  assert.equal(scheduled, 2);
  ctx._relinkProc.running = false; run();
  assert.equal(ctx._relinkProc.running, true); assert.equal(root._relinkPending, false);
  root.busy = true; root.scheduleRelink(); run(); assert.equal(root._relinkPending, true);
  root.enabled = false; run(); assert.equal(root._relinkPending, false);
});

test("SelfTrack: latest app click is queued; collapse cancels old pages", () => {
  const root = { monitorEnabled: true, pageApp: "", dateStr: "2026-10-10",
    _pagesGeneration: 0, _pendingPageApp: "", selftrackBin: "selftrack" };
  const ctx = { root, fetchPagesProc: { running: false } };
  root.fetchPendingPages = method("monitors/SelfTrackMonitor.qml", "fetchPendingPages", ctx);
  const click = method("monitors/SelfTrackMonitor.qml", "refreshPages", ctx);
  click("Browser"); click("Editor");
  assert.equal(root._pendingPageApp, "Editor");
  ctx.pagesCollector = { text: JSON.stringify({ page_app: "Browser", pages: ["old"] }) };
  const read = handler("monitors/SelfTrackMonitor.qml", "pagesCollector", "onStreamFinished", ctx);
  read(); assert.deepEqual(root.pagesModel, []);
  ctx.fetchPagesProc.running = false;
  handler("monitors/SelfTrackMonitor.qml", "fetchPagesProc", "onExited",
    { ...ctx, Qt: { callLater(fn) { fn(); } } })();
  assert.equal(ctx.fetchPagesProc.command.at(-1), "Editor");
  ctx.pagesCollector.text = JSON.stringify({ page_app: "Editor", pages: ["latest"] });
  read(); assert.deepEqual(root.pagesModel, ["latest"]);
  click("Editor"); read();
  assert.equal(root.pageApp, ""); assert.deepEqual(root.pagesModel, []);
  assert.equal(root._pendingPageApp, "");
});

test("Popup: bounded dimensions drive centered and bottom-bar anchors", () => {
  const root = { centerScreen: { width: 320, height: 240 }, viewportWidth: 300, viewportHeight: 180,
    anchor: {}, visible: true, centerAnchor: true, slideDistance: 10,
    appConfig: { cfg: { barPos: "bottom" } }, anchorTarget: {},
    popupWindow: { screen: { width: 320 }, itemRect() { return { x: 290, y: 4, width: 20, height: 28 }; } } };
  const ctx = { root, anchor: root.anchor, PopupAnchor: { None: 0 }, Qt: { rect(x, y, w, h) { return { x, y, w, h }; } },
    Item: { Top: 0, Bottom: 1 } };
  method("core/AnimatedPopup.qml", "positionUnderAnchor", ctx)();
  assert.deepEqual(root.anchor.rect, { x: 10, y: -186, w: 300, h: 180 });
  assert.equal(root.slideDistance, -10);
  method("core/AnimatedPopup.qml", "centerOnScreen", ctx)();
  assert.deepEqual(root.anchor.rect, { x: 10, y: 30, w: 300, h: 180 });
});
test("Shell: popup routing follows the focused monitor and falls back safely", () => {
  const first = { screen: { name: "HDMI-A-1" } }, second = { screen: { name: "DP-1" } };
  const root = { bars: [first, second] }, Hyprland = { focusedMonitor: { name: "DP-1" } };
  const active = method("shell.qml", "activeBar", { root, Hyprland });
  assert.equal(active(), second);
  Hyprland.focusedMonitor.name = "removed"; assert.equal(active(), first);
  root.bars = []; assert.equal(active(), null);
});

test("Pairing: disappearing requests stop countdowns and close both popups", () => {
  for (const file of ["popups/PairingPopup.qml", "popups/KdeConnectPairingPopup.qml"]) {
    let stopped = 0, closed = 0;
    const ctx = { req: null, visible: true, countdown: { stop() { stopped++; } }, close() { closed++; } };
    const sync = method(file, "syncToRequest", ctx);
    sync(); assert.equal(stopped, 1); assert.equal(closed, 1);
  }
});
test("Config: live CLI mutation preserves pending UI values and rejects wrong types", () => {
  let saves = 0;
  const root = { numericRanges: { uiScale: [.8, 1.5, false] }, defaultCfg: { themeMode: "black", uiScale: 1, leftOrder: [] },
    cfg: { themeMode: "black", uiScale: 1.25 }, saveToFile() { saves++; } };
  const set = method("core/AppConfig.qml", "setValue", { root });
  assert.equal(set("themeMode", '"matugen"'), true);
  assert.equal(root.cfg.uiScale, 1.25);
  assert.equal(saves, 1);
  assert.equal(set("uiScale", "true"), false);
  assert.equal(set("leftOrder", "[3]"), false);
  assert.equal(set("unknown", "3"), false);
});

test("Suspend: waits for secure acknowledgement and cancels on timeout", () => {
  const root = { suspendPending: false, sleepPreparing: false };
  const sessionLock = { secure: false }, lockContext = { locked: false };
  const suspendProc = { running: false };
  const ctx = { root, sessionLock, lockContext, suspendProc,
    sleepMonitor: { write() {} }, suspendTimeout: { restart() {}, stop() {} }, console: { warn() {} } };
  root.continueSuspend = method("shell.qml", "continueSuspend", ctx);
  const request = method("shell.qml", "requestSuspend", ctx);
  request(); assert.equal(lockContext.locked, true); assert.equal(suspendProc.running, false);
  sessionLock.secure = true;
  root.continueSuspend(); assert.equal(suspendProc.running, true);
  suspendProc.running = false; sessionLock.secure = false;
  request();
  handler("shell.qml", "suspendTimeout", "onTriggered", ctx)();
  sessionLock.secure = true; root.continueSuspend();
  assert.equal(suspendProc.running, false);
});

test("Upgrade: detached unit survives QML ownership and duplicate clicks are ignored", () => {
  const commands = [];
  const root = { upgrading: false, available: true, count: 1, upgradeScript: "/upgrade.sh" };
  const start = method("services/PacmanService.qml", "startUpgrade", { root,
    Quickshell: { env() { return ""; }, execDetached(cmd) { commands.push(cmd); } },
    upgradeTimeout: { restart() {} }, focusTimer: { restart() {} } });
  start(); start();
  assert.equal(commands.length, 1);
  assert.ok(commands[0].includes("--unit=selfshell-upgrade"));
  assert.ok(commands[0].includes("/upgrade.sh"));
});

console.log("QML regressions: " + checks + " passed");
