# lui
retained container ui system thats based off of roblox i guess

## contributing
* will be accepting pull requests, make sure that your pull requests are concise please

## features
* mouse actions (activated, mouseEnter, mouseLeave)
* ui constraints (padding, scale, list layout, grid layout)
* primitives (frames, text labels, image labels)
* tweening

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
		visible = false,
	}),

	scale = ui.createElement("UIScale", {
    	scale = 2,
		visible = true, -- could be false if you want to ignore this
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
