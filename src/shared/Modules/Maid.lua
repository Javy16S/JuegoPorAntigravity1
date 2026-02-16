--!strict
-- Maid.lua
-- Description: Standard Maid class for managing RBXScriptConnections and other resources.

local Maid = {}
Maid.__index = Maid

export type Maid = {
    _tasks: {[any]: any},
    Give: (self: Maid, task: any) -> any,
    DoCleaning: (self: Maid) -> (),
    Destroy: (self: Maid) -> (),
}

function Maid.new(): Maid
    return setmetatable({
        _tasks = {}
    }, Maid) :: any
end

function Maid:Give(task: any): any
    if not task then
        warn("[Maid] Attempted to give a nil task.")
        return nil
    end

    table.insert(self._tasks, task)
    return task
end

function Maid:DoCleaning()
    local tasks = self._tasks
    for index, task in pairs(tasks) do
        if typeof(task) == "RBXScriptConnection" then
            task:Disconnect()
        elseif typeof(task) == "Instance" then
            task:Destroy()
        elseif typeof(task) == "function" then
            task()
        elseif typeof(task) == "table" and typeof(task.Destroy) == "function" then
            task:Destroy()
        elseif typeof(task) == "table" and typeof(task.Disconnect) == "function" then
            task:Disconnect()
        end
        tasks[index] = nil
    end
end

function Maid:Destroy()
    self:DoCleaning()
end

return Maid
