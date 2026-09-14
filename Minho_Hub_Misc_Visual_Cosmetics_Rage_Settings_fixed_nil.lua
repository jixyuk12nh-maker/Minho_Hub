local HOME_DIR = "Minho Hub/"
local CONFIG_DIR = HOME_DIR .. "Config/"
local function ensureFolder(path)
    if makefolder then
        if isfolder then
            if not isfolder(path) then pcall(makefolder, path) end
        else
            pcall(makefolder, path)
        end
    end
end
ensureFolder(HOME_DIR)
ensureFolder(CONFIG_DIR)

-- Source
do
    repeat task.wait() until game:IsLoaded()

    local function safeRef(ref)
    	return cloneref and cloneref(ref) or ref
    end

    local setidentity = setthreadcontext or setthreadidentity or set_thread_identity or set_thread_context or setidentity

    local RunService= safeRef(game:GetService("RunService"))
    local UserInputService= safeRef(game:GetService("UserInputService"))
    local CoreGui= safeRef(game:GetService("CoreGui"))
    local HttpService= safeRef(game:GetService("HttpService"))

    LPH_NO_VIRTUALIZE = function(f) return f end
    LPH_NO_UPVALUES = function(f) return f end

    local Trove = LPH_NO_VIRTUALIZE(function()

    local FN_MARKER = {}
    local THREAD_MARKER = {}
    local GENERIC_OBJECT_CLEANUP_METHODS = table.freeze({ "Destroy", "Disconnect", "destroy", "disconnect" })

    local function GetObjectCleanupFunction(object, cleanupMethod)
    	local t = typeof(object)

    	if t == "function" then
    		return FN_MARKER
    	elseif t == "thread" then
    		return THREAD_MARKER
    	end

    	if cleanupMethod then
    		return cleanupMethod
    	end

    	if t == "Instance" then
    		return "Destroy"
    	elseif t == "RBXScriptConnection" then
    		return "Disconnect"
    	elseif t == "table" then
    		for _, genericCleanupMethod in GENERIC_OBJECT_CLEANUP_METHODS do
    			if typeof(object[genericCleanupMethod]) == "function" then
    				return genericCleanupMethod
    			end
    		end
    	end

    	error(("failed to get cleanup function for object %s: %s"):format(t, object), 3)
    end

    local function AssertPromiseLike(object)
    	if
    		typeof(object) ~= "table"
    		or typeof(object.getStatus) ~= "function"
    		or typeof(object.finally) ~= "function"
    		or typeof(object.cancel) ~= "function"
    	then
    		error("did not receive a promise as an argument", 3)
    	end
    end
    local Trove = {}
    Trove.__index = Trove
    function Trove.new()
    local self = setmetatable({}, Trove)

    	self._objects = {}
    	self._cleaning = false

    	return (self )
    end






    function Trove.Add(self, object, cleanupMethod)
    if self._cleaning then
    		error("cannot call trove:Add() while cleaning", 2)
    	end

    	local cleanup = GetObjectCleanupFunction(object, cleanupMethod)
    	table.insert(self._objects, { object, cleanup })

    	return object
    end
    function Trove.Clone(self, instance)
    if self._cleaning then
    		error("cannot call trove:Clone() while cleaning", 2)
    	end

    	return self:Add(instance:Clone())
    end



    function Trove.Construct(self, class, ...)
    	if self._cleaning then
    		error("Cannot call trove:Construct() while cleaning", 2)
    	end

    	local object = nil
    	local t = type(class)
    	if t == "table" then
    		object = (class ).new(...)
    	elseif t == "function" then
    		object = (class )(...)
    	end

    	return self:Add(object)
    end
    function Trove.Connect(self, signal, fn)
    	if self._cleaning then
    		error("Cannot call trove:Connect() while cleaning", 2)
    	end

    	return self:Add(signal:Connect(fn))
    end

    function Trove.BindToRenderStep(self, name, priority, fn)
    	if self._cleaning then
    		error("cannot call trove:BindToRenderStep() while cleaning", 2)
    	end

    	RunService:BindToRenderStep(name, priority, fn)

    	self:Add(function()
    		RunService:UnbindFromRenderStep(name)
    	end)
    end


    function Trove.AddPromise(self, promise)
    	if self._cleaning then
    		error("cannot call trove:AddPromise() while cleaning", 2)
    	end
    	AssertPromiseLike(promise)

    	if promise:getStatus() == "Started" then
    		promise:finally(function()
    			if self._cleaning then
    				return
    			end
    			self:_findAndRemoveFromObjects(promise, false)
    		end)

    		self:Add(promise, "cancel")
    	end

    	return promise
    end

    function Trove.Remove(self, object)
    if self._cleaning then
    		error("cannot call trove:Remove() while cleaning", 2)
    	end

    	return self:_findAndRemoveFromObjects(object, true)
    end

    function Trove.Extend(self)
    	if self._cleaning then
    		error("cannot call trove:Extend() while cleaning", 2)
    	end

    	return self:Construct(Trove)
    end

    function Trove.Clean(self)
    	if self._cleaning then
    		return
    	end

    	self._cleaning = true

    	for _, obj in self._objects do
    		self:_cleanupObject(obj[1], obj[2])
    	end

    	table.clear(self._objects)
    	self._cleaning = false
    end

    function Trove._findAndRemoveFromObjects(self, object, cleanup)
    local objects = self._objects

    	for i, obj in ipairs(objects) do
    		if obj[1] == object then
    			local n = #objects
    			objects[i] = objects[n]
    			objects[n] = nil

    			if cleanup then
    				self:_cleanupObject(obj[1], obj[2])
    			end

    			return true
    		end
    	end

    	return false
    end

    function Trove._cleanupObject(self, object, cleanupMethod)
    	if cleanupMethod == FN_MARKER then
    		object()
    	elseif cleanupMethod == THREAD_MARKER then
    		pcall(task.cancel, object)
    	else
    		object[cleanupMethod](object)
    	end
    end

    function Trove.AttachToInstance(self, instance)
    	if self._cleaning then
    		error("cannot call trove:AttachToInstance() while cleaning", 2)
    	elseif not instance:IsDescendantOf(game) then
    		error("instance is not a descendant of the game hierarchy", 2)
    	end

    	return self:Connect(instance.Destroying, function()
    		self:Destroy()
    	end)
    end

    function Trove.Destroy(self)
    	self:Clean()
    end

    return {
    	new = Trove.new,
    }
    end)()


    local Signal = LPH_NO_VIRTUALIZE(function()



    local freeRunnerThread = nil
    local function acquireRunnerThreadAndCallEventHandler(fn, ...)
    	local acquiredRunnerThread = freeRunnerThread
    	freeRunnerThread = nil
    	fn(...)

    	freeRunnerThread = acquiredRunnerThread
    end

    local function runEventHandlerInFreeThread(...)
    	acquireRunnerThreadAndCallEventHandler(...)
    	while true do
    		acquireRunnerThreadAndCallEventHandler(coroutine.yield())
    	end
    end


    local Connection = {}
    Connection.__index = Connection

    function Connection:Disconnect()
    	if not self.Connected then
    		return
    	end
    	self.Connected = false


    	if self._signal._handlerListHead == self then
    		self._signal._handlerListHead = self._next
    	else
    		local prev = self._signal._handlerListHead
    		while prev and prev._next ~= self do
    			prev = prev._next
    		end
    		if prev then
    			prev._next = self._next
    		end
    	end
    end

    Connection.Destroy = Connection.Disconnect


    setmetatable(Connection, {
    	__index = function(_tb, key)
    		error(("Attempt to get Connection::%s (not a valid member)"):format(tostring(key)), 2)
    	end,
    	__newindex = function(_tb, key, _value)
    		error(("Attempt to set Connection::%s (not a valid member)"):format(tostring(key)), 2)
    	end,
    })



    local Signal = {}
    Signal.__index = Signal
    function Signal.new()
    local self = setmetatable({
    		_handlerListHead = false,
    		_proxyHandler = nil,
    		_yieldedThreads = nil,
    	}, Signal)

    	return self
    end


    function Signal.Wrap(rbxScriptSignal)
    assert(
    		typeof(rbxScriptSignal) == "RBXScriptSignal",
    		"Argument #1 to Signal.Wrap must be a RBXScriptSignal; got " .. typeof(rbxScriptSignal)
    	)

    	local signal = Signal.new()
    	signal._proxyHandler = rbxScriptSignal:Connect(function(...)
    		signal:Fire(...)
    	end)

    	return signal
    end

    function Signal.Is(obj)
    return type(obj) == "table" and getmetatable(obj) == Signal
    end


    function Signal:Connect(fn)
    	local connection = setmetatable({
    		Connected = true,
    		_signal = self,
    		_fn = fn,
    		_next = false,
    	}, Connection)

    	if self._handlerListHead then
    		connection._next = self._handlerListHead
    		self._handlerListHead = connection
    	else
    		self._handlerListHead = connection
    	end

    	return connection
    end
    function Signal:ConnectOnce(fn)
    	return self:Once(fn)
    end

    function Signal:Once(fn)
    	local connection
    	local done = false

    	connection = self:Connect(function(...)
    		if done then
    			return
    		end

    		done = true
    		connection:Disconnect()
    		fn(...)
    	end)

    	return connection
    end

    function Signal:GetConnections()
    	local items = {}

    	local item = self._handlerListHead
    	while item do
    		table.insert(items, item)
    		item = item._next
    	end

    	return items
    end
    function Signal:DisconnectAll()
    	local item = self._handlerListHead
    	while item do
    		item.Connected = false
    		item = item._next
    	end
    	self._handlerListHead = false

    	local yieldedThreads = rawget(self, "_yieldedThreads")
    	if yieldedThreads then
    		for thread in yieldedThreads do
    			if coroutine.status(thread) == "suspended" then
    				warn(debug.traceback(thread, "signal disconnected; yielded thread cancelled", 2))
    				task.cancel(thread)
    			end
    		end
    		table.clear(self._yieldedThreads)
    	end
    end

    function Signal:Fire(...)
    	local item = self._handlerListHead
    	while item do
    		if item.Connected then
    			if not freeRunnerThread then
    				freeRunnerThread = coroutine.create(runEventHandlerInFreeThread)
    			end
    			task.spawn(freeRunnerThread, item._fn, ...)
    		end
    		item = item._next
    	end
    end
    function Signal:FireDeferred(...)
    	local item = self._handlerListHead
    	while item do
    		local conn = item
    		task.defer(function(...)
    			if conn.Connected then
    				conn._fn(...)
    			end
    		end, ...)
    		item = item._next
    	end
    end

    function Signal:Wait()
    	local yieldedThreads = rawget(self, "_yieldedThreads")
    	if not yieldedThreads then
    		yieldedThreads = {}
    		rawset(self, "_yieldedThreads", yieldedThreads)
    	end

    	local thread = coroutine.running()
    	yieldedThreads[thread] = true

    	self:Once(function(...)
    		yieldedThreads[thread] = nil
    		task.spawn(thread, ...)
    	end)

    	return coroutine.yield()
    end

    function Signal:Destroy()
    	self:DisconnectAll()

    	local proxyHandler = rawget(self, "_proxyHandler")
    	if proxyHandler then
    		proxyHandler:Disconnect()
    	end
    end


    setmetatable(Signal, {
    	__index = function(_tb, key)
    		error(("Attempt to get Signal::%s (not a valid member)"):format(tostring(key)), 2)
    	end,
    	__newindex = function(_tb, key, _value)
    		error(("Attempt to set Signal::%s (not a valid member)"):format(tostring(key)), 2)
    	end,
    })

    return table.freeze({
    	new = Signal.new,
    	Wrap = Signal.Wrap,
    	Is = Signal.Is,
    })
    end)()


    local function inside(x, y, pX, pY, sX, sY)
    return x > pX and x < pX + sX and y > pY and y < pY + sY
    end

    local function insideFrame(input, frame)
    	local position = frame.AbsolutePosition
    	local size = frame.AbsoluteSize

    	return inside(input.X, input.Y, position.X, position.Y, size.X, size.Y)
    end

    local function deepCopy(t)
    local copy = {}

    	for k, v in t do
    		if type(v) == "table" then
    			v = deepCopy(v)
    		end

    		copy[k] = v
    	end

    	return copy
    end







    local UISection = {}
    UISection.__index = UISection
    do
    	function UISection.new(parent, side, label)
    local self = setmetatable({}, UISection)
    		self._trove = parent._trove:Extend()
    		self.instances = {}
    		self.parent = parent

    		return UISection.into((self ) , side, label)
    	end

    	function UISection.setLabel(self, label)
    		assert(label, "UISection.setLabel(_, _, label) -> expected string got nil")
    		assert(typeof(label) == "string", "UISection.setLabel(_, _, label) -> expected string, got " .. typeof(label))

    		self.instances.label.Text = label
    	end

    	function UISection._makeInstances(self, side)
    		local container= Instance.new("Frame")
    		container.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    		container.BorderColor3 = Color3.fromRGB(50, 50, 50)
    		container.Size = UDim2.new(1, -2, 0, 22)
    		self.instances.container = container

    		local inline= Instance.new("Frame")
    		inline.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    		inline.BorderSizePixel = 0
    		inline.Position = UDim2.new(0, 1, 0, 1)
    		inline.Size = UDim2.new(1, -2, 1, -2)
    		inline.Parent = container

    		local theme= Instance.new("Frame")
    		theme.BackgroundColor3 = Color3.fromRGB(55, 175, 225)
    		theme.BorderSizePixel = 0
    		theme.Size = UDim2.new(1, 0, 0, 2)
    		theme.Parent = inline

    		local label= Instance.new("TextLabel")
    		label.BackgroundTransparency = 1
    		label.Font = Enum.Font.Arial
    		label.TextSize = 12
    		label.TextStrokeTransparency = 0
    		label.TextColor3 = Color3.fromRGB(255, 255, 255)
    		label.TextXAlignment = Enum.TextXAlignment.Left
    		label.Position = UDim2.new(0, 3, 0, 5)
    		label.Size = UDim2.new(1, -6, 0, 11)
    		label.Parent = inline
    		self.instances.label = label

    		local canvas= Instance.new("Frame")
    		canvas.Position = UDim2.new(0, 0, 1, 0)
    		canvas.Size = UDim2.new(1, 0, 1, -20)
    		canvas.AnchorPoint = Vector2.new(0, 1)
    		canvas.BackgroundTransparency = 1
    		canvas.Parent = inline
    		self.instances.canvas = canvas

    		local listLayout= Instance.new("UIListLayout")
    		listLayout.Padding = UDim.new(0, 4)
    		listLayout.FillDirection = Enum.FillDirection.Vertical
    		listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    		listLayout.Parent = canvas

    		container.Parent = self.parent.canvas[side]
    	end

    	function UISection.into(self, side, label)
    self:_makeInstances(side)
    		self:setLabel(label)
    		return self
    	end
    end

    local UISectionHolder = {}
    UISectionHolder.__index = UISectionHolder
    do
    	function UISectionHolder.new(parent)
    local self = setmetatable({}, UISectionHolder)
    		self._trove = parent._trove:Extend()
    		self.sections = {
    			left = {},
    			right = {},
    		}
    		self.parent = parent

    		return UISectionHolder.into((self ) )
    	end

    	function UISectionHolder.newSection(self, side, label)
    assert(side, "UIExtendable.newSection(_, side) : _ -> expected string got nil")
    		assert(typeof(side) == "string", "UIExtendable.newSection(_, side) : _ -> expected string, got " .. typeof(side))
    		assert(side == "left" or side == "right", "UIExtendable.newSection(_, side) : _ -> expected { \"Left\" | \"Right\" }, got \"" .. side .. "\"")

    		return UISection.new(self, side, label)
    	end

    	function UISectionHolder._makeInstances(self)
    		assert(self.sections, "UIExtendable._makeSectionInstances(_) -> internal failure")

    		local leftCanvas= Instance.new("ScrollingFrame")
    		leftCanvas.BackgroundTransparency = 1
    		leftCanvas.Position = UDim2.new(0, 5, 0, 5)
    		leftCanvas.AutomaticCanvasSize = Enum.AutomaticSize.Y
    		leftCanvas.Size = UDim2.new(0.5, -8, 1, -10)
    		leftCanvas.BorderSizePixel = 0
    		leftCanvas.CanvasSize = UDim2.new(0, 0)
    		leftCanvas.ScrollBarThickness = 1

    		local uiLayout = Instance.new("UIListLayout")
    		uiLayout.Padding = UDim.new(0, 7)
    		uiLayout.SortOrder = Enum.SortOrder.LayoutOrder
    		uiLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    		uiLayout.Parent = leftCanvas

    		local uiPadding = Instance.new("UIPadding")
    		uiPadding.PaddingTop = UDim.new(0, 1)
    		uiPadding.PaddingBottom = UDim.new(0, 1)
    		uiPadding.Parent = leftCanvas

    		local rightCanvas= Instance.new("ScrollingFrame")
    		rightCanvas.BackgroundTransparency = 1
    		rightCanvas.Position = UDim2.new(0.5, 3, 0, 5)
    		rightCanvas.AutomaticCanvasSize = Enum.AutomaticSize.Y
    		rightCanvas.Size = UDim2.new(0.5, -8, 1, -10)
    		rightCanvas.BorderSizePixel = 0
    		rightCanvas.CanvasSize = UDim2.new(0, 0)
    		rightCanvas.ScrollBarThickness = 1

    		local uiLayout = Instance.new("UIListLayout")
    		uiLayout.Padding = UDim.new(0, 7)
    		uiLayout.SortOrder = Enum.SortOrder.LayoutOrder
    		uiLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    		uiLayout.Parent = rightCanvas

    		local uiPadding = Instance.new("UIPadding")
    		uiPadding.PaddingTop = UDim.new(0, 1)
    		uiPadding.PaddingBottom = UDim.new(0, 1)
    		uiPadding.Parent = rightCanvas

    		self.canvas = {
    			left = leftCanvas,
    			right = rightCanvas,
    		}

    		leftCanvas.Parent = self.parent.instances.canvas
    		rightCanvas.Parent = self.parent.instances.canvas
    	end

    	function UISectionHolder.into(self)
    self:_makeInstances()
    		return self
    	end
    end

    local UIExtendable = {}
    UIExtendable.__index = UIExtendable
    do
    	function UIExtendable.new()
    local self = setmetatable({}, UIExtendable)
    		self.instances = {}
    		self.visible = false

    		return UIExtendable.into((self ) )
    	end

    	function UIExtendable.into(self)
    return self
    	end

    	function UIExtendable.intoSections(self)
    local child = UISectionHolder.new(self)
    		self.child = child

    		return child
    	end
    end


    local UIColorpickerMenu = {}
    UIColorpickerMenu.__index = UIColorpickerMenu
    do
    	function UIColorpickerMenu.new(base)
    		local self = setmetatable({}, UIColorpickerMenu)
    		self._trove = base._trove:Extend()

    		self.instances = {}
    		self.ref = base
    		self.options = {}

    		return UIColorpickerMenu.into((self ) )
    	end

    	function UIColorpickerMenu.attach(self, colorpicker, base)
    		if base.activeMenu ~= "none" then
    			self:detach(base )
    		end

    		self.feature = colorpicker

    		if colorpicker.hasAlpha then
    			self.instances.alphaPicker.Visible = true
    			self.instances.container.Size = UDim2.new(0, 246, 0, 260)
    		else
    			self.instances.alphaPicker.Visible = false
    			self.instances.container.Size = UDim2.new(0, 246, 0, 236)
    		end

    		self._trove:Connect(UserInputService.InputBegan, function(input)
    			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
    				local inputX, inputY = input.Position.X, input.Position.Y

    				local container = self.instances.container
    				local position, size = container.AbsolutePosition, container.AbsoluteSize

    				if inside(inputX, inputY, position.X, position.Y, size.X, size.Y) then
    					return
    				end

    				local outline = colorpicker.instances.container
    				local absPosition, absSize = outline.AbsolutePosition, outline.AbsoluteSize

    				if not inside(inputX, inputY, absPosition.X, absPosition.Y, absSize.X, absSize.Y) then
    					self:detach(base)

    					colorpicker.open = false
    				end
    			end
    		end)

    		self._trove:Connect((colorpicker.changed ), function(state)
    			local h, s, v = state.rgb:ToHSV()

    			self.instances.saturationGradient.Color = ColorSequence.new({
    				ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
    				ColorSequenceKeypoint.new(1, Color3.fromHSV(h, 1, 1)),
    			})

    			self.instances.huePosition.Position = UDim2.new(0.5, -4, 0, math.clamp(200 - (h * 200), 0, 198))
    			self.instances.chromePosition.Position = UDim2.new(0, math.clamp((s * 200), 0, 196), 0, math.clamp(200 - (v * 200), 0, 196))

    			self.instances.alphaPosition.Position = UDim2.new(0, math.clamp(state.alpha * 224, 0, 222), 0.5, -4)
    		end)


    		do
    			local h, s, v = colorpicker.value.rgb:ToHSV()

    			self.instances.saturationGradient.Color = ColorSequence.new({
    				ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
    				ColorSequenceKeypoint.new(1, Color3.fromHSV(h, 1, 1)),
    			})

    			self.instances.huePosition.Position = UDim2.new(0.5, -4, 0, math.clamp(200 - (h * 200), 0, 198))
    			self.instances.chromePosition.Position = UDim2.new(0, math.clamp((s * 200), 0, 196), 0, math.clamp(200 - (v * 200), 0, 196))

    			self.instances.alphaPosition.Position = UDim2.new(0, math.clamp(colorpicker.value.alpha * 224, 0, 222), 0.5, -4)
    		end

    		base:makeDraggable(self.instances.huePicker, self._trove, function(input)
    			local inline = self.instances.huePicker
    			local position = input.Position

    			local percent = 1 - math.clamp((position.Y - inline.AbsolutePosition.Y) / inline.AbsoluteSize.Y, 0, 1)

    			local h, s, v = colorpicker.value.rgb:ToHSV()
    			colorpicker:set({ rgb = Color3.fromHSV(percent, s, v), alpha = colorpicker.value.alpha })

    			self.instances.huePosition.Position = UDim2.new(0.5, -4, 0, math.clamp(200 - (percent * 200), 0, 198))
    		end)

    		base:makeDraggable(self.instances.chromePicker, self._trove, function(input)
    			local inline = self.instances.chromePicker
    			local position = input.Position

    			local percentX = math.clamp((position.X - inline.AbsolutePosition.X) / inline.AbsoluteSize.X, 0, 1)
    			local percentY = math.clamp((position.Y - inline.AbsolutePosition.Y) / inline.AbsoluteSize.Y, 0, 1)

    			local h, s, v = colorpicker.value.rgb:ToHSV()

    			colorpicker:set({ rgb = Color3.fromHSV(h, percentX, 1 - percentY), alpha = colorpicker.value.alpha })

    			self.instances.chromePosition.Position = UDim2.new(0, math.clamp((percentX * 200), 0, 196), 0, math.clamp(200 - ((1 - percentY) * 200), 0, 196))
    		end)

    		if colorpicker.hasAlpha then
    			base:makeDraggable(self.instances.alphaPicker, self._trove, function(input)
    				local inline = self.instances.alphaPicker
    				local position = input.Position

    				local percent = math.clamp((position.X - inline.AbsolutePosition.X) / inline.AbsoluteSize.X, 0, 1)

    				colorpicker:set({ rgb = colorpicker.value.rgb, alpha = percent })
    			end)
    		end

    		self.instances.container.Position = UDim2.new(0, colorpicker.instances.container.AbsolutePosition.X, 0, colorpicker.instances.container.AbsolutePosition.Y + 74)

    		self.instances.container.Parent = base.instances.gui
    		base.activeMenu = "color"
    	end

    	function UIColorpickerMenu.detach(self, base)
    		if not self.feature then
    			return
    		end

    		self.feature.open = false
    		self.feature = nil

    		base.activeMenu = "none"
    		self.instances.container.Parent = nil
    		self._trove:Clean()
    	end

    	function UIColorpickerMenu._makeInstances(self)
    		local container= Instance.new("Frame")
    		container.BackgroundColor3 = Color3.fromRGB(55, 175, 225)
    		container.BorderSizePixel = 1
    		container.BorderColor3 = Color3.fromRGB(0, 0, 0)
    		container.Size = UDim2.new(0, 246, 0, 236)
    		container.ZIndex = 2
    		self.instances.container = container

    		local background= Instance.new("Frame")
    		background.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    		background.BorderSizePixel = 0
    		background.Position = UDim2.new(0, 1, 0, 1)
    		background.Size = UDim2.new(1, -2, 1, -2)
    		background.ZIndex = 2
    		background.Parent = container

    		local title= Instance.new("TextLabel")
    		title.Font = Enum.Font.Arial
    		title.Position = UDim2.new(0, 4, 0, 4)
    		title.Size = UDim2.new(1, -8, 0, 11)
    		title.ZIndex = 2
    		title.BackgroundTransparency = 1
    		title.TextColor3 = Color3.fromRGB(255, 255, 255)
    		title.TextStrokeTransparency = 0
    		title.TextSize = 12
    		title.Text = "Colorpicker"
    		title.TextXAlignment = Enum.TextXAlignment.Left
    		title.Parent = background

    		local canvas= Instance.new("Frame")
    		canvas.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    		canvas.BorderColor3 = Color3.fromRGB(50, 50, 50)
    		canvas.Position = UDim2.new(0, 5, 0, 19)
    		canvas.Size = UDim2.new(1, -10, 1, -24)
    		canvas.ZIndex = 2
    		canvas.Parent = background

    		local inline= Instance.new("Frame")
    		inline.ZIndex = 2
    		inline.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    		inline.Position = UDim2.new(0, 1, 0, 1)
    		inline.Size = UDim2.new(1, -2, 1, -2)
    		inline.BorderSizePixel = 0
    		inline.Parent = canvas

    		local huePicker= Instance.new("TextButton")
    		huePicker.Text = ""
    		huePicker.AutoButtonColor = false
    		huePicker.BorderSizePixel = 0
    		huePicker.Position = UDim2.new(0, 208, 0, 4)
    		huePicker.Size = UDim2.new(0, 20, 0, 200)
    		huePicker.ZIndex = 2
    		huePicker.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    		huePicker.Parent = inline
    		self.instances.huePicker = huePicker

    		local hueGradient= Instance.new("UIGradient")
    		hueGradient.Rotation = 90
    		hueGradient.Color = ColorSequence.new({
    			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
    			ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 0, 255)),
    			ColorSequenceKeypoint.new(0.335, Color3.fromRGB(0, 0, 255)),
    			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
    			ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 255, 0)),
    			ColorSequenceKeypoint.new(0.84, Color3.fromRGB(255, 255, 0)),
    			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
    		})
    		hueGradient.Parent = huePicker

    		local huePosition= Instance.new("Frame")
    		huePosition.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    		huePosition.BorderColor3 = Color3.fromRGB(0, 0, 0)
    		huePosition.Position = UDim2.new(0.5, -4, 0, 0)
    		huePosition.Size = UDim2.new(0, 8, 0, 2)
    		huePosition.ZIndex = 2
    		huePosition.Parent = huePicker
    		self.instances.huePosition = huePosition

    		local chromePicker= Instance.new("TextButton")
    		chromePicker.Text = ""
    		chromePicker.AutoButtonColor = false
    		chromePicker.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    		chromePicker.BorderSizePixel = 0
    		chromePicker.Position = UDim2.new(0, 4, 0, 4)
    		chromePicker.Size = UDim2.new(0, 200, 0, 200)
    		chromePicker.ZIndex = 2
    		chromePicker.Parent = inline
    		self.instances.chromePicker = chromePicker

    		local saturation= Instance.new("Frame")
    		saturation.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    		saturation.BorderSizePixel = 0
    		saturation.Size = UDim2.new(1, 0, 1, 0)
    		saturation.ZIndex = 2
    		saturation.Parent = chromePicker

    		local saturationGradient= Instance.new("UIGradient")
    		saturationGradient.Color = ColorSequence.new({
    			ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
    			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
    		})
    		saturationGradient.Transparency = NumberSequence.new({
    			NumberSequenceKeypoint.new(0, 1),
    			NumberSequenceKeypoint.new(1, 0),
    		})
    		saturationGradient.Parent = saturation
    		self.instances.saturationGradient = saturationGradient

    		local brightness= Instance.new("Frame")
    		brightness.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    		brightness.BorderSizePixel = 0
    		brightness.Size = UDim2.new(1, 0, 1, 0)
    		brightness.ZIndex = 2
    		brightness.Parent = chromePicker

    		local brightnessGradient= Instance.new("UIGradient")
    		brightnessGradient.Color = ColorSequence.new(Color3.fromRGB(0, 0, 0))
    		brightnessGradient.Rotation = 90
    		brightnessGradient.Transparency = NumberSequence.new({
    			NumberSequenceKeypoint.new(0, 1),
    			NumberSequenceKeypoint.new(1, 0),
    		})
    		brightnessGradient.Parent = brightness

    		local chromePosition= Instance.new("Frame")
    		chromePosition.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    		chromePosition.BorderColor3 = Color3.fromRGB(0, 0, 0)
    		chromePosition.Position = UDim2.new(0, 0, 0, 0)
    		chromePosition.Size = UDim2.new(0, 4, 0, 4)
    		chromePosition.ZIndex = 2
    		chromePosition.Parent = chromePicker
    		self.instances.chromePosition = chromePosition

    		local alphaPicker= Instance.new("TextButton")
    		alphaPicker.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    		alphaPicker.BorderSizePixel = 0
    		alphaPicker.Position = UDim2.new(0, 4, 0, 208)
    		alphaPicker.Size = UDim2.new(0, 224, 0, 20)
    		alphaPicker.ZIndex = 2
    		alphaPicker.Text = ""
    		alphaPicker.AutoButtonColor = false
    		alphaPicker.Parent = inline
    		self.instances.alphaPicker = alphaPicker

    		local alphaGradient= Instance.new("UIGradient")
    		alphaGradient.Color = ColorSequence.new({
    			ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
    			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
    		})
    		alphaGradient.Parent = alphaPicker

    		local alphaPosition= Instance.new("Frame")
    		alphaPosition.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    		alphaPosition.BorderColor3 = Color3.fromRGB(0, 0, 0)
    		alphaPosition.Position = UDim2.new(0, 0, 0.5, -4)
    		alphaPosition.Size = UDim2.new(0, 2, 0, 8)
    		alphaPosition.ZIndex = 2
    		alphaPosition.Parent = alphaPicker
    		self.instances.alphaPosition = alphaPosition
    	end

    	function UIColorpickerMenu.into(self)
    self:_makeInstances()
    		return self
    	end

    	function UIColorpickerMenu.Destroy(self)

    	end
    end
    local UIDropdownMenu = {}
    UIDropdownMenu.__index = UIDropdownMenu
    do
    	function UIDropdownMenu.new(base)
    		local self = setmetatable({}, UIDropdownMenu)
    		self._trove = base._trove:Extend()

    		self.instances = {}
    		self.ref = base
    		self.options = {}

    		return UIDropdownMenu.into((self ) )
    	end

    	function UIDropdownMenu.resize(self)
    		assert(self.feature, "")
    		self.instances.container.Size = UDim2.new(1, 0, 0, math.min(6, #self.feature.options) * 17 + 1)
    	end

    	function UIDropdownMenu.add(self, option)
    assert(self.feature, "")
    		local trove = self._trove:Extend()

    		local outline= Instance.new("TextButton")
    		outline.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    		outline.BorderColor3 = Color3.fromRGB(50, 50, 50)
    		outline.BorderSizePixel = 1
    		outline.Size = UDim2.new(1, 0, 0, 16)
    		outline.AutoButtonColor = false
    		outline.Text = ""
    		outline.ZIndex = 2

    		local label= Instance.new("TextLabel")
    		label.Font = Enum.Font.Arial
    		label.TextSize = 12
    		label.TextStrokeTransparency = 0
    		label.Position = UDim2.new(0, 4, 0, 3)
    		label.Size = UDim2.new(1, -8, 0, 11)
    		label.Text = option
    		label.BackgroundTransparency = 1
    		label.TextXAlignment = Enum.TextXAlignment.Left
    		label.ZIndex = 2
    		label.Parent = outline

    		local value = self.feature.value
    		if typeof(value) == "table" and value[option] or option == value then
    			label.TextColor3 = Color3.fromRGB(55, 175, 225)
    		else
    			label.TextColor3 = Color3.fromRGB(255, 255, 255)
    		end

    		outline.Parent = self.instances.layout

    		trove:Connect(outline.InputBegan, function(input)
    			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
    				local value = self.feature.value

    				if typeof(value) == "table" then
    					value[option] = not value[option]

    					self.feature:set(value)
    				else
    					self.feature:set(option)
    				end
    			end
    		end)

    		self:resize()
    		trove:Add(outline)
    		return trove
    	end

    	function UIDropdownMenu.attach(self, dropdown, base)
    		if base.activeMenu ~= "none" then
    			self:detach(base )
    		end

    		self.feature = dropdown

    		for _, option in dropdown.options do
    			self.options[option] = self:add(option)
    		end

    		self._trove:Connect((dropdown.onOptionAdded ), function(option)
    			self.options[option] = self:add(option)
    		end)

    		self._trove:Connect((dropdown.onOptionRemoved ), function(option)
    			self._trove:Remove(self.options[option])
    			self.options[option] = nil

    			self:resize()
    		end)

    		self._trove:Connect((dropdown.changed ), function(value)
    			for _, outline in self.instances.layout:GetChildren() do
    				if outline:IsA("UIListLayout") then
    					continue
    				end

    				local label = outline:FindFirstChildOfClass("TextLabel")
    				assert(label, "internal error")

    				if typeof(value) == "table" and value[label.Text] or label.Text == value then
    					label.TextColor3 = Color3.fromRGB(55, 175, 225)
    				else
    					label.TextColor3 = Color3.fromRGB(255, 255, 255)
    				end
    			end
    		end)

    		self._trove:Connect(UserInputService.InputBegan, function(input)
    			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
    				local inputX, inputY = input.Position.X, input.Position.Y

    				local container = self.instances.container
    				local position, size = container.AbsolutePosition, container.AbsoluteSize

    				if inside(inputX, inputY, position.X, position.Y, size.X, size.Y) then
    					return
    				end

    				local outline = dropdown.instances.outline
    				local absPosition, absSize = outline.AbsolutePosition, outline.AbsoluteSize

    				if not inside(inputX, inputY, absPosition.X, absPosition.Y, absSize.X, absSize.Y) then
    					self:detach(base )

    					dropdown:setOpen(false, base)
    				end
    			end
    		end)

    		self:resize()

    		self.instances.container.Position = UDim2.new(0, dropdown.instances.outline.AbsolutePosition.X + 1, 0, dropdown.instances.outline.AbsolutePosition.Y + 80)
    		self.instances.container.Size = UDim2.new(0, dropdown.instances.outline.AbsoluteSize.X, 0, self.instances.container.Size.Y.Offset)
    		self.instances.container.Parent = base.instances.gui
    		base.activeMenu = "dropdown"
    	end

    	function UIDropdownMenu.detach(self, base)
    		assert(self.feature, "?")

    		self.feature:setOpen(false, base)
    		self.feature = nil

    		base.activeMenu = "none"
    		self.instances.container.Parent = nil
    		self._trove:Clean()
    		self.options = {}
    	end

    	function UIDropdownMenu._makeInstances(self)
    		local container= Instance.new("Frame")
    		container.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    		container.BorderSizePixel = 1
    		container.BorderColor3 = Color3.fromRGB(0, 0, 0)
    		container.Position = UDim2.new(0, 0, 1, 3)
    		container.Size = UDim2.new(1, 0, 0, 0)
    		container.ZIndex = 2
    		self.instances.container = container

    		local layout= Instance.new("ScrollingFrame")
    		layout.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    		layout.BorderSizePixel = 0
    		layout.Position = UDim2.new(0, 1, 0, 1)
    		layout.Size = UDim2.new(1, -2, 1, -2)
    		layout.AutomaticCanvasSize = Enum.AutomaticSize.Y
    		layout.CanvasSize = UDim2.new(0, 0, 0, 0)
    		layout.ScrollBarImageColor3 = Color3.fromRGB(55, 175, 225)
    		layout.ScrollingDirection = Enum.ScrollingDirection.Y
    		layout.ScrollBarThickness = 4
    		layout.TopImage = "rbxasset://textures/AvatarEditorImages/LightPixel.png"
    		layout.MidImage = "rbxasset://textures/AvatarEditorImages/LightPixel.png"
    		layout.BottomImage = "rbxasset://textures/AvatarEditorImages/LightPixel.png"
    		layout.ZIndex = 2
    		layout.Parent = container
    		self.instances.layout = layout

    		local listLayout= Instance.new("UIListLayout")
    		listLayout.Padding = UDim.new(0, 1)
    		listLayout.Parent = layout
    	end

    	function UIDropdownMenu.into(self)
    self:_makeInstances()
    		return self
    	end

    	function UIDropdownMenu.Destroy(self)

    	end
    end

    local UIIconList = {}
    UIIconList.__index = UIIconList; do
    	function UIIconList.new(parent)
            assert(parent, "TabList.new(parent) : _ -> expected UIExtendable, got nil")

    		local self = setmetatable({}, UIIconList)
    		self._trove = parent._trove:Extend()
    		self.instances = {}
    		self.children = {}
    		self.parent = parent

    		return UIIconList.into((self ) )
    	end

    	function UIIconList.newIcon(self, image)
    		assert(image, "UIIconList.newIcon(_, image) : _ -> expected string got nil")
    		assert(typeof(image) == "string", "UIIconList.newIcon(_, image) : _ -> expected string, got " .. typeof(image))

    		local tab= UIExtendable.new()
    		tab._trove = self._trove:Extend()

    		local tab= tab
            tab.setVisible = UIIconList.setVisible
    		tab.parent = self
    		table.insert(self.children, tab)

    		self:_makeIconInstances(tab)
    		tab.instances.image.Image = image

    		if #self.children == 1 then
    			tab:setVisible(true)
    		end

    		self._trove:Connect(tab.instances.button.InputBegan, function(input)
    			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
    				tab:setVisible(true)
    			end
    		end)

    		self:_resize()

    		return tab
    	end

    	function UIIconList.setVisible(self, state)
    		return UIIconList.setIconVisible(self , state)
    	end

    	function UIIconList.setIconVisible(self, state)
    		assert(typeof(state) == "boolean", "UIIconList.setVisible(_, state: boolean) -> expected boolean, got " .. typeof(state))
    		assert(state, "UIIconList.setVisible(_, state: boolean) -> unused variable")

    		if self.visible == state then
    			return
    		end

    		self.visible = state

    		assert(self.parent, "UIIconList.setIconVisible(_, _) -> internal failure")

    		for _, tab in (self.parent.children )do
    			local instances = tab.instances
    			instances.image.ImageColor3 = Color3.fromRGB(150, 150, 150)
    			instances.canvas.Visible = false

    			tab.visible = false
    		end

    		local instances = self.instances
    		instances.image.ImageColor3 = Color3.fromRGB(255, 255, 255)
    		instances.canvas.Visible = true
    	end

    	function UIIconList._makeIconInstances(self, tab)
    		local button= Instance.new("TextButton")
    		button.Size = UDim2.new(0, 0, 1, 0)
    		button.BackgroundTransparency = 1
    		button.Text = ""
    		tab.instances.button = button

    		local image= Instance.new("ImageLabel")
    		image.Position = UDim2.new(0.5, 0, 0.5, 0)
    		image.AnchorPoint = Vector2.new(0.5, 0.5)
    		image.Size = UDim2.new(0, 48, 1, 0)
    		image.BackgroundTransparency = 1
    		image.ImageColor3 = Color3.fromRGB(150, 150, 150)
    		image.Parent = button
    		tab.instances.image = image

    		local canvas= Instance.new("Frame")
    		canvas.Size = UDim2.new(1, 0, 1, 0)
    		canvas.BackgroundTransparency = 1
    		canvas.Visible = false
    		canvas.Parent = self.instances.canvas
    		tab.instances.canvas = canvas
    		tab.instances.container = canvas

    		button.Parent = self.instances.layout
    	end

    	function UIIconList._makeInstances(self)
    		local container= Instance.new("Frame")
    		container.BorderColor3 = Color3.fromRGB(0, 0, 0)
    		container.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    		container.Size = UDim2.new(1, -10, 0, 50)
    		container.Position = UDim2.new(0, 5, 0, 5)

    		local layout= Instance.new("Frame")
    		layout.BorderSizePixel = 0
    		layout.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    		layout.Size = UDim2.new(1, -2, 1, -2)
    		layout.Position = UDim2.new(0, 1, 0, 1)
    		layout.Parent = container
    		self.instances.layout = layout

    		local listLayout= Instance.new("UIListLayout")
    		listLayout.FillDirection = Enum.FillDirection.Horizontal
    		listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    		listLayout.Parent = layout

    		local canvas= Instance.new("Frame")
    		canvas.BackgroundTransparency = 1
    		canvas.Position = UDim2.new(0, 0, 0, 55)
    		canvas.Size = UDim2.new(1, 0, 1, -55)
    		self.instances.canvas = canvas

    		container.Parent = self.parent.instances.canvas
    		canvas.Parent = self.parent.instances.canvas
    	end

    	function UIIconList._resize(self)
    		local layout= self.instances.layout
    		local cnt= #self.children

    		local totalSize= layout.AbsoluteSize.X
    		local size= totalSize / cnt

    		for _, tab in self.children do
    			tab.instances.button.Size = UDim2.new(0, size, 1, 0)
    		end

    		local last= self.children[#self.children]
    		local button= last.instances.button

    		local curr= button.AbsolutePosition.X + button.AbsoluteSize.X
    		local expected= layout.AbsolutePosition.X + layout.AbsoluteSize.X
    		local diff= expected - curr

    		if diff ~= 0 then
    			button.Size += UDim2.new(0, diff, 0, 0)
    		end
    	end

    	function UIIconList.into(self)
    self:_makeInstances()
    		return self
    	end
    end

    local UITabList = {}
    UITabList.__index = UITabList do
    	function UITabList.new(parent)
            assert(parent, "TabList.new(parent) : _ -> expected UIExtendable, got nil")

    		local self = setmetatable({}, UITabList)
    		self._trove = parent._trove:Extend()
    		self.instances = {}
    		self.children = {}
    		self.parent = parent

    		return UITabList.into((self ) )
    	end

    	function UITabList.newTab(self, label)
            assert(label, "TabList.newTab(_, label) : _ -> expected string got nil")
    		assert(typeof(label) == "string", "TabList.newTab(_, label) : _ -> expected string, got " .. typeof(label))

    		local tab= UIExtendable.new()
    		tab._trove = self._trove:Extend()

    		local tab= tab
    tab.setVisible = UITabList.setVisible
    		tab.parent = self
    		table.insert(self.children, tab)

    		self:_makeTabInstances(tab)
    		tab.instances.button.Text = label

    		if #self.children == 1 then
    			tab:setVisible(true)
    		end

    		self._trove:Connect(tab.instances.button.InputBegan, function(input)
    			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
    				tab:setVisible(true)
    			end
    		end)

    		self:_resize()

    		return tab
    	end

    	function UIExtendable.newTabList(self)
    assert(self.sectionHolder == nil, "UIExtendable.newIconList(_) : _ -> expected sections to be nil")
    		assert(self.child == nil, "UIExtendable.newTabList(_) : _ -> expected child to be nil")

    		local tabList= UITabList.new(self)
    		self.child = tabList

    		return tabList
    	end

    	function UIExtendable.newIconList(self)
    assert(self.sectionHolder == nil, "UIExtendable.newIconList(_) : _ -> expected sections to be nil")
    		assert(self.child == nil, "UIExtendable.newIconList(_) : _ -> expected child to be nil")

    		local iconList= UIIconList.new(self)
    		self.child = iconList

    		return iconList
    	end

    	function UITabList.setVisible(self, state)
    		return UITabList.setTabVisible(self , state)
    	end

    	function UITabList.setTabVisible(self, state)
    		assert(typeof(state) == "boolean", "UIExtendable.setVisible(_, state: boolean) -> expected boolean, got " .. typeof(state))
    		assert(state, "UIExtendable.setVisible(_, state: boolean) -> unused variable")

    		if self.visible == state then
    			return
    		end

    		self.visible = state

    		assert(self.parent, "UITabList.setTabVisible(_, _) -> internal failure")

    		for _, tab in (self.parent.children )do
    			local instances = tab.instances
    			instances.inline.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    			instances.cover.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    			instances.cover.Size = UDim2.new(1, 0, 0, 1)
    			instances.canvas.Visible = false

    			tab.visible = false
    		end

    		local instances = self.instances
    		instances.inline.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    		instances.cover.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    		instances.cover.Size = UDim2.new(1, 0, 0, 2)
    		instances.canvas.Visible = true
    	end

    	function UITabList._makeTabInstances(self, tab)
    		local outline= Instance.new("Frame")
    		outline.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    		outline.BorderSizePixel = 0
    		outline.Size = UDim2.new(0, 0, 1, 0)
    		tab.instances.outline = outline

    		local inline= Instance.new("Frame")
    		inline.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    		inline.BorderColor3 = Color3.fromRGB(50, 50, 50)
    		inline.Position = UDim2.new(0, 2, 0, 2)
    		inline.Size = UDim2.new(1, -4, 1, -3)
    		inline.Parent = outline
    		tab.instances.inline = inline

    		local cover= Instance.new("Frame")
    		cover.BorderSizePixel = 0
    		cover.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    		cover.Position = UDim2.new(0, 0, 1, 0)
    		cover.Size = UDim2.new(1, 0, 0, 1)
    		cover.Parent = inline
    		tab.instances.cover = cover

    		local button= Instance.new("TextButton")
    		button.BackgroundTransparency = 1
    		button.Font = Enum.Font.Arial
    		button.TextSize = 12
    		button.TextColor3 = Color3.fromRGB(255, 255, 255)
    		button.Size = UDim2.new(1, 0, 1, 0)
    		button.TextStrokeTransparency = 0
    		button.Parent = inline
    		tab.instances.button = button

    		local canvas= Instance.new("Frame")
    		canvas.Size = UDim2.new(1, 0, 1, 0)
    		canvas.BackgroundTransparency = 1
    		canvas.Visible = false
    		canvas.Parent = self.instances.canvas
    		tab.instances.canvas = canvas
    		tab.instances.container = canvas

    		outline.Parent = self.instances.layout
    	end

    	function UITabList._resize(self)
    		local layout= self.instances.layout
    		local cnt= #self.children

    		local totalSize= layout.AbsoluteSize.X - (cnt - 1) * 4
    		local size= totalSize / cnt

    		for _, tab in self.children do
    			tab.instances.outline.Size = UDim2.new(0, size, 1, 0)
    		end

    		local last= self.children[#self.children]
    		local outline= last.instances.outline

    		local curr= outline.AbsolutePosition.X + outline.AbsoluteSize.X
    		local expected= layout.AbsolutePosition.X + layout.AbsoluteSize.X
    		local diff= expected - curr

    		if diff ~= 0 then
    			outline.Size += UDim2.new(0, diff, 0, 0)
    		end
    	end

    	function UITabList._makeInstances(self)
    		local container= Instance.new("Frame")
    		container.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    		container.BorderColor3 = Color3.fromRGB(0, 0, 0)
    		container.BorderSizePixel = 1
    		container.Position = UDim2.new(0, 5, 0, 26)
    		container.Size = UDim2.new(1, -10, 1, -31)
    		self.instances.container = container

    		local canvas= Instance.new("Frame")
    		canvas.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    		canvas.BorderSizePixel = 0
    		canvas.Position = UDim2.new(0, 1, 0, 1)
    		canvas.Size = UDim2.new(1, -2, 1, -2)
    		canvas.Parent = container
    		self.instances.canvas = canvas

    		local layout= Instance.new("Frame")
    		layout.BackgroundTransparency = 1
    		layout.Position = UDim2.new(0, -1, 0, -21)
    		layout.Size = UDim2.new(1, 2, 0, 21)
    		layout.Parent = container
    		self.instances.layout = layout

    		local listLayout= Instance.new("UIListLayout")
    		listLayout.Padding = UDim.new(0, 4)
    		listLayout.FillDirection = Enum.FillDirection.Horizontal
    		listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    		listLayout.Parent = layout

    		container.Parent = self.parent.instances.canvas
    	end

    	function UITabList.into(self)
    self:_makeInstances()
    		self.parent.child = self
    		return self
    	end
    end

    UIBase = {}
    UIBase.__index = UIBase do
    	function UIBase.new()
            local self = setmetatable({}, UIBase)
    		self._trove = Trove.new()

    		self.refs = {}
    		self.instances = {}
    		self.features = {}

    		self.visible = true
    		self.dragging = false
    		self.keybind = Enum.KeyCode.RightShift

    		self.activeMenu = "none"

    		self.visibilityChanged = self._trove:Add(Signal.new())

    		return UIBase.into((self ) )
    	end

    	function UIBase.setLabel(self, label)
            assert(label, "UIBase.setLabel(_, label) : _ -> expected string, got nil")
    		assert(typeof(label) == "string", "UIBase.setLabel(_, label) : _ -> expected string, got " .. typeof(label))

    		self.instances.label.Text = label
    		return self
    	end

    	function UIBase.setKeybind(self, keybind)
            assert(keybind, "UIBase.setKeybind(_, keybind) : _ -> expected Enum.KeyCode, got nil")
    		assert(typeof(keybind) == "EnumItem", "UIBase.setKeybind(_, keybind) : _ -> expected Enum.KeyCode, got " .. typeof(keybind))

    		self.keybind = keybind
    		return self
    	end

    	function UIBase.setVisible(self, state)
    		assert(typeof(state) == "boolean", "UIBase.setVisible(_, state: boolean) -> expected boolean, got " .. typeof(state))

    		if self.visible == state then
    			return
    		end

    		self.visible = state
    		self.instances.container.Visible = self.visible

    		self.visibilityChanged:Fire(self.visible)
    	end

    	function UIBase.makeDraggable(self, guiObject, trove, callback)
    		local dragInput
            local dragging= false

    		local onMouseMove = function(input)
    			if dragging and input == dragInput then
    				callback(input)
    			end
    		end

    		local connection = self._trove:Connect(UserInputService.InputChanged, onMouseMove)

    		trove:Connect((self.visibilityChanged ), function(state)
    			if not state then
    				dragging = false
    				trove:Remove(connection)
    				return
    			end

    			connection = trove:Connect(UserInputService.InputChanged, onMouseMove)
    		end)

    		trove:Connect(guiObject.InputBegan, function(input)
    			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
    				dragging = true
    				dragInput = input

    				onMouseMove(input)

    				local onChanged
    				onChanged = self._trove:Connect(input.Changed, function()
    					if input.UserInputState == Enum.UserInputState.End then
    						dragging = false
    						trove:Remove(onChanged)
    						dragInput = nil
    					end
    				end)
    			end
    		end)

    		trove:Connect(guiObject.InputChanged, function(input)
    			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
    				dragInput = input
    			end
    		end)
    	end

    	function UIBase._makeInstances(self)
    		local screenGui= Instance.new("ScreenGui")
    		screenGui.ResetOnSpawn = false
    		screenGui.IgnoreGuiInset = true
    		screenGui.ScreenInsets = Enum.ScreenInsets.None
    		screenGui.DisplayOrder = 100
    		self.instances.gui = screenGui

    		local container= Instance.new("Frame")
    		container.BackgroundColor3 = Color3.fromRGB(55, 175, 225)
    		container.BorderSizePixel = 1
    		container.BorderColor3 = Color3.fromRGB(0, 0, 0)
    		container.AnchorPoint = Vector2.new(0, 0)
    		container.Position = UDim2.new(0.5, -500 / 2, 0.5, -330 / 2)
    		container.Size = UDim2.new(0, 500, 0, 330)
    		container.Parent = screenGui
    		self.instances.container = container

    		local background= Instance.new("Frame")
    		background.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    		background.Position = UDim2.new(0, 1, 0, 1)
    		background.Size = UDim2.new(1, -2, 1, -2)
    		background.BorderSizePixel = 0
    		background.Parent = container

    		local outer= Instance.new("Frame")
    		outer.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    		outer.Position = UDim2.new(0, 5 , 0, 19)
    		outer.Size = UDim2.new(1, -10, 1, -24)
    		outer.BorderColor3 = Color3.fromRGB(50, 50, 50)
    		outer.Parent = background

    		local canvas= Instance.new("Frame")
    		canvas.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    		canvas.Position = UDim2.new(0, 1, 0, 1)
    		canvas.Size = UDim2.new(1, -2, 1, -2)
    		canvas.BorderSizePixel = 0
    		canvas.Parent = outer
    		self.instances.canvas = canvas

    		local title= Instance.new("TextLabel")
    		title.Size = UDim2.new(1, -8, 0, 11)
    		title.Position = UDim2.new(0, 4, 0, 4)
    		title.Font = Enum.Font.Arial
    		title.TextSize = 12
    		title.TextStrokeTransparency = 0
    		title.BackgroundTransparency = 1
    		title.TextXAlignment = Enum.TextXAlignment.Left
    		title.TextColor3 = Color3.fromRGB(255, 255, 255)
    		title.Parent = background
    		self.instances.label = title

    		local drag= Instance.new("TextButton")
    		drag.BackgroundTransparency = 1
    		drag.Text = ""
    		drag.Size = UDim2.new(1, 0, 0, 20)
    		drag.Modal = true
    		drag.Parent = container
    		self.instances.drag = drag

    		local resize= Instance.new("TextButton")
    		resize.BackgroundTransparency = 1
    		resize.Text = ""
    		resize.Position = UDim2.new(1, 0, 1, 0)
    		resize.AnchorPoint = Vector2.new(1, 1)
    		resize.Size = UDim2.new(0, 13, 0, 13)
    		resize.Parent = container
    		self.instances.resize = resize

    		local open= Instance.new("TextButton")
    		open.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    		open.AutoButtonColor = false
    		open.Position = UDim2.new(0.5, 0, 0, 0)
    		open.Size = UDim2.new(0, 50, 0, 50)
    		open.Font = Enum.Font.Arimo
    		open.TextSize = 12
    		open.TextColor3 = Color3.fromRGB(255, 255, 255)
    		open.Text = "Open"
    		open.BackgroundTransparency = 0.5
    		open.AnchorPoint = Vector2.new(0.5, 0)
    		open.Parent = screenGui
    		self.instances.open = open

    		local uiCorner = Instance.new("UICorner")
    		uiCorner.CornerRadius = UDim.new(0, 5)
    		uiCorner.Parent = open
    	end

    	function UIBase.into(self)
    self:_makeInstances()

    		local dragInput= nil
    		local dragStart= Vector3.zero
    		local guiStart= UDim2.new()

    		self._trove:Connect(self.instances.drag.InputBegan, function(input)
    			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
    				self.dragging = true

    				dragStart = input.Position
    				guiStart = self.instances.container.Position
    				dragInput = input

    				local onChanged
    				onChanged = self._trove:Connect(input.Changed, function()
    					if input.UserInputState == Enum.UserInputState.End then
    						self.dragging = false
    						self._trove:Remove(onChanged)
    						dragInput = nil
    					end
    				end)
    			end
    		end)

    		self._trove:Connect(UserInputService.InputChanged, function(input)
            if self.dragging and input == dragInput then
                local delta = input.Position - dragStart
                local container = self.instances.container
                local screenSize = self.instances.gui.AbsoluteSize
                local containerSize = container.AbsoluteSize

                local newX = guiStart.X.Offset + delta.X
                local newY = guiStart.Y.Offset + delta.Y

                local maxX = math.max(0, screenSize.X - containerSize.X)
                local maxY = math.max(0, screenSize.Y - containerSize.Y)

                container.Position = UDim2.new(
                    guiStart.X.Scale,
                    math.clamp(newX, -screenSize.X * guiStart.X.Scale, maxX),
                    guiStart.Y.Scale,
                    math.clamp(newY, -screenSize.Y * guiStart.Y.Scale, maxY)
                )
            end
        end)

        self._trove:Connect(self.instances.drag.InputChanged, function(input)
    			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
    				dragInput = input
    			end
    		end)

    		self._trove:Add(self.instances.gui)

    		local resizeInput= nil
    		local resizeStart= Vector3.zero

    		self._trove:Connect(self.instances.resize.InputBegan, function(input)
    			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
    				self.resizing = true

    				dragStart = input.Position
    				guiStart = self.instances.container.Position
    				resizeInput = input

    				local onChanged
    				onChanged = self._trove:Connect(input.Changed, function()
    					if input.UserInputState == Enum.UserInputState.End then
    						self.resizing = false
    						self._trove:Remove(onChanged)
    						resizeInput = nil
    					end
    				end)
    			end
    		end)

    		self._trove:Connect(UserInputService.InputChanged, function(input)
    			if self.resizing and input == resizeInput then
    				local uiPosition = self.instances.container.AbsolutePosition
    				local mousePosition= Vector2.new(input.Position.X, input.Position.Y)
    				local delta= mousePosition - uiPosition


    				local newSize = UDim2.new(0, math.max(500, delta.X), 0, math.max(330, delta.Y))
    				self.instances.container.Size = newSize

    				local function recursiveResize(parent)


    local child = ((parent.child ))

    if child then
    						if child._resize then
    							child:_resize()
    						end

    						if child.children then
    							for _, tab in child.children do
    								if tab.child then
    									recursiveResize((tab ) )
    								end
    							end
    						else

    							local sections = ((child ) ).sections

    							local left = sections.left[#sections.left]

    							if left then

    							end
    						end
    					end
    				end

    				recursiveResize(self)
    			end
    		end)

    		self._trove:Connect(self.instances.resize.InputChanged, function(input)
    			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
    				resizeInput = input
    			end
    		end)

    		self.menus = {
    			dropdown = UIDropdownMenu.new(self),
    			colorpicker = UIColorpickerMenu.new(self),
    		}

    self._trove:Add(self.menus.dropdown)
    		self._trove:Add(self.menus.colorpicker)

    		self._trove:Connect(self.instances.open.InputBegan, function(input)
    			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
    				self:setVisible(not self.visible)
    			end
    		end)

    		return self
    	end

    	function UIBase.newTabList(self)
    assert(self.child == nil, "UIBase.newTabList(_) : _ -> expected child to be nil")

    		local tabList= UITabList.new(self)
    		self.child = tabList

    		return tabList
    	end

    	function UIBase.newIconList(self)
    assert(self.child == nil, "UIBase.newIconList(_) : _ -> expected child to be nil")

    		local iconList= UIIconList.new(self)
    		self.child = iconList

    		return iconList
    	end

    	function UIBase.encodeJSON(self)
    local config = {}

    		for flag, feature in self.features do
    			if typeof(feature.value) == "table" then
    				local clone = table.clone(feature.value)

    				for k, v in clone do
    					if typeof(v) == "Color3" then
    						clone[k] = { v.R, v.G, v.B }
    					elseif typeof(v) == "EnumItem" then
    						local key = clone.key
    						clone[k] = {
    							"Enum",
    							key ~= "None" and tostring(key.EnumType) or "Unknown",
    							key ~= "None" and key.Name or "None",
    						}
    					end
    				end

    				config[flag] = clone
    			else
    				config[flag] = feature.value
    			end
    		end

    		return HttpService:JSONEncode(config)
    	end

    	function UIBase.decodeJSON(self, json)
            local jsonDecoded = HttpService:JSONDecode(json)

            local status, err = pcall(function()
                for flag, value in next, jsonDecoded do
    				pcall(function()
    					if type(value) == "table" then
    						if value.rgb and value.alpha then
    							self.features[flag]:set({ rgb = Color3.new(value.rgb[1], value.rgb[2], value.rgb[3]), alpha = value.alpha })
    						elseif value.key and value.mode then
    							self.features[flag]:set({ key = Enum[value.key[2]][value.key[3]], mode = value.mode })
    						else
    							self.features[flag]:set(value)
    						end
    					else
    						self.features[flag]:set(value)
    					end
    				end)
                end
            end)

            return status, err
        end

    	function UIBase.Finish(self)
    		if setidentity then
    			setidentity(8)
    		end
    		self.instances.gui.Parent = CoreGui
    	end

    	function UIBase.Destroy(self)
    		self._trove:Clean()
    	end
    end

    local UIColorpicker = {}
    UIColorpicker.__index = UIColorpicker do
    	function UIColorpicker.new(parent, flag, base, hasAlpha)
    assert(base.features[flag] == nil, string.format("UIBase.features[\"%s\"] already exists.", flag))

    		local self = setmetatable({}, UIColorpicker)
    		self._trove = parent._trove:Extend()

    		self.instances = {}
    		self.changed = self._trove:Add(Signal.new())
    		self.value = { rgb = Color3.new(), alpha = 0 }
    		self.hasAlpha = hasAlpha

    		return UIColorpicker.into((self ) , parent, base, flag)
    	end

    	function UIColorpicker.set(self, value)
    if self.value.rgb == value.rgb and self.value.alpha == value.alpha then
    			return self
    		end

    		local color = value.rgb
    		local top = Color3.fromRGB(math.min(255, color.R * 255 + 20), math.min(255, color.G * 255 + 20), math.min(255, color.B * 255 + 20))
    		local bottom = Color3.fromRGB(math.max(0, color.R * 255 - 20), math.max(0, color.G * 255 - 20), math.max(0, color.B * 255 - 20))

    		self.instances.gradient.Color = ColorSequence.new(top, bottom)

    		self.value = value
    		self.changed:Fire(self.value)

    		return self
    	end

    	function UIColorpicker._makeInstances(self, parent)
    		local container= Instance.new("Frame")
    		container.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    		container.BorderSizePixel = 1
    		container.BorderColor3 = Color3.fromRGB(0, 0, 0)
    		container.Size = UDim2.new(0, 40, 1, 0)
    		self.instances.container = container

    		local inline= Instance.new("Frame")
    		inline.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    		inline.Position = UDim2.new(0, 1, 0, 1)
    		inline.Size = UDim2.new(1, -2, 1, -2)
    		inline.BorderSizePixel = 0
    		inline.Parent = container

    		local button= Instance.new("TextButton")
    		button.Size = UDim2.new(1, 0, 1, 0)
    		button.AutoButtonColor = false
    		button.BorderSizePixel = 0
    		button.TextStrokeTransparency = 0
    		button.Text = ""
    		button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    		button.BackgroundTransparency = 0
    		button.Parent = inline

    		local gradient= Instance.new("UIGradient")
    		gradient.Rotation = 90
    		gradient.Parent = button
    		self.instances.gradient = gradient

    		container.Parent = parent.instances.layout
    		self.instances.button = button
    	end

    	function UIColorpicker.into(self, parent, base, flag)
    self:_makeInstances(parent)
    		self:set({ rgb = Color3.fromRGB(255, 255, 225), alpha = 0 })

    		self._trove:Connect(self.instances.button.InputBegan, function(input)
    			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
    				if base.activeMenu == "dropdown" and insideFrame(input.Position, base.menus.dropdown.instances.container) then
    					return
    				end

    				if base.activeMenu == "color" and insideFrame(input.Position, base.menus.colorpicker.instances.container) then
    					return
    				end

    				self.open = not self.open

    				if self.open then
    					base.menus.colorpicker:attach(self, base )
    				else
    					base.menus.colorpicker:detach(base )
    				end
    			end
    		end)

    		base.features[flag] = self
    		return self
    	end
    end





    local UIKeybind = {}
    UIKeybind.__index = UIKeybind
    do
    	function UIKeybind.new(parent, flag, modes, base)
    		assert(base.features[flag] == nil, string.format("UIBase.features[\"%s\"] already exists.", flag))

    		local self = setmetatable({}, UIKeybind)
    		self._trove = parent._trove:Extend()

    		self.instances = {}
    		self.changed = self._trove:Add(Signal.new())
    		self.value = {}

    		self.binding = false
    		self.active = false
    		self.activeChanged = self._trove:Add(Signal.new())

    		self.modes = modes

    		return UIKeybind.into((self ) , parent, base, flag)
    	end

    	function UIKeybind.set(self, value)
    if self.value.key == value.key and self.value.mode == value.mode and not self.binding then
    			return self
    		end

    		if value.key == Enum.UserInputType.MouseMovement then
    			return self
    		end

    		self.instances.button.Text = string.format("%s: %s", value.mode, value.key and value.key.Name or "None")

    		self.value = value
    		self.changed:Fire(self.value)
    		return self
    	end

    	function UIKeybind._setActive(self, state)
    		if self.active == state then
    			return
    		end

    		self.active = state
    		self.activeChanged:Fire(self.active)
    	end

    	function UIKeybind.isInputKey(self, input)
    local key = self.value.key

    		if not key then
    			return false
    		end

    		if key.EnumType == Enum.KeyCode and input.KeyCode ~= key then
    			return false
    		end

    		if key.EnumType == Enum.UserInputType and input.UserInputType ~= key then
    			return false
    		end

    		return true
    	end

    	function UIKeybind._makeInstances(self, parent)
    		local container= Instance.new("Frame")
    		container.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    		container.BorderSizePixel = 1
    		container.BorderColor3 = Color3.fromRGB(0, 0, 0)
    		container.Size = UDim2.new(0, 0, 1, 0)
    		self.instances.container = container

    		local inline= Instance.new("Frame")
    		inline.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    		inline.Position = UDim2.new(0, 1, 0, 1)
    		inline.Size = UDim2.new(1, -2, 1, -2)
    		inline.BorderSizePixel = 0
    		inline.Parent = container

    		local button= Instance.new("TextButton")
    		button.Size = UDim2.new(1, 0, 1, 0)
    		button.TextColor3 = Color3.fromRGB(255, 255, 255)
    		button.TextStrokeTransparency = 0
    		button.TextXAlignment = Enum.TextXAlignment.Center
    		button.Font = Enum.Font.Arial
    		button.TextSize = 12
    		button.BackgroundTransparency = 1
    		button.Parent = inline

    		container.Parent = parent.instances.layout
    		self.instances.button = button
    	end

    	function UIKeybind.into(self, parent, base, flag)
    self:_makeInstances(parent)

    		self._trove:Connect(self.instances.button:GetPropertyChangedSignal("TextBounds"), function()
    			self.instances.container.Size = UDim2.new(0, self.instances.button.TextBounds.X + 8, 1, 0)
    		end)

    		self._trove:Connect((self.changed ), function(state)
    			self:_setActive(state.mode == "Always")
    		end)

    		self:set({ key = nil, mode = (self.modes[1] )})

    		local disable_keybind = false

    		self._trove:Connect(UserInputService.InputBegan, function(input)
    			if not self:isInputKey(input) then
    				return
    			end

    			if disable_keybind then
    				disable_keybind = false
    				return
    			end

    			local mode = self.value.mode

    			if mode == "Toggle" or mode == "Tap" then
    				self:_setActive(not self.active)
    			elseif mode == "Hold" or mode == "Release" then
    				self:_setActive(mode == "Hold")
    			end
    		end)

    		self._trove:Connect(UserInputService.InputEnded, function(input)
    			if not self:isInputKey(input) then
    				return
    			end

    			local mode = self.value.mode

    			if mode == "Hold" or mode == "Release" then
    				self:_setActive(mode == "Release")
    			end
    		end)

    		local inputBegan, inputEnded

    		self._trove:Connect(self.instances.button.InputBegan, function(input)
    			if base.activeMenu == "dropdown" and insideFrame(input.Position, base.menus.dropdown.instances.container) then
    				return
    			end

    			if base.activeMenu == "color" and insideFrame(input.Position, base.menus.colorpicker.instances.container) then
    				return
    			end

    			if base.binding then
    				return
    			end


    			if input.UserInputType == Enum.UserInputType.MouseButton1 then
    				base.binding = self
    				self.binding = true
    				self.instances.button.Text = "..."


    				local debounce = true

    				local connection
    				connection = self._trove:Connect(UserInputService.InputBegan, function(input)
    					if debounce then
    						debounce = false
    						return
    					end

    					if input.UserInputType == Enum.UserInputType.MouseMovement then
    						return
    					end

    					local key

    if input.KeyCode ~= Enum.KeyCode.Backspace then
    						if input.KeyCode ~= Enum.KeyCode.Unknown then
    							key = input.KeyCode
    						else
    							key = input.UserInputType
    						end
    					end

    					disable_keybind = true

    					self:set({ key = key, mode = self.value.mode })
    					self.binding = false
    					base.binding = nil

    					self._trove:Remove(connection)
    				end)
    			elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
    				local index = (table.find(self.modes, self.value.mode) )
    self:set({ key = self.value.key, mode = (self.modes[(index % #self.modes) + 1] )})
    			end
    		end)

    		base.features[flag] = self
    		return self
    	end
    end

    local UIToggle = {}
    UIToggle.__index = UIToggle
    do
    	function UIToggle.new(parent, flag)
    		assert(flag, "UIToggle.new(_, flag) : _ -> expected string, got nil")
    		assert(typeof(flag) == "string", "UIToggle.new(_, flag) : _ -> expected string, got " .. typeof(flag))

    		local base= parent

    		while base.parent do
    			base = base.parent
    		end

    		local base = base
    assert(base.features[flag] == nil, string.format("UIBase.features[\"%s\"] already exists.", flag))

    		local self = setmetatable({}, UIToggle)
    		self._trove = parent._trove:Extend()

    		self.instances = {}
    		self.changed = self._trove:Add(Signal.new())
    		self.value = false

    		self.base = base

    		parent.instances.container.Size += UDim2.new(0 , 0, 0, 19)
    		return UIToggle.into((self ) , parent, base, flag)
    	end

    	function UISection.newToggle(self, flag)
    return UIToggle.new(self, flag)
    	end

    	function UIToggle.set(self, state)
    if typeof(state) ~= "boolean" then
    			warn("UIToggle.set(_, state) : _ -> expected boolean, got " .. typeof(state))
    			return self
    		end

    		local self = self

    if self.value == state then
    			return self
    		end

    		self.value = state

    		local gradient= self.instances.gradient

    		if self.value then
    			gradient.Color = ColorSequence.new(Color3.fromRGB(60, 180, 230), Color3.fromRGB(10, 130, 180))
    		else
    			gradient.Color = ColorSequence.new(Color3.fromRGB(30, 30, 30), Color3.fromRGB(25, 25, 25))
    		end

    		self.changed:Fire(self.value)
    		return self
    	end

    	function UIToggle.setLabel(self, label)
    assert(label, "UIToggle.setLabel(_, label) : _ -> expected string, got nil")
    		assert(typeof(label) == "string", "UIToggle.setLabel(_, label) : _ -> expected string, got " .. typeof(label))

    		self.instances.label.Text = label
    		return self
    	end

    	function UIToggle.newKeybind(self, flag, modes)
    return ((UIKeybind.new(self, flag, modes or { "Always", "Toggle", "Hold", "Release" }, self.base) ))
    end

    	function UIToggle.newColorpicker(self, flag, hasAlpha)
    return ((UIColorpicker.new(self, flag, self.base, hasAlpha or false) ))
    end

    	function UIToggle._makeInstances(self, parent)
    		local button = Instance.new("TextButton")
    		button.BackgroundTransparency = 1
    		button.Size = UDim2.new(1, 0, 0, 15)
    		button.Text = ""

    		local outline= Instance.new("Frame")
    		outline.BorderColor3 = Color3.fromRGB(0, 0, 0)
    		outline.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    		outline.Size = UDim2.new(0, 13, 0, 13)
    		outline.Position = UDim2.new(0, 5, 0.5, 0)
    		outline.AnchorPoint = Vector2.new(0, 0.5)
    		outline.Parent = button

    		local inline= Instance.new("Frame")
    		inline.BorderSizePixel = 0
    		inline.Size = UDim2.new(1, -2, 1, -2)
    		inline.Position = UDim2.new(0, 1, 0, 1)
    		inline.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    		inline.Parent = outline

    		local gradient= Instance.new("UIGradient")
    		gradient.Color = ColorSequence.new(Color3.fromRGB(30, 30, 30), Color3.fromRGB(25, 25, 25))
    		gradient.Rotation = 90
    		gradient.Parent = inline
    		self.instances.gradient = gradient

    		local label= Instance.new("TextLabel")
    		label.Font = Enum.Font.Arial
    		label.TextSize = 12
    		label.TextStrokeTransparency = 0
    		label.Position = UDim2.new(0, 23, 0.5, 0)
    		label.Size = UDim2.new(1, -27, 0, 11)
    		label.AnchorPoint = Vector2.new(0, 0.5)
    		label.Text = ""
    		label.BackgroundTransparency = 1
    		label.TextColor3 = Color3.fromRGB(255, 255, 255)
    		label.TextXAlignment = Enum.TextXAlignment.Left
    		label.Parent = button
    		self.instances.label = label

    		local layout= Instance.new("Frame")
    		layout.Size = UDim2.new(1, -10, 0, 13)
    		layout.Position = UDim2.new(0, 5, 0, 1)
    		layout.BackgroundTransparency = 1
    		layout.Parent = button
    		self.instances.layout = layout

    		local listLayout= Instance.new("UIListLayout")
    		listLayout.Padding = UDim.new(0, 4)
    		listLayout.FillDirection = Enum.FillDirection.Horizontal
    		listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    		listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    		listLayout.Parent = layout

    		button.Parent = parent.instances.canvas
    		self.instances.button = button
    	end

    	function UIToggle.into(self, parent, base, flag)
    self:_makeInstances(parent)

    		self._trove:Connect(self.instances.button.InputBegan, function(input)
    			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
    				if base.activeMenu == "dropdown" and insideFrame(input.Position, base.menus.dropdown.instances.container) then
    					return
    				end

    				if base.activeMenu == "color" and insideFrame(input.Position, base.menus.colorpicker.instances.container) then
    					return
    				end

    				self:set(not self.value)
    			end
    		end)

    		base.features[flag] = self
    		return self
    	end
    end

    local UISlider = {}
    UISlider.__index = UISlider
    do
    	function UISlider.new(parent, flag, min, max, decimals)
    		assert(flag, "UISlider.new(_, flag) : _ -> expected string, got nil")
    		assert(typeof(flag) == "string", "UISlider.new(_, flag) : _ -> expected string, got " .. typeof(flag))

    		local base= parent

    		while base.parent do
    			base = base.parent
    		end

    		local base = base
    assert(base.features[flag] == nil, string.format("UIBase.features[\"%s\"] already exists.", flag))

    		local self = setmetatable({}, UISlider)
    		self._trove = parent._trove:Extend()

    		self.min = min or 0
    		self.max = max or 100
    		self.decimals = decimals or 1

    		self.instances = {}
    		self.changed = self._trove:Add(Signal.new())
    		self.value = nil

    		parent.instances.container.Size += UDim2.new(0, 0, 0, 30)
    		return UISlider.into((self ) , parent, base, flag)
    	end

    	function UISection.newSlider(self, flag, min, max, decimals)
    return UISlider.new(self, flag, min, max, decimals)
    	end

    	function UISlider.set(self, value)
    if typeof(value) ~= "number" then
    			warn("UISlider.set(_, value) : _ -> expected number, got " .. typeof(value))
    			return self
    		end

    		local self = self

    local value = math.clamp(math.round(value * self.decimals) / self.decimals, self.min, self.max)
    		local equal = self.value == value

    		self.value = value
    		self.instances.scale.Size = UDim2.new((self.value - self.min) / (self.max - self.min), 0, 1, 0)
    		self.instances.value.Text = string.format("%s/%s", tostring(self.value), tostring(self.max))

    		if not equal then
    			self.changed:Fire(self.value)
    		end

    		return self
    	end

    	function UISlider.setLabel(self, label)
    assert(label, "UISlider.setLabel(_, label) : _ -> expected string, got nil")
    		assert(typeof(label) == "string", "UISlider.setLabel(_, label) : _ -> expected string, got " .. typeof(label))

    		self.instances.label.Text = label
    		return self
    	end

    	function UISlider._makeInstances(self, parent)
    		local container= Instance.new("Frame")
    		container.BackgroundTransparency = 1
    		container.Size = UDim2.new(1, 0, 0, 26)

    		local label= Instance.new("TextLabel")
    		label.Font = Enum.Font.Arial
    		label.TextSize = 12
    		label.TextStrokeTransparency = 0
    		label.Position = UDim2.new(0, 5, 0, 1)
    		label.Size = UDim2.new(1, -6, 0, 11)
    		label.Text = ""
    		label.BackgroundTransparency = 1
    		label.TextColor3 = Color3.fromRGB(255, 255, 255)
    		label.TextXAlignment = Enum.TextXAlignment.Left
    		label.Parent = container
    		self.instances.label = label

    		local outline= Instance.new("TextButton")
    		outline.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    		outline.BorderSizePixel = 1
    		outline.BorderColor3 = Color3.fromRGB(0, 0, 0)
    		outline.Size = UDim2.new(1, -10, 0, 10)
    		outline.Position = UDim2.new(0, 5, 0, 15)
    		outline.Text = ""
    		outline.AutoButtonColor = false
    		outline.Parent = container
    		self.instances.outline = outline

    		local inline= Instance.new("Frame")
    		inline.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    		inline.BorderSizePixel = 0
    		inline.Size = UDim2.new(1, -2, 1, -2)
    		inline.Position = UDim2.new(0, 1, 0, 1)
    		inline.Parent = outline
    		self.instances.inline = inline

    		local gradient= Instance.new("UIGradient")
    		gradient.Color = ColorSequence.new(Color3.fromRGB(30, 30, 30), Color3.fromRGB(25, 25, 25))
    		gradient.Rotation = 90
    		gradient.Parent = inline

    		local scale= Instance.new("Frame")
    		scale.BorderSizePixel = 0
    		scale.Size = UDim2.new(0.5, 0, 1, 0)
    		scale.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    		scale.BorderSizePixel = 0
    		scale.Parent = inline
    		self.instances.scale = scale

    		local gradient= Instance.new("UIGradient")
    		gradient.Color = ColorSequence.new(Color3.fromRGB(60, 180, 230), Color3.fromRGB(10, 130, 180))
    		gradient.Rotation = 90
    		gradient.Parent = scale

    		local plus= Instance.new("TextButton")
    		plus.Text = "+"
    		plus.BackgroundTransparency = 1
    		plus.Size = UDim2.new(0, 11, 0, 11)
    		plus.Font = Enum.Font.Arial
    		plus.TextSize = 12
    		plus.Position = UDim2.new(1, -13, 0, 0)
    		plus.TextStrokeTransparency = 0
    		plus.TextColor3 = Color3.fromRGB(255, 255, 255)
    		plus.Parent = container
    		self.instances.plus = plus

    		local minus= Instance.new("TextButton")
    		minus.Text = "-"
    		minus.BackgroundTransparency = 1
    		minus.Size = UDim2.new(0, 11, 0, 11)
    		minus.Font = Enum.Font.Arial
    		minus.TextSize = 12
    		minus.Position = UDim2.new(1, -26, 0, 0)
    		minus.TextStrokeTransparency = 0
    		minus.TextColor3 = Color3.fromRGB(255, 255, 255)
    		minus.Parent = container
    		self.instances.minus = minus

    		local value= Instance.new("TextLabel")
    		value.Font = Enum.Font.Arial
    		value.TextSize = 12
    		value.TextStrokeTransparency = 0
    		value.Position = UDim2.new(0, 0, 0, 0)
    		value.Size = UDim2.new(1, 0, 1, 0)
    		value.Text = "undefined"
    		value.BackgroundTransparency = 1
    		value.TextColor3 = Color3.fromRGB(255, 255, 255)
    		value.TextXAlignment = Enum.TextXAlignment.Center
    		value.Parent = inline
    		self.instances.value = value

    		container.Parent = parent.instances.canvas
    	end

    	function UISlider.into(self, parent, base, flag)
    self:_makeInstances(parent)
    		self:set((self.min + self.max) / 2)

    		local dragInput
    local dragging= false

    		local onMouseMove = function(input)
    			if dragging and input == dragInput then
    				local inline = self.instances.inline
    				local position = input.Position

    				local percent = math.clamp((position.X - inline.AbsolutePosition.X) / inline.AbsoluteSize.X, 0, 1)
    				self:set(self.min + (self.max - self.min) * percent)
    			end
    		end

    		local connection = self._trove:Connect(UserInputService.InputChanged, onMouseMove)

    		self._trove:Connect((base.visibilityChanged ), function(state)
    			if not state then
    				dragging = false
    				self._trove:Remove(connection)
    				return
    			end

    			connection = self._trove:Connect(UserInputService.InputChanged, onMouseMove)
    		end)

    		self._trove:Connect(self.instances.outline.InputBegan, function(input)
    			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
    				if base.activeMenu == "dropdown" and insideFrame(input.Position, base.menus.dropdown.instances.container) then
    					return
    				end

    				if base.activeMenu == "color" and insideFrame(input.Position, base.menus.colorpicker.instances.container) then
    					return
    				end

    				dragging = true
    				dragInput = input

    				onMouseMove(input)

    				local onChanged
    				onChanged = self._trove:Connect(input.Changed, function()
    					if input.UserInputState == Enum.UserInputState.End then
    						dragging = false
    						self._trove:Remove(onChanged)
    						dragInput = nil
    					end
    				end)
    			end
    		end)

    		self._trove:Connect(self.instances.outline.InputChanged, function(input)
    			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
    				dragInput = input
    			end
    		end)

    		self._trove:Connect(self.instances.plus.InputBegan, function(input)
    			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
    				if base.activeMenu == "dropdown" and insideFrame(input.Position, base.menus.dropdown.instances.container) then
    					return
    				end

    				if base.activeMenu == "color" and insideFrame(input.Position, base.menus.colorpicker.instances.container) then
    					return
    				end

    				self:set(self.value + (1 / self.decimals))
    			end
    		end)

    		self._trove:Connect(self.instances.minus.InputBegan, function(input)
    			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
    				if base.activeMenu == "dropdown" and insideFrame(input.Position, base.menus.dropdown.instances.container) then
    					return
    				end

    				if base.activeMenu == "color" and insideFrame(input.Position, base.menus.colorpicker.instances.container) then
    					return
    				end

    				self:set(self.value - (1 / self.decimals))
    			end
    		end)

    		base.features[flag] = self
    		return self
    	end
    end

    local UIDropdown = {}
    UIDropdown.__index = UIDropdown
    do
    	function UIDropdown.new(parent, flag, multi, options)
    		assert(flag, "UIDropdown.new(_, flag, _) : _ -> expected string, got nil")
    		assert(typeof(flag) == "string", "UIDropdown.new(_, flag, _) : _ -> expected string, got " .. typeof(flag))
    		assert(options, "todo: error")
    		assert(typeof(options) == "table", "todo: error")

    		local base= parent

    		while base.parent do
    			base = base.parent
    		end

    		local base = base
    assert(base.features[flag] == nil, string.format("UIBase.features[\"%s\"] already exists.", flag))

    		local self = setmetatable({}, UIDropdown)
    		self._trove = parent._trove:Extend()

    		self.base = base

    		self.instances = {}
    		self.changed = self._trove:Add(Signal.new())
    		self.value = nil

    		self.onOptionAdded = self._trove:Add(Signal.new())
    		self.onOptionRemoved = self._trove:Add(Signal.new())

    		self.open = false
    		self.options = options

    		self.multi = multi

    		parent.instances.container.Size += UDim2.new(0, 0, 0, 24)
    		return UIDropdown.into((self ) , parent, base, flag)
    	end

    	function UISection.newDropdown(self, flag, multi, options)
    return UIDropdown.new(self, flag, multi, options)
    	end

    	function UIDropdown.add(self, option)
    		if not table.find(self.options, option) then
    			table.insert(self.options, option)
    			self.onOptionAdded:Fire(option)
    		end
    	end

    	function UIDropdown.remove(self, option)
    		local index = table.find(self.options, option)

    		if index then
    			table.remove(self.options, index)
    			self.onOptionRemoved:Fire(option)

    			local value = self.value

    			if typeof(value) == "table" then
    				if value[option] then
    					value[option] = nil

    					self:set(value)
    				end
    			else
    				if self.value == option then
    					self:set(self.options[1])
    				end
    			end
    		end
    	end

    	function UIDropdown._makeInstances(self, parent)
    		local container= Instance.new("Frame")
    		container.Size = UDim2.new(1, 0, 0, 20)
    		container.BackgroundTransparency = 1

    		local outline= Instance.new("TextButton")
    		outline.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    		outline.BorderSizePixel = 1
    		outline.BorderColor3 = Color3.fromRGB(0, 0, 0)
    		outline.Position = UDim2.new(0, 5, 0, 0)
    		outline.Size = UDim2.new(1, -10, 0, 18)
    		outline.AutoButtonColor = false
    		outline.Text = ""
    		outline.Parent = container
    		self.instances.outline = outline

    		local inline= Instance.new("Frame")
    		inline.Position = UDim2.new(0, 1, 0, 1)
    		inline.Size = UDim2.new(1, -2, 1, -2)
    		inline.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    		inline.BorderSizePixel = 0
    		inline.Parent = outline

    		local gradient= Instance.new("UIGradient")
    		gradient.Color = ColorSequence.new(Color3.fromRGB(30, 30, 30), Color3.fromRGB(25, 25, 25))
    		gradient.Rotation = 90
    		gradient.Parent = inline

    		local value= Instance.new("TextLabel")
    		value.Font = Enum.Font.Arial
    		value.TextSize = 12
    		value.TextStrokeTransparency = 0
    		value.Position = UDim2.new(0, 4, 0.5, 0)
    		value.Size = UDim2.new(1, -18, 0, 11)
    		value.AnchorPoint = Vector2.new(0, 0.5)
    		value.Text = "None"
    		value.BackgroundTransparency = 1
    		value.TextColor3 = Color3.fromRGB(255, 255, 255)
    		value.TextXAlignment = Enum.TextXAlignment.Left
    		value.TextTruncate = Enum.TextTruncate.AtEnd
    		value.Parent = inline
    		self.instances.value = value

    		local open= Instance.new("TextLabel")
    		open.Font = Enum.Font.Arial
    		open.TextSize = 12
    		open.TextStrokeTransparency = 0
    		open.Position = UDim2.new(0, 5, 0.5, -1)
    		open.Size = UDim2.new(1, -8, 0, 11)
    		open.AnchorPoint = Vector2.new(0, 0.5)
    		open.Text = "+"
    		open.BackgroundTransparency = 1
    		open.TextColor3 = Color3.fromRGB(255, 255, 255)
    		open.TextXAlignment = Enum.TextXAlignment.Right
    		open.Parent = inline
    		self.instances.open = open

    		container.Parent = parent.instances.canvas
    	end

    	function UIDropdown.setOpen(self, state, base)
    		if self.open == state then
    			return
    		end

    		self.open = state
    		self.instances.open.Text = self.open and "-" or "+"
    	end

    	function UIDropdown.set(self, value)
    		if self.value == value and not self.multi then
    			return
    		end

    		self.value = value

    		if typeof(value) == "table" then
    			local res = ""

    			for _, option in self.options do
    				if value[option] then
    					res ..= option .. ", "
    				end
    			end

    			if string.len(res) == 0 then
    				self.instances.value.Text = "..."
    			else
    				self.instances.value.Text = string.sub(res, 1, string.len(res) - 2)
    			end
    		else
    			self.instances.value.Text = value or "None"
    		end

    		self.changed:Fire(self.value)
    	end

    	function UIDropdown.into(self, parent, base, flag)
    self:_makeInstances(parent)

    		if not self.multi then
    			self:set(self.options[1])
    		else
    			self:set({})
    		end

    		self._trove:Connect(self.instances.outline.InputBegan, function(input)
    			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
    				if base.activeMenu == "dropdown" and insideFrame(input.Position, base.menus.dropdown.instances.container) then
    					return
    				end

    				if base.activeMenu == "color" and insideFrame(input.Position, base.menus.colorpicker.instances.container) then
    					return
    				end

    				self:setOpen(not self.open, base)

    				if self.open then
    					base.menus.dropdown:attach(self, base )
    				else
    					base.menus.dropdown:detach(base )
    				end
    			end
    		end)

    		base.features[flag] = self
    		return self
    	end
    end

    local UIButton = {}
    UIButton.__index = UIButton
    do
    	function UIButton.new(parent, flag)
    		assert(flag, "UIButton.new(_, flag) : _ -> expected string, got nil")
    		assert(typeof(flag) == "string", "UIButton.new(_, flag) : _ -> expected string, got " .. typeof(flag))

    		local base= parent

    		while base.parent do
    			base = base.parent
    		end

    		local base = base
    assert(base.features[flag] == nil, string.format("UIBase.features[\"%s\"] already exists.", flag))

    		local self = setmetatable({}, UIButton)
    		self._trove = parent._trove:Extend()

    		self.instances = {}
    		self.changed = self._trove:Add(Signal.new())

    		parent.instances.container.Size += UDim2.new(0 , 0, 0, 24)
    		return UIButton.into((self ) , parent, base, flag)
    	end

    	function UISection.newButton(self, flag)
    return UIButton.new(self, flag)
    	end

    	function UIButton.set(self, state)
    return self
    	end

    	function UIButton.setLabel(self, label)
    assert(label, "UIButton.setLabel(_, label) : _ -> expected string, got nil")
    		assert(typeof(label) == "string", "UIButton.setLabel(_, label) : _ -> expected string, got " .. typeof(label))

    		self.instances.button.Text = label
    		return self
    	end

    	function UIButton._makeInstances(self, parent)
    		local container= Instance.new("Frame")
    		container.Size = UDim2.new(1, 0, 0, 20)
    		container.BackgroundTransparency = 1

    		local outline= Instance.new("Frame")
    		outline.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    		outline.BorderSizePixel = 1
    		outline.BorderColor3 = Color3.fromRGB(0, 0, 0)
    		outline.Position = UDim2.new(0, 5, 0, 0)
    		outline.Size = UDim2.new(1, -10, 0, 18)
    		outline.Parent = container

    		local inline= Instance.new("Frame")
    		inline.Position = UDim2.new(0, 1, 0, 1)
    		inline.Size = UDim2.new(1, -2, 1, -2)
    		inline.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    		inline.BorderSizePixel = 0
    		inline.Parent = outline

    		local gradient= Instance.new("UIGradient")
    		gradient.Color = ColorSequence.new(Color3.fromRGB(30, 30, 30), Color3.fromRGB(25, 25, 25))
    		gradient.Rotation = 90
    		gradient.Parent = inline

    		local button= Instance.new("TextButton")
    		button.Font = Enum.Font.Arial
    		button.TextSize = 12
    		button.TextStrokeTransparency = 0
    		button.Position = UDim2.new(0, 0, 0, 0)
    		button.Size = UDim2.new(1, 0, 1, 0)
    		button.BackgroundTransparency = 1
    		button.TextColor3 = Color3.fromRGB(255, 255, 255)
    		button.TextXAlignment = Enum.TextXAlignment.Center
    		button.Parent = inline
    		self.instances.button = button

    		container.Parent = parent.instances.canvas
    	end

    	function UIButton.into(self, parent, base, flag)
    self:_makeInstances(parent)

    		self._trove:Connect(self.instances.button.InputBegan, function(input)
    			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
    				if base.activeMenu == "dropdown" and insideFrame(input.Position, base.menus.dropdown.instances.container) then
    					return
    				end

    				if base.activeMenu == "color" and insideFrame(input.Position, base.menus.colorpicker.instances.container) then
    					return
    				end

    				self.changed:Fire()
    				self.instances.button.TextColor3 = Color3.fromRGB(55, 175, 225)
    			end
    		end)

    		self._trove:Connect(self.instances.button.InputEnded, function(input)
    			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
    				self.instances.button.TextColor3 = Color3.fromRGB(255, 255, 255)
    			end
    		end)

    		base.features[flag] = self
    		return self
    	end
    end

    local UIList = {}
    UIList.__index = UIList
    do
    	function UIList.new(parent, flag, size, options)
    		assert(flag, "UIList.new(_, flag) : _ -> expected string, got nil")
    		assert(typeof(flag) == "string", "UIList.new(_, flag) : _ -> expected string, got " .. typeof(flag))

    		local base= parent

    		while base.parent do
    			base = base.parent
    		end

    		local base = base
    assert(base.features[flag] == nil, string.format("UIBase.features[\"%s\"] already exists.", flag))

    		local self = setmetatable({}, UIList)
    		self._trove = parent._trove:Extend()

    		self.instances = {}
    		self.changed = self._trove:Add(Signal.new())

    		self.options = options
    		self.size = size * 18 + 4

    		parent.instances.container.Size += UDim2.new(0, 0, 0, self.size + 4)
    		return UIList.into((self ) , parent, base, flag)
    	end

    	function UISection.newList(self, flag, size, options)
    return UIList.new(self, flag, size, options)
    	end

    	function UIList.set(self, value)
    if self.value == value then
    			return self
    		end

    		self.value = value
    		self.changed:Fire(self.value)
    		return self
    	end

    	function UIList.add(self, option)
    		if self.options[option] then
    			return
    		end

    		local trove = self._trove:Extend()

    		local container= Instance.new("Frame")
    		container.BackgroundTransparency = 1
    		container.Size = UDim2.new(1, 0, 0, 18)

    		local button= Instance.new("TextButton")
    		button.Text = option
    		button.Size = UDim2.new(1, 0, 1, 0)
    		button.TextColor3 = Color3.fromRGB(255, 255, 255)
    		button.TextStrokeTransparency = 0
    		button.TextXAlignment = Enum.TextXAlignment.Center
    		button.Font = Enum.Font.Arial
    		button.TextSize = 12
    		button.BackgroundTransparency = 1
    		button.Parent = container

    		container.Parent = self.instances.layout

    		trove:Connect(button.InputBegan, function(input)
    			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
    				self:set(option)
    			end
    		end)

    		local function updateColors()
    			if option == self.value then
    				button.TextColor3 = Color3.fromRGB(55, 175, 225)
    			else
    				button.TextColor3 = Color3.fromRGB(255, 255, 255)
    			end
    		end

    		updateColors()
    		trove:Connect((self.changed ), updateColors)

    		trove:Add(container)
    		self.options[option] = trove
    	end

    	function UIList.remove(self, option)
    		self._trove:Remove(self.options[option])
    		self.options[option] = nil
    		self:set(nil)
    	end

    	function UIList._reset(self)
    		for option in self.options do
    			self:set(option)
    			break
    		end
    	end

    	function UIList._makeInstances(self, parent)
    		local container= Instance.new("Frame")
    		container.Size = UDim2.new(1, 0, 0, self.size)
    		container.BackgroundTransparency = 1

    		local outline= Instance.new("Frame")
    		outline.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    		outline.BorderSizePixel = 1
    		outline.BorderColor3 = Color3.fromRGB(0, 0, 0)
    		outline.Position = UDim2.new(0, 5, 0, 0)
    		outline.Size = UDim2.new(1, -10, 1, 0)
    		outline.Parent = container

    		local layout= Instance.new("ScrollingFrame")
    		layout.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    		layout.BorderSizePixel = 0
    		layout.Position = UDim2.new(0, 1, 0, 1)
    		layout.Size = UDim2.new(1, -2, 1, -2)
    		layout.AutomaticCanvasSize = Enum.AutomaticSize.Y
    		layout.CanvasSize = UDim2.new(0, 0, 0, 0)
    		layout.ScrollBarImageColor3 = Color3.fromRGB(55, 175, 225)
    		layout.ScrollingDirection = Enum.ScrollingDirection.Y
    		layout.ScrollBarThickness = 4
    		layout.TopImage = "rbxasset://textures/AvatarEditorImages/LightPixel.png"
    		layout.MidImage = "rbxasset://textures/AvatarEditorImages/LightPixel.png"
    		layout.BottomImage = "rbxasset://textures/AvatarEditorImages/LightPixel.png"
    		layout.Parent = outline
    		self.instances.layout = layout

    		local listLayout= Instance.new("UIListLayout")
    		listLayout.FillDirection = Enum.FillDirection.Vertical
    		listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    		listLayout.Parent = layout

    		container.Parent = parent.instances.canvas
    	end

    	function UIList.into(self, parent, base, flag)
    self:_makeInstances(parent)
    		self:_reset()

    		base.features[flag] = self
    		return self
    	end
    end

    local UITextBox = {}
    UITextBox.__index = UITextBox
    do
    	function UITextBox.new(parent, flag)
    		assert(flag, "UITextBox.new(_, flag) : _ -> expected string, got nil")
    		assert(typeof(flag) == "string", "UITextBox.new(_, flag) : _ -> expected string, got " .. typeof(flag))

    		local base= parent

    		while base.parent do
    			base = base.parent
    		end

    		local base = base
    assert(base.features[flag] == nil, string.format("UIBase.features[\"%s\"] already exists.", flag))

    		local self = setmetatable({}, UITextBox)
    		self._trove = parent._trove:Extend()

    		self.instances = {}
    		self.changed = self._trove:Add(Signal.new())

    		parent.instances.container.Size += UDim2.new(0 , 0, 0, 24)
    		return UITextBox.into((self ) , parent, base, flag)
    	end

    	function UISection.newTextBox(self, flag)
    return UITextBox.new(self, flag)
    	end

    	function UITextBox.set(self, text)
    local textbox = (self ).instances.textbox
    		local text = string.sub(text, 1, 20)

    		if self.value == text then
    			textbox.Text = text
    			return self
    		end

    		textbox.Text = text

    		self.value = text
    		self.changed:Fire(self.value)
    		return self
    	end

    	function UITextBox.setLabel(self, label)
    assert(label, "UITextBox.setLabel(_, label) : _ -> expected string, got nil")
    		assert(typeof(label) == "string", "UITextBox.setLabel(_, label) : _ -> expected string, got " .. typeof(label))

    		self.instances.textbox.PlaceholderText = label
    		return self
    	end

    	function UITextBox._makeInstances(self, parent)
    		local container= Instance.new("Frame")
    		container.Size = UDim2.new(1, 0, 0, 20)
    		container.BackgroundTransparency = 1

    		local outline= Instance.new("Frame")
    		outline.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    		outline.BorderSizePixel = 1
    		outline.BorderColor3 = Color3.fromRGB(0, 0, 0)
    		outline.Position = UDim2.new(0, 5, 0, 0)
    		outline.Size = UDim2.new(1, -10, 0, 18)
    		outline.Parent = container

    		local inline= Instance.new("Frame")
    		inline.Position = UDim2.new(0, 1, 0, 1)
    		inline.Size = UDim2.new(1, -2, 1, -2)
    		inline.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    		inline.BorderSizePixel = 0
    		inline.Parent = outline

    		local gradient= Instance.new("UIGradient")
    		gradient.Color = ColorSequence.new(Color3.fromRGB(30, 30, 30), Color3.fromRGB(25, 25, 25))
    		gradient.Rotation = 90
    		gradient.Parent = inline

    		local textbox= Instance.new("TextBox")
    		textbox.Font = Enum.Font.Arial
    		textbox.TextSize = 12
    		textbox.TextStrokeTransparency = 0
    		textbox.Position = UDim2.new(0, 0, 0, 0)
    		textbox.Size = UDim2.new(1, 0, 1, 0)
    		textbox.BackgroundTransparency = 1
    		textbox.TextColor3 = Color3.fromRGB(255, 255, 255)
    		textbox.TextXAlignment = Enum.TextXAlignment.Center
    		textbox.Text = ""
    		textbox.ClearTextOnFocus = false
    		textbox.Parent = inline
    		self.instances.textbox = textbox

    		container.Parent = parent.instances.canvas
    	end

    	function UITextBox.into(self, parent, base, flag)
    self:_makeInstances(parent)
    		self:set("")

    		local textbox = self.instances.textbox

    		self._trove:Connect(textbox:GetPropertyChangedSignal("Text"), function()
    			textbox.TextXAlignment = Enum.TextXAlignment.Center
    			self:set(textbox.Text)
    		end)

    		base.features[flag] = self
    		return self
    	end
    end

    local UILabel = {}
    UILabel.__index = UILabel
    do
    	function UILabel.new(parent, flag)
    		assert(flag, "UILabel.new(_, flag) : _ -> expected string, got nil")
    		assert(typeof(flag) == "string", "UILabel.new(_, flag) : _ -> expected string, got " .. typeof(flag))

    		local base= parent

    		while base.parent do
    			base = base.parent
    		end

    		local base = base
    assert(base.features[flag] == nil, string.format("UIBase.features[\"%s\"] already exists.", flag))

    		local self = setmetatable({}, UILabel)
    		self._trove = parent._trove:Extend()

    		self.instances = {}
    		self.changed = self._trove:Add(Signal.new())
    		self.value = false

    		self.base = base

    		parent.instances.container.Size += UDim2.new(0 , 0, 0, 19)
    		return UILabel.into((self ) , parent, base, flag)
    	end

    	function UISection.newLabel(self, flag)
    return UILabel.new(self, flag)
    	end

    	function UILabel.set(self, state)
    return self
    	end

    	function UILabel.setLabel(self, label)
    assert(label, "UILabel.setLabel(_, label) : _ -> expected string, got nil")
    		assert(typeof(label) == "string", "UILabel.setLabel(_, label) : _ -> expected string, got " .. typeof(label))

    		self.instances.label.Text = label
    		return self
    	end

    	function UILabel.newKeybind(self, flag, modes)
    return ((UIKeybind.new(self, flag, modes or { "Always", "Toggle", "Hold", "Release" }, self.base) ))
    end

    	function UILabel.newColorpicker(self, flag, hasAlpha)
    return ((UIColorpicker.new(self, flag, self.base, hasAlpha or false) ))
    end

    	function UILabel._makeInstances(self, parent)
    		local container= Instance.new("Frame")
    		container.Size = UDim2.new(1, 0, 0, 15)
    		container.BackgroundTransparency = 1

    		local label= Instance.new("TextLabel")
    		label.Font = Enum.Font.Arial
    		label.TextSize = 12
    		label.TextStrokeTransparency = 0
    		label.Position = UDim2.new(0, 5, 0.5, 0)
    		label.AnchorPoint = Vector2.new(0, 0.5)
    		label.Size = UDim2.new(1, -10, 0, 11)
    		label.Text = ""
    		label.BackgroundTransparency = 1
    		label.TextColor3 = Color3.fromRGB(255, 255, 255)
    		label.TextXAlignment = Enum.TextXAlignment.Left
    		label.Parent = container
    		self.instances.label = label

    		local layout= Instance.new("Frame")
    		layout.Size = UDim2.new(1, -10, 0, 13)
    		layout.Position = UDim2.new(0, 5, 0, 1)
    		layout.BackgroundTransparency = 1
    		layout.Parent = container
    		self.instances.layout = layout

    		local listLayout= Instance.new("UIListLayout")
    		listLayout.Padding = UDim.new(0, 4)
    		listLayout.FillDirection = Enum.FillDirection.Horizontal
    		listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    		listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    		listLayout.Parent = layout

    		container.Parent = parent.instances.canvas
    	end

    	function UILabel.into(self, parent, base, flag)
    self:_makeInstances(parent)

    		base.features[flag] = self
    		return self
    	end
    end

    local UICurveGraph = {}
    UICurveGraph.__index = UICurveGraph
    do
    	function UICurveGraph.new(parent, flag)
    		assert(flag, "UICurveGraph.new(_, flag) : _ -> expected string, got nil")
    		assert(typeof(flag) == "string", "UICurveGraph.new(_, flag) : _ -> expected string, got " .. typeof(flag))

    		local base= parent

    		while base.parent do
    			base = base.parent
    		end

    		local base = base
    assert(base.features[flag] == nil, string.format("UIBase.features[\"%s\"] already exists.", flag))

    		local self = setmetatable({}, UICurveGraph)
    		self._trove = parent._trove:Extend()

    		self.instances = {}
    		self.instances.points = {}
    		self.changed = self._trove:Add(Signal.new())
    		self.value = { a = Vector2.new(0, 1), b = Vector2.new(1, 0) }
    		self.base = base

    		self.dragging = false

    		parent.instances.container.Size += UDim2.new(0 , 0, 0, 104)
    		return UICurveGraph.into((self ) , parent, base, flag)
    	end

    	function UISection.newCurveGraph(self, flag)
    return UICurveGraph.new(self, flag)
    	end

    	function UICurveGraph.set(self, value)
    if self.value.a == value.a and self.value.b == value.b then
    			return self
    		end

    		local self = self
    self.value = value
    		self:updatePoints()

    		self.changed:Fire(self.value)
    		return self
    	end

    	function UICurveGraph.updatePoints(self)
    		local instances = self.instances
    		local size = instances.outline.AbsoluteSize

    		local start = size.Y
    		local pointA = size.Y * self.value.a.Y * 3
    		local pointB = size.Y * self.value.b.Y * 3

    		for i = 1, 19 do
    			local t = i / 20
    			local t_1 = 1 - t
    			local p1 = start * t_1 * t_1 * t_1
    			local p2 = pointA * t_1 * t_1 * t
    			local p3 = pointB * t_1 * t * t

    			local point = p1 + p2 + p3

    			self.instances.points[i].Position = UDim2.new(i / 20, 0, point / size.Y, 0)
    		end

    		local value = self.value
    		instances.controlA.Position = UDim2.new(value.a.X, 0, value.a.Y, 0)
    		instances.controlB.Position = UDim2.new(value.b.X, 0, value.b.Y, 0)
    	end

    	function UICurveGraph._makeInstances(self, parent)
    		local container= Instance.new("Frame")
    		container.Size = UDim2.new(1, 0, 0, 100)
    		container.BackgroundTransparency = 1

    		local outline= Instance.new("Frame")
    		outline.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    		outline.BorderSizePixel = 1
    		outline.BorderColor3 = Color3.fromRGB(0, 0, 0)
    		outline.Size = UDim2.new(1, -10, 1, -2)
    		outline.Position = UDim2.new(0, 5, 0, 1)
    		outline.Parent = container
    		self.instances.outline = outline

    		local inline= Instance.new("Frame")
    		inline.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    		inline.BorderSizePixel = 0
    		inline.Size = UDim2.new(1, -2, 1, -2)
    		inline.Position = UDim2.new(0, 1, 0, 1)
    		inline.Parent = outline
    		self.instances.inline = inline

    		local gradient= Instance.new("UIGradient")
    		gradient.Color = ColorSequence.new(Color3.fromRGB(30, 30, 30), Color3.fromRGB(25, 25, 25))
    		gradient.Rotation = 90
    		gradient.Parent = inline

    		for scale = 0.25, 0.75, 0.25 do
    			local line = Instance.new("Frame")
    			line.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    			line.Position = UDim2.new(scale, 0, 0, 0)
    			line.BorderSizePixel = 0
    			line.Size = UDim2.new(0, 1, 1, 0)
    			line.Parent = inline
    		end

    		for scale = 0.25, 0.75, 0.25 do
    			local line = Instance.new("Frame")
    			line.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    			line.Position = UDim2.new(0, 0, scale, 0)
    			line.BorderSizePixel = 0
    			line.Size = UDim2.new(1, 0, 0, 1)
    			line.Parent = inline
    		end

    		local graph= Instance.new("Frame")
    		graph.BorderSizePixel = 0
    		graph.Size = UDim2.new(1, -6, 1, -6)
    		graph.Position = UDim2.new(0, 3, 0, 3)
    		graph.BackgroundTransparency = 1
    		graph.Parent = inline
    		self.instances.graph = graph

    		for i = 1, 19 do
    			local point = Instance.new("Frame")
    			point.BackgroundColor3 = Color3.fromRGB(55, 175, 225)
    			point.Position = UDim2.new(i / 20, 0, 0.5, 0)
    			point.AnchorPoint = Vector2.new(0.5, 0.5)
    			point.BorderSizePixel = 1
    			point.BorderColor3 = Color3.fromRGB(0, 0, 0)
    			point.Size = UDim2.new(0, 4, 0, 4)
    			point.Parent = graph
    			self.instances.points[i] = point
    		end

    		local controlA = Instance.new("TextButton")
    		controlA.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    		controlA.AnchorPoint = Vector2.new(0.5, 0.5)
    		controlA.BorderSizePixel = 1
    		controlA.BorderColor3 = Color3.fromRGB(0, 0, 0)
    		controlA.Size = UDim2.new(0, 4, 0, 4)
    		controlA.Text = ""
    		controlA.AutoButtonColor = false
    		controlA.Parent = graph
    		self.instances.controlA = controlA

    		local controlB = Instance.new("TextButton")
    		controlB.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    		controlB.AnchorPoint = Vector2.new(0.5, 0.5)
    		controlB.BorderSizePixel = 1
    		controlB.BorderColor3 = Color3.fromRGB(0, 0, 0)
    		controlB.Size = UDim2.new(0, 4, 0, 4)
    		controlB.Text = ""
    		controlB.AutoButtonColor = false
    		controlB.Parent = graph
    		self.instances.controlB = controlB

    		container.Parent = parent.instances.canvas
    	end

    	function UICurveGraph.into(self, parent, base, flag)
    self:_makeInstances(parent)
    		self:updatePoints()

    		local base = base

    base:makeDraggable(self.instances.controlA, self._trove, function(input)
    			local inline = self.instances.graph
    			local position = input.Position

    			local percentX = math.clamp((position.X - inline.AbsolutePosition.X) / inline.AbsoluteSize.X, 0, 1)
    			local percentY = math.clamp((position.Y - inline.AbsolutePosition.Y) / inline.AbsoluteSize.Y, 0, 1)

    			self:set({ a = Vector2.new(percentX, percentY), b = self.value.b })
    		end)

    		base:makeDraggable(self.instances.controlB, self._trove, function(input)
    			local inline = self.instances.graph
    			local position = input.Position

    			local percentX = math.clamp((position.X - inline.AbsolutePosition.X) / inline.AbsoluteSize.X, 0, 1)
    			local percentY = math.clamp((position.Y - inline.AbsolutePosition.Y) / inline.AbsoluteSize.Y, 0, 1)

    			self:set({ a = self.value.a, b = Vector2.new(percentX, percentY) })
    		end)

    		base.features[flag] = self
    		return self
    	end
    end
end

-- Example
do
    local base = UIBase.new():setLabel("Minho Hub") do
        local tabList= base:newTabList()
    
        local misc = tabList:newTab("Misc"):intoSections()
        do
            local movement = misc:newSection("left", "Movement")
            do
                movement:newToggle("misc/movement/no_slide_cooldown"):setLabel("No Slide Cooldown")
                movement:newToggle("misc/movement/speed_multiplier/enabled"):setLabel("Enable Speed Multiplier")
                movement:newSlider("misc/movement/speed_multiplier/mult", 1, 10, 100):set(2):setLabel("Speed Multiplier")
                movement:newToggle("misc/movement/jump_height/enabled"):setLabel("Jump Height Multiplier")
                movement:newSlider("misc/movement/jump_height/mult", 1, 10, 100):set(2):setLabel("Jump Height Multiplier")
                movement:newToggle("misc/movement/infinite_jump"):setLabel("Infinite Jump")
            end

            -- UI only: no functionality is attached to these controls.
            -- Guns stay on the right, with Utilities below them.
            local guns = misc:newSection("right", "Guns")
            do
                guns:newToggle("misc/guns/no_recoil"):setLabel("No Recoil")
                guns:newToggle("misc/guns/no_spread"):setLabel("No Spread")
                guns:newToggle("misc/guns/no_shoot_cooldown"):setLabel("No Shoot Cooldown")
                guns:newSlider("misc/guns/shoot_cooldown", 10, 100, 1):set(10):setLabel("Shoot Cooldown")
            end

            local miscTools = misc:newSection("right", "Utilities")
            do
                -- Checkbox-style controls.
                miscTools:newToggle("misc/utilities/name_spoofer"):setLabel("Name Spoofer")
                miscTools:newTextBox("misc/utilities/name_spoofer_text"):setLabel("Name")
                miscTools:newToggle("misc/utilities/info_spoofer"):setLabel("Info Spoofer")
                miscTools:newDropdown("misc/utilities/info_spoofer_platform", false, {
                    "Mobile",
                    "Desktop",
                    "Controller",
                    "VR",
                }):set("Mobile")
                miscTools:newToggle("misc/utilities/auto_queue"):setLabel("Auto Queue")
            end

        end
    
        -- Visual parent tab with functional subtabs.
        local visual = tabList:newTab("Visual")
        local visualTabs = visual:newTabList()

        -- HUD
        local crosshairTab = visualTabs:newTab("Crosshair"):intoSections()
        do
            local cross = crosshairTab:newSection("left", "Crosshair")
            cross:newToggle("hud/crosshair"):setLabel("Crosshair")
            cross:newSlider("drawing_crosshair_length", 1, 20, 1):set(5):setLabel("Length")
            cross:newSlider("drawing_crosshair_gap", 0, 30, 1):set(5):setLabel("Gap")
            cross:newToggle("drawing_crosshair_spin"):setLabel("Spin")
            cross:newSlider("drawing_crosshair_speed", 1, 20, 1):set(5):setLabel("Spin Speed")
            cross:newDropdown("drawing_crosshair_location", false, {"Mouse", "Center"}):set("Mouse")
            cross:newLabel("hud/crosshair_color_label"):setLabel("Crosshair Color"):newColorpicker("hud/crosshair_color", false):set({rgb = Color3.fromRGB(255,255,255), alpha = 1})

            local notifications = crosshairTab:newSection("left", "Notifications")
            notifications:newToggle("hud/notifications"):setLabel("Notifications")
            notifications:newDropdown("notification_style", false, {"Default", "Minimalistic", "Eclipse"}):set("Default")
            notifications:newSlider("notification_y_offset", 0, 500, 1):set(50):setLabel("Y Offset")

            local keybinds = crosshairTab:newSection("right", "Keybind List")
            keybinds:newToggle("hud/keybinds"):setLabel("Keybinds")
            keybinds:newSlider("keybind_x", 0, 2000, 1):set(500):setLabel("X Position")
            keybinds:newSlider("keybind_y", 0, 2000, 1):set(500):setLabel("Y Position")

            local watermark = crosshairTab:newSection("left", "Watermark")
            watermark:newToggle("hud/watermark"):setLabel("Watermark")
            watermark:newTextBox("watermark_text"):setLabel("Text") :set("mihno.win")
            watermark:newDropdown("watermark_location", false, {"Center", "Mouse"}):set("Center")
            watermark:newSlider("watermark_x_offset", -1000, 1000, 1):set(0):setLabel("X Offset")
            watermark:newSlider("watermark_y_offset", -1000, 1000, 1):set(0):setLabel("Y Offset")
        end

        -- World (moved from the top-level tabs into Visual).
        local world = visualTabs:newTab("World"):intoSections()
        do
            local environment = world:newSection("left", "World")
            environment:newToggle("world_brightness"):setLabel("World Brightness")
            environment:newSlider("world_brightness_value", 0, 5, 10):set(game:GetService("Lighting").Brightness):setLabel("Brightness")
            environment:newToggle("remove_shadows"):setLabel("Remove Shadows")
            environment:newToggle("world_exposure"):setLabel("World Exposure")
            environment:newSlider("world_exposure_value", -2, 3, 10):set(game:GetService("Lighting").ExposureCompensation):setLabel("Exposure")
            environment:newToggle("world_ambient"):setLabel("World Ambient")
            environment:newLabel("world_ambient_color_label"):setLabel("Ambient Color"):newColorpicker("world_ambient_color", false):set({rgb = game:GetService("Lighting").Ambient, alpha = 1})
            environment:newToggle("world_time"):setLabel("World Time")
            environment:newSlider("world_time_value", 0, 24, 10):set(game:GetService("Lighting").ClockTime):setLabel("Time")
            environment:newToggle("fog_changer"):setLabel("World Fog")
            environment:newLabel("fog_color_label"):setLabel("Fog Color"):newColorpicker("fog_color", false):set({rgb = game:GetService("Lighting").FogColor, alpha = 1})
            environment:newSlider("fog_start", 1, 5000, 1):set(game:GetService("Lighting").FogStart):setLabel("Fog Start")
            environment:newSlider("fog_end", 1, 5000, 1):set(game:GetService("Lighting").FogEnd):setLabel("Fog End")

            -- Skybox is kept in the World tab and is fully local (no UI library/GitHub UI loading).
            local skybox = world:newSection("right", "Skybox")
            skybox:newToggle("world/skybox/enabled"):setLabel("Skybox")
            skybox:newDropdown("world/skybox/preset", false, {"Default", "Minecraft", "Space", "Night"}):set("Default")

            local texturePack = world:newSection("right", "Texture Pack")
            texturePack:newToggle("world/texture_pack/enabled"):setLabel("Texture Pack")
            texturePack:newDropdown("world/texture_pack/pack", false, {"Minecraft", "Grods"}):set("Minecraft")
        end

        -- Other: sounds moved here from the old World area.
        local other = visualTabs:newTab("Other"):intoSections()
        do
            local hitSound = other:newSection("left", "Hit Sound")
            hitSound:newToggle("world/sound/hit_enabled"):setLabel("Hit Sound Replacement")
            hitSound:newDropdown("world/sound/hit_sound", false, {"Successful Hit", "Ender Dragon Hit"}):set("Successful Hit")
            hitSound:newSlider("world/sound/hit_volume", 0, 2, 10):set(1):setLabel("Hit Sound Volume")

            local killSound = other:newSection("right", "Kill Sound")
            killSound:newToggle("world/sound/kill_enabled"):setLabel("Kill Sound Replacement")
            killSound:newDropdown("world/sound/kill_sound", false, {"Silverfish Headshot", "Zombie Hurt", "Ghast Death", "Wither Death"}):set("Silverfish Headshot")
            killSound:newSlider("world/sound/kill_volume", 0, 2, 10):set(1):setLabel("Kill Sound Volume")
        end
        -- ====================== COSMETICS CORE ======================
        -- Integrated local cosmetics state. No `return CosmeticHelper` here:
        -- this file is a single executable script, not a ModuleScript.
        local CosmeticHelper = {}
        local SLOT_KEYS = {
            Skin = "skin", Wrap = "wrap", Charm = "charm", Finisher = "finisher",
        }

        function CosmeticHelper.cosmeticTypeToSlotKey(t) return SLOT_KEYS[t] end
        function CosmeticHelper.cloneWrapSelection(wrap)
            if wrap == nil then return nil end
            if type(wrap) ~= "table" then return {name = tostring(wrap), inverted = false} end
            return {name = wrap.name, inverted = wrap.inverted == true}
        end
        function CosmeticHelper.cloneSelection(sel)
            if type(sel) ~= "table" then return sel end
            return {
                skin = sel.skin,
                wrap = CosmeticHelper.cloneWrapSelection(sel.wrap),
                charm = sel.charm,
                finisher = sel.finisher,
            }
        end
        function CosmeticHelper.getSelectionValue(sel, cosmeticType)
            if type(sel) ~= "table" then return nil end
            local key = SLOT_KEYS[cosmeticType]
            return key and sel[key] or nil
        end
        function CosmeticHelper.setSelectionValue(sel, cosmeticType, value)
            if type(sel) ~= "table" then return end
            local key = SLOT_KEYS[cosmeticType]
            if not key then return end
            if cosmeticType == "Wrap" then
                sel[key] = CosmeticHelper.cloneWrapSelection(value)
            else
                sel[key] = value
            end
        end
        function CosmeticHelper.getSelectedCosmeticName(sel, cosmeticType)
            local value = CosmeticHelper.getSelectionValue(sel, cosmeticType)
            if cosmeticType == "Wrap" and type(value) == "table" then return value.name end
            return value
        end
        function CosmeticHelper.areSelectionsEqual(a, b)
            if a == b then return true end
            if a == nil or b == nil then return false end
            local aw, bw = a.wrap, b.wrap
            local wrapEqual = aw == bw or (type(aw) == "table" and type(bw) == "table" and aw.name == bw.name and aw.inverted == bw.inverted)
            return a.skin == b.skin and a.charm == b.charm and a.finisher == b.finisher and wrapEqual
        end

        local Intent = {}
        Intent.__index = Intent
        function Intent.new()
            return setmetatable({_layers = {}, changed = Signal.new()}, Intent)
        end
        function Intent:SetLayerActive(priority, active)
            if active then self._layers[priority] = self._layers[priority] or {}
            else self._layers[priority] = nil end
            self.changed:Fire()
        end
        function Intent:IsLayerActive(priority) return self._layers[priority] ~= nil end
        function Intent:SetChoice(itemName, cosmeticType, cosmeticName, priority)
            priority = priority or "SkinChanger"
            self._layers[priority] = self._layers[priority] or {}
            local itemData = self._layers[priority][itemName] or {}
            self._layers[priority][itemName] = itemData
            CosmeticHelper.setSelectionValue(itemData, cosmeticType, cosmeticName)
            self.changed:Fire()
        end
        function Intent:ClearSelection(itemName, cosmeticType, priority)
            local function clearLayer(layer)
                local itemData = layer and layer[itemName]
                if itemData then
                    CosmeticHelper.setSelectionValue(itemData, cosmeticType, nil)
                    if next(itemData) == nil then layer[itemName] = nil end
                end
            end
            if priority ~= nil then clearLayer(self._layers[priority])
            else for _, layer in pairs(self._layers) do clearLayer(layer) end end
            self.changed:Fire()
        end
        function Intent:GetItemEffective(itemName)
            local result, priorities = {}, {}
            for p in pairs(self._layers) do table.insert(priorities, p) end
            table.sort(priorities, function(a,b) return tostring(a) > tostring(b) end)
            for _, p in ipairs(priorities) do
                local itemData = self._layers[p][itemName]
                if itemData then
                    for k,v in pairs(itemData) do if result[k] == nil then result[k] = v end end
                end
            end
            return next(result) and result or nil
        end
        function Intent:GetItemNames()
            local names = {}
            for _, layer in pairs(self._layers) do for name in pairs(layer) do names[name] = true end end
            return names
        end
        function Intent:GetLayerSelections(itemName, priority)
            local layer = self._layers[priority]
            return layer and layer[itemName] or nil
        end
        function Intent:ExportState()
            local out = {}
            for p,layer in pairs(self._layers) do
                out[p] = {}
                for name,data in pairs(layer) do out[p][name] = CosmeticHelper.cloneSelection(data) end
            end
            return out
        end
        function Intent:ImportState(data)
            self._layers = {}
            if type(data) == "table" then
                for p,layer in pairs(data) do
                    if type(layer) == "table" then
                        self._layers[p] = {}
                        for name,data2 in pairs(layer) do self._layers[p][name] = CosmeticHelper.cloneSelection(data2) end
                    end
                end
            end
            self.changed:Fire()
        end
        function Intent:Destroy() if self.changed then self.changed:Destroy() end end

        local Store = {}
        Store.__index = Store
        function Store.new()
            return setmetatable({_storage = {}}, Store)
        end
        function Store:SetItem(player, itemName, selection)
            self._storage[player] = self._storage[player] or {}
            self._storage[player][itemName] = CosmeticHelper.cloneSelection(selection)
        end
        function Store:SetItems(player, items)
            self._storage[player] = {}
            for name,sel in pairs(items or {}) do self._storage[player][name] = CosmeticHelper.cloneSelection(sel) end
        end
        function Store:GetAll(player) return self._storage[player] or {} end
        function Store:Get(player,itemName) return self:GetAll(player)[itemName] end
        function Store:ClearItem(player,itemName) if self._storage[player] then self._storage[player][itemName] = nil end end
        function Store:ClearAll(player) self._storage[player] = {} end
        function Store:Destroy() self._storage = {} end

        local Resolver = {}
        Resolver.__index = Resolver
        function Resolver.new(intent, catalog)
            local self = setmetatable({_intent=intent,_catalog=catalog,_resolved={},changed=Signal.new()}, Resolver)
            if intent and intent.changed then intent.changed:Connect(function() self:_Rebuild() end) end
            if catalog and catalog.built then catalog.built:Connect(function() self:_Rebuild() end) end
            self:_Rebuild()
            return self
        end
        function Resolver:_randomFrom(pool)
            local keys = {}
            for k in pairs(pool or {}) do table.insert(keys,k) end
            return #keys > 0 and keys[math.random(1,#keys)] or nil
        end
        function Resolver:_ResolveItem(itemName)
            local e = self._intent:GetItemEffective(itemName)
            if not e then return nil end
            local out = {skin=nil,wrap=nil,charm=nil,finisher=nil}
            out.skin = e.skin == "RANDOM_COSMETIC" and self:_randomFrom(self._catalog._lookupByType.Skin[itemName] or {}) or e.skin
            if out.skin == "NONE_COSMETIC" then out.skin=nil end
            if type(e.wrap)=="table" then out.wrap=CosmeticHelper.cloneWrapSelection(e.wrap)
            elseif e.wrap=="RANDOM_COSMETIC" then out.wrap={name=self:_randomFrom(self._catalog._lookupByType.Wrap or {})}
            elseif e.wrap and e.wrap~="NONE_COSMETIC" then out.wrap={name=e.wrap,inverted=false} end
            if type(out.wrap)=="table" and out.wrap.name=="NONE_COSMETIC" then out.wrap=nil end
            out.charm = e.charm == "RANDOM_COSMETIC" and self:_randomFrom(self._catalog._lookupByType.Charm or {}) or e.charm
            out.finisher = e.finisher == "RANDOM_COSMETIC" and self:_randomFrom(self._catalog._lookupByType.Finisher or {}) or e.finisher
            if out.charm=="NONE_COSMETIC" then out.charm=nil end
            if out.finisher=="NONE_COSMETIC" then out.finisher=nil end
            return (out.skin or out.wrap or out.charm or out.finisher) and out or nil
        end
        function Resolver:_Rebuild()
            self._resolved = {}
            for name in pairs(self._intent:GetItemNames()) do self._resolved[name]=self:_ResolveItem(name) end
            self.changed:Fire()
        end
        function Resolver:ResolveItem(name) return self._resolved[name] or self:_ResolveItem(name) end
        function Resolver:ResolveAll() return self._resolved end
        function Resolver:RerollItem(name) self._resolved[name]=self:_ResolveItem(name); self.changed:Fire(); return self._resolved[name] end
        function Resolver:RerollAll() self:_Rebuild() end
        function Resolver:Destroy() if self.changed then self.changed:Destroy() end end

        local RankCharm = {}
        RankCharm.__index = RankCharm
        function RankCharm.new() return setmetatable({_overrides={},changed=Signal.new()},RankCharm) end
        function RankCharm:SetForSeason(charmName,rankName,leaderboardRank)
            if not charmName then return end
            if rankName==nil then self._overrides[charmName]=nil else self._overrides[charmName]={rankName=rankName,leaderboardRank=leaderboardRank} end
            self.changed:Fire()
        end
        function RankCharm:GetForSeason(charmName) local o=self._overrides[charmName]; return o and o.rankName or nil,o and o.leaderboardRank or nil end
        function RankCharm:GetAllOverrides() return self._overrides end
        function RankCharm:SetAllOverrides(data) self._overrides=type(data)=="table" and data or {}; self.changed:Fire() end
        function RankCharm:Destroy() if self.changed then self.changed:Destroy() end end

        local Cosmetics = {}
        Cosmetics.__index = Cosmetics
        function Cosmetics.new(opts)
            opts=opts or {}
            local self=setmetatable({
                _catalog=opts.catalog,
                _intent=Intent.new(),
                _resolver=nil,
                _store=Store.new(),
                _rankCharm=RankCharm.new(),
                _runtimeEnabled=false,
                storesUpdated=Signal.new(),
            },Cosmetics)
            self._resolver=Resolver.new(self._intent,self._catalog)
            self._intent:SetLayerActive("SkinChanger",false)
            return self
        end
        function Cosmetics:SetRuntimeEnabled(enabled) self._runtimeEnabled=enabled==true end
        function Cosmetics:SetSkinChangerEnabled(enabled) self._intent:SetLayerActive("SkinChanger",enabled==true) end
        function Cosmetics:IsSkinChangerEnabled() return self._intent:IsLayerActive("SkinChanger") end
        function Cosmetics:SetSkinChangerChoice(itemName,sel)
            if not itemName or type(sel)~="table" then return end
            for _,t in ipairs({"Skin","Wrap","Charm","Finisher"}) do
                if sel[SLOT_KEYS[t]] ~= nil then self._intent:SetChoice(itemName,t,sel[SLOT_KEYS[t]],"SkinChanger") end
            end
            self.storesUpdated:Fire()
        end
        function Cosmetics:GetSkinChangerSelections(itemName) return self._intent:GetLayerSelections(itemName,"SkinChanger") end
        function Cosmetics:GetResolved(itemName) return self._resolver:ResolveItem(itemName) end
        function Cosmetics:ExportState() return {itemSelections=self._intent:ExportState(),runtimeEnabled=self._runtimeEnabled,rankCharmOverride=self._rankCharm:GetAllOverrides()} end
        function Cosmetics:ImportState(data)
            if type(data)~="table" then return {success=false,error="Invalid cosmetics state"} end
            self._intent:ImportState(data.itemSelections or {})
            self._rankCharm:SetAllOverrides(data.rankCharmOverride or {})
            self._runtimeEnabled=data.runtimeEnabled==true
            return {success=true}
        end
        function Cosmetics:GetRankCharm() return self._rankCharm end
        function Cosmetics:Destroy() self._intent:Destroy(); self._resolver:Destroy(); self._rankCharm:Destroy(); self.storesUpdated:Destroy(); self._store:Destroy() end

        -- ====================== COSMETICS CATALOG ======================
        local Catalog = {}
        Catalog.__index = Catalog
        function Catalog.new()
            return setmetatable({
                _typeSet={}, _raritySet={}, _typeByName={},
                _byType={Skin={},Wrap={},Charm={},Finisher={},Emote={}},
                _lookupByType={Skin={},Wrap={},Charm={},Finisher={},Emote={}},
                built=Signal.new(),
            },Catalog)
        end
        function Catalog:_getLibrary()
            local lib=nil
            pcall(function() if type(KiciaHook)=="table" and type(KiciaHook.ao)=="table" then lib=KiciaHook.ao.CosmeticLibrary end end)
            if lib==nil then pcall(function() lib=CosmeticLibrary end) end
            return lib
        end
        function Catalog:Build()
            local lib=self:_getLibrary(); local cosmeticsTable=lib and lib.Cosmetics
            for _,t in ipairs({"Skin","Wrap","Charm","Finisher","Emote"}) do self._byType[t]={}; self._lookupByType[t]={} end
            self._typeByName={}
            if type(cosmeticsTable)~="table" then self.built:Fire(); return end
            if next(self._raritySet)==nil then
                for _,data in pairs(cosmeticsTable) do if type(data)=="table" and data.Rarity~=nil then self._raritySet[data.Rarity]=true end end
            end
            for name,data in pairs(cosmeticsTable) do
                if type(data)=="table" then
                    local t=data.Type
                    if t and self._typeSet[t] and self._byType[t] then
                        self._typeByName[name]=t; table.insert(self._byType[t],name)
                        local rarity=data.Rarity
                        if rarity==nil or self._raritySet[rarity] then
                            if t=="Skin" and data.ItemName then
                                self._lookupByType.Skin[data.ItemName]=self._lookupByType.Skin[data.ItemName] or {}
                                self._lookupByType.Skin[data.ItemName][name]=true
                            elseif t~="Skin" then self._lookupByType[t][name]=true end
                        end
                    end
                end
            end
            for _,list in pairs(self._byType) do table.sort(list,function(a,b)return tostring(a):lower()<tostring(b):lower() end) end
            self.built:Fire()
        end
        function Catalog:SetIncludedTypes(types) self._typeSet={}; for _,t in ipairs(types or {}) do self._typeSet[t]=true end end
        function Catalog:SetIncludedRarities(rarities) self._raritySet={}; for _,r in ipairs(rarities or {}) do self._raritySet[r]=true end end
        function Catalog:GetIncludedTypes() local o={}; for k in pairs(self._typeSet) do o[k]=true end; return o end
        function Catalog:GetIncludedRarities() local o={}; for k in pairs(self._raritySet) do o[k]=true end; return o end
        function Catalog:IsInCatalog(opts)
            opts=opts or {}; local t,n,item=opts.cosmeticType,opts.cosmeticName,opts.itemName
            if t=="Skin" then return self._lookupByType.Skin[item] and self._lookupByType.Skin[item][n] == true end
            return self._lookupByType[t] and self._lookupByType[t][n] == true
        end
        function Catalog:IsEmpty(itemName,t)
            local lookup=t=="Skin" and self._lookupByType.Skin[itemName] or self._lookupByType[t]
            return not lookup or next(lookup)==nil
        end
        function Catalog:IsCosmeticType(name,t) return self._typeByName[name]==t end

        local catalog=Catalog.new()
        catalog:SetIncludedTypes({"Skin","Wrap","Charm","Finisher"})
        catalog:Build()
        local cosmetics=tabList:newTab("Cosmetics")
        local cosmeticTabs=cosmetics:newTabList()
        local cosmeticsEngine=Cosmetics.new({catalog=catalog})

        local function copyList(source)
            local out={}; for i,v in ipairs(source or {}) do out[i]=v end; return out
        end
        local function refillDropdown(feature, options, emptyText)
            if not feature then return end
            for _,old in ipairs(feature.options or {}) do pcall(function() feature:remove(old) end) end
            if #options==0 then options={emptyText or "No items found"} end
            for _,v in ipairs(options) do pcall(function() feature:add(v) end) end
            pcall(function() feature:set(options[1]) end)
        end
        local function listFromSet(set)
            local out={}; for k in pairs(set or {}) do table.insert(out,k) end
            table.sort(out,function(a,b)return tostring(a):lower()<tostring(b):lower() end); return out
        end

        do
            local miscCosmetics=cosmeticTabs:newTab("Misc"):intoSections()
            local info=miscCosmetics:newSection("left","Catalog")
            info:newButton("cosmetics/catalog/refresh"):setLabel("Refresh Catalog")
            info:newToggle("cosmetics/runtime/enabled"):setLabel("Cosmetics Runtime")
            info:newToggle("cosmetics/skinchanger/enabled"):setLabel("Skin Changer")
            info:newLabel("cosmetics/catalog/types"):setLabel("Types: Skin, Wrap, Charm, Finisher")
            info:newLabel("cosmetics/catalog/source"):setLabel("Source: CosmeticLibrary (local)")
        end

        do
            local skinTab=cosmeticTabs:newTab("Skin"):intoSections()
            local section=skinTab:newSection("left","Skin Changer")
            local itemNames={}; local lib=catalog:_getLibrary(); local cosmeticsTable=lib and lib.Cosmetics
            if type(cosmeticsTable)=="table" then
                local seen={}
                for _,data in pairs(cosmeticsTable) do
                    if type(data)=="table" and data.Type=="Skin" and data.ItemName and not seen[data.ItemName] then seen[data.ItemName]=true; table.insert(itemNames,data.ItemName) end
                end
            end
            table.sort(itemNames,function(a,b)return tostring(a):lower()<tostring(b):lower() end)
            if #itemNames==0 then itemNames={"No items found"} end
            local skinItem=section:newDropdown("cosmetics/skin/item",false,itemNames):set(itemNames[1])
            local skinOptions={}
            if itemNames[1]~="No items found" then skinOptions=listFromSet(catalog._lookupByType.Skin[itemNames[1]]) end
            if #skinOptions==0 then skinOptions={"No skins found"} end
            local skinSelect=section:newDropdown("cosmetics/skin/selected",false,skinOptions):set(skinOptions[1])
            skinItem.changed:Connect(function(itemName)
                local opts=listFromSet(catalog._lookupByType.Skin[itemName]); refillDropdown(skinSelect,opts,"No skins found")
            end)
            skinSelect.changed:Connect(function(name)
                local item=skinItem.value
                if item and item~="No items found" and name and name~="No skins found" then cosmeticsEngine:SetSkinChangerChoice(item,{skin=name}) end
            end)
        end

        local function cosmeticSimpleTab(title, typeName)
            local tab=cosmeticTabs:newTab(title):intoSections()
            local section=tab:newSection("left",title)
            local opts=copyList(catalog._byType[typeName]); if #opts==0 then opts={"No items found"} end
            local select=section:newDropdown("cosmetics/"..string.lower(title).."/selected",false,opts):set(opts[1])
            select.changed:Connect(function(name)
                if name and name~="No items found" then
                    local item="Default"
                    local sel={}; sel[SLOT_KEYS[typeName]]=name
                    cosmeticsEngine:SetSkinChangerChoice(item,sel)
                end
            end)
            return tab
        end
        cosmeticSimpleTab("Wrap","Wrap")
        cosmeticSimpleTab("Charm","Charm")
        cosmeticSimpleTab("Finisher","Finisher")

        do
            local refresh=base.features["cosmetics/catalog/refresh"]
            if refresh then
                refresh.changed:Connect(function()
                    catalog:Build()
                    local skinFeature=base.features["cosmetics/skin/selected"]
                    if skinFeature then refillDropdown(skinFeature,copyList(catalog._byType.Skin),"No skins found") end
                    for _,pair in ipairs({{"cosmetics/wrap/selected","Wrap"},{"cosmetics/charm/selected","Charm"},{"cosmetics/finisher/selected","Finisher"}}) do
                        refillDropdown(base.features[pair[1]],copyList(catalog._byType[pair[2]]),"No items found")
                    end
                end)
            end
            local runtimeToggle=base.features["cosmetics/runtime/enabled"]
            if runtimeToggle then runtimeToggle.changed:Connect(function(v) cosmeticsEngine:SetRuntimeEnabled(v==true) end) end
            local skinToggle=base.features["cosmetics/skinchanger/enabled"]
            if skinToggle then skinToggle.changed:Connect(function(v) cosmeticsEngine:SetSkinChangerEnabled(v==true) end) end
        end

local rage = tabList:newTab("Rage"):intoSections()
        do
            local info = rage:newSection("left", "Rage")
            info:newToggle("main/rage/enabled"):setLabel("Enable Rage")
        end

        local settings= tabList:newTab("Settings"):intoSections()
        do
            local discord = settings:newSection("left", "Discord")
            do
                local DISCORD_INVITE = "https://discord.gg/WXCupTFwu5"
                local joinDiscord = discord:newButton("settings/discord/join"):setLabel("Join Discord")
                local copyInvite = discord:newButton("settings/discord/copy_invite"):setLabel("Copy Discord Invite")

                joinDiscord.changed:Connect(function()
                    if setclipboard then
                        pcall(setclipboard, DISCORD_INVITE)
                    elseif toclipboard then
                        pcall(toclipboard, DISCORD_INVITE)
                    end
                end)

                copyInvite.changed:Connect(function()
                    if setclipboard then
                        pcall(setclipboard, DISCORD_INVITE)
                    elseif toclipboard then
                        pcall(toclipboard, DISCORD_INVITE)
                    end
                end)
            end

            local menu = settings:newSection("left", "Menu")
            do
                menu:newLabel("settings/menu/label_accent"):setLabel("Accent"):newColorpicker("settings/menu/accent"):set({rgb = Color3.fromRGB(55, 175, 225), alpha = 1})
                menu:newLabel("settings/menu/label_font"):setLabel("Font")
                menu:newDropdown("settings/menu/font", false, {"SourceSans"}):set("SourceSans")
                menu:newSlider("settings/menu/text_size", 1, 26, 1):set(16):setLabel("Text Size")
                menu:newButton("settings/menu/unload"):setLabel("Unload")
                menu:newToggle("settings/menu/debug_mode"):setLabel("Debug Mode")
                menu:newToggle("settings/menu/keybind_menu"):setLabel("Keybind Menu")
                menu:newToggle("settings/menu/auto_reconnect"):setLabel("Auto Reconnect")
                menu:newToggle("settings/menu/auto_run_script"):setLabel("Auto Run Script")
                menu:newToggle("settings/menu/auto_load"):setLabel("Auto Load")
                menu:newLabel("settings/menu/label_keybind"):setLabel("Menu Keybind")
                    :newKeybind("settings/menu/menu_keybind", { "Tap" }):set({ key = Enum.KeyCode.RightShift, mode = "Tap" })
                    .activeChanged:Connect(function()
                        base:setVisible(not base.visible)
                    end)
            end

            local configuration = settings:newSection("right", "Configuration")
            do
                configuration:newTextBox("settings/config/name"):setLabel("Config Name")
                configuration:newButton("settings/config/create"):setLabel("Create")
                configList = configuration:newList("settings/config/list", 6, {})
                configList:add("default.json")
                configuration:newButton("settings/config/load"):setLabel("Load")
                configuration:newButton("settings/config/save"):setLabel("Save")
                configuration:newButton("settings/config/delete"):setLabel("Delete")
                configuration:newToggle("settings/config/auto_save"):setLabel("Auto Save To Config")
            end
        end
    
    
        -- ====================== HIT / KILL SOUNDS ======================
        -- Replace the game's matching Sound before playback. No Humanoid events,
        -- no RemoteEvent, no new Sound, and no direct :Play().

        local assetCache = {}
        local assetLoading = {}

        local HitSoundRules = {
            { ids = {17138490999}, url = "https://66mods-assets.pages.dev/repos/InventivetalentDev/minecraft-assets/assets/minecraft/sounds/random/successful_hit.ogg" },
            { ids = {138975587469438}, url = "https://66mods-assets.pages.dev/repos/66buncer/Rivals-Pack-Assets/sniper_candidate_enderdragon_hit.ogg" },
        }

        local KillSoundRules = {
            { ids = {15109829804}, url = "https://66mods-assets.pages.dev/repos/66buncer/Rivals-Pack-Assets/headshot_silverfish_kill.ogg" },
            { ids = {16530229616}, url = "https://66mods-assets.pages.dev/repos/66buncer/Rivals-Pack-Assets/kill1_zombie_hurt.ogg" },
            { ids = {16530229541}, url = "https://66mods-assets.pages.dev/repos/66buncer/Rivals-Pack-Assets/kill2_ghast_death.ogg" },
            { ids = {16530229695}, url = "https://66mods-assets.pages.dev/repos/66buncer/Rivals-Pack-Assets/kill3_wither_death.ogg" },
        }

        local function makeFileName(url)
            local hash = 2166136261
            for i = 1, #url do
                hash = bit32.bxor(hash, string.byte(url, i))
                hash = (hash * 16777619) % 4294967296
            end
            return "MinhoHub_Audio_" .. tostring(hash) .. ".ogg"
        end

        local function getAsset(url)
            if not url then return nil end
            if assetCache[url] then return assetCache[url] end
            if assetLoading[url] then
                local started = os.clock()
                while assetLoading[url] and os.clock() - started < 8 do task.wait() end
                return assetCache[url]
            end

            assetLoading[url] = true
            local result = nil
            pcall(function()
                local loader = getcustomasset or getsynasset
                if not (writefile and isfile and loader) then return end
                local fileName = makeFileName(url)
                if not isfile(fileName) then
                    local data = game:HttpGet(url)
                    if type(data) ~= "string" or #data <= 80 then return end
                    writefile(fileName, data)
                end
                local asset = loader(fileName)
                if type(asset) == "string" and asset ~= "" then result = asset end
            end)
            assetCache[url] = result
            assetLoading[url] = nil
            return result
        end

        local hitSoundToggle = base.features["world/sound/hit_enabled"]
        local killSoundToggle = base.features["world/sound/kill_enabled"]
        local hitSoundDropdown = base.features["world/sound/hit_sound"]
        local killSoundDropdown = base.features["world/sound/kill_sound"]
        local hitVolume = base.features["world/sound/hit_volume"]
        local killVolume = base.features["world/sound/kill_volume"]

        local HitIds, KillIds = {}, {}
        for _, rule in ipairs(HitSoundRules) do
            for _, id in ipairs(rule.ids) do HitIds[tostring(id)] = true end
        end
        for _, rule in ipairs(KillSoundRules) do
            for _, id in ipairs(rule.ids) do KillIds[tostring(id)] = true end
        end

        local function selectedUrl(category)
            if category == "hit" then
                local selected = hitSoundDropdown and hitSoundDropdown.value
                if selected == "Ender Dragon Hit" then return HitSoundRules[2].url end
                return HitSoundRules[1].url
            end
            local selected = killSoundDropdown and killSoundDropdown.value
            if selected == "Zombie Hurt" then return KillSoundRules[2].url end
            if selected == "Ghast Death" then return KillSoundRules[3].url end
            if selected == "Wither Death" then return KillSoundRules[4].url end
            return KillSoundRules[1].url
        end

        local function enabled(category)
            return category == "hit"
                and hitSoundToggle and hitSoundToggle.value
                or category == "kill" and killSoundToggle and killSoundToggle.value
        end

        local function categoryFromId(id)
            if HitIds[id] then return "hit" end
            if KillIds[id] then return "kill" end
            return nil
        end

        local replacing = setmetatable({}, {__mode = "k"})
        local watched = setmetatable({}, {__mode = "k"})
        local replacedCategory = setmetatable({}, {__mode = "k"})

        local function applyVolume(sound, category)
            local feature = category == "hit" and hitVolume or killVolume
            local value = feature and tonumber(feature.value) or 1
            pcall(function() sound.Volume = math.clamp(value, 0, 2) end)
        end

        local function tryReplace(sound)
            if replacing[sound] or not sound or not sound.Parent then return end
            local id = string.match(sound.SoundId or "", "%d+")
            local category = id and categoryFromId(id)
            if not category or not enabled(category) then return end

            -- IMPORTANT: this runs when the game assigns the original SoundId,
            -- before waiting for IsPlaying, so the current hit/kill playback uses
            -- the replacement instead of changing the Sound after it already started.
            local asset = getAsset(selectedUrl(category))
            if not asset then return end

            replacing[sound] = true
            pcall(function()
                sound.SoundId = asset
                replacedCategory[sound] = category
                applyVolume(sound, category)
            end)
            replacing[sound] = nil
        end

        local function watchSound(sound)
            if not sound or not sound:IsA("Sound") or watched[sound] then return end
            watched[sound] = true

            sound:GetPropertyChangedSignal("SoundId"):Connect(function()
                if not replacing[sound] then
                    tryReplace(sound)
                end
            end)

            -- Existing idle matching Sounds are prepared now. Sounds already playing
            -- are left alone, preventing replacement-triggered startup audio.
            if not sound.IsPlaying then
                tryReplace(sound)
            end
        end

        for _, obj in ipairs(game:GetDescendants()) do
            if obj:IsA("Sound") then watchSound(obj) end
        end

        game.DescendantAdded:Connect(function(obj)
            if obj:IsA("Sound") then
                task.defer(function()
                    if obj and obj.Parent then watchSound(obj) end
                end)
            end
        end)

        -- Changing dropdowns never plays or immediately rewrites active Sounds.
        -- The next time the game assigns a matching original SoundId, the new choice applies.

        if hitVolume then
            hitVolume.changed:Connect(function()
                for sound, category in pairs(replacedCategory) do
                    if category == "hit" and sound and sound.Parent then applyVolume(sound, category) end
                end
            end)
        end

        if killVolume then
            killVolume.changed:Connect(function()
                for sound, category in pairs(replacedCategory) do
                    if category == "kill" and sound and sound.Parent then applyVolume(sound, category) end
                end
            end)
        end

        -- ====================== WORLD MODIFIER ======================
        -- World runtime, based on the supplied World file.
        local Lighting = game:GetService("Lighting")
        local original = {
            Brightness = Lighting.Brightness,
            ExposureCompensation = Lighting.ExposureCompensation,
            Ambient = Lighting.Ambient,
            ClockTime = Lighting.ClockTime,
            GlobalShadows = Lighting.GlobalShadows,
            FogColor = Lighting.FogColor,
            FogStart = Lighting.FogStart,
            FogEnd = Lighting.FogEnd,
        }

        local World = {}

        function World.brightness(value)
            if type(value) ~= "number" then return end
            Lighting.Brightness = math.clamp(value, 0, 5)
        end
        function World.exposure(value)
            if type(value) ~= "number" then return end
            Lighting.ExposureCompensation = math.clamp(value, -2, 3)
        end
        function World.ambient(color)
            if typeof(color) ~= "Color3" then return end
            Lighting.Ambient = color
        end
        function World.removeShadows(bool)
            Lighting.GlobalShadows = not bool
        end
        function World.time(hour)
            if type(hour) ~= "number" then return end
            Lighting.ClockTime = math.clamp(hour, 0, 24)
        end
        function World.fog(color, startDist, endDist)
            if color then Lighting.FogColor = color end
            if startDist then Lighting.FogStart = math.clamp(startDist, 1, 5000) end
            if endDist then Lighting.FogEnd = math.clamp(endDist, 1, 5000) end
        end
        function World.fogStart(value)
            if type(value) ~= "number" then return end
            Lighting.FogStart = math.clamp(value, 1, 5000)
        end
        function World.fogEnd(value)
            if type(value) ~= "number" then return end
            Lighting.FogEnd = math.clamp(value, 1, 5000)
        end
        function World.fullBright()
            Lighting.Brightness = 5
            Lighting.ExposureCompensation = 1
            Lighting.Ambient = Color3.fromRGB(255, 255, 255)
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 100000
        end
        function World.nightVision()
            Lighting.Brightness = 5
            Lighting.Ambient = Color3.fromRGB(0, 255, 0)
            Lighting.ExposureCompensation = 2
            Lighting.FogColor = Color3.fromRGB(0, 100, 0)
        end
        function World.hellMode()
            Lighting.Ambient = Color3.fromRGB(150, 0, 0)
            Lighting.FogColor = Color3.fromRGB(255, 50, 0)
            Lighting.FogStart = 10
            Lighting.FogEnd = 300
            Lighting.Brightness = 2
        end
        function World.iceMode()
            Lighting.Ambient = Color3.fromRGB(100, 150, 255)
            Lighting.FogColor = Color3.fromRGB(200, 230, 255)
            Lighting.FogStart = 5
            Lighting.FogEnd = 150
            Lighting.Brightness = 3
        end
        function World.radioactive()
            Lighting.Ambient = Color3.fromRGB(0, 100, 0)
            Lighting.FogColor = Color3.fromRGB(100, 255, 0)
            Lighting.FogStart = 20
            Lighting.FogEnd = 400
            Lighting.Brightness = 1
        end
        function World.horror()
            Lighting.Brightness = 0
            Lighting.ClockTime = 0
            Lighting.Ambient = Color3.fromRGB(0, 0, 0)
            Lighting.FogColor = Color3.fromRGB(20, 20, 20)
            Lighting.FogStart = 1
            Lighting.FogEnd = 50
        end
        function World.night()
            Lighting.ClockTime = 0
            Lighting.Ambient = Color3.fromRGB(0, 0, 100)
            Lighting.FogColor = Color3.fromRGB(20, 20, 60)
            Lighting.Brightness = 1
        end
        function World.day()
            Lighting.ClockTime = 12
            Lighting.Brightness = 2
            Lighting.FogEnd = 100000
        end
        function World.restore()
            Lighting.Brightness = original.Brightness
            Lighting.ExposureCompensation = original.ExposureCompensation
            Lighting.Ambient = original.Ambient
            Lighting.ClockTime = original.ClockTime
            Lighting.GlobalShadows = original.GlobalShadows
            Lighting.FogColor = original.FogColor
            Lighting.FogStart = original.FogStart
            Lighting.FogEnd = original.FogEnd
        end
        pcall(function() getgenv().World = World end)

        local function feature(name) return base.features[name] end
        local brightnessToggle, brightnessValue = feature("world_brightness"), feature("world_brightness_value")
        local exposureToggle, exposureValue = feature("world_exposure"), feature("world_exposure_value")
        local timeToggle, timeValue = feature("world_time"), feature("world_time_value")
        local shadowsToggle = feature("remove_shadows")
        local ambientToggle, ambientColor = feature("world_ambient"), feature("world_ambient_color")
        local fogToggle, fogColor = feature("fog_changer"), feature("fog_color")
        local fogStartValue, fogEndValue = feature("fog_start"), feature("fog_end")

        -- Local Skybox runtime. The UI and state live in this file; nothing loads a UI from GitHub.
        local skyboxToggle = feature("world/skybox/enabled")
        local skyboxPreset = feature("world/skybox/preset")
        local skyboxOriginal = {}
        local skyboxObject = nil
        local skyboxCreated = false

        local SKYBOX_PRESETS = {
            Minecraft = {
                SkyboxBk = "rbxassetid://271042516", SkyboxDn = "rbxassetid://271077243",
                SkyboxFt = "rbxassetid://271042556", SkyboxLf = "rbxassetid://271042310",
                SkyboxRt = "rbxassetid://271042467", SkyboxUp = "rbxassetid://271077958",
            },
            Space = {
                SkyboxBk = "rbxassetid://159454299", SkyboxDn = "rbxassetid://159454296",
                SkyboxFt = "rbxassetid://159454293", SkyboxLf = "rbxassetid://159454286",
                SkyboxRt = "rbxassetid://159454300", SkyboxUp = "rbxassetid://159454288",
            },
            Night = {
                SkyboxBk = "rbxassetid://12064107", SkyboxDn = "rbxassetid://12064152",
                SkyboxFt = "rbxassetid://12064121", SkyboxLf = "rbxassetid://12063984",
                SkyboxRt = "rbxassetid://12064115", SkyboxUp = "rbxassetid://12064131",
            },
        }

        local function getSkybox()
            local existing = Lighting:FindFirstChildOfClass("Sky")
            if existing then
                return existing
            end
            local sky = Instance.new("Sky")
            sky.Name = "MinhoHubSkybox"
            sky.Parent = Lighting
            skyboxCreated = true
            return sky
        end

        local function captureSkybox(sky)
            if skyboxOriginal.Captured then return end
            skyboxOriginal.Captured = true
            skyboxOriginal.SkyboxBk = sky.SkyboxBk
            skyboxOriginal.SkyboxDn = sky.SkyboxDn
            skyboxOriginal.SkyboxFt = sky.SkyboxFt
            skyboxOriginal.SkyboxLf = sky.SkyboxLf
            skyboxOriginal.SkyboxRt = sky.SkyboxRt
            skyboxOriginal.SkyboxUp = sky.SkyboxUp
        end

        local function applySkybox()
            if not skyboxToggle or not skyboxPreset then return end
            if not skyboxToggle.value then
                if skyboxObject and skyboxObject.Parent then
                    if skyboxCreated then
                        skyboxObject:Destroy()
                    elseif skyboxOriginal.Captured then
                        skyboxObject.SkyboxBk = skyboxOriginal.SkyboxBk
                        skyboxObject.SkyboxDn = skyboxOriginal.SkyboxDn
                        skyboxObject.SkyboxFt = skyboxOriginal.SkyboxFt
                        skyboxObject.SkyboxLf = skyboxOriginal.SkyboxLf
                        skyboxObject.SkyboxRt = skyboxOriginal.SkyboxRt
                        skyboxObject.SkyboxUp = skyboxOriginal.SkyboxUp
                    end
                end
                skyboxObject = nil
                skyboxCreated = false
                return
            end

            local preset = skyboxPreset.value or "Default"
            local existing = Lighting:FindFirstChildOfClass("Sky")
            if existing and existing.Name ~= "MinhoHubSkybox" then
                captureSkybox(existing)
                skyboxObject = existing
            else
                skyboxObject = skyboxObject or getSkybox()
            end

            if preset == "Default" then
                if skyboxOriginal.Captured then
                    skyboxObject.SkyboxBk = skyboxOriginal.SkyboxBk
                    skyboxObject.SkyboxDn = skyboxOriginal.SkyboxDn
                    skyboxObject.SkyboxFt = skyboxOriginal.SkyboxFt
                    skyboxObject.SkyboxLf = skyboxOriginal.SkyboxLf
                    skyboxObject.SkyboxRt = skyboxOriginal.SkyboxRt
                    skyboxObject.SkyboxUp = skyboxOriginal.SkyboxUp
                elseif skyboxCreated then
                    skyboxObject:Destroy()
                    skyboxObject = nil
                    skyboxCreated = false
                end
                return
            end

            local data = SKYBOX_PRESETS[preset]
            if not data then return end
            for property, value in pairs(data) do
                skyboxObject[property] = value
            end
        end

        local function applyBrightness()
            if brightnessToggle.value then World.brightness(tonumber(brightnessValue.value) or original.Brightness)
            else Lighting.Brightness = original.Brightness end
        end
        local function applyExposure()
            if exposureToggle.value then World.exposure(tonumber(exposureValue.value) or original.ExposureCompensation)
            else Lighting.ExposureCompensation = original.ExposureCompensation end
        end
        local function applyTime()
            if timeToggle.value then World.time(tonumber(timeValue.value) or original.ClockTime)
            else Lighting.ClockTime = original.ClockTime end
        end
        local function applyShadows()
            World.removeShadows(shadowsToggle.value)
            if not shadowsToggle.value then Lighting.GlobalShadows = original.GlobalShadows end
        end
        local function applyAmbient()
            if ambientToggle.value and ambientColor.value then World.ambient(ambientColor.value.rgb)
            else Lighting.Ambient = original.Ambient end
        end
        local function applyFog()
            if fogToggle.value and fogColor.value then
                World.fog(fogColor.value.rgb, tonumber(fogStartValue.value), tonumber(fogEndValue.value))
            else
                Lighting.FogColor, Lighting.FogStart, Lighting.FogEnd = original.FogColor, original.FogStart, original.FogEnd
            end
        end

        brightnessToggle.changed:Connect(applyBrightness)
        brightnessValue.changed:Connect(applyBrightness)
        exposureToggle.changed:Connect(applyExposure)
        exposureValue.changed:Connect(applyExposure)
        timeToggle.changed:Connect(applyTime)
        timeValue.changed:Connect(applyTime)
        shadowsToggle.changed:Connect(applyShadows)
        ambientToggle.changed:Connect(applyAmbient)
        ambientColor.changed:Connect(applyAmbient)
        fogToggle.changed:Connect(applyFog)
        fogColor.changed:Connect(applyFog)
        fogStartValue.changed:Connect(applyFog)
        fogEndValue.changed:Connect(applyFog)
        if skyboxToggle and skyboxPreset then
            skyboxToggle.changed:Connect(applySkybox)
            skyboxPreset.changed:Connect(applySkybox)
        end

        task.defer(function()
            applyBrightness(); applyExposure(); applyTime(); applyShadows(); applyAmbient(); applyFog(); applySkybox()
        end)

        -- World Texture Pack
        -- Switches the map texture cleanly: restore the original first, then apply the new pack.
        local worldTextureToggle = base.features["world/texture_pack/enabled"]
        local worldTextureDropdown = base.features["world/texture_pack/pack"]

        local WORLD_TEXTURE_ID = "7658055825"

        local WORLD_TEXTURES = {
            Minecraft = "https://raw.githubusercontent.com/jixyuk12nh-maker/World/main/texture_pack/item_slot_3_blue_hollow.png",
            Grods = "https://raw.githubusercontent.com/jixyuk12nh-maker/World/main/texture_pack/grods.png",
        }

        local worldTextureCache = {}
        local worldTextureOriginals = {}
        local worldTextureTargets = {}

        local function getWorldTexture(url)
            if worldTextureCache[url] then
                return worldTextureCache[url]
            end

            local success, result = pcall(function()
                if writefile and isfile and getcustomasset then
                    local fileName = "minho_world_" .. tostring(#url % 1000000) .. ".png"

                    if not isfile(fileName) then
                        local data = game:HttpGet(url)
                        if data and #data > 80 then
                            writefile(fileName, data)
                        end
                    end

                    if isfile(fileName) then
                        local asset = getcustomasset(fileName)
                        if asset and asset ~= "" then
                            return asset
                        end
                    end
                end

                return url
            end)

            local asset = (success and result) or url
            worldTextureCache[url] = asset
            return asset
        end

        local function getWorldTextureProperty(obj)
            if obj:IsA("Decal") or obj:IsA("Texture") then
                return "Texture"
            elseif obj:IsA("MeshPart") then
                return "TextureID"
            end
            return nil
        end

        local function getWorldTextureId(value)
            if type(value) ~= "string" then
                return nil
            end
            return string.match(value, "%d+")
        end

        local function rememberWorldTextureTarget(obj, property, original)
            worldTextureOriginals[obj] = original
            worldTextureTargets[obj] = property
        end

        local function findWorldTextureTargets()
            for _, obj in ipairs(game:GetDescendants()) do
                local property = getWorldTextureProperty(obj)
                if property then
                    local success, value = pcall(function()
                        return obj[property]
                    end)

                    if success and type(value) == "string" then
                        -- Only register the actual map texture, not every Decal/Texture/MeshPart.
                        if getWorldTextureId(value) == WORLD_TEXTURE_ID then
                            if worldTextureOriginals[obj] == nil then
                                rememberWorldTextureTarget(obj, property, value)
                            end
                        end
                    end
                end
            end
        end

        local function restoreWorldTextures()
            for obj, original in pairs(worldTextureOriginals) do
                if obj and obj.Parent then
                    local property = worldTextureTargets[obj] or getWorldTextureProperty(obj)
                    if property then
                        pcall(function()
                            -- Remove the currently applied pack before restoring the original.
                            obj[property] = ""
                            obj[property] = original
                        end)
                    end
                end
            end
        end

        local function clearWorldTextureTracking()
            table.clear(worldTextureOriginals)
            table.clear(worldTextureTargets)
        end

        local function getSelectedWorldTexture()
            local selected = worldTextureDropdown and worldTextureDropdown.value or "Minecraft"
            if type(selected) == "table" then
                selected = selected[1]
            end
            return tostring(selected)
        end

        local function applyWorldTexture()
            if not worldTextureToggle or not worldTextureToggle.value then
                return
            end

            local selected = getSelectedWorldTexture()
            local url = WORLD_TEXTURES[selected] or WORLD_TEXTURES.Minecraft

            -- Download/load once BEFORE touching the map. This removes most of the visible delay.
            local asset = getWorldTexture(url)

            findWorldTextureTargets()

            for obj, property in pairs(worldTextureTargets) do
                if obj and obj.Parent then
                    pcall(function()
                        -- Clear the old texture first, then assign the newly selected texture.
                        obj[property] = ""
                        obj[property] = asset
                    end)
                end
            end
        end

        local function switchWorldTexture()
            if not worldTextureToggle or not worldTextureToggle.value then
                return
            end

            -- 1. Remove the currently applied texture and restore the original.
            restoreWorldTextures()
            clearWorldTextureTracking()

            -- 2. Load/apply the newly selected texture.
            applyWorldTexture()
        end

        if worldTextureToggle and worldTextureToggle.changed then
            worldTextureToggle.changed:Connect(function()
                if worldTextureToggle.value then
                    applyWorldTexture()
                else
                    restoreWorldTextures()
                    clearWorldTextureTracking()
                end
            end)
        end

        if worldTextureDropdown and worldTextureDropdown.changed then
            worldTextureDropdown.changed:Connect(function()
                if worldTextureToggle and worldTextureToggle.value then
                    switchWorldTexture()
                end
            end)
        end

        game.DescendantAdded:Connect(function(obj)
            if not worldTextureToggle or not worldTextureToggle.value then
                return
            end

            task.defer(function()
                local property = getWorldTextureProperty(obj)
                if not property then
                    return
                end

                local success, value = pcall(function()
                    return obj[property]
                end)

                if not success or type(value) ~= "string" then
                    return
                end

                if getWorldTextureId(value) == WORLD_TEXTURE_ID then
                    if worldTextureOriginals[obj] == nil then
                        rememberWorldTextureTarget(obj, property, value)
                    end

                    local selected = getSelectedWorldTexture()
                    local url = WORLD_TEXTURES[selected] or WORLD_TEXTURES.Minecraft
                    local asset = getWorldTexture(url)

                    pcall(function()
                        obj[property] = ""
                        obj[property] = asset
                    end)
                end
            end)
        end)

        local nameBox = base.features["settings/config/name"]
        local createButton = base.features["settings/config/create"]
        local loadButton = base.features["settings/config/load"]
        local saveButton = base.features["settings/config/save"]
        local deleteButton = base.features["settings/config/delete"]
        local autoSaveToggle = base.features["settings/config/auto_save"]
        local configList = base.features["settings/config/list"]

        local selectedConfig = "default.json"
        local knownConfigs = {}

        -- Normalize names so "KK" becomes "KK.json" exactly once.
        local function configName(name)
            name = tostring(name or "")
            name = name:gsub("%.json$", "")
            name = name:gsub("[^%w%._%-]", "")
            name = name:gsub("%.json$", "")
            if name == "" then name = "default" end
            return name .. ".json"
        end

        local function configPath(name)
            return CONFIG_DIR .. configName(name)
        end

        local function addConfigToList(filename)
            filename = configName(filename)
            if knownConfigs[filename] then return end
            knownConfigs[filename] = true
            if configList and configList.add then
                pcall(function() configList:add(filename) end)
            end
        end

        local function getSelectedConfig()
            local value = configList and configList.value
            if type(value) == "table" then value = value[1] end
            if value and tostring(value) ~= "" then return configName(value) end
            return selectedConfig
        end

        local function saveConfig(name)
            if not writefile then return false end
            local filename = configName(name)
            local ok = pcall(function()
                writefile(configPath(filename), base:encodeJSON())
            end)
            if ok then
                selectedConfig = filename
                addConfigToList(filename)
            end
            return ok
        end

        local function loadConfig(name)
            if not readfile or not isfile then return false end
            local filename = configName(name)
            local path = configPath(filename)
            if not isfile(path) then return false end
            local ok = pcall(function()
                base:decodeJSON(readfile(path))
            end)
            if ok then
                selectedConfig = filename
                addConfigToList(filename)
            end
            return ok
        end

        -- Load existing .json configs into the list on startup.
        addConfigToList("default.json")
        if listfiles then
            pcall(function()
                for _, path in ipairs(listfiles(CONFIG_DIR)) do
                    local filename = tostring(path):match("([^/\\]+)$")
                    if filename and filename:match("%.json$") then
                        addConfigToList(filename)
                    end
                end
            end)
        end

        createButton.changed:Connect(function()
            local rawName = tostring(nameBox.value or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if rawName == "" then return end
            saveConfig(configName(rawName))
        end)

        saveButton.changed:Connect(function()
            local rawName = tostring(nameBox.value or ""):gsub("^%s+", ""):gsub("%s+$", "")
            saveConfig(rawName ~= "" and rawName or selectedConfig)
        end)

        loadButton.changed:Connect(function()
            loadConfig(getSelectedConfig())
        end)

        deleteButton.changed:Connect(function()
            -- Always keep at least one config in the list.
            local configCount = 0
            for _ in pairs(knownConfigs) do
                configCount += 1
            end

            if configCount <= 1 then
                return
            end

            local filename = getSelectedConfig()
            if delfile and isfile and isfile(configPath(filename)) then
                pcall(delfile, configPath(filename))
            end
            if configList and configList.remove then
                pcall(function() configList:remove(filename) end)
            end
            knownConfigs[filename] = nil
            if selectedConfig == filename then
                selectedConfig = "default.json"
            end
        end)

        for flag, feature in next, base.features do
            if flag ~= "settings/config/auto_save"
                and feature.changed
                and feature.changed.Connect then
                feature.changed:Connect(function()
                    if autoSaveToggle.value then
                        saveConfig(selectedConfig)
                    end
                end)
            end
        end
    end

    -- Live Settings: default text size 16, original blue accent.
    local originalAccent = Color3.fromRGB(55, 175, 225)
    local currentAccent = originalAccent

    local function applyMenuSettings()
        local accentFeature = base.features["settings/menu/accent"]
        local sizeFeature = base.features["settings/menu/text_size"]
        local accent = originalAccent
        if accentFeature and accentFeature.value and accentFeature.value.rgb then
            accent = accentFeature.value.rgb
        end
        local textSize = math.clamp(tonumber(sizeFeature and sizeFeature.value) or 16, 1, 26)
        local gui = base.instances.gui
        if not gui then return end

        local objects = {gui}
        for _, obj in ipairs(gui:GetDescendants()) do
            table.insert(objects, obj)
        end
        for _, obj in ipairs(objects) do
            if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                obj.TextSize = textSize
                if obj.TextColor3 == currentAccent or obj.TextColor3 == originalAccent then
                    obj.TextColor3 = accent
                end
            elseif obj:IsA("Frame") then
                if obj.BackgroundColor3 == currentAccent or obj.BackgroundColor3 == originalAccent then
                    obj.BackgroundColor3 = accent
                end
            elseif obj:IsA("ScrollingFrame") then
                if obj.ScrollBarImageColor3 == currentAccent or obj.ScrollBarImageColor3 == originalAccent then
                    obj.ScrollBarImageColor3 = accent
                end
            end
        end
        currentAccent = accent
    end

    if base.features["settings/menu/accent"] then
        base.features["settings/menu/accent"].changed:Connect(applyMenuSettings)
    end
    if base.features["settings/menu/text_size"] then
        base.features["settings/menu/text_size"].changed:Connect(applyMenuSettings)
    end
    task.defer(applyMenuSettings)


    -- ═══════════════════════════════════════════════════
    -- Crosshair / HUD runtime
    -- ═══════════════════════════════════════════════════
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local LocalPlayer = Players.LocalPlayer

    local function getFeature(name)
        return base.features and base.features[name] or nil
    end

    local function getValue(name, fallback)
        local feature = getFeature(name)
        if not feature then return fallback end
        local value = feature.value
        if value == nil then return fallback end
        return value
    end

    local function safeDrawing(kind)
        if not Drawing or type(Drawing.new) ~= "function" then return nil end
        local ok, object = pcall(Drawing.new, kind)
        if ok then return object end
        return nil
    end

    local crosshairDrawings = {}
    for i = 1, 4 do
        local line = safeDrawing("Line")
        local outline = safeDrawing("Line")
        if line then
            line.Thickness = 1
            line.Visible = false
        end
        if outline then
            outline.Thickness = 3
            outline.Color = Color3.new(0,0,0)
            outline.Visible = false
        end
        crosshairDrawings[i] = {line, outline}
    end

    local function hideCrosshair()
        for _, pair in ipairs(crosshairDrawings) do
            if pair[1] then pair[1].Visible = false end
            if pair[2] then pair[2].Visible = false end
        end
    end

    local function getCrosshairLocation()
        local mode = getValue("drawing_crosshair_location", "Mouse")
        local camera = workspace.CurrentCamera
        if not camera then return nil end
        if mode == "Center" then
            return camera.ViewportSize / 2
        end
        local mouse = UserInputService:GetMouseLocation()
        return Vector2.new(mouse.X, mouse.Y)
    end

    local spinAngle = 0
    local crosshairConnection
    crosshairConnection = RunService.RenderStepped:Connect(function(dt)
        local ok = pcall(function()
            local toggle = getFeature("hud/crosshair")
            if not toggle or not toggle.value or not Drawing then
                hideCrosshair()
                return
            end

            local location = getCrosshairLocation()
            if not location then hideCrosshair() return end

            local length = getValue("drawing_crosshair_length", 5) * 5
            local gap = getValue("drawing_crosshair_gap", 5)
            local spinning = getValue("drawing_crosshair_spin", false)
            local speed = getValue("drawing_crosshair_speed", 5)
            spinAngle = spinning and (spinAngle + math.rad((speed * 5) * dt)) or 0

            local colorFeature = getFeature("hud/crosshair_color")
            local customColor = colorFeature and colorFeature.value and colorFeature.value.rgb or Color3.new(1,1,1)
            local angles = {0.0, math.pi/2, math.pi, math.pi*1.5}
            local rainbowTime = os.clock() * math.max(0.1, speed * 0.45)

            for i = 1, 4 do
                local line, outline = crosshairDrawings[i][1], crosshairDrawings[i][2]
                if line and outline then
                    local dir = Vector2.new(math.cos(spinAngle + angles[i]), math.sin(spinAngle + angles[i]))
                    line.From = location + dir * gap
                    line.To = line.From + dir * length
                    line.Color = Color3.fromHSV((rainbowTime + (i - 1) * 0.25) % 1, 1, 1)
                    outline.From = location + dir * math.max(0, gap - 1)
                    outline.To = outline.From + dir * (length + 1)
                    line.Visible = true
                    outline.Visible = true
                end
            end
        end)
        if not ok then hideCrosshair() end
    end)

    -- Watermark: editable text, based on the supplied HUD behavior.
    local watermarkDrawings = {}
    if Drawing then
        local text = safeDrawing("Text")
        if text then
            text.Text = "mihno.win"
            text.Size = 14
            text.Font = 2
            text.Color = Color3.fromRGB(226,226,226)
            text.Outline = true
            text.Center = true
            text.Visible = false
            watermarkDrawings = {text}
        end
    end

    local function updateWatermark()
        local toggle = getFeature("hud/watermark")
        local drawing = watermarkDrawings[1]
        if not toggle or not toggle.value or not drawing then
            if drawing then drawing.Visible = false end
            return
        end

        local camera = workspace.CurrentCamera
        if not camera then drawing.Visible = false return end

        local location = getValue("watermark_location", "Center")
        local pos = camera.ViewportSize / 2
        if location == "Mouse" then
            local m = UserInputService:GetMouseLocation()
            pos = Vector2.new(m.X, m.Y)

        pos += Vector2.new(getValue("watermark_x_offset", 0), getValue("watermark_y_offset", 0))
        local customText = getValue("watermark_text", "mihno.win")
        customText = tostring(customText or "mihno.win")
        if customText == "" then customText = "mihno.win" end
        drawing.Text = customText
        drawing.Position = pos
        drawing.Visible = true
    end

    RunService.RenderStepped:Connect(function()
        pcall(updateWatermark)
    end)

    base:Finish()
    local unload = base.features["settings/menu/unload"]
    if unload then
        unload.changed:Connect(function()
            if base.instances.gui then
                base.instances.gui:Destroy()
            end
            base.visible = false
        end)
    end
end
