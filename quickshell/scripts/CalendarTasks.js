// ============================================================
// CalendarTasks.js — задачі календаря
// ============================================================
.pragma library

// Керування задачами календаря: додавання, видалення, виконання

var _data = {}
var _saveCallback = null

// Встановлює функцію збереження (викликається після змін)
function setSaveCallback(cb) {
  _saveCallback = cb
}

// Завантажує всі задачі з JSON
function setData(data) {
  _data = data || {}
}

// Повертає список задач на дату
function getTasks(date) {
  var list = _data[date]
  return list ? list.slice() : []
}

// Перевіряє чи є задачі на дату
function hasTasks(date) {
  var list = _data[date]
  return list ? list.length > 0 : false
}

// Додає задачу на дату
function add(date, text) {
  if (!text.trim()) return false
  if (!_data[date]) _data[date] = []
  _data[date].push({ text: text.trim(), done: false })
  scheduleSave()
  return true
}

// Перемикає стан виконання задачі
function toggle(date, index) {
  var list = _data[date]
  if (!list || index < 0 || index >= list.length) return
  list[index].done = !list[index].done
  scheduleSave()
}

// Видаляє задачу
function remove(date, index) {
  var list = _data[date]
  if (!list || index < 0 || index >= list.length) return
  list.splice(index, 1)
  if (list.length === 0) delete _data[date]
  scheduleSave()
}

// Викликає функцію збереження
function scheduleSave() {
  if (_saveCallback) _saveCallback()
}

// Серіалізує всі задачі в JSON
function serialize() {
  return JSON.stringify(_data)
}

// Форматує дату в "YYYY-MM-DD"
function formatDate(y, m, d) {
  var mm = (m + 1).toString().padStart(2, "0")
  var dd = d.toString().padStart(2, "0")
  return y + "-" + mm + "-" + dd
}
