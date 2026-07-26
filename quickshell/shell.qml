// ============================================================
// shell.qml — кореневий компонент, створює панель для кожного
// монітора
// ============================================================
import Quickshell
import Quickshell.Hyprland
import QtQuick

ShellRoot {
  Variants {
    model: Quickshell.screens

    Bar {}
  }
}
