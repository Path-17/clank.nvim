local M = {}

-- helpers --
-- hacky way to get errors to show up properly but keeping cmdheight 0
local function err_notify(msg)
    local old = vim.o.cmdheight
    vim.o.cmdheight = 1
    vim.notify(msg, vim.log.levels.ERROR)
    vim.defer_fn(function()
        vim.o.cmdheight = old
    end, 1500)
end

local function get_visual_selection()
    local s_start = vim.fn.getpos("'<")
    local s_end = vim.fn.getpos("'>")
    local n_lines = math.abs(s_end[2] - s_start[2]) + 1
    local lines = vim.api.nvim_buf_get_lines(0, s_start[2] - 1, s_end[2], false)
    lines[1] = string.sub(lines[1], s_start[3], -1)
    if n_lines == 1 then
        lines[n_lines] = string.sub(lines[n_lines], 1, s_end[3] - s_start[3] + 1)
    else
        lines[n_lines] = string.sub(lines[n_lines], 1, s_end[3])
    end
    return table.concat(lines, '\n')
end

local function replace_visual_selection(new_text)
    local bufnr = vim.api.nvim_get_current_buf()

    local start_pos = vim.api.nvim_buf_get_mark(bufnr, "<")
    local end_pos = vim.api.nvim_buf_get_mark(bufnr, ">")

    local start_line, start_col = start_pos[1] - 1, start_pos[2]
    local end_line, end_col = end_pos[1] - 1, end_pos[2]

    local lines = vim.api.nvim_buf_get_lines(bufnr, end_line, end_line + 1, false)
    local line_length = #lines[1] or 0

    -- Clamp end_col to avoid going past the line length
    if end_col >= line_length then
        end_col = line_length
    end

    -- Handle visual mode
    local mode = vim.fn.visualmode()
    local new_lines = vim.split(new_text, "\n", { plain = true })

    if mode == "V" then
        -- Linewise visual mode
        vim.api.nvim_buf_set_lines(bufnr, start_line, end_line + 1, false, new_lines)
    else
        -- Character-wise visual mode
        vim.api.nvim_buf_set_text(bufnr, start_line, start_col, end_line, end_col + 1, new_lines)
    end
end

