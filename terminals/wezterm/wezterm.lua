-- ~/.config/wezterm/wezterm.lua
-- Kitty replacement first: preserve Catppuccin/font rendering and native
-- terminal scrollback for Claude Code / Pi.
-- Optional WezTerm-as-tmux-replacement bindings are preserved below but disabled
-- by default so Ctrl-b flows through to real tmux sessions.

local wezterm = require("wezterm")
local act = wezterm.action

local config = wezterm.config_builder()

-- -----------------------------------------------------------------------------
-- Appearance: Kitty-inspired, but let WezTerm do the good font/rendering bits.
-- -----------------------------------------------------------------------------
config.font = wezterm.font_with_fallback({
  -- Keep your current face, but use WezTerm's fallback/shaping pipeline for
  -- Nerd Font symbols, emoji, and odd glyphs instead of pinning everything
  -- to a single Kitty-style font declaration.
  { family = "JetBrainsMonoNL Nerd Font Mono" },
  "Apple Color Emoji",
})
config.font_size = 13.0
config.audible_bell = "Disabled"
config.window_background_opacity = 0.95
-- Laptop-first startup size, measured in terminal cells rather than pixels.
config.initial_cols = 140
config.initial_rows = 40
config.scrollback_lines = 10000
config.alternate_buffer_wheel_scroll_speed = 1
config.enable_scroll_bar = false

-- Kitty keyboard protocol keeps modern Neovim / CLI key handling closer to Kitty.
config.enable_kitty_keyboard = true

-- On macOS, make Option behave as terminal Alt/Meta, matching tmux's M-Arrow
-- resize bindings rather than entering accented characters.
config.send_composed_key_when_left_alt_is_pressed = false
config.send_composed_key_when_right_alt_is_pressed = false

-- Catppuccin Macchiato: use WezTerm's built-in scheme name, then pin the
-- Kitty-proven palette below so the theme survives even if scheme names change.
config.color_scheme = "Catppuccin Macchiato"
config.colors = {
  foreground = "#cad3f5",
  background = "#24273a",
  cursor_bg = "#f4dbd6",
  cursor_fg = "#24273a",
  cursor_border = "#f4dbd6",
  selection_fg = "#24273a",
  selection_bg = "#f4dbd6",
  scrollbar_thumb = "#6e738d",
  split = "#6e738d",
  ansi = {
    "#494d64", -- black
    "#ed8796", -- red
    "#a6da95", -- green
    "#eed49f", -- yellow
    "#8aadf4", -- blue
    "#f5bde6", -- magenta
    "#8bd5ca", -- cyan
    "#b8c0e0", -- white
  },
  brights = {
    "#5b6078", -- bright black
    "#ed8796", -- bright red
    "#a6da95", -- bright green
    "#eed49f", -- bright yellow
    "#8aadf4", -- bright blue
    "#f5bde6", -- bright magenta
    "#8bd5ca", -- bright cyan
    "#a5adcb", -- bright white
  },
  tab_bar = {
    background = "#181926",
    active_tab = {
      fg_color = "#181926",
      bg_color = "#c6a0f6",
      intensity = "Bold",
    },
    inactive_tab = {
      fg_color = "#cad3f5",
      bg_color = "#1e2030",
    },
    inactive_tab_hover = {
      fg_color = "#cad3f5",
      bg_color = "#363a4f",
    },
    new_tab = {
      fg_color = "#cad3f5",
      bg_color = "#181926",
    },
    new_tab_hover = {
      fg_color = "#181926",
      bg_color = "#8aadf4",
    },
  },
}

-- -----------------------------------------------------------------------------
-- tmux-like tabs/status
-- -----------------------------------------------------------------------------
config.tab_bar_at_bottom = false -- tmux status-position top
config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = false
config.tab_max_width = 32

local function basename(path)
  if not path or path == "" then
    return "~"
  end
  path = path:gsub("/$", "")
  return path:match("([^/]+)$") or path
end

local function cwd_basename(pane)
  local cwd = pane:get_current_working_dir()
  if not cwd then
    return "~"
  end

  -- Newer WezTerm exposes a Url object with file_path; older versions stringify.
  local ok, file_path = pcall(function()
    return cwd.file_path
  end)
  if ok and file_path then
    return basename(file_path)
  end

  local uri = tostring(cwd)
  uri = uri:gsub("^file://[^/]*", "")
  uri = uri:gsub("%%20", " ")
  return basename(uri)
end

wezterm.on("format-tab-title", function(tab, _, _, _, _, max_width)
  local title = tab.active_pane.title
  if title == "" then
    title = "shell"
  end

  title = wezterm.truncate_right(title, math.max(6, max_width - 6))
  local index = tab.tab_index + 1

  if tab.is_active then
    return {
      { Background = { Color = "#c6a0f6" } },
      { Foreground = { Color = "#181926" } },
      { Attribute = { Intensity = "Bold" } },
      { Text = " " .. index .. ":" .. title .. " " },
    }
  end

  return {
    { Background = { Color = "#1e2030" } },
    { Foreground = { Color = "#cad3f5" } },
    { Text = " " .. index .. ":" .. title .. " " },
  }
end)

