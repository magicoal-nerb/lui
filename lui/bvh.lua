local new = require("table.new")

-- Dynamic BVH based off of Erin Catto's dynamic tree

local kFatAABB = { 4, 4 }
local kStackSize = 8

local Bvh = {}
Bvh.__index = Bvh

local function engulfed(min0, max0, min1, max1)
	return min1[1] <= min0[1] - kFatAABB[1] and min1[2] <= min0[2] - kFatAABB[2]
		and max0[1] + kFatAABB[1] <= max1[1] and max0[2] + kFatAABB[2] <= max1[2]
end

local function sah(min, max)
	return (max[1] - min[1]) * (max[2] - min[2])
end

local function union(a, b)
	return { math.min(a.min[1], b.min[1]), math.min(a.min[2], b.min[2]) },
		{ math.max(a.max[1], b.max[1]), math.max(a.max[2], b.max[2]) }
end

local function collides(min0, max0, min1, max1)
	return min0[1] <= max1[1] and max0[1] >= min1[1]
		and min0[2] <= max1[2] and max0[2] >= min1[2]
end

local function rayhit(min, max, origin, direction)
	if collides(min, max, origin, origin) then
		return true
	end

	local invDirection = { 1.0 / direction[1], 1.0 / direction[2] }

	local vMax, vMin = { (max[1] - origin[1]) * invDirection[1], (max[2] - origin[2]) * invDirection[2] },
		{ (min[1] - origin[1]) * invDirection[1], (min[2] - origin[2]) * invDirection[2] }

	local rMax, rMin = { math.max(vMax[1], vMin[1]), math.max(vMax[2], vMin[2]) },
		{ math.min(vMax[1], vMin[1]), math.min(vMax[2], vMin[2]) }

	local tMin, tMax = math.max(rMin[1], rMin[2], rMin[3]), math.min(rMax[1], rMax[2], rMax[3])

	return 0.0 <= math.min(tMax, tMin) and tMin <= 1.0 and tMin <= tMax
end

function Bvh.new()
	return setmetatable({
		freelist = {},
		leaves = {},
		nodes = {},
		root = 0,
	}, Bvh)
end

function Bvh.allocateNode(self)
	local id = table.remove(self.freelist) or #self.nodes + 1
	self.nodes[id] = {
		left = 0,
		right = 0,
		parent = 0,
		height = 0,
		min = { 0, 0 },
		max = { 0, 0 },
	}

	return id
end

function Bvh.findBestSibling(self, box)
	local area = sah(box.min, box.max)

	local nodes = self.nodes
	local rootNode = nodes[self.root]

	local baseArea = sah(rootNode.min, rootNode.max)
	local directCost = sah(union(rootNode, box))
	local inheritedCost = 0.0

	local bestSibling = self.root
	local bestCost = directCost

	-- Descend the tree from the root, using a greedy path approach
	-- (could improve w/ a priority queue, but eh.)
	local index = self.root
	while nodes[index].height > 0 do
		local node = nodes[index]
		local left, right = nodes[node.left], nodes[node.right]

		local cost = directCost + inheritedCost
		if cost < bestCost then
			bestSibling = index
			bestCost = cost
		end

		inheritedCost = inheritedCost + directCost - baseArea

		local leftLeaf, rightLeaf = left.height == 0, right.height == 0

		local leftLowerCost, rightLowerCost = math.huge, math.huge
		local leftArea, rightArea = 0, 0
		local leftDirectCost, rightDirectCost = sah(union(left, box)), sah(union(right, box))

		if leftLeaf then
			-- Left is a leaf node
			local leftCost = leftDirectCost + inheritedCost
			if leftCost < bestCost then
				bestSibling = node.left
				bestCost = leftCost
			end
		else
			-- Internal node
			leftArea = sah(left.min, left.max)
			leftLowerCost = inheritedCost + leftDirectCost + math.min(area - leftArea, 0)
		end

		if rightLeaf then
			-- Right is a leaf node
			local rightCost = rightDirectCost + inheritedCost
			if rightCost < bestCost then
				bestSibling = node.right
				bestCost = rightCost
			end
		else
			-- Internal node
			rightArea = sah(right.min, right.max)
			rightLowerCost = inheritedCost + rightDirectCost + math.min(area - rightArea, 0)
		end

		if bestCost <= leftLowerCost and bestCost <= rightLowerCost then
			-- Can't reduce the cost any further
			break
		elseif leftLowerCost < rightLowerCost and not leftLeaf then
			-- Go left
			index = node.left
			baseArea = leftArea
			directCost = leftDirectCost
		else
			-- Go right
			index = node.right
			baseArea = rightArea
			directCost = rightDirectCost
		end
	end

	return bestSibling