local function paste_at_cursor(text, bufnr, winnr)
    local row, col = unpack(vim.api.nvim_win_get_cursor(winnr))
    local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1] or ""

    local before, after = line:sub(1, col), line:sub(col + 1)
    local lines = {}
    for s in (text .. "\n"):gmatch("(.-)\n") do
        table.insert(lines, s)
    end

    if #lines == 1 then
        vim.api.nvim_buf_set_lines(bufnr, row - 1, row, false, { before .. lines[1] .. after })

        -- Clamp new col to line length
        local new_col = math.min(col + #lines[1], #before + #lines[1])
        vim.api.nvim_win_set_cursor(winnr, { row, new_col })
    else
        lines[1] = before .. lines[1]
        lines[#lines] = lines[#lines] .. after
        vim.api.nvim_buf_set_lines(bufnr, row - 1, row, false, lines)

        local new_row = row - 1 + #lines
        local last_line_len = #lines[#lines]

        -- Clamp row and col inside buffer and line length
        local line_count = vim.api.nvim_buf_line_count(bufnr)
        if new_row > line_count then new_row = line_count end

        vim.api.nvim_win_set_cursor(winnr, { new_row, last_line_len })
    end
end
-- end of helpers --

-- hacky auto complete, read the global later in lua to do things
function M.auto_complete(opts)
    _G.LayupGlobalAutocompleteArgs = opts.args
end

-- run the command on the highlighted text, replace highlighted text with output
function M.bash_on_highlight(opts)
    local visual_text = get_visual_selection()

    local input = opts.args
    if input == nil then
        print("Cancelled")
        return
    end

    -- run the command
    vim.system({ "bash", "-c", input }, { stdin = visual_text, text = true }, function(obj)
        local stdout = obj.stdout
        local stderr = obj.stderr
        local exit_code = obj.code

        -- basic error handling, prints it in red
        if exit_code ~= 0 then
            vim.schedule(function()
                err_notify("The command failed with: " .. stderr)
            end)
            -- else success, proceed
        else
            -- replace just what was highlighted
            -- has to be scheduled because it is done in a fast context
            vim.schedule(function()
                replace_visual_selection(stdout)
            end)
        end
    end)
end

-- run the command on the buf, replace buf with output
function M.bash_on_buf(opts)
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local full_text = table.concat(lines, "\n")

    local input = opts.args
    if input == nil then
        print("Cancelled")
        return
    end

    vim.system({ "bash", "-c", input }, { stdin = full_text, text = true }, function(obj)
        local stdout = obj.stdout
        local stderr = obj.stderr
        local exit_code = obj.code

        -- basic error handling, prints it in red
        if exit_code ~= 0 then
            vim.schedule(function()
                err_notify("The command failed with: " .. stderr)
            end)
            -- else success, proceed
        else
            -- replace the current buffer
            -- has to be scheduled because done in fast context
            vim.schedule(function()
                local bufnr = vim.api.nvim_get_current_buf()
                local tmp_lines = vim.split(stdout, "\n", { plain = true })
                vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, tmp_lines)
            end)
        end
    end)
end

-- run the command, insert the output into the buf just after cursor location
function M.bash_to_buf(opts)
    local input = opts.args
    if input == nil then
        print("Cancelled")
        return
    end

    -- run the command
    vim.system({ "bash", "-c", input }, { text = true }, function(obj)
        vim.schedule(function()
            local stdout = obj.stdout
            local stderr = obj.stderr
            local exit_code = obj.code

            if exit_code ~= 0 then
                err_notify("The command failed with: " .. stderr)
            else
                paste_at_cursor(stdout, vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win())
            end
        end)
    end)
end

-- Dependent on mini.pick
-- Fuzzy find a file using mini.pick and then read it into the current buffer
-- Default src_dir is ~/Documents/pentests
function M.file_to_buf(src_dir)
    -- Recursively find all files under src_dir
    local files = vim.fn.glob(src_dir .. "/**", true, true)

    -- Filter out directories
    local file_list = vim.tbl_filter(function(f)
        return vim.fn.isdirectory(f) == 0
    end, files)

    -- Need these outside of the call back
    local curbuf = vim.api.nvim_get_current_buf()
    local curwin = vim.api.nvim_get_current_win()

    require('mini.pick').start({
        source = {
            name = 'Files in ' .. src_dir,
            items = file_list,
            choose = function(path)
                local file = io.open(path, "r")
                local content = file:read("*a")
                file:close()
                paste_at_cursor(content, curbuf, curwin)
            end,
        },
    })
end

-- Dependent on mini.pick
-- Fuzzy find a file using mini.pick and then run a command on it and insert it into the file
-- Default src_dir is ~/Documents/pentests
function M.file_bash_to_buf(src_dir, opts)
    -- Recursively find all files under src_dir
    local files = vim.fn.glob(src_dir .. "/**", true, true)

    -- Filter out directories
    local file_list = vim.tbl_filter(function(f)
        return vim.fn.isdirectory(f) == 0
    end, files)

    -- Need these outside of the call back
    local curbuf = vim.api.nvim_get_current_buf()
    local curwin = vim.api.nvim_get_current_win()

    require('mini.pick').start({
        source = {
            name = 'Files in ' .. src_dir,
            items = file_list,
            choose = function(path)
                local file = io.open(path, "r")
                local content = file:read("*a")
                file:close()

                -- super sketchy auto complete functionality, nothing to see here
                _G.LayupGlobalAutocompleteArgs = nil
                vim.api.nvim_feedkeys(":LayupAutoComplete ", "n", false)

                local timer = vim.loop.new_timer()
                timer:start(0, 100, vim.schedule_wrap(function()
                    if _G.LayupGlobalAutocompleteArgs ~= nil then
                        timer:stop()
                        timer:close()

                        vim.system({ "bash", "-c", _G.LayupGlobalAutocompleteArgs }, { stdin = content, text = true },
                            function(obj)
                                vim.schedule(function()
                                    local stdout = obj.stdout
                                    local stderr = obj.stderr
                                    local exit_code = obj.code

                                    if exit_code ~= 0 then
                                        err_notify("The command failed with: " .. stderr)
                                    end
                                    if stdout ~= nil then
                                        paste_at_cursor(stdout, curbuf, curwin)
                                    end
                                end)
                            end)

                    end
                end))
            end,
        },
    })
end

return M
