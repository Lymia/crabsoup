--!strict
--!native

local module = {}

function module.wait_on_processes(processes: { { name: string, thread: () -> () } })
    local queued = {}
    for k, v in processes do
        queued[k] = {
            name = v.name,
            thread = coroutine.create(function()
                return xpcall(v.thread, Plugin.traceback)
            end),
            resume_with = nil :: any?,
        }
    end

    local deferred = {}

    table.sort(queued, function(a, b)
        return a.name > b.name
    end)

    while #queued ~= 0 do
        -- resume the first plausible thread
        local active = table.pop(queued)

        local result, value, msg = coroutine.resume(active.thread, active.resume_with)
        if not result then
            error("Error resuming plugin??")
        end

        if coroutine.status(active.thread) == "suspended" then
            if typeof(value) == "Process" then
                if Log.trace_enabled then
                    Log.trace(`Deferring page '{active.name}' to wait for process...`)
                end
                table.insert(deferred, { obj = active, proc = value })
            elseif typeof(value) == "PluginInstruction" then
                if value:is_exit() then
                    -- do nothing
                elseif value:is_fail() then
                    error(`Plugin in page '{active.name}' failed with message: {value:get_message()}`)
                else
                    error("unreachable?")
                end
            else
                error(`Plugin in page '{active.name}' yielded with unexpected values: {Value.repr(value)}`)
            end
        else
            if coroutine.status(active.thread) == "dead" then
                -- normal return
                if not value then
                    error(`Page '{active.name}' encountered an error during rendering:\n{msg}`)
                end
            else
                error("unreachable?")
            end
        end

        -- end early if everything is processed
        if #queued == 0 and #deferred == 0 then
            break
        end

        while true do
            -- check for deferred processes that can be put back into the queue
            for i = #deferred, 1, -1 do
                local obj = deferred[i]
                if obj.proc and Process.is_completed(obj.proc) then
                    if Log.trace_enabled then
                        Log.trace(`Resuming deferred page '{obj.obj.name}'`)
                    end
                    obj.obj.resume_with = Process.wait_on(obj.proc)
                    table.insert(queued, obj.obj)
                    table.remove(deferred, i)
                end
            end

            -- wait if too many CPU-consuming processes are currently deferred or no threads are ready to run
            local cpu_task_count = 0
            for _, v in deferred do
                if v.proc then
                    cpu_task_count += 1
                end
            end

            if cpu_task_count <= Sys.cpu_count and #queued > 0 then
                break
            end

            Sys.sleep(0.0001)
        end
    end
end

return module
