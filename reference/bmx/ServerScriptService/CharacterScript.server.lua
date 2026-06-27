-- services

local ServerStorage	= game:GetService("ServerStorage")
local Workspace		= game:GetService("Workspace")
local Players		= game:GetService("Players")

-- events

Players.PlayerAdded:connect(function(player)
	local character	= ServerStorage.Objects.Character:Clone()
		character.Name		= player.Name
		character.Parent	= Workspace.Characters
		
	character:SetNetworkOwner(player)
end)

Players.PlayerRemoving:connect(function(player)
	local character	= Workspace.Characters:FindFirstChild(player.Name)
	
	if character then
		character:Destroy()
	end
end)

-- loop

while true do
	wait(0.1)
	
	for _, character in pairs(Workspace.Characters:GetChildren()) do
		if character.Position.Y < -64 then
			character.CFrame	= CFrame.new(0, 64, 0)
		end
	end
end