-- services

local UserInputService	= game:GetService("UserInputService")
local RunService		= game:GetService("RunService")
local Workspace			= game:GetService("Workspace")
local Players			= game:GetService("Players")

-- constants

local PLAYER		= Players.LocalPlayer
local CAMERA		= Workspace.CurrentCamera
local IGNORE		= Workspace:WaitForChild("Ignore")
local CHARACTERS	= Workspace:WaitForChild("Characters")
local CHARACTER		= CHARACTERS:WaitForChild(PLAYER.Name)
local BIKE			= IGNORE:WaitForChild(PLAYER.Name .. "Bike")
local CHAR			= IGNORE:WaitForChild(PLAYER.Name .. "Character")

-- variables

local modes	= {
	"Orbit";
	"Follow";
	"FPS";
	"Track";
	"Gopro";
	"Gopro2";
}

local mode	= 1

local x, y	= 0, 0

-- functions

local function Lerp(a, b, d) return a + (b - a) * d end

-- initiate

UserInputService.MouseIconEnabled	= false
UserInputService.MouseBehavior		= Enum.MouseBehavior.LockCenter

CAMERA.FieldOfView		= 80
CAMERA.CameraType		= Enum.CameraType.Custom
CAMERA.CameraSubject	= CHARACTER

RunService:BindToRenderStep("Camera", Enum.RenderPriority.Last.Value, function(deltaTime)
	CAMERA.FieldOfView	= Lerp(CAMERA.FieldOfView, 80 + CHARACTER.Velocity.Magnitude / 5, math.min(deltaTime * 5, 1))
	
	if modes[mode] == "FPS" then
		CHAR.Head.LocalTransparencyModifier	= 1
	else
		CHAR.Head.LocalTransparencyModifier	= 0
	end
	
	if modes[mode] == "Orbit" then
		local center	= CHARACTER.Position + Vector3.new(0, 2, 0)
		local cframe	= CFrame.new(center) * CFrame.Angles(0, x, 0) * CFrame.Angles(y, 0, 0) * CFrame.new(0, 0, 20)
		local rotation	= cframe - cframe.p
		
		local ray			= Ray.new(center, (cframe.p - CHARACTER.Position))
		local _, position	= Workspace:FindPartOnRayWithIgnoreList(ray, {CHARACTERS, IGNORE})
		CAMERA.CFrame		= CFrame.new(position) * rotation
	elseif modes[mode] == "Follow" then
		CAMERA.CFrame	= CAMERA.CFrame:Lerp(BIKE.Frame.CFrame * CFrame.new(0, 5, 10), math.min(deltaTime * 2, 1))
	elseif modes[mode] == "FPS" then
		local offset	= CHAR.Hips.CFrame:toObjectSpace(CHAR.Torso.CFrame)
		CAMERA.CFrame	= CHAR.Head.CFrame * CFrame.Angles(-offset.Z * 0.2, 0, 0)
	elseif modes[mode] == "Track" then
		local distance	= (CAMERA.CFrame.p - CHARACTER.Position).Magnitude
		
		CAMERA.FieldOfView	= math.clamp(100 - distance, 10, 90)
		CAMERA.CFrame	= CAMERA.CFrame:Lerp(CFrame.new(CAMERA.CFrame.p, CHARACTER.Position), math.min(deltaTime * 5, 1))
	elseif modes[mode] == "Gopro" then
		CAMERA.FieldOfView	= 100
		CAMERA.CFrame		= BIKE.Frame.CFrame * CFrame.new(2, 0, 2)
	elseif modes[mode] == "Gopro2" then
		CAMERA.FieldOfView	= 100
		CAMERA.CFrame		= BIKE.Frame.CFrame * CFrame.new(0, 3, -1.2)
	end
	
	CAMERA.Focus	= CFrame.new(CHARACTER.Position)
end)

-- events

UserInputService.InputChanged:connect(function(inputObject, processed)
	if not processed then
		if modes[mode] == "Orbit" then
			x	= (x - inputObject.Delta.X * (1/260)) % (math.pi * 2)
			y	= math.clamp(y - inputObject.Delta.Y * (1/260), -1.4, 1.4)
		end
	end
end)

UserInputService.InputBegan:connect(function(inputObject, processed)
	if not processed then
		if inputObject.KeyCode == Enum.KeyCode.C then
			mode	= mode + 1
			if mode > #modes then
				mode	= 1
			end
			
			if modes[mode] == "Orbit" then
				local lookVector	= CAMERA.CFrame.lookVector
				x	= math.atan2(-lookVector.X, -lookVector.Z)
				y	= math.clamp(math.asin(lookVector.Y), -1.4, 1.4)
			end
		end
	end
end)