end

function Bvh.rotateNode(self, iA)
	local nodes = self.nodes

	local A = nodes[iA]
	if A.height < 2 then
		return
	end

	local iB, iC = A.left, A.right
	local B, C = nodes[iB], nodes[iC]
	if B.height == 0 then
		-- B is a leaf and C is internal
		local iF, iG = C.left, C.right
		local F, G = nodes[iF], nodes[iG]
		local costBase = sah(C.min, C.max)

		local costBF = sah(union(B, G))
		local costBG = sah(union(B, F))

		if costBase < costBF and costBase < costBG then
			-- Rotation doesn't improve cost
			return
		elseif costBF < costBG then
			-- Swap BF
			A.left, C.left = iF, iB
			B.parent, F.parent = iC, iA
			C.min, C.max = union(B, G)
			C.height, A.height = 1 + math.max(B.height, G.height), 1 + math.max(C.height, F.height)
		else
			-- Swap BG
			A.left, C.right = iG, iB
			B.parent, G.parent = iC, iA
			C.min, C.max = union(B, F)
			C.height, A.height = 1 + math.max(B.height, F.height), 1 + math.max(C.height, G.height)
		end
	elseif C.height == 0 then
		-- C is a leaf and B is internal
		local iD, iE = B.left, B.right
		local D, E = nodes[iD], nodes[iE]

		local costBase = sah(B.min, B.max)

		local costCD = sah(union(C, E))
		local costCE = sah(union(C, D))

		if costBase < costCD and costBase < costCE then
			-- Rotation doens't improve cost
			return
		elseif costCD < costCE then
			-- Swap C and D
			A.right, B.left = iD, iC
			C.parent,  D.parent = iB, iA
			B.min, B.max = union(C, E)
			B.height, A.height = 1 + math.max(C.height, E.height), 1 + math.max(B.height, D.height)
		else
			-- Swap C and E
			A.right, B.right = iE, iC
			C.parent, E.parent = iB, iA
			B.min, B.max = union(C, D)
			B.height, A.height = 1 + math.max(C.height, D.height), 1 + math.max(B.height, E.height)
		end
	else
		local iD, iE, iF, iG = B.left, B.right, C.left, C.right
		local D, E, F, G = nodes[iD], nodes[iE], nodes[iF], nodes[iG]

		local areaB = sah(B.min, B.max)
		local areaC = sah(C.min, C.max)

		local costBase = areaB + areaC

		local bestRotation = 0
		local bestCost = costBase

		-- Cost of swapping B and F
		local costBF = areaB + sah(union(B, G))
		local costBG = areaB + sah(union(B, F))
		local costCD = areaC + sah(union(C, E))
		local costCE = areaC + sah(union(C, D))

		if costBF < bestCost then
			bestRotation = 1
			bestCost = costBF
		end

		if costBG < bestCost then
			bestRotation = 2
			bestCost = costBG
		end

		if costCD < bestCost then
			bestRotation = 3
			bestCost = costCD
		end

		if costCE < bestCost then
			bestRotation = 4
		end

		if bestRotation == 0 then
			return
		elseif bestRotation == 1 then
			-- BF rotation
			A.left, C.left = iF, iB
			B.parent, F.parent = iC, iA
			C.min, C.max = union(B, G)
			C.height, A.height = 1 + math.max(B.height, G.height), 1 + math.max(C.height, F.height)
		elseif bestRotation == 2 then
			-- BG rotation
			A.left, C.right = iG, iB
			B.parent, G.parent = iC, iA
			C.min, C.max = union(B, F)
			C.height, A.height = 1 + math.max(B.height, F.height), 1 + math.max(C.height, G.height)
		elseif bestRotation == 3 then
			-- CD rotation
			A.right, B.left = iD, iC
			C.parent, D.parent = iB, iA
			B.min, B.max = union(C, E)
			B.height, A.height = 1 + math.max(C.height, E.height), 1 + math.max(B.height, D.height)
		elseif bestRotation == 4 then
			-- CE rotation
			A.right, B.right = iE, iC
			C.parent, E.parent = iB, iA
			B.min, B.max = union(C, D)
			B.height, A.height = 1 + math.max(C.height, D.height), 1 + math.max(B.height, E.height)
		end
	end
end

