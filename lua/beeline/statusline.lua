---@module "uv"

local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup

---@type uv.uv_timer_t?
local timer = nil

local function time()
  if not timer then
    timer = vim.uv.new_timer()
  end

  assert(timer)
  timer:start(1000, 1000, vim.schedule_wrap(vim.cmd.redrawstatus))

  return '%#StatusLineTime# ' .. os.date('%I:%M:%S %p ', os.time())
end

local command_icon = '  '
local normal_icon = '  '
local insert_icon = '  '
local select_icon = '  '
local replace_icon = '  '
local confirm_icon = '❔ '

--- Enumerates the different modes and their respective text and highlight groups
---@type { [string]: { text: string, hl: string, icon: string } }
local modes = {
  -- Normal
  ['n'] = { text = 'NORMAL', hl = 'StatusLineNormalMode', icon = normal_icon },
  ['no'] = { text = 'NORMAL (no)', hl = 'StatusLineNormalMode', icon = normal_icon },
  ['nov'] = { text = 'NORMAL (nov)', hl = 'StatusLineNormalMode', icon = normal_icon },
  ['noV'] = { text = 'NORMAL (noV)', hl = 'StatusLineNormalMode', icon = normal_icon },
  ['noCTRL-V'] = { text = 'NORMAL', hl = 'StatusLineNormalMode', icon = normal_icon },
  ['niI'] = { text = 'NORMAL i', hl = 'StatusLineNormalMode', icon = normal_icon },
  ['niR'] = { text = 'NORMAL r', hl = 'StatusLineNormalMode', icon = normal_icon },
  ['niV'] = { text = 'NORMAL v', hl = 'StatusLineNormalMode', icon = normal_icon },

  -- Visual
  ['v'] = { text = 'VISUAL', hl = 'StatusLineVisualMode', icon = '  ' },
  ['vs'] = { text = 'V-CHAR (Ctrl O)', hl = 'StatusLineVisualMode', icon = ' 󱡠 ' },
  ['V'] = { text = 'V-LINE', hl = 'StatusLineVisualMode', icon = '  ' },
  ['Vs'] = { text = 'V-LINE', hl = 'StatusLineVisualMode', icon = '  ' },
  [''] = { text = 'V-BLOCK', hl = 'StatusLineVisualMode', icon = ' 󰣟 ' },

  -- Insert
  ['i'] = { text = 'INSERT', hl = 'StatusLineInsertMode', icon = insert_icon },
  ['ic'] = { text = 'INSERT (completion)', hl = 'StatusLineInsertMode', icon = insert_icon },
  ['ix'] = { text = 'INSERT completion', hl = 'StatusLineInsertMode', icon = insert_icon },

  -- Terminal   
  ['t'] = { text = 'TERMINAL', hl = 'StatusLineTerminalMode', icon = '  ' },
  ['nt'] = { text = 'NTERMINAL', hl = 'StatusLineTerminalMode', icon = normal_icon },
  ['ntT'] = { text = 'NTERMINAL (ntT)', hl = 'StatusLineTerminalMode', icon = normal_icon },

  -- Replace
  ['R'] = { text = 'REPLACE', hl = 'StatusLineReplaceMode', icon = replace_icon },
  ['Rc'] = { text = 'REPLACE (Rc)', hl = 'StatusLineReplaceMode', icon = replace_icon },
  ['Rx'] = { text = 'REPLACEa (Rx)', hl = 'StatusLineReplaceMode', icon = replace_icon },
  ['Rv'] = { text = 'V-REPLACE', hl = 'StatusLineReplaceMode', icon = replace_icon },
  ['Rvc'] = { text = 'V-REPLACE (Rvc)', hl = 'StatusLineReplaceMode', icon = replace_icon },
  ['Rvx'] = { text = 'V-REPLACE (Rvx)', hl = 'StatusLineReplaceMode', icon = replace_icon },

  -- Select
  ['s'] = { text = 'SELECT', hl = 'StatusLineSelectMode', icon = select_icon },
  ['S'] = { text = 'S-LINE', hl = 'StatusLineSelectMode', icon = select_icon },
  [''] = { text = 'S-BLOCK', hl = 'StatusLineSelectMode', icon = select_icon },

  -- Command
  ['c'] = { text = 'COMMAND', hl = 'StatusLineCommandMode', icon = command_icon },
  ['cv'] = { text = 'COMMAND', hl = 'StatusLineCommandMode', icon = command_icon },
  ['ce'] = { text = 'COMMAND', hl = 'StatusLineCommandMode', icon = command_icon },

  -- Confirm
  ['r'] = { text = 'PROMPT', hl = 'StatusLineConfirmMode', icon = confirm_icon },
  ['rm'] = { text = 'MORE', hl = 'StatusLineConfirmMode', icon = confirm_icon },
  ['r?'] = { text = 'CONFIRM', hl = 'StatusLineConfirmMode', icon = confirm_icon },
  ['x'] = { text = 'CONFIRM', hl = 'StatusLineConfirmMode', icon = confirm_icon },

  -- Shell
  ['!'] = { text = 'SHELL', hl = 'StatusLineTerminalMode', icon = '  ' },
}

