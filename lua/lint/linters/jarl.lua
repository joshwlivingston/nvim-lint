--- Convert character offset to 0-base {lnum, col}
local function offset_to_pos(bufnr, offset)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local current_offset = 0

  for lnum, line in ipairs(lines) do
    local line_length = #line + 1
    if current_offset + line_length > offset then
      local col = offset - current_offset
      return lnum - 1, col
    end
    current_offset = current_offset + line_length
  end

  local last_line = #lines
  return math.max(0, last_line - 1), #lines[last_line] or 0
end

return {
  cmd = "jarl",
  args = {
    "check",
    "--output-format",
    "json"
  },
  parser = function(output, bufnr)
    local diagnostics = {}

    if output == nil then
      return diagnostics
    end

    local decoded = vim.json.decode(output)
    if not decoded then
      return diagnostics
    end

    local items = decoded.diagnostics
    if not items then
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
