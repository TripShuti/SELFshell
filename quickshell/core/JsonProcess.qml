// ============================================================
// quickshell/core/JsonProcess.qml — процес з JSON-виводом одним документом
// ============================================================
import Quickshell.Io
import QtQuick

// hyprctl -j друкує pretty-printed JSON (поле на рядок), тому SplitParser
// ріже його по рядках і JSON.parse одного рядка завжди падає. Компонент
// накопичує рядки в буфер і емітить parsed() лише коли зібрався повний
// документ. Буфер скидається на кожному старті — інакше хвостовий чанк
// попереднього виводу клеїться до нового JSON і парс вмирає назавжди.
// Не перевизначати onStarted/stdout — вони зайняті буфером.
Process {
  id: root

  signal parsed(var obj)

  property string buf: ""
  onStarted: root.buf = ""

  stdout: SplitParser {
    splitMarker: "\n"
    onRead: data => {
      root.buf += (data ?? "")
      var obj = null
      try { obj = JSON.parse(root.buf) } catch (e) {}
      if (obj === null) return
      root.buf = ""
      root.parsed(obj)
    }
  }
}