local function mode()
  local entry = modes[vim.api.nvim_get_mode().mode]
  local entry_hl = '%#' .. entry.hl .. '#'
  local current_mode = entry_hl .. entry.icon .. entry.text .. ' ' .. entry_hl .. ''

  local recording_register = vim.fn.reg_recording()

  if recording_register == '' then
    return current_mode
  end

  return '%#StatusLineMacro# 󰑊 MACRO ' .. recording_register .. ' '
end

local function truncate_filename(filename)
  local max_len = 20
  local len = #filename

  if len <= max_len then
    return filename
  end

  local base_name, extension = filename:match('(.*)%.(.*)')
  if not base_name then
    base_name = filename
    extension = ''
  end

  local base_len = max_len - #extension - 1
  local partial_len = math.floor(base_len / 2)

  return base_name:sub(1, partial_len) .. '…' .. base_name:sub(-partial_len) .. '.' .. extension
end

local function file_info()
  local icon = ' 󰈚 '
  local buf = vim.api.nvim_win_get_buf(0)
  local path = vim.api.nvim_buf_get_name(buf)
  local name = (path == '' and 'Empty ') or path:match('([^/\\]+)[/\\]*$')

  if name == '[Command Line]' then
    return '  CmdHistory '
  end

  if #name > 25 then
    name = truncate_filename(name)
  end

  if name ~= 'Empty ' then
    local _, f_ext = name:match('(.*)%.(.*)')
    local ft_icon, _ = require('nvim-web-devicons').get_icon(name, f_ext)
    icon = ((ft_icon ~= nil) and ' %#StatusLineFtIcon#' .. ft_icon) or icon

    name = ' ' .. name .. ' '
  end

  local filetypes = {
    DressingInput = { icon = '  ', label = 'INPUT BOX' },
    poon = { icon = '  ', label = 'POON' },
    lspinfo = { icon = '  ', label = 'LSP INFO' },
    mason = { icon = '%#StatusLineMason# 󱌣 ', label = 'MASON' },
    undotree = { icon = '  ', label = 'UNDOTREE' },
    NvimTree = { icon = '%#StatusLineNvimTree#  ', label = 'NVIMTREE' },
    lazy = { icon = '%#StatusLineLazy# 💤 ', label = 'LAZY' },
    Trouble = { icon = '%#StatusLineTrouble#  ', label = 'TROUBLE' },
    snacks_picker_input = { icon = '  ', label = 'PICKER' },
    snacks_input = { icon = ' 󰙏 ', label = 'INPUT' },
    neotest = { icon = ' 󰙨 ', label = 'NEOTEST' },
  }

  for k, v in pairs(filetypes) do
    if vim.bo.ft:find(k) ~= nil then
      return v.icon .. v.label .. ' ' .. ''
    end
  end

  return icon .. '%#StatusLineFileInfo#' .. name .. '%#StatusLineDefaultSep#' .. ''
