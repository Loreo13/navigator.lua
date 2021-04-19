local util = require "navigator.util"
local lsphelper = require "navigator.lspwrapper"
local locations_to_items = lsphelper.locations_to_items
local gui = require "navigator.gui"
local log = util.log
local TextView = require("guihua.textview")
-- callback for lsp definition, implementation and declaration handler
local function definition_hdlr(_, _, locations, _, bufnr)
  -- log(locations)
  if locations == nil or vim.tbl_isempty(locations) then
    print "Definition not found"
    return
  end
  if vim.tbl_islist(locations) then
    if #locations > 1 then
      local items = locations_to_items(locations)
      gui.new_list_view({items = items, api = 'Definition'})
    else
      vim.lsp.util.jump_to_location(locations[1])
    end
  else
    vim.lsp.util.jump_to_location(locations)
  end
end

local function def_preview(timeout_ms)
  local method = "textDocument/definition"
  local params = vim.lsp.util.make_position_params()
  local result = vim.lsp.buf_request_sync(0, method, params, timeout_ms or 2000)

  if result == nil or vim.tbl_isempty(result) then
    print("No result found: " .. method)
    return nil
  end

  local data = {}
  -- result = {vim.tbl_deep_extend("force", {}, unpack(result))}
  -- log("def-preview", result)
  for key, value in pairs(result) do
    if result[key] ~= nil then
      table.insert(data, result[key].result[1])
    end
  end
  local range = data[1].targetRange or data[1].range

  local row = range.start.line
  -- in case there are comments
  row = math.max(row - 3, 1)
  local delta = range.start.line - row + 1
  local uri = data[1].uri or data[1].targetUri
  if not uri then
    return
  end
  local bufnr = vim.uri_to_bufnr(uri)
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    vim.fn.bufload(bufnr)
  end

  local definition = vim.api.nvim_buf_get_lines(bufnr, row, range["end"].line + 12, false)
  local def_line = vim.api.nvim_buf_get_lines(bufnr, range.start.line, range.start.line + 1, false)
  for _ = 1, math.min(3, #definition), 1 do
    if #definition[1] < 2 then
      table.remove(definition, 1)
      delta = delta - 1
    else
      break
    end
  end
  definition = vim.list_extend({"    " .. "Definition: "}, definition)
  local filetype = vim.api.nvim_buf_get_option(bufnr, "filetype")

  -- TODO multiple resuts?
  local opts = {
    relative = "cursor",
    style = "minimal",
    ft = filetype,
    data = definition,
    enter = true
  }
  TextView:new(opts)
  delta = delta + 1 -- header
  local cmd = "normal! " .. tostring(delta) .. "G"

  vim.cmd(cmd)
  vim.cmd('set cursorline')
  if #def_line > 0 then
    local niddle = require('guihua.util').add_escape(def_line[1])
    log(def_line[1], niddle)
    vim.fn.matchadd("Search", niddle)
  end
  -- TODO:
  -- https://github.com/oblitum/goyo.vim/blob/master/autoload/goyo.vim#L108-L135
end

vim.lsp.handlers["textDocument/definition"] = definition_hdlr
return {
  definition_handler = definition_hdlr,
  definition_preview = def_preview,
  declaration_handler = definition_hdlr,
  typeDefinition_handler = definition_hdlr
}