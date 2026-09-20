describe('linter.jarl', function()
  local parser = require('lint.linters.jarl').parser
  local bufnr

  before_each(function()
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, "/projects/shinyfilters/lint_example.R")

    -- Set CRLF file format so byte offsets match Windows/R linting output
    vim.bo[bufnr].fileformat = 'dos'

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      "fmt: skip",
      "penguins |>",
      "\tas_filters(slider = TRUE) |>",
      "\twith_filter(year = \"radio\") |>",
      "\twith_args(",
      "\t\t\"numeric\",",
      "\t\t~ list(value = c(min(.x, na.rm = TRUE), max(.x, na.rm = TRUE)))",
      "\t) |>",
      "\tfilterInput() -> ",
      "x",
      "",
      "x <- any(is.na(letters))",
      "",
      "for (x in x) {}",
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
          "range": [
            206,
            212
          ],
          "location": {
            "row": 9,
            "column": 15
          },
          "fix": {
            "content": "x <- penguins |>\r\n\tas_filters(slider = TRUE) |>\r\n\twith_filter(year = \"radio\") |>\r\n\twith_args(\r\n\t\t\"numeric\",\r\n\t\t~ list(value = c(min(.x, na.rm = TRUE), max(.x, na.rm = TRUE)))\r\n\t) |>\r\n\tfilterInput()",
            "start": 13,
            "end": 212,
            "to_skip": false
          }
        },
        {
          "message": {
            "name": "any_is_na",
            "body": "`any(is.na(...))` is inefficient.",
            "suggestion": "Use `anyNA(...)` instead."
          },
          "filename": "lint_example.R",
          "range": [
            221,
            240
          ],
          "location": {
            "row": 12,
            "column": 5
          },
          "fix": {
            "content": "anyNA(letters)",
            "start": 221,
            "end": 240,
            "to_skip": false
          }
        },
        {
          "message": {
            "name": "for_loop_index",
            "body": "Don't re-use any sequence symbols as the index symbol in a for loop.",
            "suggestion": null
          },
          "filename": "lint_example.R",
          "range": [
            249,
            255
          ],
          "location": {
            "row": 14,
            "column": 5
          },
          "fix": {
            "content": "",
            "start": 0,
            "end": 0,
            "to_skip": true
          }
        }
      ],
      "errors": []
    }]]

    local result = parser(output, bufnr)

    assert.are.same(3, #result)

    -- Diagnostic without suggestion
    assert.are.same({
      source = 'jarl',
      lnum = 8,
      end_lnum = 10,
      col = 17,
      end_col = 0,
      severity = vim.diagnostic.severity.WARN,
      message = "Use `<-` for assignment.",
      code = "assignment",
    }, result[1])

    -- Diagnostic with suggestion
    local message_base = "`any(is.na(...))` is inefficient."
    local delim = string.rep("-", #message_base)
    local message_full = message_base .. "\n"
        .. delim .. "\n"
        .. "Help:" .. "\n"
        .. "Use `anyNA(...)` instead."

    assert.are.same({
      source = 'jarl',
      lnum = 11,
      end_lnum = 12,
      col = 7,
      end_col = 0,
      severity = vim.diagnostic.severity.WARN,
      message = message_full,
      code = "any_is_na",
    }, result[2])

    -- Middle of line
    assert.are.same({
      source = 'jarl',
      lnum = 13,
      end_lnum = 13,
      col = 7,
      end_col = 13,
      severity = vim.diagnostic.severity.WARN,
      message = "Don't re-use any sequence symbols as the index symbol in a for loop.",
      code = "for_loop_index",
    }, result[3])
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
