local ReplicatedStorage = game:GetService("ReplicatedStorage")

local extend = require(ReplicatedStorage.Modules.extend)

local _task = task
local task = {}

local queues = {}
local processing = {}

function task.queue(queueName: string, f: () -> ())
	assert(typeof(queueName) == "string", "First argument to task.queue must be a string")
	assert(typeof(f) == "function", "Second argument to task.queue must be a function")
	if not queues[queueName] then
		queues[queueName] = {}
	end
	table.insert(queues[queueName], f)
	if not processing[queueName] then
		processing[queueName] = true
		_task.spawn(function()
			while #queues[queueName] > 0 do
				local nextFn = table.remove(queues[queueName], 1)
				local success, err = pcall(nextFn)
				if not success then
					error("[task.queue][" .. queueName .. "] Error: ".. err)
				end
			end
			queues[queueName] = nil
			processing[queueName] = nil
		end)
	end
end

extend(task, _task)
return task:: typeof(task) & typeof(_task)