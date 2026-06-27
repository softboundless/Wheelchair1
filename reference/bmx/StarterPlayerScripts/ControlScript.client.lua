-- services

local UserInputService	= game:GetService("UserInputService")
local ReplicatedStorage	= game:GetService("ReplicatedStorage")
local RunService		= game:GetService("RunService")
local Workspace			= game:GetService("Workspace")
local Players			= game:GetService("Players")

-- constants

local PLAYER		= Players.LocalPlayer
local CAMERA		= Workspace.CurrentCamera
local EVENTS		= ReplicatedStorage:WaitForChild("Events")
local IGNORE		= Workspace:WaitForChild("Ignore")
local CHARACTERS	= Workspace:WaitForChild("Characters")
local CHARACTER		= CHARACTERS:WaitForChild(PLAYER.Name)
local FORCE			= CHARACTER:WaitForChild("VectorForce")

local MASS			= CHARACTER:GetMass()
local ACCELERATION	= 0.5
local FLOOR_CHECK	= 10
local HEIGHT		= 3.5

local SPEED		= 128
local JUMP		= 30

-- variables

local floor				= Vector3.new(0, 1, 0)
local targetVelocity	= Vector3.new()
local grounded			= false

-- initiate

RunService:BindToRenderStep("Control", Enum.RenderPriority.Character.Value, function(deltaTime)
	-- grounded check
	local floorRay				= Ray.new(CHARACTER.Position, -floor.Unit * FLOOR_CHECK)
	local hit, position, normal	= Workspace:FindPartOnRayWithIgnoreList(floorRay, {CHARACTER, IGNORE})
	local floorDistance			= (position - CHARACTER.Position).Magnitude
	
	if floorDistance <= HEIGHT then
		grounded	= true
	else
		grounded	= false
	end
	
	if hit then
		if grounded then
			floor	= normal
		else
			floor	= floor:Lerp(normal, math.min(deltaTime * 5, 1))
		end
	else
		floor	= floor:Lerp(Vector3.new(0, 1, 0), math.min(deltaTime, 1))
	end
	
	-- floor cframe
	local lookVector	= CAMERA.CFrame.lookVector
	lookVector			= Vector3.new(lookVector.X, 0, lookVector.Z).Unit
	local floorCFrame	= CFrame.new(Vector3.new(), lookVector)
	local localFloor	= floorCFrame:vectorToObjectSpace(floor)
	
	local x, y	= math.atan2(-localFloor.X, localFloor.Y), math.atan2(localFloor.Z, localFloor.Y)
	local cfA	= CFrame.Angles(y, 0, 0) * CFrame.Angles(0, 0, x)
	local cfB	= CFrame.Angles(0, 0, x) * CFrame.Angles(y, 0, 0)
	
	floorCFrame	= floorCFrame * cfA:Lerp(cfB, 0.5)
	
	-- input
	if not UserInputService:GetFocusedTextBox() then
		local input	= Vector3.new()
		
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then
			input	= input + Vector3.new(0, 0, -1)
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then
			input	= input + Vector3.new(0, 0, 1)
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then
			input	= input + Vector3.new(-1, 0, 0)
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then
			input	= input + Vector3.new(1, 0, 0)
		end
		
		if input.Magnitude > 0 then
			input	= input.Unit
		end
		
		targetVelocity	= floorCFrame:vectorToWorldSpace(input * SPEED)
	end
	
	-- apply force
	if grounded then
		FORCE.Force	= (targetVelocity - CHARACTER.Velocity) * MASS * ACCELERATION
	else
		FORCE.Force	= Vector3.new()
	end
end)

-- events

UserInputService.InputBegan:connect(function(inputObject, processed)
	if not processed then
		if inputObject.KeyCode == Enum.KeyCode.Space then
			if grounded then
				CHARACTER.Velocity	= CHARACTER.Velocity + floor * JUMP
			end
		--[[elseif inputObject.KeyCode == Enum.KeyCode.E then
			EVENTS.Trick:Fire(CHARACTER, "Test")
		elseif inputObject.KeyCode == Enum.KeyCode.Q then
			EVENTS.Trick:Fire(CHARACTER, "Test2")]]
		end
	end
end)