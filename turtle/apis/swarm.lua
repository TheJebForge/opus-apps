local Event   = require('event')
local Socket  = require('socket')
local Util    = require('util')

local function hijackTurtle(remoteId)
	local socket, msg = Socket.connect(remoteId, 188)

  if not socket then
		error(msg)
	end

	socket:write('turtle')
	local methods = socket:read()

	local hijack = { }
	for _,method in pairs(methods) do
		hijack[method] = function(...)
			socket:write({ fn = method, args = { ... } })
			local resp = socket:read()
			if not resp then
				error('timed out: ' .. method)
			end
			return table.unpack(resp)
		end
	end

	return hijack, socket
end
local class = require('class')
local Swarm = class()
function Swarm:init(args)
  self.pool = { }
  Util.merge(self, args)
end
function Swarm:add(id, args)
  local member = Util.shallowCopy(args)
  member.id = id
  self.pool[id] = member
end
function Swarm:run(fn)
  for id, member in pairs(self.pool) do
    Event.addRoutine(function()
      local s, m = pcall(function()
        member.turtle, member.socket = hijackTurtle(id)

        fn(member)
      end)
      if member.socket then
        member.socket:close()
        member.socket = nil
      end
      self.pool[id] = nil
      self:onRemove(member, s, m)
    end)
  end
end
function Swarm:shutdown()
  for _, member in pairs(self.pool) do
    if member.socket then
      member.socket:close()
      member.socket = nil
    end
  end
end
function Swarm:onRemove(member, success, msg)
  print('removed from pool: ' .. member.id)
  if not success then
    _G.printError(msg)
  end
end

return Swarm