end

local function git()
  local bufnr = vim.api.nvim_win_get_buf(0)
  if not vim.b[bufnr].gitsigns_head or vim.b[bufnr].gitsigns_git_status then
    return '%#StatusLineEmptySpace#'
  end

  local git_status = vim.b[bufnr].gitsigns_status_dict

  local added = (git_status.added and git_status.added ~= 0) and ('%#StatusLineGitAdd#  ' .. git_status.added) or ''
  local changed = (git_status.changed and git_status.changed ~= 0) and ('%#StatusLineGitChange#  ' .. git_status.changed) or ''
  local removed = (git_status.removed and git_status.removed ~= 0) and ('%#StatusLineGitRemove#  ' .. git_status.removed) or ''
  local branch_name = '%#StatusLineGitBranch#  ' .. git_status.head

  return branch_name .. added .. changed .. removed .. '%#StatusLineDefaultSep#  '
end

local virt_ns = vim.api.nvim_create_namespace('SearchVirt')
local searchcount_text = ''

---@class SearchCount
---@field current number
---@field exact_match number
---@field incomplete number
---@field maxcount number
---@field total number

---Draws the virtual text into the buffer
---@param count SearchCount
local function draw_virt(count)
  if not count or (count.current == 0 and count.total == 0) then
    return
  end
  vim.api.nvim_buf_set_extmark(0, virt_ns, vim.api.nvim_win_get_cursor(0)[1] - 1, 0, {
    virt_text = { { '[' .. count.current .. '/' .. count.total .. ']', 'SearchVirtualText' } },
    virt_text_pos = 'eol',
    hl_mode = 'combine',
  })
end

vim.api.nvim_create_autocmd('CursorMoved', {
  group = augroup('StatusLineSearchCount', { clear = true }),
  callback = function()
    local searchcount = vim.fn.searchcount()
    vim.api.nvim_buf_clear_namespace(0, virt_ns, 0, -1)
    if vim.v.hlsearch == 0 then
      return
    end

    if searchcount.exact_match == 0 or not searchcount.current or not searchcount.total then
      vim.schedule(vim.cmd.nohlsearch)
      searchcount_text = ''
      vim.api.nvim_buf_clear_namespace(0, virt_ns, 0, -1)
    else
      searchcount_text = searchcount.current .. '/' .. searchcount.total
      draw_virt(searchcount)
    end
  end,
})

local function search()
  return #searchcount_text == 0 and '' or '%#StatusLineSearchCount#󰍉 ' .. searchcount_text
end

local function lsp_diagnostics()
  if vim.bo.ft == 'lazy' then
    return ''
  end

  local count = vim.diagnostic.count(0)
  local errors = count[1]
  local warnings = count[2]
  local hints = count[3]
  local info = count[4]

  errors = (errors and errors > 0) and ('%#StatusLineLspError#󰅚 ' .. errors .. ' ') or ''
  warnings = (warnings and warnings > 0) and ('%#StatusLineLspWarning# ' .. warnings .. ' ') or ''
  hints = (hints and hints > 0) and ('%#StatusLineLspHints#󱡴 ' .. hints .. ' ') or ''
  info = (info and info > 0) and ('%#StatusLineLspInfo# ' .. info .. ' ') or ''

  return vim.o.columns > 140 and errors .. warnings .. hints .. info or ''
end

local function lsp_status()
  if rawget(vim, 'lsp') then
    for _, client in ipairs(vim.lsp.get_clients()) do
      local buf = vim.api.nvim_win_get_buf(0)
      if client.attached_buffers[buf] then
        return (vim.o.columns > 100 and '%#StatusLineLspStatus#' .. '   LSP [' .. client.name .. '] ') or '   LSP '
      end
    end
  end

  return ''
end

