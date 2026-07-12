local tween = require("lui.tween")
local ui = require("lui.ui")

local function testUi()
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

		-- gridLayout = ui.createElement("UIGridLayout", {
		-- 	tileSize = { 0, 80, 0, 80 },
		-- 	horizontalFlex = true,
		-- 	verticalFlex = true,
		-- }),

		-- scale = ui.createElement("UIScale", {
		-- 	scale = 2,
		-- }),

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

	tween.create(frame, { position = { 0, 10, 1, -10 } }, tween.easings.easeOutQuad, 1)
end

function love.mousepressed(x, y)
    ui.mouseActivated(x, y, true)
end

function love.mousemoved(x, y)
    ui.mouseMoved(x, y, true)
end

function love.load()
	testUi()
end

function love.update(dt)
	tween.update()
    ui.update()
end

function love.draw()
    ui.draw()
end