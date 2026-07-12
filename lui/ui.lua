local Freelist = {}
local Drawlist = {}
local Defers = {}

local clear = require("table.clear")
local bvh = require("lui.bvh")

local ElementsInMouse = {}
local VectorTemp = { 0, 0 }
local Broadphase = bvh.new()

local Elements = {{
	-- gui root
	absolutePosition = { 0, 0 },
	absoluteSize = { 800, 600 },
	children = 0,
	sibling = 0,
	kind = 0,
	id = 1,
}}

local ELEMENT_KEYMAP = {
	-- use this so we don't have to
	-- do a dynamic string hash
	Root = 0,
	Frame = 1,
	TextLabel = 2,
	ImageLabel = 3,
	UIScale = 4,
	UIListLayout = 5,
	UIAspectRatioConstraint = 6,
	UIGridLayout = 7,
	UIPadding = 8,
}

local function getChildren(element)
	local child = element.children
	if child == 0 then
		return { 0 }
	end

	local children = {}
	local index = child

	while index ~= 0 do
		local child = Elements[index]
		index = child.sibling

		if child.position then
			table.insert(children, child)
		end
	end

	return children
end

local function iterate(element, callback)
	local index = element.children
	while index ~= 0 do
		local child = Elements[index]
		index = child.sibling
		callback(child)
	end
end

local function updateGenericLayout(element)
	local parent = Elements[element.parent]
	local px, py = parent.absolutePosition[1], parent.absolutePosition[2]
	local sx, sy = parent.absoluteSize[1], parent.absoluteSize[2]
	local ax, ay = element.anchorPoint[1], element.anchorPoint[2]

	element.absoluteSize[1] = sx * element.size[1] + element.size[2]
	element.absoluteSize[2] = sy * element.size[3] + element.size[4]
	element.absolutePosition[1] = px + sx * element.position[1] + element.position[2] - element.absoluteSize[1] * ax
	element.absolutePosition[2] = py + sy * element.position[3] + element.position[4] - element.absoluteSize[2] * ay

	if element.bvh then
		-- update its position in the bvh if necessary :3
		VectorTemp[1], VectorTemp[2] = element.absolutePosition[1] + element.absoluteSize[1],
			element.absolutePosition[2] + element.absoluteSize[2]
		Broadphase:update(element.bvh, element.absolutePosition, VectorTemp)
	end
end

local Validation = {
	[ELEMENT_KEYMAP.Frame] = function(element)
		element.position = element.position or { 0, 0, 0, 0 }
		element.rotation = element.rotation or 0
		element.size = element.size or { 0, 1, 0, 1 }
		element.anchorPoint = element.anchorPoint or { 0, 0 }
		element.backgroundColor = element.backgroundColor or { 1, 1, 1, 1 }

		if element.borderSizePixel then
			element.borderColor = element.borderColor or { 0, 0, 0, 1 }
		end
	end,

	[ELEMENT_KEYMAP.ImageLabel] = function(element)
		element.position = element.position or { 0, 0, 0, 0 }
		element.rotation = element.rotation or 0
		element.size = element.size or { 0, 1, 0, 1 }
		element.anchorPoint = element.anchorPoint or { 0, 0 }
		element.imageColor = element.imageColor or { 1, 1, 1, 1}

		assert(element.image, "imageLabel(): element must have an image!")
		element.imageSize = { element.image:getDimensions() }
	end,

	[ELEMENT_KEYMAP.TextLabel] = function(element)
		element.text = element.text or "Text"
		element.position = element.position or { 0, 0, 0, 0 }
		element.rotation = element.rotation or 0
		element.size = element.size or { 0, 1, 0, 1 }
		element.anchorPoint = element.anchorPoint or { 0, 0 }
		element.textColor = element.textColor or { 1, 1, 1, 1 }
		element.font = love.graphics.newFont(32)
		assert(element.alignment, "textLabel(): element alignment must be left, right, center")
	end,

	[ELEMENT_KEYMAP.UIScale] = function(element)
		assert(element.scale, "uiScale(): element must have a scale field!")
	end,

	[ELEMENT_KEYMAP.UIListLayout] = function(element)
		assert(element.horizontalFlex ~= nil, "uiListLayout(): element must have the `horizontalFlex` field!")
		assert(element.verticalFlex ~= nil, "uiListLayout(): element must have the `verticalFlex` field!")
	end,

	[ELEMENT_KEYMAP.UIGridLayout] = function(element)
		assert(element.horizontalFlex ~= nil, "uiGridLayout(): element must have the `horizontalFlex` field!")
		assert(element.verticalFlex ~= nil, "uiGridLayout(): element must have the `verticalFlex` field!")
		assert(element.tileSize ~= nil, "uiGridLayout(): element must have the `tileSize` field!")
	end,

	[ELEMENT_KEYMAP.UIPadding] = function(element)
		element.left = element.left or { 0, 0 }
		element.right = element.right or { 0, 0 }
		element.up = element.up or { 0, 0 }
		element.down = element.down or { 0, 0 }
	end,
}