local function cursor_position()
  local current_mode = vim.fn.mode(true)
  local v_line, v_col = vim.fn.line('v'), vim.fn.col('v')
  local cur_line, cur_col = vim.fn.line('.'), vim.fn.col('.')

  if current_mode == '' then
    return '%#StatusLineVisualMode#'
      .. ''
      .. ' Ln '
      .. math.abs(v_line - cur_line) + 1
      .. ', Col '
      .. math.abs(v_col - cur_col) + 1
      .. ' '
  end

  local total_lines = math.abs(v_line - cur_line) + 1
  if current_mode == 'V' then
    local cur_line_is_bigger = v_line and cur_line and v_line < cur_line

    if cur_line_is_bigger then
      return '%#StatusLineVisualMode#' .. ' Ln ' .. v_line .. ' - Ln %l ⎸ ' .. total_lines
    else
      return '%#StatusLineVisualMode#' .. ' Ln %l - Ln ' .. v_line .. ' ⎸ ' .. total_lines
    end
  end

  if current_mode == 'v' then
    if v_line == cur_line then
      return '%#StatusLineVisualMode#' .. ' Col ' .. math.abs(v_col - cur_col) + 1 .. ' '
    else
      return '%#StatusLineVisualMode#' .. ' Ln ' .. total_lines .. ' '
    end
  end

  return vim.o.columns > 140 and '%#StatusLinePos# Ln %l, Col %c ' or ''
end

local function cwd()
  local dir_name = '%#StatusLineCwd#' .. '' .. ' 󰉖 ' .. vim.fn.fnamemodify(vim.fn.getcwd(), ':t') .. ' '
  return (vim.o.columns > 85 and dir_name) or ''
end

local toggle = false
local macro_timer = vim.uv.new_timer()
local macrohl = vim.api.nvim_create_augroup('MacroHL', { clear = true })

autocmd('RecordingEnter', {
  desc = 'Toggles highlight group for the statusline macro segment',
  group = macrohl,
  callback = function()
    assert(macro_timer)

    macro_timer:start(
      0,
      500,
      vim.schedule_wrap(function()
        if not toggle then
          vim.api.nvim_set_hl(0, 'StatusLineMacro', { link = 'StatusLineMacroA' })
          toggle = true
        else
          vim.api.nvim_set_hl(0, 'StatusLineMacro', { link = 'StatusLineMacroB' })
          toggle = false
        end
      end)
    )

    autocmd('RecordingLeave', {
      once = true,
      desc = 'Stops toggling the highlight group for the statusline macro segment',
      group = macrohl,
      callback = function()
        macro_timer:stop()
      end,
    })
  end,
})
autocmd('ModeChanged', {
  desc = 'Dynamically changes the highlight group of the statusline mode segment based on the current mode',
  group = augroup('StatusLineMode', { clear = true }),
  callback = function()
    local hl = vim.api.nvim_get_hl(0, { name = modes[vim.api.nvim_get_mode().mode].hl })
    vim.api.nvim_set_hl(0, 'StatusLineNvimTree', { fg = hl.fg, bg = hl.bg, italic = true })
    vim.api.nvim_set_hl(0, 'StatusLinePoon', { fg = hl.fg, bg = hl.bg, italic = true })
  end,
})

autocmd('BufEnter', {
  desc = 'Dynamically changes the highlight group of the statusline filetype icon based on the current file',
  group = augroup('StatusLineFiletype', { clear = true }),
  callback = function()
    local _, hl_group = require('nvim-web-devicons').get_icon(vim.fn.expand('%:t'))
    vim.api.nvim_set_hl(0, 'StatusLineFtIcon', { fg = vim.api.nvim_get_hl(0, { name = hl_group }).fg, bg = '#21252b' })
  end,
})

vim.opt.statusline = "%!v:lua.require('beeline.statusline')()"

return function()
  return table.concat({
    mode(),
    file_info(),
    git(),
    search(),
    '%=',
    lsp_diagnostics(),
    lsp_status(),
    cursor_position(),
    time(),
    cwd(),
  })
end
