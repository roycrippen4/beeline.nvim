local t = vim.t

local function filter_bufs(bufnr)
  return (vim.bo[bufnr].buflisted and vim.bo[bufnr].ft ~= '') and bufnr or nil
end

t.bufs = vim.iter(vim.api.nvim_list_bufs()):filter(filter_bufs):totable()
vim.api.nvim_create_autocmd({ 'BufAdd', 'BufEnter', 'TabNew' }, {
  callback = function(args)
    local bufs = t.bufs

    if t.bufs == nil then
      t.bufs = vim.api.nvim_get_current_buf() == args.buf and {} or { args.buf }
    else
      if
        not vim.tbl_contains(bufs, args.buf)
        and (args.event == 'BufEnter' or vim.bo[args.buf].buflisted or args.buf ~= vim.api.nvim_get_current_buf())
        and vim.api.nvim_buf_is_valid(args.buf)
        and vim.bo[args.buf].buflisted
        and vim.bo.ft ~= 'undotree' -- This was a super annoying bug
      then
        table.insert(bufs, args.buf)
        t.bufs = bufs
      end
    end

    -- remove unnamed buffer which isnt current buf & modified
    if args.event == 'BufAdd' then
      local first_buf = t.bufs[1]

      if #vim.api.nvim_buf_get_name(first_buf) == 0 and not vim.api.nvim_get_option_value('modified', { buf = first_buf }) then
        table.remove(bufs, 1)
        t.bufs = bufs
      end
    end
  end,
})

vim.api.nvim_create_autocmd('BufDelete', {
  callback = function(args)
    vim.iter(vim.api.nvim_list_tabpages()):each(function(tab)
      local bufs = t[tab].bufs ---@type integer[]
      if bufs then
        for i, bufnr in ipairs(bufs) do
          if bufnr == args.buf then
            table.remove(bufs, i)
            t[tab].bufs = bufs
            break
          end
        end
      end
    end)
  end,
})

vim.api.nvim_create_autocmd({ 'BufNew', 'BufNewFile', 'BufRead', 'TabEnter', 'TermOpen' }, {
  pattern = '*',
  callback = function()
    if #vim.fn.getbufinfo({ buflisted = 1 }) >= 2 or #vim.api.nvim_list_tabpages() >= 2 then
      vim.opt.showtabline = 2
      vim.opt.tabline = "%!v:lua.require('beeline.modules').run()"
    end
  end,
})
