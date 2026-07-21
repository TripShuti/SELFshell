local s = require("modules.env")

hl.bind("Print",               hl.dsp.exec_cmd("sh -c 'grim - | tee ~/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png | wl-copy'"))
hl.bind(s.mainMod .. " + Print", hl.dsp.exec_cmd("sh -c 'grim -g \"$(slurp)\" - | tee ~/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png | wl-copy'"))

hl.bind("Pause",                hl.dsp.exec_cmd("systemctl suspend"))
hl.bind(s.mainMod .. " + Escape", hl.dsp.exec_cmd("~/.config/wofi/powermenu.sh"))

hl.bind(s.mainMod .. " + W", hl.dsp.exec_cmd(s.browser))
hl.bind(s.mainMod .. " + Q", hl.dsp.exec_cmd(s.terminal))
hl.bind(s.mainMod .. " + E", hl.dsp.exec_cmd(s.fileManager))
--hl.bind(s.mainMod .. " + R", hl.dsp.exec_cmd(s.menu))
hl.bind(s.mainMod .. " + R", hl.dsp.exec_cmd("qs ipc call launcher toggle"))
hl.bind(s.mainMod .. " + C", hl.dsp.window.close())
hl.bind(s.mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))

hl.bind(s.mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(s.mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(s.mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(s.mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

for i = 1, 10 do
    local key = i % 10
    hl.bind(s.mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(s.mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(s.mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(s.mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

hl.bind(s.mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(s.mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })