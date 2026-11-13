-- Material 3 Hyprland
-- Colours come from ~/.config/hypr/colors.lua, which `m3-theme` regenerates.
-- The Settings app (Super+I) writes ~/.config/hypr/settings.lua.
-- Put your own tweaks in ~/.config/hypr/user.lua - the installer never overwrites it.

local home = os.getenv("HOME")
local bin  = home .. "/.local/bin/"

local ok, c = pcall(dofile, home .. "/.config/hypr/colors.lua")
if not ok or type(c) ~= "table" then
    -- M3 baseline purple (dark) until m3-theme has run once
    c = { primary = "rgb(d0bcff)", outline_variant = "rgb(49454f)", surface = "rgb(141218)" }
end

------------------
---- MONITORS ----
------------------
-- Load user-configured monitors from Settings (Super+I)
pcall(dofile, home .. "/.config/hypr/settings.lua")
-- Fallback for unconfigured monitors
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

---------------------
---- ENVIRONMENT ----
---------------------
hl.env("PATH", home .. "/.local/bin:" .. (os.getenv("PATH") or "/usr/bin:/bin"))
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland:GNOME")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "qt5ct") -- qt5ct and qt6ct both answer to this
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("SSH_AUTH_SOCK", (os.getenv("XDG_RUNTIME_DIR") or ("/run/user/" .. (os.getenv("UID") or "1000"))) .. "/keyring/ssh")

-- NVIDIA proprietary driver
local nv = io.open("/proc/driver/nvidia/version", "r")
if nv then
    nv:close()
    hl.env("LIBVA_DRIVER_NAME", "nvidia")
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
    hl.env("NVD_BACKEND", "direct")
    hl.config({
        cursor = { no_hardware_cursors = false },
        opengl = { nvidia_anti_flicker = true },
        misc   = { vrr = 0 },
    })
end

-------------------
---- AUTOSTART ----
-------------------
hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE SSH_AUTH_SOCK")
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets,pkcs11,ssh")
    hl.exec_cmd(bin .. "m3-theme restore")
    hl.exec_cmd("waybar")
    hl.exec_cmd("swaync")
    hl.exec_cmd("swayosd-server")
    hl.exec_cmd("hypridle")
    -- polkit agent, started directly: its systemd unit is masked so it stays out of other desktops
    hl.exec_cmd("sh -c 'for p in /usr/libexec/hyprpolkitagent /usr/lib/hyprpolkitagent/hyprpolkitagent /usr/lib/hyprpolkitagent; do [ -x \"$p\" ] && [ ! -d \"$p\" ] && exec \"$p\"; done'")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd(bin .. "m3-minimize daemon")
    pcall(hl.plugin.load, home .. "/.local/lib/m3-minimize-plugin.so")
end)

-----------------------
---- LOOK AND FEEL ----
-----------------------
hl.config({
    general = {
        gaps_in     = 4,
        gaps_out    = 8,
        border_size = 2,
        col = {
            active_border   = c.primary,
            inactive_border = c.outline_variant,
        },
        resize_on_border = true, -- drag window edges to resize, like Windows
        layout = "dwindle",
    },

    decoration = {
        rounding       = 20, -- between M3 "large" (16) and "extra large" (28)
        rounding_power = 2,
        shadow = {
            enabled      = true,
            range        = 14,
            render_power = 3,
            color        = "rgba(00000050)",
        },
        blur = { enabled = false }, -- M3 surfaces are opaque
    },

    animations = { enabled = true },

    dwindle = { preserve_split = true },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
        background_color        = c.surface,
        focus_on_activate       = false, -- Keep focus on active window; prevent background apps shifting view
    },

    input = {
        kb_layout    = "us",
        follow_mouse = 1,
        touchpad = { natural_scroll = true, tap_to_click = true },
    },
})

-- Material 3 motion: the "emphasized" easing set
hl.curve("emphasized",      { type = "bezier", points = { {0.2, 0},    {0, 1}      } })
hl.curve("emphasizedDecel", { type = "bezier", points = { {0.05, 0.7}, {0.1, 1}    } })
hl.curve("emphasizedAccel", { type = "bezier", points = { {0.3, 0},    {0.8, 0.15} } })

