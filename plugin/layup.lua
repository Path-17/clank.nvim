-- TODO: Config
-- Default to using q register, have it be customizable
-- Default to Fuzzy searching in ~/Documents/pentests, have it be customizable
local default_insert_dir = "~/Documents/pentests"
-- Global value just to hold args passed to LayupAutoComplete user command
-- read by other functions, used as a hacky way to get autocomplete for files / commands
_G.LayupGlobalAutocompleteArgs = {}

-- helpers --
local function custom_complete(ArgLead, CmdLine, CursorPos)
    -- Get completions from file names
    local files = vim.fn.getcompletion(ArgLead, "file")

    -- Get completions from directories
    local dirs = vim.fn.getcompletion(ArgLead, "dir")

    -- Get completions from shell commands
    local shellcmds = vim.fn.getcompletion(ArgLead, "shellcmd")

    -- Combine them all and remove duplicates
    local all = vim.tbl_extend("force", files, dirs, shellcmds)
    local seen = {}
    local unique = {}
    for _, item in ipairs(all) do
        if not seen[item] then
            table.insert(unique, item)
            seen[item] = true
        end
    end
    return unique
end
-- end of helpers --

-- Auto complete helper
vim.api.nvim_create_user_command(
    'LayupAutoComplete',
    require('layup').auto_complete,
    {
        nargs = "*",
        complete = custom_complete
    }
)
-- Run bash script on highlighted text as if it was piped into it
vim.api.nvim_create_user_command(
    'LayupBashOnHighlight',
    require('layup').bash_on_highlight,
    {
        nargs = "*",
        complete = custom_complete
    }
)
vim.keymap.set('v', '<Leader>b', ':<C-u>LayupBashOnHighlight ')

-- Run bash script on entire text buffer as if it was piped into it
vim.api.nvim_create_user_command(
    'LayupBashOnBuf',
    require('layup').bash_on_buf,
    {
        nargs = "*",
        complete = custom_complete
    }
)
vim.keymap.set('n', '<Leader>B', ':<C-u>LayupBashOnBuf ')

-- Run bash script and paste the stdout into the current buffer
vim.api.nvim_create_user_command(
    'LayupBashToBuf',
    require('layup').bash_to_buf,
    {
        nargs = "*",
        complete = custom_complete
    }
)
vim.keymap.set('n', '<Leader>b', ':<C-u>LayupBashToBuf ')

-- Dependant on mini.pick
-- Fuzzy find a file starting in a particular directory, read it into the current buffer
vim.api.nvim_create_user_command(
    'LayupFileToBuf',
    function()
        require('layup').file_to_buf(default_insert_dir)
    end,
    {}
)
vim.keymap.set('n', '<Leader>F', ':<C-u>LayupFileToBuf<CR>')

-- Fuzzy find a file starting in a particular directory, run a bash command on it, then read it into the current buffer
vim.api.nvim_create_user_command(
    'LayupFileBashToBuf',
    function()
        require('layup').file_bash_to_buf(default_insert_dir)
    end,
    {
        nargs = "*",
        complete = custom_complete
    }
)
vim.keymap.set('n', '<Leader>Fb', ':<C-u>LayupFileBashToBuf<CR>')
