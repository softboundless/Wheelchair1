-- services

local ReplicatedStorage	= game:GetService("ReplicatedStorage")
local RunService		= game:GetService("RunService")
local Workspace			= game:GetService("Workspace")
local Players			= game:GetService("Players")

-- constants

local PLAYER		= Players.LocalPlayer
local IGNORE		= Workspace:WaitForChild("Ignore")
local CHARACTERS	= Workspace:WaitForChild("Characters")

local MODULES	= ReplicatedStorage:WaitForChild("Modules")
	local BIKE		= require(MODULES:WaitForChild("Bike"))

-- functions

local function Handle(character)
	BIKE:Attach(character)
end

-- initiate

for _, character in pairs(CHARACTERS:GetChildren()) do
	Handle(character)
end

-- events

CHARACTERS.ChildAdded:connect(Handle)