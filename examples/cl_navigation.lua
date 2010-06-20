-------------------
-- gm_navigation
-- Spacetech
-------------------

require("navigation")

-- If running clientside hold down alt to see it.

local GridSize = 32 -- Space between the nodes

local Nav = CreateNav(GridSize)

local Diagonal = true

-- Diagonal Linking is disabled by default
Nav:SetDiagonal(Diagonal) -- Enable / Disable Diagonal linking (Will DOUBLE the time it takes for the generation)

-- Nav:SetGridSize(256) -- You can also set grid size this way (But its required to at least put some number in CreateNav

-- The module will ignore COLLISION_GROUP_PLAYER

local PrintPath = {}
local Start, End
local NormalUp = Vector(0, 0, 1)
local Mask = MASK_PLAYERSOLID_BRUSHONLY
local HitWorld, Pos, ONormal

Nav:SetMask(Mask) -- Set the mask for the nav traces - Default is MASK_PLAYERSOLID_BRUSHONLY

local function TraceDown(Pos)
	local trace = {}
	trace.start = Pos + Vector(0, 0, 1)
	trace.endpos = trace.start - Vector(0, 0, 9000)
	trace.mask = Mask
	local tr = util.TraceLine(trace)
	return tr.HitWorld, tr.HitPos, tr.HitNormal
end

local function ComputePath()
	local FoundPath, Path = Nav:FindPath()
	if(FoundPath) then
		print("Found Path!", Path, table.Count(Path))
		PrintTable(Path)
	else
		print("Failed to Find Path", table.Count(Path))
		PrintTable(Path)
		if(table.Count(Path) > 0) then
			print(Path[1]:GetPosition(), Path[table.Count(Path)]:GetPosition())
		end
	end
	
	PrintPath = Path
	Start = Nav:GetStart()
	End = Nav:GetEnd()
end

local function OnGenerated(Loaded)
	print("\n")
	-- I'm using node:GetPosition() because it makes it easier to see what node is which
	
	local LinkTotal = 0
	
	for k,v in pairs(Nav:GetNodes()) do
		LinkTotal = LinkTotal + table.Count(v:GetConnections())
	end
	
	print("Node Total", Nav:GetNodeTotal(), "Link Total", LinkTotal)
	
	local Node = Nav:GetNodes()[math.random(1, Nav:GetNodeTotal())]
	
	print("GetNode", Nav:GetNode(Node:GetPosition()):GetPosition(), Node:GetPosition())
	
	print("GetClosestNode", Nav:GetClosestNode(Vector(0, 0, 0)))
	
	print("Node Info", Nav:GetNodes(), Nav:GetNodeTotal(), table.Count(Nav:GetNodes()))
	
	print("First Node", Nav:GetNodes()[1]:GetPosition(), Nav:GetNodeByID(1):GetPosition())
	print("Last Node", Nav:GetNodes()[Nav:GetNodeTotal()]:GetPosition(), Nav:GetNodeByID(Nav:GetNodeTotal()):GetPosition())
	
	print("GetNodeTotal 1", Nav:GetNodeTotal())
	Nav:SetStart(Nav:GetNodeByID(1))
	print("GetNodeTotal 2", Nav:GetNodeTotal())
	
	Nav:SetEnd(Nav:GetNodeByID(Nav:GetNodeTotal()))
	
	print("Start", Nav:GetStart():GetPosition(), "End", Nav:GetEnd():GetPosition())
	
	print("Diagonal 1", Nav:GetDiagonal())
	
	Nav:SetDiagonal(!Diagonal)
	
	print("Diagonal 2", Nav:GetDiagonal())
	
	Nav:SetDiagonal(Diagonal)

	print("GridSize 1", Nav:GetGridSize())
	
	Nav:SetGridSize(256)
	
	print("GridSize 2", Nav:GetGridSize())
	
	Nav:SetGridSize(GridSize)
	
	-- HEURISTIC_MANHATTAN
	-- HEURISTIC_EUCLIDEAN
	-- HEURISTIC_CUSTOM (Not Implemented Yet)
	Nav:SetHeuristic(HEURISTIC_MANHATTAN)
	
	-- ComputePath()
	
	print("Save", Nav:Save("data/test.nav"))
	
	if(!Loaded) then
		print("Load", Nav:Load("data/test.nav"), "\n")
		OnGenerated(true)
	end
end

-- Make sure you are nocliped and above the ground (Not sure if I need to do this anymore?)
concommand.Add("snav", function(ply)
	HitWorld, Pos, Normal = TraceDown((IsValid(ply) and ply:GetPos()) or Vector(0, 0, 1))
	
	if(HitWorld) then
		ErrorNoHalt("Creating Nav\n")
		
		if(IsValid(ply)) then
			-- Remove this line if you don't want a max distance
			Nav:SetupMaxDistance(ply:GetPos(), 256) -- All nodes must stay within 1024 from the players position
		end
		
		Nav:ClearWalkableSeeds()
		
		-- Once 1 seed runs out, it will go onto the next seed
		Nav:AddWalkableSeed(Pos, Normal)
		
		HitWorld, Pos, Normal = TraceDown(Vector(0, 0, 0))
		
		Nav:AddWalkableSeed(Pos, Normal)
		
		-- The module will account for node overlapping
		Nav:AddWalkableSeed(Pos, NormalUp)
		Nav:AddWalkableSeed(Pos, NormalUp)
		
		-- Nav:AddWalkableSeed(Pos - Vector(50, 200, 0), NormalUp)
		-- Nav:AddWalkableSeed(Pos + Vector(0, 100, 0), NormalUp)
		
		-- You must call this
		-- Reset all generation variables so you can generate
		Nav:StartGeneration()
		
		-- Calling Nav:UpdateGeneration() just steps it once so you will want to loop / think it
		-- FullGeneration does the whole loop in the module -> faster but it will lock game while its computing (Should I thread it?)
		if(false) then
			local StartTime = CurTime()
			hook.Add("Think", "NavUpdateGeneration", function()
				if(Nav:UpdateGeneration()) then
					ErrorNoHalt("Generated in ".. string.ToMinutesSeconds(CurTime() - StartTime).."\n")
					OnGenerated()
					hook.Remove("Think", "NavUpdateGeneration")
				end
			end)
		else
			ErrorNoHalt("Generated in ".. string.ToMinutesSeconds(math.Round(Nav:FullGeneration())), "\n")
			OnGenerated()		
		end
	end
end)

concommand.Add("snav_setstart", function(ply)
	Nav:SetStart(Nav:GetClosestNode(ply:GetPos()))
	Start = Nav:GetStart()
end)

concommand.Add("snav_setend", function(ply)
	Nav:SetEnd(Nav:GetClosestNode(ply:GetPos()))
	End = Nav:GetEnd()
	ComputePath()
end)

concommand.Add("snav_debug", function()
	print(Nav:GetNodes(), table.Count(Nav:GetNodes()))
end)

concommand.Add("snav_debug_2", function()
	for k,v in pairs(Nav:GetNodes()) do
		print(v, v:GetPosition(), table.Count(v:GetConnections()))
	end
end)

if(SERVER) then
	return
end

local Alpha = 200
local ColNORMAL = Color(255, 255, 255, Alpha) -- White
local ColNORTH = Color(255, 255, 0, Alpha) -- Pink?
local ColSOUTH = Color(255, 0, 0, Alpha) -- RED
local ColEAST = Color(0, 255, 0, Alpha) -- GREEN
local ColWEST = Color(0, 0, 255, Alpha) -- BLUE
local ColOTHER = Color(0, 255, 255, Alpha) -- Black

local PathOffset = Vector(0, 0, 10)
local ColPath = Color(255, 0, 0, 255)

local function DrawNodeLines(Table, PlyPos)
	for k,v in pairs(Table) do
		if(PlyPos:Distance(v:GetPosition()) <= 512) then
			for k2,v2 in pairs(v:GetConnections()) do
				local Col = ColOTHER
				if(k2 == NORTH) then
					Col = ColNORTH
				elseif(k2 == SOUTH) then
					Col = ColSOUTH
				elseif(k2 == EAST) then
					Col = ColEAST
				elseif(k2 == WEST) then
					Col = ColWEST
				end
				
				render.DrawBeam(v:GetPosition(), v:GetPosition() + (v2:GetPosition() - v:GetPosition()) * 0.3, 4, 0.25, 0.75, Col)
			end
			render.DrawBeam(v:GetPosition(), v:GetPosition() + (v:GetNormal() * 13), 4, 0.25, 0.75, ColNORMAL)
		end
	end
end

local function DrawNodePath(Table)
	for k,v in pairs(Table) do
		if(Table[k + 1]) then
			render.DrawBeam(v:GetPosition() + PathOffset, Table[k + 1]:GetPosition() + PathOffset, 4, 0.25, 0.75, ColPath)
		end
	end
end

local Mat = Material("effects/laser_tracer")
hook.Add("RenderScreenspaceEffects", "NavRenderScreenspaceEffects", function()
	if(!Nav or !input.IsKeyDown(KEY_LALT)) then
		return
	end
	render.SetMaterial(Mat)
	cam.Start3D(EyePos(), EyeAngles())
		DrawNodeLines(Nav:GetNodes(), LocalPlayer():GetPos())
		DrawNodePath(PrintPath)
		if(Start) then
			render.DrawBeam(Start:GetPosition(), Start:GetPosition() + (Start:GetNormal() * 64), 4, 0.25, 0.75, ColPath)
		end
		if(End) then
			render.DrawBeam(End:GetPosition(), End:GetPosition() + (End:GetNormal() * 64), 4, 0.25, 0.75, ColPath)
		end
	cam.End3D()
end)
