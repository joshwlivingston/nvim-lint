describe('linter.jarl', function()
  local parser = require('lint.linters.jarl').parser
  local bufnr

  before_each(function()
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, "/projects/shinyfilters/lint_example.R")

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      "penguins |>",
      "  as_filters(slider = TRUE) |>",
      "  with_filter(year = \"radio\") |>",
      "  with_args(",
      "    \"numeric\",",
      "    ~ list(value = c(min(.x, na.rm = TRUE), max(.x, na.rm = TRUE)))",
      "  ) |>",
      "  filterInput() -> "
      "x",
      "",
      "x <- any(is.na(letters))",
    })
  end)

  after_each(function()
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)

  it('parses diagnostic output and converts offsets to 0-indexed positions', function()
    local output = [[{
      "diagnostics": [
        {
          "message": {
            "name": "assignment",
            "body": "Use `<-` for assignment.",
            "suggestion": null
          },
          "filename": "lint_example.R",
          "range": [193, 197]
        },
        {
          "message": {
            "name": "any_is_na",
            "body": "`any(is.na(...))` is inefficient.",
            "suggestion": "Use `anyNA(...)` instead."
          },
          "filename": "lint_example.R",
          "range": [206, 225]
        }
      ],
      "errors": []
    }]]

    local result = parser(output, bufnr)

    assert.are.same(2, #result)

    -- Diagnostic without suggestion
    assert.are.same({
      source = 'jarl',
      lnum = 7,
      end_lnum = 8,
      col = 17,
      end_col = 1,
      severity = vim.diagnostic.severity.WARN,
      message = "Use `<-` for assignment.",
      code = "assignment",
    }, result[1])

    -- Diagnostic with suggestion formatting attached
    local expected_msg = "`any(is.na(...))` is inefficient.\n"
        .. string.rep("-", 34) .. "\n"
        .. "Help:\n"
        .. "Use `anyNA(...)` instead."

    assert.are.same({
      source = 'jarl',
      lnum = 9,
      end_lnum = 9,
      col = 1,
      end_col = 20,
      severity = vim.diagnostic.severity.WARN,
      message = expected_msg,
      code = "any_is_na",
    }, result[2])
  end)

  it('filters out diagnostics that belong to a different file', function()
    local output = [[{
      "diagnostics": [
        {
          "message": {
            "name": "assignment",
            "body": "Use `<-` for assignment.",
            "suggestion": null
          },
          "filename": "other_file.R",
          "range": [10, 15]
        }
      ]
    }]]

    local result = parser(output, bufnr)
    assert.are.same({}, result)
  end)

  it('handles nil, empty, or malformed json output gracefully', function()
    assert.are.same({}, parser(nil, bufnr))
    assert.are.same({}, parser("", bufnr))
    assert.are.same({}, parser("not json", bufnr))
    assert.are.same({}, parser("{}", bufnr))
    assert.are.same({}, parser('{"diagnostics": null}', bufnr))
  end)
end)