wezterm.on("update-right-status", function(window, pane)
  local cwd = cwd_basename(pane)
  local workspace = window:active_workspace()

  window:set_right_status(wezterm.format({
    { Foreground = { Color = "#8aadf4" } },
    { Text = " dir:" .. cwd .. " " },
    { Foreground = { Color = "#c6a0f6" } },
    { Text = " session:" .. workspace .. " " },
  }))
end)

-- -----------------------------------------------------------------------------
-- Key bindings
-- -----------------------------------------------------------------------------
-- Default mode is intentionally Kitty-like, not tmux-like. This lets Ctrl-b pass
-- through to real tmux, so `tmux a -t infra-central` keeps Ctrl-b z, Ctrl-b [,
-- Ctrl-b l, and other tmux bindings working normally.
local enable_wezterm_tmux_replacement_keys = false

config.keys = {
  -- Direct WezTerm copy-mode entry for Claude Code / Pi output. This avoids
  -- stealing Ctrl-b from tmux; WezTerm's default Ctrl-Shift-X still works too.
  { key = "x", mods = "CMD|SHIFT", action = act.ActivateCopyMode },

  -- Shift+Enter inserts a newline in Claude Code / Pi instead of submitting.
  -- Send the CSI-u encoding (ESC [ 13 ; 2 u) rather than a bare ESC+CR: it is a
  -- single atomic sequence that survives tmux's escape-time/Alt handling and
  -- matches `extended-keys-format csi-u`, so it forwards intact through tmux.
  { key = "Enter", mods = "SHIFT", action = act.SendString("\x1b[13;2u") },
}

-- Disabled tmux-replacement layer. Flip enable_wezterm_tmux_replacement_keys to
-- true if you want WezTerm itself to handle tmux-style prefix panes/tabs instead
-- of running tmux inside WezTerm.
if enable_wezterm_tmux_replacement_keys then
  config.leader = { key = "b", mods = "CTRL", timeout_milliseconds = 1000 }

  local rename_current_tab = act.PromptInputLine({
    description = "Rename tab/window",
    action = wezterm.action_callback(function(window, _, line)
      if line and line ~= "" then
        window:active_tab():set_title(line)
      end
    end),
  })

  local tmux_replacement_keys = {
    -- Send a literal Ctrl-b with Ctrl-b Ctrl-b, matching tmux.
    { key = "b", mods = "LEADER|CTRL", action = act.SendKey({ key = "b", mods = "CTRL" }) },

    -- Panes: tmux prefix % / prefix " plus the friendlier | / - aliases.
    -- Shifted punctuation is terminal/layout dependent, so bind both the
    -- character and the shifted physical key forms.
    { key = "%", mods = "LEADER", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
    { key = "%", mods = "LEADER|SHIFT", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
    { key = "5", mods = "LEADER|SHIFT", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
    { key = "|", mods = "LEADER", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
    { key = "|", mods = "LEADER|SHIFT", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
    { key = "\\", mods = "LEADER", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
    { key = "\"", mods = "LEADER", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
    { key = "\"", mods = "LEADER|SHIFT", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
    { key = "'", mods = "LEADER|SHIFT", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
    { key = "-", mods = "LEADER", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
    { key = "x", mods = "LEADER", action = act.CloseCurrentPane({ confirm = true }) },
    { key = "z", mods = "LEADER", action = act.TogglePaneZoomState },

    -- Pane navigation. I intentionally keep Ctrl-h/j/k/l free for Neovim.
    -- Ctrl-b l follows tmux window-toggle muscle memory, so use prefix arrows
    -- (or prefix h/j/k for the other directions) at the WezTerm layer.
    { key = "h", mods = "LEADER", action = act.ActivatePaneDirection("Left") },
    { key = "j", mods = "LEADER", action = act.ActivatePaneDirection("Down") },
    { key = "k", mods = "LEADER", action = act.ActivatePaneDirection("Up") },
    { key = "L", mods = "LEADER|SHIFT", action = act.ActivatePaneDirection("Right") },
    { key = "LeftArrow", mods = "LEADER", action = act.ActivatePaneDirection("Left") },
    { key = "DownArrow", mods = "LEADER", action = act.ActivatePaneDirection("Down") },
    { key = "UpArrow", mods = "LEADER", action = act.ActivatePaneDirection("Up") },
    { key = "RightArrow", mods = "LEADER", action = act.ActivatePaneDirection("Right") },

    -- Resize panes like ~/.tmux.conf: Alt-arrow by 5, prefix Shift-arrow by 10.
    { key = "LeftArrow", mods = "ALT", action = act.AdjustPaneSize({ "Left", 5 }) },
    { key = "DownArrow", mods = "ALT", action = act.AdjustPaneSize({ "Down", 5 }) },
    { key = "UpArrow", mods = "ALT", action = act.AdjustPaneSize({ "Up", 5 }) },
    { key = "RightArrow", mods = "ALT", action = act.AdjustPaneSize({ "Right", 5 }) },
    { key = "LeftArrow", mods = "LEADER|SHIFT", action = act.AdjustPaneSize({ "Left", 10 }) },
    { key = "DownArrow", mods = "LEADER|SHIFT", action = act.AdjustPaneSize({ "Down", 10 }) },
    { key = "UpArrow", mods = "LEADER|SHIFT", action = act.AdjustPaneSize({ "Up", 10 }) },
    { key = "RightArrow", mods = "LEADER|SHIFT", action = act.AdjustPaneSize({ "Right", 10 }) },

    -- Tabs/windows as tmux windows: 1-based selection, renumbering is native.
    { key = "c", mods = "LEADER", action = act.SpawnTab("CurrentPaneDomain") },
    { key = "&", mods = "LEADER|SHIFT", action = act.CloseCurrentTab({ confirm = true }) },
    { key = "n", mods = "LEADER", action = act.ActivateTabRelative(1) },
    { key = "p", mods = "LEADER", action = act.ActivateTabRelative(-1) },
    { key = "l", mods = "LEADER", action = act.ActivateLastTab },
    { key = "1", mods = "LEADER", action = act.ActivateTab(0) },
    { key = "2", mods = "LEADER", action = act.ActivateTab(1) },
    { key = "3", mods = "LEADER", action = act.ActivateTab(2) },
    { key = "4", mods = "LEADER", action = act.ActivateTab(3) },
    { key = "5", mods = "LEADER", action = act.ActivateTab(4) },
    { key = "6", mods = "LEADER", action = act.ActivateTab(5) },
    { key = "7", mods = "LEADER", action = act.ActivateTab(6) },
    { key = "8", mods = "LEADER", action = act.ActivateTab(7) },
    { key = "9", mods = "LEADER", action = act.ActivateTab(-1) },

    -- tmux-ish utility bindings.
    { key = "[", mods = "LEADER", action = act.ActivateCopyMode },
    { key = "]", mods = "LEADER", action = act.PasteFrom("Clipboard") },
    { key = "r", mods = "LEADER", action = act.ReloadConfiguration },
    { key = ":", mods = "LEADER|SHIFT", action = act.ActivateCommandPalette },
    { key = ",", mods = "LEADER", action = rename_current_tab },
    { key = "w", mods = "LEADER", action = act.ShowLauncherArgs({ flags = "FUZZY|TABS" }) },
  }

  for _, key in ipairs(tmux_replacement_keys) do
    table.insert(config.keys, key)
  end
end

-- -----------------------------------------------------------------------------
-- WezTerm copy mode tweaks
-- -----------------------------------------------------------------------------
local copy_mode = wezterm.gui.default_key_tables().copy_mode

local function remove_copy_mode_binding(key, mods)
  for i = #copy_mode, 1, -1 do
    if copy_mode[i].key == key and copy_mode[i].mods == mods then
      table.remove(copy_mode, i)
    end
  end
end

-- tmux-yank parity: y copies, clears the visual selection, and STAYS in copy
-- mode instead of jumping back to the bottom. Press Enter for copy-and-exit.
remove_copy_mode_binding("y", "NONE")
table.insert(copy_mode, 1, {
  key = "y",
  mods = "NONE",
  action = act.Multiple({
    act.CopyTo("ClipboardAndPrimarySelection"),
    act.ClearSelection,
    act.CopyMode("ClearSelectionMode"),
  }),
})

table.insert(copy_mode, 2, {
  key = "Enter",
  mods = "NONE",
  action = act.Multiple({
    act.CopyTo("ClipboardAndPrimarySelection"),
    act.CopyMode("MoveToScrollbackBottom"),
    act.CopyMode("Close"),
  }),
})

-- Search in copy mode. WezTerm does not exactly model tmux's `/` forward
-- search vs `?` backward search; both enter the search pattern editor, then
-- use n/N (or Ctrl-n/Ctrl-p while typing) to move between matches.
table.insert(copy_mode, 3, { key = "/", mods = "NONE", action = act.CopyMode("EditPattern") })
table.insert(copy_mode, 4, { key = "?", mods = "NONE", action = act.CopyMode("EditPattern") })
table.insert(copy_mode, 5, { key = "/", mods = "SHIFT", action = act.CopyMode("EditPattern") })
table.insert(copy_mode, 6, { key = "n", mods = "NONE", action = act.CopyMode("NextMatch") })
table.insert(copy_mode, 7, { key = "N", mods = "SHIFT", action = act.CopyMode("PriorMatch") })

config.key_tables = {
  copy_mode = copy_mode,
}

return config
