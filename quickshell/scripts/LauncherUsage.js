// ============================================================
// LauncherUsage.js — статистика запусків додатків
// ============================================================
.pragma library

// Зберігає кількість запусків додатків для сортування в лаунчері

var _data = {}

// Завантажує дані з JSON
function setData(data) {
  _data = data || {}
}

// Збільшує лічильник запуску додатка
function record(id) {
  _data[id] = (_data[id] || 0) + 1
}

// Повертає кількість запусків додатка
function getCount(id) {
  return _data[id] || 0
}

// Серіалізує дані в JSON
function serialize() {
  return JSON.stringify(_data)
}
