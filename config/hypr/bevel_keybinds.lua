-- Bevel rice — keybinds
local mainMod = "SUPER"
local terminal    = "kitty"
local fileManager = "dolphin"
local qs = "qs -c bevel ipc call "

-- Apps and shell
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))                                  -- floating
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exec_cmd(terminal .. " --class kitty-tiled"))   -- tiled
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(qs .. "launcher toggle"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd(qs .. "power toggle"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + I", hl.dsp.exec_cmd(qs .. "settings toggle"))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("bevelctl random"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd(qs .. "notifications clear"))
hl.bind(mainMod .. " + SHIFT + Z", hl.dsp.exec_cmd(qs .. "screensaver start"))
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd(qs .. "controlpanel toggle"))
hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd("bevelctl lock"))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("bevelctl random favorites"))

-- Windows
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd(qs .. "clipboard toggle"))
-- Windows-style Alt+Tab (the shell keeps the list; releasing Alt picks the window)
hl.bind("ALT + TAB", hl.dsp.exec_cmd(qs .. "switcher next"))
hl.bind("ALT + SHIFT + TAB", hl.dsp.exec_cmd(qs .. "switcher prev"))
hl.bind(mainMod .. " + F1", hl.dsp.exec_cmd("bevelctl welcome keys"))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + F",         hl.dsp.exec_cmd("bevelctl fullscreen full"))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.exec_cmd("bevelctl fullscreen max"))

hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Several monitors: Super+Ctrl+←/→ go to the next monitor, add Shift to take the window along,
-- Super+Alt+←/→ moves the whole workspace there. (pcall: a Hyprland without these keeps the rest)
pcall(function()
    hl.bind(mainMod .. " + CTRL + left",          hl.dsp.focus({ monitor = "-" }))
    hl.bind(mainMod .. " + CTRL + right",         hl.dsp.focus({ monitor = "+" }))
    hl.bind(mainMod .. " + CTRL + SHIFT + left",  hl.dsp.window.move({ monitor = "-", follow = true }))
    hl.bind(mainMod .. " + CTRL + SHIFT + right", hl.dsp.window.move({ monitor = "+", follow = true }))
    hl.bind(mainMod .. " + ALT + left",           hl.dsp.workspace.move({ monitor = "-" }))
    hl.bind(mainMod .. " + ALT + right",          hl.dsp.workspace.move({ monitor = "+" }))
end)

-- Workspaces: Super+1..0 switch, Super+Shift+1..0 move window
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Scratchpad: Super+S shows/hides it, Super+Alt+S sends a window there
-- (not Super+Shift+S: many laptop PrtSc keys send exactly that)
hl.bind(mainMod .. " + S",       hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + ALT + S", hl.dsp.window.move({ workspace = "special:magic" }))
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Volume (the OSD reacts to PipeWire on its own)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true })

-- Brightness (also pops the OSD)
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("bevelctl brightness up"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("bevelctl brightness down"), { locked = true, repeating = true })
hl.bind("XF86KbdBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -d '*::kbd_backlight' set 33%+"), { locked = true })
hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd("brightnessctl -d '*::kbd_backlight' set 33%-"), { locked = true })

-- Media
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- Screenshots: Print = pick a region, Shift+Print = whole screen, Super+Print = active window
-- (saved to ~/Pictures/Screenshots and copied to the clipboard)
hl.bind("Print",                    hl.dsp.exec_cmd("bevelctl shot region"))
hl.bind("SHIFT + Print",            hl.dsp.exec_cmd("bevelctl shot full"))
hl.bind(mainMod .. " + Print",      hl.dsp.exec_cmd("bevelctl shot window"))
hl.bind(mainMod .. " + SHIFT + S",  hl.dsp.exec_cmd("bevelctl shot region"))   -- Windows-style snip (some laptops' PrtSc key sends this)
