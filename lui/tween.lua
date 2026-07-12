local Tweens = {}

local new = require("table.new")

local PI = math.pi
local c1 = 1.70158
local c2 = c1 * 1.525
local c3 = c1 + 1
local c4 = (2 * PI) / 3
local c5 = (2 * PI) / 4.5

local function bounceOut(x)
	local n1 = 7.5625
	local d1 = 2.75

	if x < (1.0 / d1) then
		return n1 * x * x
	elseif x < (2.0 / d1) then
		x = x - 1.5 / d1
		return n1 * x * x + 0.75
	elseif x < (2.5 / d1) then
		x = x - 2.25 / d1
		return n1 * x * x + 0.9375
	else
		x = x - 2.625 / d1
		return n1 * x * x + 0.984375
	end
end

local easings = {
	constant = function(x)
		return x > 0.99 and 1.0 or 0.0
	end,

	linear = function(x)
		return x
	end,

	easeInQuad = function(x)
		return x * x
	end,

	easeOutQuad = function(x)
		return 1 - (1 - x) * (1 - x)
	end,

	easeInOutQuad = function(x)
		return x < 0.5 and 2 * x * x or 1 - math.pow(-2 * x + 2, 2) / 2
	end,

	easeInCubic = function(x)
		return x * x * x
	end,

	easeOutCubic = function(x)
		return 1 - math.pow(1 - x, 3)
	end,

	easeInOutCubic = function(x)
		return x < 0.5 and 4 * x * x * x or 1 - math.pow(-2 * x + 2, 3) / 2
	end,

	easeInQuart = function(x)
		return x * x * x * x
	end,

	easeOutQuart = function(x)
		return 1 - math.pow(1 - x, 4)
	end,

	easeInOutQuart = function(x)
		return x < 0.5 and 8 * x * x * x * x or 1 - math.pow(-2 * x + 2, 4) / 2
	end,

	easeInQuint = function(x)
		return x * x * x * x * x
	end,

	easeOutQuint = function(x)
		return 1 - math.pow(1 - x, 5)
	end,

	easeInOutQuint = function(x)
		return x < 0.5 and 16 * x * x * x * x * x or 1 - math.pow(-2 * x + 2, 5) / 2
	end,

	easeInSine = function(x)
		return 1 - math.cos((x * PI) / 2)
	end,

	easeOutSine = function(x)
		return math.sin((x * PI) / 2)
	end,

	easeInOutSine = function(x)
		return -(math.cos(PI * x) - 1) / 2
	end,

	easeInExpo = function(x)
		return x == 0 and 0 or math.pow(2, 10 * x - 10)
	end,

	easeOutExpo = function(x)
		return x == 1 and 1 or 1 - math.pow(2, -10 * x)
	end,

	easeInOutExpo = function(x)
		return x == 0 and 0
			or x == 1 and 1
			or x < 0.5 and math.pow(2, 20 * x - 10) / 2
			or (2 - math.pow(2, -20 * x + 10)) / 2
	end,

	easeInCirc = function(x)
		return 1 - math.sqrt(1 - math.pow(x, 2))
	end,

	easeOutCirc = function(x)
		return math.sqrt(1 - math.pow(x - 1, 2))
	end,

	easeInOutCirc = function(x)
		return x < 0.5
			and (1 - math.sqrt(1 - math.pow(2 * x, 2))) / 2
			or (math.sqrt(1 - math.pow(-2 * x + 2, 2)) + 1) / 2
	end,

	easeInBack = function(x)
		return c3 * x * x * x - c1 * x * x
	end,

	easeOutBack = function(x)
		return 1 + c3 * math.pow(x - 1, 3) + c1 * math.pow(x - 1, 2)
	end,

	easeInOutBack = function(x)
		return x < 0.5 and (math.pow(2 * x, 2) * ((c2 + 1) * 2 * x - c2)) / 2
			or (math.pow(2 * x - 2, 2) * ((c2 + 1) * (x * 2 - 2) + c2) + 2) / 2
	end,

	easeInElastic = function(x)
		return x == 0 and 0
			or x == 1 and 1
			or -math.pow(2, 10 * x - 10) * math.sin((x * 10 - 10.75) * c4)
	end,

	easeOutElastic = function(x)
		return x == 0 and 0
			or x == 1 and 1
			or math.pow(2, -10 * x) * math.sin((x * 10 - 0.75) * c4) + 1
	end,

	easeInOutElastic = function(x)
		return x == 0 and 0
			or x == 1 and 1
			or x < 0.5 and -(math.pow(2, 20 * x - 10) * math.sin((20 * x - 11.125) * c5)) / 2
			or (math.pow(2, -20 * x + 10) * math.sin((20 * x - 11.125) * c5)) / 2 + 1
	end,

	easeInBounce = function(x)
		return 1 - bounceOut(1 - x)
	end,

	easeOutBounce = bounceOut,
	easeInOutBounce = function(x)
		return x < 0.5
			and (1 - bounceOut(1 - 2 * x)) / 2
			or (1 + bounceOut(2 * x - 1)) / 2
	end,
}

local function create(object, goal, easing, duration)
	local original = {}
	for name in pairs(goal) do
		original[name] = object[name]
	end

	Tweens[object] = {
		original = original,
		goal = goal,
		easing = easing,
		clock = os.clock(),
		duration = duration,
	}
end

local function lerp(a, b, t)
	if type(a) == "table" then
		-- Assume vector space (ideally you would put the tables in a ring buffer, cuz, lua)
		local output = table.new(#a, 0)
		for i = 1, #a do
			output[i] = a[i] * (1.0 - t) + b[i] * t
		end

		return output
	elseif type(a) == "number" then
		-- Reals
		return a * (1.0 - t) + b * t
	else
		error("tween(): could not interpolate type ".. type(a))
	end
end

local function update()
	local clock = os.clock()

	for object, tweenData in pairs(Tweens) do
		local t = math.min((clock - tweenData.clock) / tweenData.duration, 1.0)
		local alpha = tweenData.easing(t)
		local goal = tweenData.goal

		for property, value in pairs(tweenData.original) do
			object[property] = lerp(value, goal[property], alpha)
		end

		if t == 1.0 then
			Tweens[object] = nil
		end
	end
end

return {
	easings = easings,
	create = create,
	update = update,
}
