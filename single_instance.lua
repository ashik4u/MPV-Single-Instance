-- single_instance.lua - forces single instance using IPC communication with "master" mpv instance
-- From https://github.com/ashik4u/MPV-Single-Instance

-- 2026/02/07 TK - modified, windows socket path corrected, play / enqueue actions based on file extension

local mp    = require 'mp'
local msg   = require 'mp.msg'
local utils = require 'mp.utils'
local opts = require("mp.options")

local o = {
    -- play mode used for all files not explicitly listed in extra_play_types (see loadfile mpv documentation)
    default_play_mode = 'insert-next-play',
    -- play mode used for explicitly listed file extensions
    extra_play_mode =  'replace',
    -- file extensions for which extra_play_mode is used when opened in secondary mpv instance
    extra_play_types = [[ [ ".m3u", ".pls" ] ]], 
}

opts.read_options(o, "single_instance")

local ipc_socket_path
local is_windows = package.config:sub(1,1) == "\\"
if is_windows then
    ipc_socket_path = "\\\\.\\pipe\\mpvsocket"
else
    local runtime_dir = os.getenv("XDG_RUNTIME_DIR") or "/tmp"
    ipc_socket_path = runtime_dir .. "/mpvsocket"
end

local function escape_json_str(str)
    if not str then return "" end
    return (str:gsub("\\", "\\\\")
               :gsub("\"", "\\\""))
end

local function get_play_mode(fname)
    fname = fname:lower()
    msg.info('get_play_mode() called for '..fname)
    -- check presence of fname extension within configured extra play types
    -- and based on (non)presence returns configured default/extra play mode
    for k,ext in pairs(utils.parse_json(o.extra_play_types)) do
        print("DEBUG: "..k.." "..ext)
        if (fname:sub(-(#ext)) == ext:lower() ) then
            msg.info('get_play_mode() - match!, using ' .. o.extra_play_mode)
            return o.extra_play_mode
        end
    end
    msg.info('get_play_mode() - no match, using default ' .. o.default_play_mode)
    return o.default_play_mode
end

local function get_full_path()
    local path = mp.get_property("path") or ""
    return path
end

local function try_connect_pipe(path)
    -- Use a non-destructive check on Unix (don't open for writing,
    -- which could create a regular file and block socket creation).
    local mode = is_windows and "w" or "r"
    local f = io.open(path, mode)
    if f then
        f:close()
        return true
    end
    return false
end

local function send_file_to_main(path, filepath)
    local escaped = escape_json_str(filepath or "")
    local json = string.format(
        -- replace originally, insert-next-play modified (=enqueue after actual file)
        '{\"command\": [\"loadfile\", \"%s\", \"'..get_play_mode(filepath)..'\"]}',
        escaped
    )

    local f = io.open(path, "w")
    if not f then
        msg.error("Could not connect to IPC pipe: " .. path)
        return false
    end

    f:write(json .. "\n")
    f:close()

    msg.info("Sent file to main MPV instance: " .. filepath)
    return true
end

local function create_ipc_server(path)
    -- Remove stale socket file on Unix-like systems before creating server.
    if not is_windows then
        pcall(os.remove, path)
    end
    mp.set_property("input-ipc-server", path)
    msg.info("Created IPC server: " .. path)
end

function start_main_instance()
    if try_connect_pipe(ipc_socket_path) then
        msg.info("Another MPV instance detected. Acting as secondary.")
        return false
    else
        create_ipc_server(ipc_socket_path)
        msg.info("No other instance found. Acting as main MPV.")
        return true
    end
end
local is_main_instance = start_main_instance()

mp.register_event("start-file", function()
    local filepath = get_full_path()

    if filepath == "" then
        msg.warn("No valid file path. Idle mode.")
        return
    end

    msg.info("Opening file: " .. filepath)

    if is_main_instance then
        msg.info("Main instance: playing normally.")
    else
        msg.info("Secondary instance: forwarding file → quitting.")

        if send_file_to_main(ipc_socket_path, filepath) then
            --mp.add_timeout(0.1, function()
                mp.commandv("quit")     -- immediatelly exit after forwarding - prevent enqueuing of playlist tracks
            --end )
        else
            msg.error("Failed to send file. Converting to main instance.")
            create_ipc_server(ipc_socket_path)
            is_main_instance = true
        end
    end
end)

