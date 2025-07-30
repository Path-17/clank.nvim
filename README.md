# layup.nvim

Just a basic lua extension to run bash commands in place on highlighted text.

I mostly use nvim as a notepad replacement at work rather than coding, so it's something I wanted to make for myself.

## Functionality

Take a look inside of the `lua/layup/init.lua` file for implementations, and `plugins/layup.lua` for keybindings / user commands

A brief overview of what is included is below.

### Commands and functionality

1. My favorite one gives you auto complete for files / commands etc. by using the command functionality in nvim.


```
LayupAutoComplete <args>
```

Sets a global `_G.LayupGlobalAutocompleteArgs` with the passed in args. Can then read / process them as normal for any function in Lua.

**No default remap.**


2. Run bash command on highlighted text, replace in-line. The highlighted text is passed as stdin to the commands string.


```
LayupBashOnHighlight <bash_args>

ex: Base64 the highlighted text, no newlines

LayupBashOnHighlight base64 -w0
```

**Default remap to visual-mode <leader>b**

3. Run bash command on the entire current buffer, replace it with the stdout. The buffer contents is passed in as stdin to the commands string.


```
LayupBashOnBuf <bash_args>

ex: Open an nmap scan and filter for open ports

LayupBashOnHighlight grep open
```

**Default remap to normal-mode <leader>B**

4. **Normal mode only.** Run bash command and insert it's stdout into the buffer at your cursor.


```
LayupBashToBuf <bash_args>

ex: dig for dmarc records

LayupBashToBuf dig _dmarc.domain.tld txt
```

**Default remap to normal-mode <leader>b**

5. Select a file using mini.pick inside of the configured directory, insert it into buffer at cursor. Defaults to `~/Documents/georgy/pentests/` for me, feel free to change it. Can find the `default_insert_dir` var in the top of `plugins/layup.lua`.


```
LayupFileToBuf <bash_args>

ex: insert a nmap file

LayupFileToBuf dig _dmarc.domain.tld txt
```

**Default remap to normal-mode <leader>F**

6. Select a file using mini.pick inside of the configured directory, run a bash command on it, insert the commands stdout into buffer at cursor. Defaults to `~/Documents/georgy/pentests/` for me, feel free to change it. Can find the `default_insert_dir` var in the top of `plugins/layup.lua`.

```
LayupFileBashToBuf <bash_args>

ex: dig for dmarc records

LayupFileBashToBuf dig _dmarc.domain.tld txt
```

**Default remap to normal-mode <leader>Fb**
