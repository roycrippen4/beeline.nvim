local M = {}

function M.bufilter()
  local bufs = vim.t.bufs or nil

  if not bufs then
    return {}
  end

  for i, nr in ipairs(bufs) do
    if not vim.api.nvim_buf_is_valid(nr) then
      table.remove(bufs, i)
    end
  end

  vim.t.bufs = bufs
  return bufs
end

---@param bufnr integer
function M.get_buf_index(bufnr)
  for i, value in ipairs(M.bufilter()) do
    if value == bufnr then
      return i
    end
  end
end

function M.next()
  vim.cmd.redrawtabline()
  local bufs = M.bufilter() or {}
  local curbufIndex = M.get_buf_index(vim.api.nvim_get_current_buf())

  if not curbufIndex then
    vim.cmd('b' .. vim.t.bufs[1])
    return
  end

  vim.cmd(curbufIndex == #bufs and 'b' .. bufs[1] or 'b' .. bufs[curbufIndex + 1])
end

function M.prev()
  vim.cmd.redrawtabline()
  local bufs = M.bufilter() or {}
  local curbufIndex = M.get_buf_index(vim.api.nvim_get_current_buf())

  if not curbufIndex then
    vim.cmd('b' .. vim.t.bufs[1])
    return
  end

  vim.cmd(curbufIndex == 1 and 'b' .. bufs[#bufs] or 'b' .. bufs[curbufIndex - 1])
end

---@param bufnr integer
function M.close_buffer(bufnr)
  if vim.bo.buftype == 'terminal' then
    vim.cmd(vim.bo.buflisted and 'set nobl | enew' or 'hide')
  else
    -- for those who have disabled tabufline
    if not vim.t.bufs then
      vim.cmd('bd')
      return
    end

    bufnr = bufnr or vim.api.nvim_get_current_buf()
    local curBufIndex = M.get_buf_index(bufnr)
    local bufhidden = vim.bo.bufhidden

    -- force close floating wins
    if bufhidden == 'wipe' then
      vim.cmd('bw')
      return

      -- handle listed bufs
    elseif curBufIndex and #vim.t.bufs > 1 then
      local newBufIndex = curBufIndex == #vim.t.bufs and -1 or 1
      vim.cmd('b' .. vim.t.bufs[curBufIndex + newBufIndex])

    -- handle unlisted
    elseif not vim.bo.buflisted then
      local tmpbufnr = vim.t.bufs[1]

      if vim.g.nv_previous_buf and vim.api.nvim_buf_is_valid(vim.g.nv_previous_buf) then
        tmpbufnr = vim.g.nv_previous_buf
      end

      vim.cmd('b' .. tmpbufnr .. ' | bw' .. bufnr)
      return
    else
      vim.cmd('enew')
    end

    if not (bufhidden == 'delete') then
      vim.cmd('confirm bd' .. bufnr)
    end
  end

  vim.cmd.redrawtabline()
end
---@param n integer
function M.move_buf(n)
  local bufs = vim.t.bufs

  for i, bufnr in ipairs(bufs) do
    if bufnr == vim.api.nvim_get_current_buf() then
      if n < 0 and i == 1 or n > 0 and i == #bufs then
        bufs[1], bufs[#bufs] = bufs[#bufs], bufs[1]
      else
        bufs[i], bufs[i + n] = bufs[i + n], bufs[i]
      end

      break
    end
  end

  vim.t.bufs = bufs
  vim.cmd.redrawtabline()
end

function M.setup()
  require('beeline.lazyload')
end

return M
