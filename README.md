# lui
retained container ui system

## features
* buttons, ui constraints, primitives (frames, text labels, image labels)
* tweening

## properties
* anchorPoint: where the center of an element should be, e.g: anchorPoint = { 0.5, 0.5 } (at the cener)
* size: { scaleX, offsetX, scaleY, offsetY }, scale is usually from 0..1, offset is in pixels
* position: { scaleX, offsetX, scaleY, offsetY }

## example
```lua
local frame = ui.createElement("Frame", {
	position = { 0, 0, 2, 0 },
	size = { 0, 400, 0, 300 },
	anchorPoint = { 0, 1 },

	backgroundColor = { 1, 1, 1, 0.2 },
	borderSizePixel = 3,
}, {
	padding = ui.createElement("UIPadding", {
		left = { 0, 16 },
		right = { 0, 16 },
		up = { 0, 16 },
		down = { 0, 16 },
	}),

	listLayout = ui.createElement("UIListLayout", {
    horizontalFlex = false,
    verticalFlex = true,
	}),

	gridLayout = ui.createElement("UIGridLayout", {
    tileSize = { 0, 80, 0, 80 },
    horizontalFlex = true,
    verticalFlex = true,
	}),

	scale = ui.createElement("UIScale", {
    scale = 2,
	}),

	image = ui.createElement("ImageLabel", {
		position = { 0, 0, 0.5, 0 },
		size = { 0, 200, 0, 200 },
		image = love.graphics.newImage("assets/test.png"),
		layoutOrder = 1,

		activated = function()
			print("activated")
		end,

		mouseEnter = function()
			print("mouse enter")
		end,

		mouseLeave = function()
			print("mouse leave")
		end,
	}),

	textLabel = ui.createElement("TextLabel", {
		position = { 0, 0, 0, 0 },
		size = { 1, 0, 0.25, 0 },
		anchorPoint = { 0, 0 },

		textColor = { 1, 1, 1, 1 },
		text = "hello, world!",
		alignment = "left",
		font = ui.loadFont("default", 32),
		layoutOrder = 0,
	}),
}, ui.root)
```

<img width="624" height="459" alt="image" src="https://github.com/user-attachments/assets/24355a87-7313-44c9-857c-cf268868b11a" />
