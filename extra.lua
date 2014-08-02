--[[

GetIndicesInLine = function(self, x1, y1, x2, y2)
		local plots = {}
		local x1, y1 = mCeil(x1), mCeil(y1)
		local x2, y2 = mCeil(x2), mCeil(y2)
		if x1 > x2 then
			local x1store = x1+0
			x1 = x2+0
			x2 = x1store
		end
		if y1 > y2 then
			local y1store = y1+0
			y1 = y2+0
			y2 = y1store
		end
		local dx = x2 - x1
		local dy = y2 - y1
		if dx == 0 then
			if dy ~= 0 then
				for y = y1, y2 do
					tInsert(plots, self:GetIndex(x1, y))
				end
			end
		elseif dy == 0 then
			if dx ~= 0 then
				for x = x1, x2 do
					tInsert(plots, self:GetIndex(x, y1))
				end
			end
		else
			local m = dy / dx
	        local b = y1 - m*x1
			for x = x1, x2 do
				local y = mFloor( (m * x) + b + 0.5 )
				tInsert(plots, self:GetIndex(x, y))
			end
		end
		return plots
	end,

function Space:ComputeFeatures()
	-- testing ocean rifts
	for i, hex in pairs(self.hexes) do
		if hex.polygon.oceanIndex then
			if hex.terrainType == terrainOcean then
				-- hex.featureType = featureIce
			elseif hex.polygon.continentIndex then
				hex.featureType = featureIce
			else
				hex.featureType = featureJungle
				for i, nhex in pairs(hex:Neighbors()) do
					if nhex.plotType ~= plotOcean then
						EchoDebug("non ocean plot type: " .. nhex.plotType, nhex.tinyIsland)
					end
				end
				EchoDebug(hex.plotType, hex.nearLand)
			end
		end
		-- if hex.nearOceanTrench then hex.featureType = featureIce end
	end
end

function SetTerrainTypes(terrainTypes)
	print("DON'T USE THIS Setting Terrain Types (Fantastical)");
	for i, plot in Plots() do
		plot:SetTerrainType(self.hexes[i+1].terrainType, false, false)
		-- MapGenerator's SetPlotTypes uses i+1, but MapGenerator's SetTerrainTypes uses just i. wtf.
	end
end

function Space:ExpandCoasts()
	EchoDebug(self.coastArea .. " coastal hexes before expansion")
	local d = 1
	repeat 
		local makeCoast = {}
		local potential = 0
		for i, hex in pairs(self.deepHexes) do
			if hex.plotType == plotOcean and hex.terrainType == terrainOcean and hex.polygon.oceanIndex == nil then
				local nearcoast
				for n, nhex in pairs(hex:Neighbors()) do
					if nhex.terrainType == terrainCoast then
						nearcoast = nhex
						break
					end
				end
				if nearcoast then
					potential = potential + 1
					if Map.Rand(hex.polygon.coastExpansionDice[d], "expand coast?") == 0 or nearcoast.featureType == featureIce then
						makeCoast[hex] = nearcoast
					end
				end
			end
		end
		for hex, nearcoast in pairs(makeCoast) do
			hex.terrainType = terrainCoast
			if nearcoast.coastalTemperature <= self.freezingTemperature then
				nearcoast.featureType = featureIce
			elseif nearcoast.coastalTemperature >= self.atollTemperature then
				nearcoast.featureType = featureAtoll
			end
			hex.expandedCoast = true
			hex.coastalTemperature = nearcoast.coastalTemperature
			self.coastArea = self.coastArea + 1
		end
		d = d + 1
		if d > self.coastDiceAmount then d = 1 end
	until self.coastArea >= self.prescribedCoastArea or potential == 0
	EchoDebug(self.coastArea .. " coastal hexes after expansion")
end

			local dx = terminal.x - hex.x
			local dy = terminal.y - hex.y
			if dx == 0 then
				if dy > 0 then d = mRandom(2, 3) else d = mRandom(5, 6) end
			elseif dx > 0 then
				if dy == 0 then
					d = 4
				elseif dy > 0 then
					d = mRandom(3, 4)
				elseif dy < 0 then
					d = mRandom(5, 4)
				end
			elseif dx < 0 then
				if dy == 0 then
					d = 1
				elseif dy > 0 then
					d = 2
				elseif dy < 0 then
					d = 6
				end
			end
			local neighbors = hex:Neighbors({d})
			hex = neighbors[1]
			local angle = AngleAtoB(hex.x, hex.y, terminal.x, terminal.y)
			local bestDist = 10
			local bestDir
			local neighbors = hex:Neighbors()
			for d = 1, 6 do
				if neighbors[d] then
					if hexAngles[d] == angle or neighbors[d] == terminalHex then
						bestDir = d
						break
					end
					local dist = AngleDist(angle, hexAngles[d])
					if dist < bestDist then
						bestDist = dist
						bestDir = d
					end
				end
			end
			hex = neighbors[bestDir]


function Space:PickOceansCylinder()
	local div = self.w / self.oceanNumber
	local x = 0
	-- if self.oceanNumber == 1 then x = 0 else x = mRandom(0, self.w) end
	for oceanIndex = 1, self.oceanNumber do
		local hex = self.hexes[self:GetIndex(x, 0)]
		local polygon = hex.polygon
		local edge
		for i, e in pairs(polygon.edges) do
			if e.polygons[1].bottomY and e.polygons[2].bottomY then
				edge = e
				break
			end
		end
		local ocean = {}
		local iterations = 0
		while iterations < 100 do
			edge.oceanIndex = oceanIndex
			for p = 1, 2 do
				if not edge.polygons[p].oceanIndex then
					edge.polygons[p].oceanIndex = oceanIndex
					tInsert(ocean, edge.polygons[p])
					self.nonOceanArea = self.nonOceanArea - edge.polygons[p].area
					self.nonOceanPolygons = self.nonOceanPolygons - 1
				end
			end
			if edge.polygons[1].topY and edge.polygons[2].topY then
				EchoDebug("topY found, stopping ocean #" .. oceanIndex .. " at " .. iterations .. " iterations")
				break
			end
			local up = {}
			local down = {}
			for cedge, yes in pairs(edge.connections) do
				if not cedge.oceanIndex then
					if cedge.maxY > edge.maxY then
						tInsert(up, cedge)
					else
						tInsert(down, cedge)
					end
				end
			end
			if #up == 0 then
				if #down == 0 then
					if #edge.connections == 0 then
						EchoDebug("no edge connections!, stopping ocean #" .. oceanIndex .. " at " .. iterations .. " iterations")
						break
					else
						up = edge.connections
					end
				else
					up = down
				end
			end
			local highestY = 0
			local highestEdge
			for c, cedge in pairs(up) do
				if cedge.maxY > highestY then
					highestY = cedge.maxY
					highestEdge = cedge
				end
			end
			edge = highestEdge or tGetRandom(up)
			iterations = iterations + 1
		end
		tInsert(self.oceans, ocean)
		x = mCeil(x + div) % self.w
	end
end

]]--