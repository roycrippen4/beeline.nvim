--- checks if the buffer is valid and listed
---@param bufnr integer
---@return boolean
local function is_buf_valid(bufnr)
  return vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buflisted
end

---------------------------------------------------------- btn onclick functions ----------------------------------------------
vim.cmd("function! TbGoToBuf(bufnr,b,c,d) \n execute 'b'..a:bufnr \n endfunction")

vim.cmd([[
         function! TbKillBuf(bufnr,b,c,d) 
           call luaeval('require("beeline").close_buffer(_A)', a:bufnr)
         endfunction
       ]])

vim.cmd('function! TbNewTab(a,b,c,d) \n tabnew \n endfunction')
vim.cmd("function! TbGotoTab(tabnr,b,c,d) \n execute a:tabnr ..'tabnext' \n endfunction")
-- vim.cmd("function! TbTabClose(a,b,c,d) \n lua require('beeline').closeAllBufs('closeTab') \n endfunction")

-------------------------------------------------------- functions ------------------------------------------------------------
--- gets the width of the nvim-tree window
---@return integer
local function get_tree_width()
  for _, win in pairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].ft == 'NvimTree' or vim.bo[vim.api.nvim_win_get_buf(win)].ft == 'neo-tree' then
      return vim.api.nvim_win_get_width(win) + 1
    end
  end
  return 0
end

--- gets the width of the buttons on the right side of the tabline
---@return integer
local function get_btns_width() -- close, theme toggle btn etc
  local width = 6
  if vim.fn.tabpagenr('$') ~= 1 then
    width = width + ((3 * vim.fn.tabpagenr('$')) + 2) + 10
    width = not vim.g.TbTabsToggled and 8 or width
  end
  return width
end

--- adds file info to the buffer tab
---@param name string
---@param bufnr integer
---@return string?
local function add_file_info(name, bufnr)
  if name ~= ' No Name ' then
    for _, value in ipairs(vim.t.bufs) do
      if is_buf_valid(value) then
        if name == vim.api.nvim_buf_get_name(value):match('^.+/(.+)$') and value ~= bufnr then
          local other = {}
          for match in (vim.fs.normalize(vim.api.nvim_buf_get_name(value)) .. '/'):gmatch('(.-)' .. '/') do
            table.insert(other, match)
          end

          local current = {}
          for match in (vim.fs.normalize(vim.api.nvim_buf_get_name(bufnr)) .. '/'):gmatch('(.-)' .. '/') do
            table.insert(current, match)
          end

          name = current[#current]

          for i = #current - 1, 1, -1 do
            local value_current = current[i]
            local other_current = other[i]

            if value_current ~= other_current then
              if (#current - i) < 2 then
                name = value_current .. '/' .. name
              else
                name = value_current .. '/../' .. name
              end
              break
            end
          end
          break
        end
      end
    end

    -- padding around bufname; 24 = bufame length (icon + filename)
    local pad = (30 - #name - 5) / 2
    local r_pad = math.floor(pad / 2)
    local l_pad = pad - r_pad
    local maxname_len = 16

    local idx
    if require('poon').is_marked(bufnr) then
      local full_path = vim.api.nvim_buf_get_name(bufnr)
      local relative_path = vim.fn.fnamemodify(full_path, ':.')
      idx = require('poon').mark_get_index(relative_path)
    end

    local marked_on = '%#TbLineMarkedBufOn# ' .. '󰫈 '
    local marked_off = '%#TbLineMarkedBufOff# ' .. '󰋙 '

    name = (#name > maxname_len and string.sub(name, 1, 14) .. '..') or name
    name = (vim.api.nvim_get_current_buf() == bufnr and '%#TbLineBufOn# ' .. name) or ('%#TbLineBufOff# ' .. name)

    if idx ~= nil then
      local poon_icon = (vim.api.nvim_get_current_buf() == bufnr and '%#TbLineMarkedBufOn#' .. idx .. marked_on) or idx .. marked_off
      return string.rep(' ', l_pad) .. (poon_icon .. name) .. string.rep(' ', r_pad)
    end

    return string.rep(' ', l_pad) .. name .. string.rep(' ', r_pad)
  end
end

--- styles the buffer tab contents
---@param nr integer
---@return string
local function style_buffer_tab(nr)
  local close_btn = '%' .. nr .. '@TbKillBuf@ 󰅖 %X'
  local filepath = vim.api.nvim_buf_get_name(nr)
  local name = (filepath == '' and ' No Name') or filepath:match('([^/\\]+)[/\\]*$')
  name = '%' .. nr .. '@TbGoToBuf@' .. add_file_info(name, nr) .. '%X'

  -- color close btn for focused / hidden  buffers
  if nr == vim.api.nvim_get_current_buf() then
    close_btn = (vim.bo[0].modified and '%' .. nr .. '@TbKillBuf@%#TbLineBufOnModified#  ') or ('%#TbLineBufOnClose#' .. close_btn)
    name = '%#TbLineBufOn#' .. name .. close_btn
  else
    close_btn = (vim.bo[nr].modified and '%' .. nr .. '@TbKillBuf@%#TbLineBufOffModified#  ') or ('%#TbLineBufOffClose#' .. close_btn)
    name = '%#TbLineBufOff#' .. name .. close_btn
  end

  return name
end

---------------------------------------------------------- components ------------------------------------------------------------
local M = {}

--- sets the buffer list on the tabline
--- @return string
function M.bufferlist()
  local buffers = {} -- buffersults
  local available_space = vim.o.columns - get_tree_width() - get_btns_width() - 5
  local current_buf = vim.api.nvim_get_current_buf()
  local has_current = false -- have we seen current buffer yet?

  for _, bufnr in pairs(vim.t.bufs) do
    if is_buf_valid(bufnr) then
      if ((#buffers + 1) * 21) > available_space then
        if has_current then
          break
        end

        table.remove(buffers, 1)
      end

      has_current = (bufnr == current_buf and true) or has_current
      table.insert(buffers, style_buffer_tab(bufnr))
    end
  end

  return table.concat(buffers) .. '%#TbLineFill#' .. '%=' -- buffers + empty space
end

--- runs the tabline components
--- @return string
function M.run()
  local modules = {
    '%#TbLineFill#' .. string.rep(' ', get_tree_width() - 1),
    M.bufferlist(),
  }

  return table.concat(modules)
end

return M
