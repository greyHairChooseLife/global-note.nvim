local preset = require("global-note.preset")
local utils = require("global-note.utils")

local M = {
  _inited = false,
  _open_windows = {}, -- Add this new field to track open windows

  _default_preset_default_values = {
    filename = "global.md",
    ---@diagnostic disable-next-line: param-type-mismatch
    directory = utils.joinpath(vim.fn.stdpath("data"), "global-note"),
    title = "Global note",
    command_name = "GlobalNote",
    window_config = function()
      local window_height = vim.api.nvim_list_uis()[1].height
      local window_width = vim.api.nvim_list_uis()[1].width
      return {
        relative = "editor",
        border = "single",
        title = "Note",
        title_pos = "center",
        width = math.floor(0.7 * window_width),
        height = math.floor(0.85 * window_height),
        row = math.floor(0.05 * window_height),
        col = math.floor(0.15 * window_width),
      }
    end,
    post_open = function(_, _) end,
    autosave = true,
  },
}

---@class GlobalNote_UserPreset
---@field filename? string|fun(): string? Filename of the note.
---@field directory? string|fun(): string? Directory to keep notes.
---@field title? string|fun(): string? Floating window title.
---@field command_name? string Ex command name.
---@field window_config? table|fun(): table A nvim_open_win config.
---@field post_open? fun(buffer_id: number, window_id: number) It's called after the window creation.
---@field autosave? boolean Whether to use autosave.

---@class GlobalNote_UserConfig: GlobalNote_UserPreset
---@field additional_presets? { [string]: GlobalNote_UserPreset }

M._setup_resize_autocmd = function()
  vim.api.nvim_create_autocmd("VimResized", {
    group = vim.api.nvim_create_augroup("GlobalNoteResize", { clear = true }),
    callback = function()
      -- Reapply window configurations for all open windows
      for name, info in pairs(M._open_windows) do
        local win_id = info.window_id
        local preset_obj = info.preset

        -- Check if window still exists
        if win_id and vim.api.nvim_win_is_valid(win_id) then
          -- Get fresh window config
          local expanded_preset = preset_obj:_expand_options()
          if expanded_preset then
            -- Update window configuration
            vim.api.nvim_win_set_config(win_id, expanded_preset.window_config)
          end
        else
          -- Window no longer exists, remove from tracking
          M._open_windows[name] = nil
        end
      end
    end,
  })
end

---@return boolean Whether the specified note is open
---@param preset_name? string The name of the preset to check. If nil or empty, checks the default preset.
M.is_note_open = function(preset_name)
  preset_name = preset_name or ""
  return M._open_windows[preset_name] ~= nil
end

---@return string[] List of names of open notes
M.get_open_notes = function()
  local open_notes = {}
  for name, _ in pairs(M._open_windows) do
    table.insert(open_notes, name)
  end
  return open_notes
end

---@return number|nil Window ID for the specified note, nil if not open
---@param preset_name? string The name of the preset to get the window for. If nil or empty, gets the default preset window.
M.get_note_window = function(preset_name)
  preset_name = preset_name or ""
  local info = M._open_windows[preset_name]
  return info and info.window_id or nil
end

-- Modify the setup function to initialize the autocmd
---@param options? GlobalNote_UserConfig
M.setup = function(options)
  local user_options = vim.deepcopy(options or {})
  user_options.additional_presets = user_options.additional_presets or {}

  -- Setup default preset
  local default_preset_options =
    vim.tbl_extend("force", M._default_preset_default_values, user_options)
  default_preset_options.additional_presets = nil
  default_preset_options.name = ""
  M._default_preset = preset.new(default_preset_options)

  -- Setup additional presets
  M._presets = {}
  for key, value in pairs(user_options.additional_presets) do
    local preset_options = vim.tbl_extend("force", M._default_preset, value)
    preset_options.command_name = value.command_name
    preset_options.name = key
    M._presets[key] = preset.new(preset_options)
  end

  -- Initialize the _open_windows table and set up the resize autocmd
  M._open_windows = {}
  M._setup_resize_autocmd()
  M._inited = true
end

---Opens or closes a note in a floating window.
---@param preset_name? string preset to use. If it's not set, use default preset.
M.toggle_note = function(preset_name)
  if not M._inited then
    M.setup()
  end

  local p = M._default_preset
  if preset_name ~= nil and preset_name ~= "" then
    p = M._presets[preset_name]
    if p == nil then
      local template = "The preset with the name %s doesn't eixst"
      local message = string.format(template, preset_name)
      error(message)
    end
  end

  p:toggle()
end

return M
