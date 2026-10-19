-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
--  Bevel rice — Hyprland Lua config                       --
--  Look & feel is generated into bevel_generated.lua by   --
--  `bevelctl` (Super+I). Keybinds live in                 --
--  bevel_keybinds.lua. Put your own tweaks in             --
--  user.lua — the installer never overwrites that file.   --
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

-- make sure files next to this one can be required
if os and os.getenv and package and package.path then
    local dir = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr/"
    package.path = dir .. "?.lua;" .. package.path
end

-- `require` caches modules; clear them so `hyprctl reload` picks up changes.
local function load(name)
    package.loaded[name] = nil
    local ok, err = pcall(require, name)
    if not ok then
        print("bevel: could not load " .. name .. ": " .. tostring(err))
    end
end

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
-- QT_QPA_PLATFORMTHEME is set in bevel_generated.lua (kde if plasma-integration is installed, else qt6ct)
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("GDK_SCALE", "1")

-------------------
---- AUTOSTART ----
-------------------
hl.on("hyprland.start", function ()
    hl.exec_cmd("bevelctl session")     -- wallpaper daemon, theme, Quickshell (log: ~/.cache/bevel/session.log)
    -- systemd starts the polkit agent as a user service; without systemd (Artix…) run it directly
    hl.exec_cmd("systemctl --user start hyprpolkitagent 2>/dev/null || /usr/lib/hyprpolkitagent/hyprpolkitagent")
end)

-----------------------------------------
---- LOOK, MONITOR SCALE, KEYBINDS ------
-----------------------------------------
load("bevel_generated")   -- gaps, borders, rounding, blur, monitor scale
load("bevel_keybinds")

hl.curve("easeOutQuint", { type = "bezier", points = { {0.23, 1}, {0.32, 1} } })
hl.curve("linear",       { type = "bezier", points = { {0, 0},    {1, 1}    } })
hl.curve("almostLinear", { type = "bezier", points = { {0.5, 0.5}, {0.75, 1} } })
hl.curve("quick",        { type = "bezier", points = { {0.15, 0}, {0.1, 1}  } })
hl.curve("snap",         { type = "spring", mass = 1, stiffness = 320, dampening = 30 })

hl.animation({ leaf = "global",     enabled = true, speed = 10,  bezier = "default" })
hl.animation({ leaf = "border",     enabled = true, speed = 4,   bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",    enabled = true, speed = 3.5, spring = "snap" })
hl.animation({ leaf = "windowsIn",  enabled = true, speed = 3,   spring = "snap", style = "popin 92%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.4, bezier = "linear", style = "popin 92%" })
hl.animation({ leaf = "fade",       enabled = true, speed = 2.5, bezier = "quick" })
hl.animation({ leaf = "layers",     enabled = true, speed = 3,   bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",   enabled = true, speed = 3,   bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",  enabled = true, speed = 1.5, bezier = "linear", style = "fade" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 2.5, bezier = "almostLinear", style = "slide" })

hl.config({
    dwindle = { preserve_split = true },
    master  = { new_status = "master" },
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
        disable_splash_rendering = true,
    },
})

---------------
---- INPUT ----
---------------
hl.config({
    input = {
        kb_layout  = "us",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",
        follow_mouse = 1,
        -- touchpad and pointer speed: bevel_generated.lua (Super+I → Touchpad)
    },
})

-- keep the pointer where you left it: no jumping to the middle of a window when the dock,
-- Alt+Tab or a keybind focuses one
pcall(hl.config, {
    cursor = {
        no_warps = true,
    },
})

hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})

--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------
hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})

-- Bevel settings window floats in the middle (pcall: a typo here must not break the config)
pcall(hl.window_rule, {
    name  = "bevel-settings",
    match = { title = "^Bevel Settings$" },
    float = true,
    center = true,
    size  = "900 660",
})

-- the Welcome tour / keyboard shortcuts
pcall(hl.window_rule, {
    name  = "bevel-welcome",
    match = { title = "^Welcome to Bevel$" },
    float = true,
    center = true,
    size  = "760 520",
})

-- Tip of the Day floats in the middle too
pcall(hl.window_rule, {
    name  = "bevel-tips",
    match = { title = "^Tip of the Day$" },
    float = true,
    center = true,
    size  = "480 290",
})

-- you didn't see this one
pcall(hl.window_rule, {
    name  = "bevel-opsec",
    match = { title = "^WELCOME TO OPSEC$" },
    float = true,
    center = true,
    size  = "560 330",
})

-- Small dialogs float
pcall(hl.window_rule, {
    name  = "float-dialogs",
    match = { title = "^(Open File|Save File|Save As|Choose Files|File Upload).*" },
    float = true,
})

-- Your own additions (created empty by the installer, never overwritten)
load("user")
