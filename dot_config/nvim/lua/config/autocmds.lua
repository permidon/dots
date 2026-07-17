local api = vim.api

-- don't auto comment new line
api.nvim_create_autocmd("BufEnter", { command = [[set formatoptions-=cro]] })

-- wrap words "softly" (no carriage return) in mail buffer
api.nvim_create_autocmd("Filetype", {
  pattern = "mail",
  callback = function()
    vim.opt.textwidth = 0
    vim.opt.wrapmargin = 0
    vim.opt.wrap = true
    vim.opt.linebreak = true
    vim.opt.columns = 80
    vim.opt.colorcolumn = "80"
  end,
})

-- Highlight on yank
api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    vim.hl.on_yank()
  end,
})

-- go to last loc when opening a buffer
-- this mean that when you open a file, you will be at the last position
api.nvim_create_autocmd("BufReadPost", {
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- show cursor line only in active window
local cursorGrp = api.nvim_create_augroup("CursorLine", { clear = true })
api.nvim_create_autocmd({ "InsertLeave", "WinEnter" }, {
  pattern = "*",
  command = "set cursorline",
  group = cursorGrp,
})
api.nvim_create_autocmd(
  { "InsertEnter", "WinLeave" },
  { pattern = "*", command = "set nocursorline", group = cursorGrp }
)

-- Enable spell checking for certain file types
api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = { "*.txt", "*.md", "*.tex" },
  callback = function()
    vim.opt.spell = true
    vim.opt.spelllang = "en"
  end,
})

-- close some filetypes with <q>
api.nvim_create_autocmd("FileType", {
  group = api.nvim_create_augroup("close_with_q", { clear = true }),
  pattern = {
    "PlenaryTestPopup",
    "help",
    "lspinfo",
    "man",
    "notify",
    "qf",
    "spectre_panel",
    "startuptime",
    "tsplayground",
    "neotest-output",
    "checkhealth",
    "neotest-summary",
    "neotest-output-panel",
  },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = event.buf, silent = true })
  end,
})

-- Resize neovim split when terminal is resized
api.nvim_create_autocmd("VimResized", {
  callback = function()
    vim.cmd("wincmd =")
  end,
})

-- Fix terraform and hcl comment string
api.nvim_create_autocmd("FileType", {
  group = api.nvim_create_augroup("FixTerraformCommentString", { clear = true }),
  pattern = { "terraform", "hcl" },
  callback = function(ev)
    vim.bo[ev.buf].commentstring = "# %s"
  end,
})

-- Check for external file changes (works with Claude Code)
api.nvim_create_autocmd({ "FocusGained", "BufEnter" }, { -- CursorHold
  callback = function()
    if vim.fn.mode() ~= "c" then
      vim.cmd("checktime")
    end
  end,
})

-- Disable auto formatting and markdown rendering on the Index
-- Also conceals brackets on the Index for cleaner consistent formatting

vim.api.nvim_create_autocmd("BufEnter", {
  pattern = "00.00 Index.md",
  callback = function()
    if vim.bo.filetype == "markdown" then
      vim.cmd("RenderMarkdown disable")
      vim.cmd("LspStop")
      vim.b.autoformat = false

      vim.o.conceallevel = 2
      vim.o.concealcursor = "nvic"

      -- Conceal the opening [[ and closing ]] brackets, but show the text inside
      vim.fn.matchadd("Conceal", "\\[\\[", 10, -1, { conceal = "" })
      vim.fn.matchadd("Conceal", "\\]\\]", 10, -1, { conceal = "" })

      -- Optionally, define a syntax for the content inside [[ ]] to ensure it’s not concealed
      vim.cmd([[syntax region WikiLink start=/\[\[/ end=/\]\]/ concealends]])
    end
  end,
})

-- Ignore Non existent & Ambigious link warnings in Marksman

vim.api.nvim_create_autocmd("LspAttach", {
  pattern = "00.00 Index.md",
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client.name == "marksman" then
      -- Override the diagnostic handler to filter out unwanted messages
      client.handlers["textDocument/publishDiagnostics"] = function(_, result, ctx, config)
        -- Filter diagnostics
        local filtered_diagnostics = {}
        for _, diagnostic in ipairs(result.diagnostics) do
          local message = diagnostic.message
          if not (message:match("Link to non%-existent document") or message:match("Ambiguous link to document")) then
            table.insert(filtered_diagnostics, diagnostic)
          end
        end
        result.diagnostics = filtered_diagnostics
        -- Call the default handler with filtered diagnostics
        vim.lsp.diagnostic.on_publish_diagnostics(_, result, ctx, config)
      end
    end
  end,
})