local Drawable = {
	[ELEMENT_KEYMAP.Frame] = function(element)
		love.graphics.setColor(element.backgroundColor)
		love.graphics.rectangle(
			"fill",
			element.absolutePosition[1], element.absolutePosition[2],
			element.absoluteSize[1], element.absoluteSize[2]
		)

		if element.borderSizePixel then
			love.graphics.setColor(element.borderColor)
			love.graphics.rectangle(
				"line",
				element.absolutePosition[1], element.absolutePosition[2],
				element.absoluteSize[1], element.absoluteSize[2]
			)
		end
	end,

	[ELEMENT_KEYMAP.TextLabel] = function(element)
		love.graphics.setFont(element.font)
		love.graphics.setColor(element.textColor)
		love.graphics.printf(
			element.text,
			element.absolutePosition[1],
			element.absolutePosition[2],
			element.absoluteSize[1],
			element.alignment
		)
	end,

	[ELEMENT_KEYMAP.ImageLabel] = function(element)
		love.graphics.setColor(element.imageColor)
		love.graphics.draw(
			element.image,
			element.absolutePosition[1],
			element.absolutePosition[2],
			element.rotation,
			element.absoluteSize[1] / element.imageSize[1],
			element.absoluteSize[2] / element.imageSize[2]
		)
	end,
}

local Priorities = {
	[ELEMENT_KEYMAP.UIScale] = -1,
	[ELEMENT_KEYMAP.UIPadding] = -2,
	[ELEMENT_KEYMAP.UIGridLayout] = -3,
	[ELEMENT_KEYMAP.UIListLayout] = -3,
}

