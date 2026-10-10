#!/usr/bin/env python3
# ============================================================
# quickshell/scripts/sleep_guard.py — delay-inhibitor logind до підтвердження захищеного локскріна.
# ============================================================
import json
import os
import sys


class SleepGuard:
    def __init__(self, manager, emit, close_fd=os.close):
        self.manager = manager
        self.emit = emit
        self.close_fd = close_fd
        self.fd = None
        self.preparing = False
        self.cycle = 0

    def acquire(self):
        if self.fd is None:
            self.fd = self.manager.Inhibit('sleep', 'SELFshell', 'Secure screen before sleep', 'delay').take()

    def prepare(self, active):
        self.preparing = bool(active)
        if active:
            self.cycle += 1
        if not active:
            self.acquire()
        self.emit({'sleeping': bool(active), 'cycle': self.cycle})

    def secure(self, cycle):
        if cycle == self.cycle and self.preparing and self.fd is not None:
            self.close_fd(self.fd)
            self.fd = None


def main():
    import dbus
    import dbus.mainloop.glib
    from gi.repository import GLib
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SystemBus()
    obj = bus.get_object('org.freedesktop.login1', '/org/freedesktop/login1')
    manager = dbus.Interface(obj, 'org.freedesktop.login1.Manager')
    guard = SleepGuard(manager, lambda event: print(json.dumps(event), flush=True))
    manager.connect_to_signal('PrepareForSleep', guard.prepare)
    guard.acquire()
    props = dbus.Interface(obj, 'org.freedesktop.DBus.Properties')
    if props.Get('org.freedesktop.login1.Manager', 'PreparingForSleep'):
        guard.prepare(True)
    loop = GLib.MainLoop()
    pending = b''

    def input_ready(_source, condition):
        nonlocal pending
        if condition & GLib.IO_HUP:
            loop.quit()
            return False
        chunk = os.read(sys.stdin.fileno(), 4096)
        if not chunk:
            loop.quit()
            return False
        pending += chunk
        while b'\n' in pending:
            line, pending = pending.split(b'\n', 1)
            parts = line.split()
            if len(parts) == 2 and parts[0] == b'secure':
                try:
                    guard.secure(int(parts[1]))
                except ValueError:
                    pass
        return True

    GLib.io_add_watch(sys.stdin, GLib.IO_IN | GLib.IO_HUP, input_ready)
    loop.run()


if __name__ == '__main__':
    main()