hl.animation({ leaf = "global",     enabled = true, speed = 4, bezier = "emphasized" })
hl.animation({ leaf = "windowsIn",  enabled = true, speed = 4, bezier = "emphasizedDecel", style = "popin 90%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2, bezier = "emphasizedAccel", style = "popin 90%" })
hl.animation({ leaf = "layersIn",   enabled = true, speed = 3, bezier = "emphasizedDecel", style = "fade" })
hl.animation({ leaf = "layersOut",  enabled = true, speed = 2, bezier = "emphasizedAccel", style = "fade" })
hl.animation({ leaf = "fade",       enabled = true, speed = 3, bezier = "emphasized" })
hl.animation({ leaf = "border",     enabled = true, speed = 3, bezier = "emphasized" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "emphasized", style = "slide" })

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

---------------------
---- KEYBINDINGS ----
---------------------
-- Windows-style shortcuts only. F11 is left to each app.
local exec     = hl.dsp.exec_cmd
local launcher = "pkill -x fuzzel || fuzzel"

-- The ones you asked for
hl.bind("ALT + F4",               hl.dsp.window.close())
hl.bind("CTRL + SHIFT + Escape",  exec("gnome-system-monitor"))
hl.bind("ALT + Return",           exec(launcher))
hl.bind("SUPER + period",         exec("flatpak run com.tomjwatson.Emote"))

-- Start menu / apps
hl.bind("SUPER + Super_L",        exec(launcher), { release = true }) -- tap the Windows key
hl.bind("SUPER + R",              exec(launcher))
hl.bind("SUPER + E",              exec("nautilus --new-window"))
hl.bind("SUPER + L",              exec("hyprlock"))
hl.bind("SUPER + I",              exec(bin .. "m3-settings"))
hl.bind("SUPER + N",              exec("swaync-client -t -sw"))
hl.bind("SUPER + V",              exec("cliphist list | fuzzel --dmenu --placeholder 'Clipboard' | cliphist decode | wl-copy"))
hl.bind("CTRL + ALT + Delete",    exec(bin .. "m3-power"))

-- Screenshots (COSMIC-style drag and done)
hl.bind("SUPER + SHIFT + S",      exec(bin .. "m3-screenshot region"))
hl.bind("Print",                  exec(bin .. "m3-screenshot region"))
hl.bind("SUPER + Print",          exec(bin .. "m3-screenshot full"))

-- Alt+Tab
hl.bind("ALT + Tab", function()
    hl.dispatch(hl.dsp.window.cycle_next())
    hl.dispatch(hl.dsp.window.bring_to_top())
end)
hl.bind("ALT + SHIFT + Tab", function()
    hl.dispatch(hl.dsp.window.cycle_next({ next = false }))
    hl.dispatch(hl.dsp.window.bring_to_top())
end)

-- Snap: Super+Up maximises, Super+Down restores/minimizes, Super+Left/Right moves the window
hl.bind("SUPER + up", function()
    local w = hl.get_active_window()
    if w and w.fullscreen == 0 then hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized" })) end
end)
hl.bind("SUPER + down", function()
    local w = hl.get_active_window()
    if w and w.fullscreen ~= 0 then
        hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized" }))
    else
        hl.exec_cmd(bin .. "m3-minimize window")
    end
end)
hl.bind("SUPER + M",         exec(bin .. "m3-minimize window"))
hl.bind("SUPER + SHIFT + M", exec(bin .. "m3-minimize restore"))
hl.bind("SUPER + D",         exec(bin .. "m3-minimize toggle-desktop"))
hl.bind("SUPER + BackSpace", exec(bin .. "m3-minimize menu"))
hl.bind("SUPER + left",           hl.dsp.window.move({ direction = "left" }))
hl.bind("SUPER + right",          hl.dsp.window.move({ direction = "right" }))
hl.bind("SUPER + SHIFT + left",   hl.dsp.window.move({ monitor = "l" }))
hl.bind("SUPER + SHIFT + right",  hl.dsp.window.move({ monitor = "r" }))

-- Virtual desktops
hl.bind("SUPER + CTRL + left",          hl.dsp.focus({ workspace = "r-1" }))
hl.bind("SUPER + CTRL + right",         hl.dsp.focus({ workspace = "r+1" }))
hl.bind("SUPER + CTRL + D",             hl.dsp.focus({ workspace = "empty" }))
hl.bind("SUPER + CTRL + SHIFT + left",  hl.dsp.window.move({ workspace = "r-1" }))
hl.bind("SUPER + CTRL + SHIFT + right", hl.dsp.window.move({ workspace = "r+1" }))

-- Mouse: Super+drag moves, Super+right-drag resizes (there are no title bars to grab on every app)
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Media keys
hl.bind("XF86AudioRaiseVolume",  exec(bin .. "m3-osd volume up"),       { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  exec(bin .. "m3-osd volume down"),     { locked = true, repeating = true })
hl.bind("XF86AudioMute",         exec(bin .. "m3-osd volume mute"),     { locked = true })
hl.bind("XF86AudioMicMute",      exec(bin .. "m3-osd mic mute"),        { locked = true })
hl.bind("XF86MonBrightnessUp",   exec(bin .. "m3-osd brightness up"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", exec(bin .. "m3-osd brightness down"), { locked = true, repeating = true })
hl.bind("XF86AudioNext",         exec("playerctl next"),       { locked = true })
hl.bind("XF86AudioPlay",         exec("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause",        exec("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",         exec("playerctl previous"),   { locked = true })

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

hl.window_rule({
    name  = "float-transient-event-windows",
    match = { title = ".*(event window|reg\\.exe|winedevice|xalia).*" },
    float = true,
    no_focus = true,
})

hl.window_rule({
    name  = "float-wine-exe-titles",
    match = { title = ".*[a-zA-Z]:\\\\.*" },
    float = true,
    no_focus = true,
})

hl.window_rule({
    name  = "float-wine-exe-classes",
    match = { class = ".*\\.exe$" },
    float = true,
    no_focus = true,
})

hl.window_rule({
    name  = "float-empty-xwayland",
    match = { xwayland = true, title = "^$" },
    float = true,
    no_focus = true,
})

hl.window_rule({
    name  = "float-small-tools",
    match = { class = "^(emote|com\\.tomjwatson\\.Emote|org\\.pulseaudio\\.pavucontrol|pavucontrol|zenity|xdg-desktop-portal-gtk|io\\.github\\.m3hyprland\\.Snip)$" },
    float = true,
})

-- M3 scrim behind the search bar
hl.layer_rule({ name = "launcher-scrim", match = { namespace = "^launcher$" }, dim_around = true })

-- What the Settings app (Super+I) controls: monitors, keyboard, mouse, gaps, rounding...
pcall(dofile, home .. "/.config/hypr/settings.lua")

-- Your own overrides (extra binds, anything the Settings app doesn't cover)
pcall(dofile, home .. "/.config/hypr/user.lua")