local Constraints = {
	[ELEMENT_KEYMAP.Root] = function() end,
	[ELEMENT_KEYMAP.TextLabel] = updateGenericLayout,
	[ELEMENT_KEYMAP.ImageLabel] = updateGenericLayout,
	[ELEMENT_KEYMAP.Frame] = updateGenericLayout,

	[ELEMENT_KEYMAP.UIScale] = function(element)
		local parent = Elements[element.parent]
		assert(parent, "uiScale(): ui scale parent is nil")

		parent.absoluteSize[1] = parent.absoluteSize[1] * element.scale
		parent.absoluteSize[2] = parent.absoluteSize[2] * element.scale
	end,

	[ELEMENT_KEYMAP.UIPadding] = function(element)
		local parent = Elements[element.parent]
		assert(parent, "uiGridLayout(): ui padding parent is nil")

		local w, h = parent.absoluteSize[1], parent.absoluteSize[2]
		local bottomPad = h * element.down[1] + element.down[2]
		local rightPad = w * element.right[1] + element.right[2]
		local leftPad = w * element.left[1] + element.left[2]
		local topPad = h * element.up[1] + element.up[2]

		parent.absoluteSize[1] = parent.absoluteSize[1] - leftPad - rightPad
		parent.absoluteSize[2] = parent.absoluteSize[2] - bottomPad - topPad
		parent.absolutePosition[1] = parent.absolutePosition[1] + leftPad
		parent.absolutePosition[2] = parent.absolutePosition[2] + topPad

		table.insert(Defers, function()
			updateGenericLayout(parent)
		end)
	end,

	[ELEMENT_KEYMAP.UIGridLayout] = function(element)
		local parent = Elements[element.parent]
		assert(parent, "uiGridLayout(): ui grid layout parent is nil")

		local w, h = parent.absoluteSize[1], parent.absoluteSize[2]
		local sx, sy = element.tileSize[1] * w + element.tileSize[2], element.tileSize[3] * h + element.tileSize[4]

		local children = getChildren(parent)
		table.sort(children, function(a, b)
			return a.layoutOrder < b.layoutOrder
		end)

		local dx, dy = element.horizontalFlex and 1 or 0, element.verticalFlex and 1 or 0
		dy = dx ~= 0 and 0 or dy

		local cx, cy = 0, 0
		for i, child in ipairs(children) do
			child.position = { 0, cx, 0, cy }
			child.size = { 0, sx, 0, sy }

			cx = cx + sx * dx
			if cx > w then
				cx = 0
				cy = cy + sy
			end

			cy = cy + sy * dy
			if cy > h then
				cy = 0
				cx = cx + sx
			end

			updateGenericLayout(child)
		end
	end,

	[ELEMENT_KEYMAP.UIListLayout] = function(element)
		local parent = Elements[element.parent]
		assert(parent, "uiListLayout(): ui list layout parent is nil")

		local children = getChildren(parent)
		table.sort(children, function(a, b)
			return a.layoutOrder < b.layoutOrder
		end)

		local w, h = parent.absoluteSize[1], parent.absoluteSize[2]
		local dx, dy = element.horizontalFlex and 1 or 0, element.verticalFlex and 1 or 0
		local cx, cy = 0, 0

		for i, child in ipairs(children) do
			child.position = { 0, cx, 0, cy }
			cx = cx + child.absoluteSize[1] * dx
			if cx > w then
				cx = 0
				cy = cy + child.absoluteSize[2]
			end

			cy = cy + child.absoluteSize[2] * dy
			if cy > h then
				cy = 0
				cx = cx + child.absoluteSize[1]
			end
		end
	end,
}

local function destroy(element)
	assert(element.parent ~= 0, "destroy(): element is an orphan!")

	-- farewell element
	local sibling = Elements[element.parent].sibling
	while sibling ~= 0 do
		local current = Elements[sibling]
		if current.id == element.id then
			current.sibling = element.sibling
			table.insert(Freelist, element.id)
			break
		end

		sibling = current.sibling
	end

	-- Add everyone else lol
	local stack = { element.id }
	while #stack ~= 0 do
		local currentId = table.remove(stack)
		local element = Elements[currentId]

		local sibling = element.sibling
		local children = element.children

		if element.bvh then
			Broadphase:delete(element.bvh)
		end

		if children ~= 0 then
			table.insert(Freelist, children)
			table.insert(stack, children)
		end

		if sibling ~= 0 then
			table.insert(Freelist, sibling)
			table.insert(stack, sibling)
		end
	end
end

local function getFreeId()
	return table.remove(Freelist) or #Elements + 1
end

local function isActive(props)
	return props.activated or props.mouseEnter or props.mouseLeave
end

local function setParent(element, parent)
	element.parent = parent and parent.id or 0
	if not parent then
		return
	elseif parent.children == 0 then
		parent.children = element.id
	else
		element.sibling = parent.children
		parent.children = element.id
	end
end

