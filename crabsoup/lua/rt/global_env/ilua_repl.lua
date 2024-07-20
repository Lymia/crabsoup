--
-- ilua.lua
--
-- A more friendly Lua interactive prompt
-- doesn't need '='
-- will print out tables recursively
--
-- Steve Donovan, 2007
-- Chris Hixon, 2010
-- Alissa Rao, 2024
--

-- imported global functions
local builtin_funcs = ...
local safe_loadstring = builtin_funcs.crabsoup.loadstring

-- ILUA implementation
local function repl_main()
    local env = getfenv(0)

    print('ILUA: ' .. _VERSION .. ' + ' .. builtin_funcs.crabsoup._VERSION)
    local chunkname = "@<stdin>"

    -- readline support
    local readline, saveline
    do
        local rustyline_editor = builtin_funcs.crabsoup.open_rustyline()
        function readline(prompt)
            return rustyline_editor:readline(prompt)
        end
        function saveline(line)
            return rustyline_editor:saveline(line)
        end
    end

    -- functions
    local function get_input()
        local lines, i, input, chunk, err = {}, 1
        while true do
            input = readline((i == 1) and ">> " or ".. ")
            if not input then
                return
            end
            lines[i] = input
            input = table.concat(lines, "\n")
            chunk, err = safe_loadstring(string.format("return(%s)", input), chunkname, {})
            if chunk then
                return input
            end
            chunk, err = safe_loadstring(input, chunkname, {})
            if chunk or not string.match(err, "<eof>$") then
                return input
            end
            lines[1] = input
            i = 2
        end
    end

    local function wrap_output(...)
        print(builtin_funcs.repr(...))
        env._ = select(1, ...)
    end

    local function eval_lua(line)
        -- is it an expression?
        local chunk, err = safe_loadstring(string.format("(...)((function() return %s end)())", line), chunkname)
        if err then
            -- otherwise, a statement?
            chunk, err = safe_loadstring(string.format("(...)((function() %s end)())", line), chunkname)
        end
        if err then
            print(err)
            return
        end

        -- compiled ok, evaluate the chunk
        local ok, res = pcall(chunk, wrap_output)
        if not ok then
            print(res)
        end
    end

    while true do
        local input = get_input()
        if not input or string.trim(input) == 'quit' then
            break
        end
        eval_lua(input)
        saveline(input)
    end
end

-- Export functions
local is_repl_running = false
local function run_repl(env)
    local function do_repl()
        if is_repl_running then
            error("Please do not try to start a REPL in another REPL.", 3)
        end

        is_repl_running = true
        local success, err = pcall(function()
            repl_main(env)
        end)
        is_repl_running = false

        if not success then
            error("REPL encountered an error: " .. err, 3)
        end
    end

    local thread = builtin_funcs.low_level.load_in_new_thread(do_repl, env)
    while coroutine.status(thread) == "suspended" do
        local status, result = coroutine.resume(thread)
        if not status then
            error(result)
        end

        if typeof(result) == "PluginInstruction" then
            if result:is_exit() then
                print("Exit requested via Plugin.exit")
                break
            end
            if result:is_fail() then
                error("Caught plugin failure: " .. result:get_message())
            end
        elseif result then
            print("Coroutine yielded value: " .. tostring(result))
        end
    end
end

function builtin_funcs.run_repl_from_console()
    run_repl(builtin_funcs.envs.standalone)
end

function builtin_funcs.run_repl_from_console_plugin()
    run_repl(builtin_funcs.envs.plugin)
end

function builtin_funcs.run_repl_in_env(env)
    run_repl(env)
end
