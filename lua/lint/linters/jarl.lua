local function offset_to_pos(bufnr, offset)
  if type(offset) ~= "number" then
    return 0, 0
  end

  if not vim.api.nvim_buf_is_loaded(bufnr) then
    vim.fn.bufload(bufnr)
  end

  local lnum, col
  vim.api.nvim_buf_call(bufnr, function()
    -- byte2line requires 1-based byte index
    local line = vim.fn.byte2line(offset + 1)
    if line == -1 then
      lnum, col = 0, 0
      return
    end

    local line_start = vim.fn.line2byte(line)
    if line_start == -1 then
      lnum, col = math.max(0, line - 1), 0
      return
    end

    lnum = math.max(0, line - 1)
    col = math.max(0, (offset + 1) - line_start)
  end)

  return lnum or 0, col or 0
end

return {
  cmd = "jarl",
  args = {
    "check",
    "--output-format",
    "json"
  },
  stream = 'stdout',
  ignore_exitcode = true,
  parser = function(output, bufnr)
    local diagnostics = {}

    if output == nil then
      return diagnostics
    end

    local ok, decoded = pcall(vim.json.decode, output)
    if not ok or type(decoded) ~= "table" then
      return diagnostics
    end

    local items = decoded.diagnostics
    if type(items) ~= "table" then
      return diagnostics
    end

    local bufname = vim.api.nvim_buf_get_name(bufnr)

    for _, item in pairs(items) do
      if bufname:sub(- #item.filename) == item.filename then
        local lnum, col = offset_to_pos(bufnr, item.range[1])
        local end_lnum, end_col = offset_to_pos(bufnr, item.range[2])

        local message = item.message.body

        if type(item.message.suggestion) == "string" then
          local delim = string.rep("-", #message)
          message = message .. "\n" .. delim .. "\n" .. "Help:\n" .. item.message.suggestion
        end

        table.insert(diagnostics, {
          source = 'jarl',
          lnum = lnum,
          end_lnum = end_lnum,
          col = col,
          end_col = end_col,
          severity = vim.diagnostic.severity.WARN,
          message = message,
          code = item.message.name,
        })
      end
    end

    return diagnostics
  end,
}
