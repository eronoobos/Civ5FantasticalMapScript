-- Fantastical Place Names, helper mod for Fantastical Map Script
-- handles map labels
-- Author: zoggop
-- version 2
--------------------------------------------------------------------
print('Fantastical Place Names present')
include("FLuaVector")
include("InstanceManager")
include("Serializer.lua")
--------------------------------------------------------------------
local tInsert = table.insert
local function tDuplicate(sourceTable)
	local duplicate = {}
	for k, v in pairs(sourceTable) do
		duplicate[k] = v
	end
	return duplicate
end
local mFloor, mCeil = math.floor, math.ceil
--------------------------------------------------------------------
g_Properties = {}
--------------------------------------------------------------------
local mapWidth, mapHeight = Map.GetGridSize()
local mapArea = mapWidth * mapHeight
local bigArea = math.ceil(mapArea / 8)
local featureIce = FeatureTypes.FEATURE_ICE
local g_SaveData	= Modding.OpenSaveData();
local g_MapManager = InstanceManager:new("Map", "Anchor", Controls.MapContainer)
local g_WorldOffset = {x=0, y=0, z=0}
local labelledIDs = {}
local labelledHexes = {}
--------------------------------------------------------------------
function F_ActivePlayerTurnStart()
	local teamID = Game.GetActiveTeam()
	for i, ID in pairs(GetPersistentTable("Fantastical_Label_IDs")) do
		if not labelledIDs[ID] then
			local label = GetPersistentTable("Fantastical_Map_Label_ID_" .. ID)
			local allRevealed = true
			if #label.Hexes > bigArea then
				-- for oceans, so that one doesn't need to explore every last bit to get the name
				local validHexCount, revealedHexCount = 0, 0
				for h, hex in pairs(label.Hexes) do
					local plot = Map.GetPlot(hex.X, hex.Y)
					if plot:GetFeatureType() ~= featureIce then
						validHexCount = validHexCount + 1
						if plot:IsRevealed(teamID) then
							revealedHexCount = revealedHexCount + 1
						end
					end
				end
				local necessaryHexRatio = math.max( 0.5, 1 - (validHexCount / mapArea) )
				allRevealed = revealedHexCount > (validHexCount * necessaryHexRatio)
			else
				for h, hex in pairs(label.Hexes) do
					local plot = Map.GetPlot(hex.X, hex.Y)
					if not plot:IsRevealed(teamID) then
						allRevealed = false
						break
					end
				end
			end
			if allRevealed then
				local labelled = (labelledHexes[label.X] and labelledHexes[label.X][label.Y]) or (labelledHexes[label.X-1] and labelledHexes[label.X-1][label.Y]) or (labelledHexes[label.X+1] and labelledHexes[label.X+1][label.Y])
				if not labelled then
					print(label.Label, label.Type, label.X .. ", " .. label.Y)
					local instance = g_MapManager:GetInstance()
					instance[label.Type]:LocalizeAndSetText(label.Label)
					local labelPlot = Map.GetPlot(label.X, label.Y)
					PlaceInWorld(instance.Anchor, GetWorldPos(labelPlot))
					if labelledHexes[label.X] == nil then labelledHexes[label.X] = {} end
					if labelledHexes[label.X-1] == nil then labelledHexes[label.X-1] = {} end
					if labelledHexes[label.X+1] == nil then labelledHexes[label.X+1] = {} end
					labelledHexes[label.X][label.Y] = label.ID
					labelledHexes[label.X-1][label.Y] = label.ID
					labelledHexes[label.X+1][label.Y] = label.ID
					labelledIDs[ID] = true
				end
			end
		end
	end
end
Events.ActivePlayerTurnStart.Add( F_ActivePlayerTurnStart )
--------------------------------------------------------------------
function GetWorldPos(pPlot)
	return HexToWorld(ToHexFromGrid({x=pPlot:GetX(), y=pPlot:GetY()}))
end
--------------------------------------------------------------------
function PlaceInWorld(control, world)
	control:SetWorldPosition(VecAdd(world, g_WorldOffset))
end
--------------------------------------------------------------------
function SetInitialized()
	SetPersistentProperty("Fantastical_Place_Names_Init", true);
end
--------------------------------------------------------------------
function IsInitialized()
	return GetPersistentProperty("Fantastical_Place_Names_Init");
end
--------------------------------------------------------------------
function GetPersistentProperty(name)
	if (g_Properties[name] == nil) then
		g_Properties[name] = g_SaveData.GetValue(name);
	end
	return g_Properties[name];
end
--------------------------------------------------------------------
function SetPersistentProperty(name, value)
	g_SaveData.SetValue(name, value);
	g_Properties[name] = value;
end
--------------------------------------------------------------------
function GetPersistentTable(name)
	if (g_Properties[name] == nil) then
		local code = g_SaveData.GetValue(name);
		g_Properties[name] = loadstring(code)();
	end
	return g_Properties[name];
end
--------------------------------------------------------------------
function SetPersistentTable(name, t)
    g_SaveData.SetValue(name, serialize(t))
	g_Properties[name] = t;
end
--------------------------------------------------------------------
function Initialize()
	if not IsInitialized() then
		print("Initializing Fantastical Place Names...")
		if GameInfo.Fantastical_Map_Labels then
			local IDs = {}
			for row in DB.Query("SELECT * FROM Fantastical_Map_Labels") do -- using the DB Query b/c gameinfo and the db sometimes differ inexplicably
				local label = tDuplicate(row)
				label.Hexes = {}
				if GameInfo["Fantastical_Map_Label_ID_" .. label.ID] then
					for hex in DB.Query("SELECT * FROM Fantastical_Map_Label_ID_" .. label.ID .. ";") do
						local xy = tDuplicate(hex)
						tInsert(label.Hexes, xy)
					end
					SetPersistentTable("Fantastical_Map_Label_ID_" .. label.ID, label)
					tInsert(IDs, label.ID)
				end
			end
			SetPersistentTable("Fantastical_Label_IDs", IDs)
			print("Fantastical labels loaded.")
		else
			print("no Fantastical_Map_Labels in GameInfo")
		end
		SetInitialized();
	else
		print("Fantastical Place Names already initialized in savedata")
	end
	F_ActivePlayerTurnStart()
end
--------------------------------------------------------------------
Initialize()

--[[
local function OnHexFogEvent(hexPos, fogState, bWholeMap)
	if not bWholeMap then
		local x, y = ToGridFromHex( hexPos.x, hexPos.y );
		local index = mapWidth * y + x;
		fog[index] = fogState;
	end
end
Events.HexFOWStateChanged.Add(OnHexFogEvent)
]]--