local function createElement(kind, props, children, parent)
	props.kind = assert(ELEMENT_KEYMAP[kind], "createElement(): element " .. kind .. " does not exist.")

	-- Sibling and absolute stuff
	local id = getFreeId()
	props.Destroy = destroy

	-- Defaults
	props.layoutOrder = props.layoutOrder or 0
	props.children = 0
	props.sibling = 0
	props.parent = parent and parent.id or 0
	props.absolutePosition = { 0, 0 }
	props.absoluteSize = { 0, 0 }
	props.id = id

	Validation[props.kind](props)
	Elements[id] = props

	if isActive(props) then
		props.bvh = Broadphase:insert(id, { 0, 0 }, { 0, 0 })
		props.selection = props.selection or {
			left = nil,
			right = nil,
			up = nil,
			down = nil,
		}
	end

	if parent then
		setParent(props, parent)
	end

	if not children then
		return props
	end

	-- Turn into a list
	local list = {}
	for i, child in pairs(children) do
		table.insert(list, child)
	end

	-- Sort in descending order (our insertion is reversed)
	table.sort(list, function(a, b)
		return (Priorities[a.kind] or a.layoutOrder) > (Priorities[b.kind] or b.layoutOrder)
	end)

	for _, child in ipairs(list) do
		setParent(child, props)
	end

	return props
end

local function update(id)
	table.clear(Drawlist)
	table.clear(Defers)
	id = id or 1

	-- Do this in BFS because it has better
	-- cache locality compared to DFS
	local cursor = 1
	local stack = { id }
	while stack[cursor] do
		local id = stack[cursor]
		cursor = cursor + 1

		local current = Elements[id]
		if current.children ~= 0 then
			table.insert(stack, current.children)
		end

		if current.sibling ~= 0 then
			table.insert(stack, current.sibling)
		end

		if Drawable[current.kind] then
			table.insert(Drawlist, id)
		end

		Constraints[current.kind](current)
	end

	for i, defer in ipairs(Defers) do
		defer()
	end
end

local function setViewportSize(width, height)
	Elements[1].absolutePosition = { 0, 0 }
	Elements[1].absoluteSize = { width, height }
end

local function draw()
	love.graphics.reset()
	for i, id in ipairs(Drawlist) do
		local element = Elements[id]
		Drawable[element.kind](element)
	end
end

local function loadFont(name, size)
	if name == "default" then
		return love.graphics.newFont(size)
	else
		return love.graphics.newFont(name, size)
	end
end

local function mouseMoved(x, y, arg)
	VectorTemp[1], VectorTemp[2] = x, y

	local previousElements = ElementsInMouse
	ElementsInMouse = {}

	Broadphase:query(VectorTemp, VectorTemp, function(id)
		local stable = Broadphase:getUserdata(id)
		local element = Elements[stable]
		previousElements[stable] = nil
		ElementsInMouse[stable] = true

		if element.mouseEnter and not element.mouseInFrame then
			element.mouseInFrame = true
			element.mouseEnter(x, y, arg)
		end
	end)

	for previousId in pairs(previousElements) do
		local element = Elements[previousId]
		element.mouseInFrame = false

		if element.mouseLeave then
			element.mouseLeave(x, y, arg)
		end
	end
end

local function mouseActivated(x, y, arg)
	VectorTemp[1], VectorTemp[2] = x, y
	Broadphase:query(VectorTemp, VectorTemp, function(id)
		local element = Elements[Broadphase:getUserdata(id)]
		if element.activated then
			element.activated(x, y, arg)
		end
	end)
end

return {
	-- state
	setViewportSize = setViewportSize,
	setParent = setParent,
	loadFont = loadFont,

	-- events
	mouseActivated = mouseActivated,
	mouseMoved = mouseMoved,

	-- helpers
	createElement = createElement,
	destroy = destroy,
	iterate = iterate,
	root = Elements[1],
	
	-- core ui loop
	update = update,
	draw = draw,
}