function Bvh.insert(self, userdata, min, max)
	min[1], min[2] = min[1] - kFatAABB[1], min[2] - kFatAABB[2]
	max[1], max[2] = max[1] + kFatAABB[1], max[2] + kFatAABB[2]

	local nodes = self.nodes
	local leaf = self:allocateNode()
	nodes[leaf].userdata = userdata
	nodes[leaf].min = min
	nodes[leaf].max = max

	if self.root == 0 then
		-- Root node
		self.root = leaf
		return leaf
	end

	-- Find the best sibling for this node
	local leafNode = nodes[leaf]
	local sibling = self:findBestSibling(leafNode)

	local oldParent = nodes[sibling].parent
	local newParent = self:allocateNode()

	local siblingNode = nodes[sibling]
	local parentNode = nodes[newParent]
	parentNode.min, parentNode.max = union(leafNode, siblingNode)
	parentNode.parent = oldParent
	parentNode.height = siblingNode.height + 1

	nodes[newParent] = parentNode

	if oldParent ~= 0 then
		-- Sibling is not the root
		if nodes[oldParent].left == sibling then
			nodes[oldParent].left = newParent
		else
			nodes[oldParent].right = newParent
		end

		parentNode.left = sibling
		parentNode.right = leaf
	else
		-- Sibling was the root
		parentNode.left = sibling
		parentNode.right = leaf
		self.root = newParent
	end

	siblingNode.parent = newParent
	leafNode.parent = newParent

	-- Walk back up the tree and fix heights and AABBs
	local index = nodes[leaf].parent
	while index ~= 0 do
		local node = nodes[index]
		local left = nodes[node.left]
		local right = nodes[node.right]

		node.min, node.max = union(left, right)
		node.height = 1 + math.max(left.height, right.height)

		self:rotateNode(index)
		index = nodes[index].parent
	end

	return leaf
end

function Bvh.delete(self, leaf)
	if leaf == self.root then
		table.insert(self.freelist, leaf)
		self.root = 0
		return
	end

	local nodes = self.nodes
	local parent = nodes[leaf].parent
	local grandParent = nodes[parent].parent
	local sibling = nodes[parent].left == leaf
		and nodes[parent].right
		or nodes[parent].left

	if grandParent ~= 0 then
		-- Destroy parent and connect sibling to grandparent
		if nodes[grandParent].left == parent then
			nodes[grandParent].left = sibling
		else
			nodes[grandParent].right = sibling
		end

		nodes[sibling].parent = grandParent
		table.insert(self.freelist, parent)
		table.insert(self.freelist, leaf)

		-- Adjust ancestor bounds
		local index = grandParent
		while index ~= 0 do
			local node = nodes[index]
			local left = nodes[node.left]
			local right = nodes[node.right]

			node.min, node.max = union(left, right)
			node.height = 1 + math.max(left.height, right.height)
			index = node.parent
		end
	else
		-- Then just set the root to the sibling
		self.root = sibling
		self.nodes[sibling].parent = 0
		table.insert(self.freelist, parent)
		table.insert(self.freelist, leaf)
	end
end

function Bvh.getUserdata(self, id)
	return self.nodes[id].userdata
end

function Bvh.raycast(self, origin, direction, callback)
	local nodes = self.nodes
	local output = {}

	local stack = table.new(kStackSize, 0)
	local cursor = 1
	stack[1] = self.root

	while cursor ~= 0 do
		local iA = stack[cursor]
		local A = nodes[iA]
		cursor = cursor - 1

		if rayhit(A.min, A.max, origin, direction) then
			if A.userdata then
				callback(iA)
			else
				stack[cursor + 1] = A.left
				stack[cursor + 2] = A.right
				cursor = cursor + 2
			end
		end
	end

	return output
end

function Bvh.query(self, min, max, callback)
	local nodes = self.nodes
	local output = {}

	local stack = table.new(kStackSize, 0)
	local cursor = 1
	stack[1] = self.root

	while cursor ~= 0 do
		local iA = stack[cursor]
		local A = nodes[iA]
		cursor = cursor - 1

		if collides(A.min, A.max, min, max) then
			if A.userdata then
				callback(iA)
			else
				stack[cursor + 1] = A.left
				stack[cursor + 2] = A.right
				cursor = cursor + 2
			end
		end
	end

	return output
end

function Bvh.update(self, id, min0, max0)
	local node = self.nodes[id]

	local min1 = node.min
	local max1 = node.max

	if engulfed(min0, max0, min1, max1) then
		-- No need to update because the fat aabb still persists
		return
	end

	-- Reinsert because it is outside of the aabb range
	self:delete(id)
	assert(id == self:insert(node.userdata, { min0[1], min0[2] }, { max0[1], max0[2] }))
end

return Bvh