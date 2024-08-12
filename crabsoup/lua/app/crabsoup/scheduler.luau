--!strict

local module = {}

type Task = {}

type TaskScheduler = typeof(setmetatable({} :: TaskScheduler_fields, {} :: TaskScheduler_mt))
type TaskScheduler_fields = {}
type TaskScheduler_mt = {
    __index: TaskScheduler_methods,
}
type TaskScheduler_methods = {}

local TaskScheduler: TaskScheduler_methods = {} :: TaskScheduler_methods
local TaskScheduler_mt: TaskScheduler_mt = { __index = TaskScheduler }

function module.create_task_scheduler()
    return setmetatable({}, TaskScheduler_mt)
end

return module
