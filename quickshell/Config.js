.pragma library

// ============================================================
// Config.js — глобальні перемикачі віджетів/попапів.
// Той самий патерн, що Palette.js: редагуєш значення тут,
// зберігаєш файл — Quickshell hot-reload підхопить зміну.
// Призначено для того, щоб хтось інший міг вимкнути особисті/
// нішеві модулі (Genshin тощо), не редагуючи Bar.qml напряму.
// ============================================================

// --- Ліва пігулка ---
var enableLauncherWidget = true;
var enableWorkspacesWidget = true;
var enableMprisWidget = true;

// --- Центральна пігулка ---
var enableClockWidget = true;
var enableTimerWidget = true;
var enableGenshinWidget = true;   // нішева фіча: статистика Genshin Impact з HoYoLAB

// --- Права пігулка ---
var enableKeyboardWidget = true;
var enableAudioWidget = true;
var enableControlWidget = true;   // control center: нотифікації, живлення, швидкі дії

// --- Фонові монітори (мають сенс тільки якщо відповідний віджет увімкнено) ---
var enableCavaMonitor = enableMprisWidget;      // аудіо-візуалізація в MprisWidget
var enableGenshinMonitor = enableGenshinWidget; // поллінг HoYoLAB для GenshinWidget
