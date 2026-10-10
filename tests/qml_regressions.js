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
console.log("QML regressions: " + checks + " passed");
