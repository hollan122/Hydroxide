local RemoteSpy = {}
local Remote = import("objects/Remote")

local requiredMethods = {
    ["checkCaller"] = true,
    ["newCClosure"] = true,
    ["hookFunction"] = true,
    ["isReadOnly"] = true,
    ["setReadOnly"] = true,
    ["getInfo"] = true,
    ["getMetatable"] = true,
    ["setClipboard"] = true,
    ["getNamecallMethod"] = true,
    ["getCallingScript"] = true,
}

local remoteMethods = {
    FireServer = true,
    InvokeServer = true,
    Fire = true,
    Invoke = true
}

local remotesViewing = {
    RemoteEvent = true,
    RemoteFunction = false,
    BindableEvent = false,
    BindableFunction = false
}

local methodHooks = {
    RemoteEvent = Instance.new("RemoteEvent").FireServer,
    RemoteFunction = Instance.new("RemoteFunction").InvokeServer,
    BindableEvent = Instance.new("BindableEvent").Fire,
    BindableFunction = Instance.new("BindableFunction").Invoke
}

local currentRemotes = {}

local remoteDataEvent = Instance.new("BindableEvent")
local eventSet = false

-- Connect an event to the remoteDataEvent
local function connectEvent(callback)
    remoteDataEvent.Event:Connect(callback)
    eventSet = true
end

-- Hook for namecall method interception
local nmcTrampoline
nmcTrampoline = hookmetamethod(game, "__namecall", function(self, ...)
    if typeof(self) ~= "Instance" then
        return nmcTrampoline(self, ...)
    end

    local method = getnamecallmethod()
    
    -- Normalize method names
    if method == "fireServer" then
        method = "FireServer"
    elseif method == "invokeServer" then
        method = "InvokeServer"
    end
    
    -- If we're dealing with remote objects
    if remotesViewing[self.ClassName] and remoteMethods[method] then
        local remote = currentRemotes[self]
        local vargs = {select(1, ...)}
        
        -- Ensure we are handling the remote object
        if not remote then
            remote = Remote.new(self)
            currentRemotes[self] = remote
        end

        local remoteIgnored = remote.Ignored
        local argsIgnored = remote:AreArgsIgnored(vargs)

        -- Fire the event if conditions are met
        if eventSet and not remoteIgnored and not argsIgnored then
            local call = {
                script = getcallingscript(),
                args = vargs,
                func = debug.info(3, "f")
            }

            remote:IncrementCalls(call)
            remoteDataEvent:Fire(self, call)
        end

        -- Block the call if conditions are met
        if remote.Blocked or remote:AreArgsBlocked(vargs) then
            return
        end
    end

    return nmcTrampoline(self, ...)
end)

-- Check permissions for method execution
local function checkPermission(instance)
    return instance.ClassName ~= nil
end

-- Hook the remote method functions to log calls
for _name, hook in pairs(methodHooks) do
    local originalMethod
    originalMethod = hookfunction(hook, newcclosure(function(self, ...)
        if typeof(self) ~= "Instance" then
            return originalMethod(self, ...)
        end
        
        local success = pcall(checkPermission, self)
        if not success then return originalMethod(self, ...) end
        
        -- Only intercept if we are watching the correct remote class
        if self.ClassName == _name and remotesViewing[self.ClassName] and self ~= remoteDataEvent then
            local remote = currentRemotes[self]
            local vargs = {select(1, ...)}

            -- Ensure remote exists
            if not remote then
                remote = Remote.new(self)
                currentRemotes[self] = remote
            end

            local remoteIgnored = remote.Ignored 
            local argsIgnored = remote:AreArgsIgnored(vargs)
            
            -- Fire the event if conditions are met
            if eventSet and not remoteIgnored and not argsIgnored then
                local call = {
                    script = getcallingscript(),
                    args = vargs,
                    func = debug.info(3, "f")
                }

                remote:IncrementCalls(call)
                remoteDataEvent:Fire(self, call)
            end

            -- Block the method if conditions are met
            if remote.Blocked or remote:AreArgsBlocked(vargs) then
                return
            end
        end
        
        return originalMethod(self, ...)
    end))
end

RemoteSpy.RemotesViewing = remotesViewing
RemoteSpy.CurrentRemotes = currentRemotes
RemoteSpy.ConnectEvent = connectEvent
RemoteSpy.RequiredMethods = requiredMethods

return RemoteSpy
