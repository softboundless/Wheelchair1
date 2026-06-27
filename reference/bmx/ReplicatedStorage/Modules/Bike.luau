-- services

local ReplicatedStorage	= game:GetService("ReplicatedStorage")
local RunService		= game:GetService("RunService")
local Workspace			= game:GetService("Workspace")
local Players			= game:GetService("Players")

-- constants

local PLAYER	= Players.LocalPlayer

local OBJECTS	= ReplicatedStorage:WaitForChild("Objects")
local EVENTS	= ReplicatedStorage:WaitForChild("Events")
local TRICKS	= ReplicatedStorage:WaitForChild("Tricks")
local IGNORE	= Workspace:WaitForChild("Ignore")

local MODULES	= ReplicatedStorage:WaitForChild("Modules")
	local SPRING	= require(MODULES:WaitForChild("Spring"))

local FLOOR_CHECK	= 10
local HEIGHT		= 3.5

-- functions

local function Lerp(a, b, d) return a + (b - a) * d end

-- module

local BIKE	= {}

function BIKE.Attach(self, character)
	-- setup
	local bike	= OBJECTS.Bike:Clone()
		bike.Name	= character.Name .. "Bike"
		bike.Parent	= IGNORE
		
	local char	= OBJECTS.Character:Clone()
		char.Name	= character.Name .. "Character"
		char.Parent	= IGNORE
		
	if character.Name == PLAYER.Name then
		char.Head.NameGui:Destroy()
	else
		char.Head.NameGui.NameLabel.Text	= character.Name
		char.Head.NameGui.ShadowLabel.Text	= character.Name
	end
		
	-- variables
	local charSpring	= SPRING:Create(1, 10, 2, 2)
	
	local grounded	= false
	local floor		= Vector3.new(0, 1, 0)
	
	local orientation	= CFrame.new()
	local wheelRotation	= 0
	local pedalRotation	= 0
	
	local tilt	= 0
	
	local currentTrick	= nil
	
	local lastVelocity	= Vector3.new()
	local lastPosition	= bike.Frame.Seat.WorldPosition
	
	-- functions
	local function Weld(a, b)
		local offset	= a.CFrame:toObjectSpace(b.CFrame)
		local weld	= Instance.new("Weld")
			weld.C0		= offset
			weld.Part0	= a
			weld.Part1	= b
			weld.Parent	= b
	end
	
	local function Wipeout()
		character.Anchored		= true
		character.CanCollide	= false
		character.Velocity		= Vector3.new()
		-- weld bike
		for _, v in pairs(bike:GetChildren()) do
			if v:IsA("BasePart") and v ~= bike.Frame then
				Weld(bike.Frame, v)
				v.Anchored		= false
				v.CanCollide	= true
			end
		end
		
		bike.Frame.Anchored		= false
		bike.Frame.CanCollide	= true
		
		bike.Frame.Velocity		= lastVelocity
		
		local ragdoll	= OBJECTS.Ragdoll:Clone()
			
		for _, v in pairs(ragdoll:GetChildren()) do
			if v:IsA("BasePart") then
				v.CFrame	= char[v.Name].CFrame
				v.Velocity	= lastVelocity
			end
		end
		
		ragdoll.Parent	= IGNORE
		
		for _, v in pairs(char:GetChildren()) do
			if v:IsA("BasePart") then
				v.Transparency	= 1
			end
		end
	end
		
	RunService:BindToRenderStep(character.Name .. "Bike", Enum.RenderPriority.Character.Value, function(deltaTime)
		if character.Parent then
			-- grounded check
			local floorRay				= Ray.new(character.Position, -floor.Unit * FLOOR_CHECK)
			local hit, position, normal	= Workspace:FindPartOnRayWithIgnoreList(floorRay, {character, IGNORE})
			local floorDistance			= (position - character.Position).Magnitude
			
			if floorDistance <= HEIGHT then
				grounded	= true
			else
				grounded	= false
			end
			
			if hit then
				if grounded then
					floor	= floor:Lerp(normal, math.min(deltaTime * 20, 1))
				else
					floor	= floor:Lerp(normal, math.min(deltaTime * 5, 1))
				end
			else
				floor	= floor:Lerp(Vector3.new(0, 1, 0), math.min(deltaTime, 1))
			end
			
			-- floor calculation
			local floorCFrame	= CFrame.new()
			local localFloor	= floorCFrame:vectorToObjectSpace(floor)
			
			local x, y	= math.atan2(-localFloor.X, localFloor.Y), math.atan2(localFloor.Z, localFloor.Y)
			local cfA	= CFrame.Angles(y, 0, 0) * CFrame.Angles(0, 0, x)
			local cfB	= CFrame.Angles(0, 0, x) * CFrame.Angles(y, 0, 0)
		
			floorCFrame	= floorCFrame * cfA:Lerp(cfB, 0.5)
			
			--IGNORE.Debug.CFrame	= floorCFrame + character.Position
			--IGNORE.Debug.Color	= grounded and Color3.new(0, 0.6, 0.6) or Color3.new(0.8, 0.2, 0.1)
			
			-- idk
			local localVelocity	= floorCFrame:vectorToObjectSpace(character.Velocity)
			localVelocity		= Vector3.new(localVelocity.X, 0, localVelocity.Z)
			
			if localVelocity.Magnitude > 1 then
				orientation			= orientation:Lerp(CFrame.new(Vector3.new(), localVelocity), math.min(deltaTime * 10, 1))
			end
			
			local bikeCFrame	= floorCFrame * orientation
			local localVelocity	= bikeCFrame:vectorToObjectSpace(character.Velocity)
			
			-- wheel rotation
			if grounded then
				local speed		= character.Velocity.Magnitude
				wheelRotation	= wheelRotation + ((speed * deltaTime) / 1.65) % (math.pi * 2)
				pedalRotation	= pedalRotation + ((speed * deltaTime) / 3.3) % (math.pi * 2)
			end
			
			tilt	= Lerp(tilt, -localVelocity.X / 15, math.min(deltaTime * 5, 1))
			
			-- bike visuals
			bike.Frame.CFrame	= CFrame.new(character.Position) * bikeCFrame * CFrame.new(0, -2, 0) * CFrame.Angles(0, 0, tilt) * CFrame.new(0, 2, 0)
			bike.Forks.CFrame	= bike.Frame.CFrame * bike.Frame.Front.CFrame * bike.Forks.Center.CFrame:Inverse() * CFrame.Angles(0, tilt * 2, 0)
			
			if currentTrick then
				if tick() - currentTrick.Start > currentTrick.Length then
					currentTrick	= nil
				else
					currentTrick:UpdateBike()
				end
			end
			
			bike.BackWheel.CFrame	= bike.Frame.CFrame * bike.Frame.BackWheel.CFrame * CFrame.Angles(-wheelRotation, 0, 0)
			bike.FrontWheel.CFrame	= bike.Forks.CFrame * bike.Forks.FrontWheel.CFrame * CFrame.Angles(-wheelRotation, 0, 0)
			
			bike.Pedals.CFrame		= bike.Frame.CFrame * bike.Frame.Pedals.CFrame * CFrame.Angles(-pedalRotation, 0, 0)
			bike.RightPedal.CFrame	= bike.Pedals.CFrame * CFrame.new(0.8, 0, -1) * CFrame.Angles(pedalRotation, 0, 0)
			bike.LeftPedal.CFrame	= bike.Pedals.CFrame * CFrame.new(-0.8, 0, 1) * CFrame.Angles(pedalRotation, 0, 0)
			
			bike.Handlebars.CFrame	= bike.Forks.CFrame * CFrame.new(0, 1.95, -0.05)
			bike.Grips.CFrame		= bike.Handlebars.CFrame * CFrame.new(0, 0.45, 0.05)
			bike.Gear.CFrame		= bike.Frame.CFrame * CFrame.new(0.2, -1.2, 0.15) * CFrame.Angles(-pedalRotation, 0, 0)
			bike.Seat.CFrame		= bike.Frame.CFrame * CFrame.new(0, 1, 1)
			
			bike.BackSpokes.CFrame	= bike.BackWheel.CFrame
			bike.FrontSpokes.CFrame	= bike.FrontWheel.CFrame
			
			-- character
			
			char.RightFoot.CFrame	= bike.RightPedal.CFrame * CFrame.new(0, 0.25, 0)
			char.LeftFoot.CFrame	= bike.LeftPedal.CFrame * CFrame.new(0, 0.25, 0)
			
			char.RightHand.CFrame	= bike.Grips.CFrame * CFrame.new(1.5, 0, 0) * CFrame.Angles(math.pi / 4, 0, 0)
			char.LeftHand.CFrame	= bike.Grips.CFrame * CFrame.new(-1.5, 0, 0) * CFrame.Angles(math.pi / 4, 0, 0)
			
			local seatVelocity		= (bike.Frame.Seat.WorldPosition - lastPosition) / deltaTime
			local acceleration		= (seatVelocity - lastVelocity)
			lastPosition			= bike.Frame.Seat.WorldPosition
			
			charSpring:Shove(-acceleration)
			charSpring:Update(deltaTime)
			local position		= bike.Frame.Seat.WorldCFrame:vectorToObjectSpace(charSpring.Position)
			
			char.Hips.CFrame		= bike.Frame.Seat.WorldCFrame * CFrame.new(Vector3.new(-position.X, math.max(position.Y, -0.8 / 0.1), position.Z) * 0.1)
			char.Torso.CFrame		= char.Hips.CFrame * CFrame.new(0, char.Hips.Size.Y / 2, 0) * CFrame.Angles(-math.pi / 8 - position.Z * 0.05, 0, tilt * 0.2) * CFrame.new(0, char.Torso.Size.Y / 2, 0)
			char.Head.CFrame		= char.Torso.CFrame * CFrame.new(0, 2.1, 0) * CFrame.Angles(0, tilt * 2, 0)
			
			if currentTrick then
				currentTrick:UpdateChar()
			end
			
			do
				local leg, foreleg, foot	= char.RightLeg, char.RightForeleg, char.RightFoot
				local hipCFrame		= char.Hips.CFrame * CFrame.new(0.6, -0.3, 0)
				local footCFrame	= foot.CFrame * CFrame.new(0, 0.1, 0.2)
				
				local distance		= (hipCFrame.p - footCFrame.p).Magnitude
				
				local a, b, c	= foreleg.Size.Y, leg.Size.Y, math.min(distance, leg.Size.Y + foreleg.Size.Y)
				local A			= math.acos((-a^2 + b^2 + c^2) / (2 * b * c))
				local C			= math.acos((a^2 + b^2 - c^2) / (2 * a * b))
				
				local offsetA	= hipCFrame:toObjectSpace(footCFrame)
				local x			= math.atan2(offsetA.X, -offsetA.Y)
				hipCFrame		= hipCFrame * CFrame.Angles(0, 0, x)
				local offsetB	= hipCFrame:toObjectSpace(footCFrame)
				local y			= math.atan2(-offsetB.Z, -offsetB.Y)
				hipCFrame		= hipCFrame * CFrame.Angles(y, 0, 0)
				
				leg.CFrame		= hipCFrame * CFrame.Angles(A, 0, 0) * CFrame.new(0, -leg.Size.Y / 2, 0)
				foreleg.CFrame	= leg.CFrame * CFrame.new(0, -leg.Size.Y / 2, 0) * CFrame.Angles(C - math.pi, 0, 0) * CFrame.new(0, -foreleg.Size.Y / 2, 0)
			end
			
			do
				local leg, foreleg, foot	= char.LeftLeg, char.LeftForeleg, char.LeftFoot
				local hipCFrame		= char.Hips.CFrame * CFrame.new(-0.6, -0.3, 0)
				local footCFrame	= foot.CFrame * CFrame.new(0, 0.1, 0.2)
				
				local distance		= (hipCFrame.p - footCFrame.p).Magnitude
				
				local a, b, c	= foreleg.Size.Y, leg.Size.Y, math.min(distance, leg.Size.Y + foreleg.Size.Y)
				local A			= math.acos((-a^2 + b^2 + c^2) / (2 * b * c))
				local C			= math.acos((a^2 + b^2 - c^2) / (2 * a * b))
				
				if A ~= A then
					A = 0
				end
				if C ~= C then
					C = 0
				end
				
				local offsetA	= hipCFrame:toObjectSpace(footCFrame)
				local x			= math.atan2(offsetA.X, -offsetA.Y)
				hipCFrame		= hipCFrame * CFrame.Angles(0, 0, x)
				local offsetB	= hipCFrame:toObjectSpace(footCFrame)
				local y			= math.atan2(-offsetB.Z, -offsetB.Y)
				hipCFrame		= hipCFrame * CFrame.Angles(y, 0, 0)
				
				leg.CFrame		= hipCFrame * CFrame.Angles(A, 0, 0) * CFrame.new(0, -leg.Size.Y / 2, 0)
				foreleg.CFrame	= leg.CFrame * CFrame.new(0, -leg.Size.Y / 2, 0) * CFrame.Angles(C - math.pi, 0, 0) * CFrame.new(0, -foreleg.Size.Y / 2, 0)
			end
			
			do
				local arm, forearm, hand	= char.RightArm, char.RightForearm, char.RightHand
				local shoulderCFrame	= char.Torso.CFrame * CFrame.new(0.9, 1, 0)
				local handCFrame		= hand.CFrame * CFrame.new(0, hand.Size.Y / 2, 0)
				
				local distance		= (shoulderCFrame.p - handCFrame.p).Magnitude
				
				local a, b, c	= forearm.Size.Y, arm.Size.Y, math.min(distance, arm.Size.Y + forearm.Size.Y)
				local A			= math.acos((-a^2 + b^2 + c^2) / (2 * b * c))
				local C			= math.acos((a^2 + b^2 - c^2) / (2 * a * b))
				
				if A ~= A then
					A = 0
				end
				if C ~= C then
					C = 0
				end
				
				local offsetB	= shoulderCFrame:toObjectSpace(handCFrame)
				local y			= math.atan2(-offsetB.Z, -offsetB.Y)
				shoulderCFrame		= shoulderCFrame * CFrame.Angles(y, 0, 0)
				local offsetA	= shoulderCFrame:toObjectSpace(handCFrame)
				local x			= math.atan2(offsetA.X, -offsetA.Y)
				shoulderCFrame		= shoulderCFrame * CFrame.Angles(0, 0, x)
				
				shoulderCFrame	= shoulderCFrame * CFrame.Angles(0, math.abs(position.X * 0.1), 0)
				
				arm.CFrame		= shoulderCFrame * CFrame.Angles(-A, 0, 0) * CFrame.new(0, -arm.Size.Y / 2, 0)
				forearm.CFrame	= arm.CFrame * CFrame.new(0, -arm.Size.Y / 2, 0) * CFrame.Angles(math.pi - C, 0, 0) * CFrame.new(0, -forearm.Size.Y / 2, 0)
			end
			
			do
				local arm, forearm, hand	= char.LeftArm, char.LeftForearm, char.LeftHand
				local shoulderCFrame	= char.Torso.CFrame * CFrame.new(-0.9, 1, 0)
				local handCFrame		= hand.CFrame * CFrame.new(0, hand.Size.Y / 2, 0)
				
				local distance		= (shoulderCFrame.p - handCFrame.p).Magnitude
				
				local a, b, c	= forearm.Size.Y, arm.Size.Y, math.min(distance, arm.Size.Y + forearm.Size.Y)
				local A			= math.acos((-a^2 + b^2 + c^2) / (2 * b * c))
				local C			= math.acos((a^2 + b^2 - c^2) / (2 * a * b))
				
				if A ~= A then
					A = 0
				end
				if C ~= C then
					C = 0
				end
				
				local offsetB	= shoulderCFrame:toObjectSpace(handCFrame)
				local y			= math.atan2(-offsetB.Z, -offsetB.Y)
				shoulderCFrame		= shoulderCFrame * CFrame.Angles(y, 0, 0)
				local offsetA	= shoulderCFrame:toObjectSpace(handCFrame)
				local x			= math.atan2(offsetA.X, -offsetA.Y)
				shoulderCFrame		= shoulderCFrame * CFrame.Angles(0, 0, x)
				
				shoulderCFrame	= shoulderCFrame * CFrame.Angles(0, -math.abs(position.X * 0.1), 0)
				
				arm.CFrame		= shoulderCFrame * CFrame.Angles(-A, 0, 0) * CFrame.new(0, -arm.Size.Y / 2, 0)
				forearm.CFrame	= arm.CFrame * CFrame.new(0, -arm.Size.Y / 2, 0) * CFrame.Angles(math.pi - C, 0, 0) * CFrame.new(0, -forearm.Size.Y / 2, 0)
			end
			
			--[[if acceleration.Magnitude / deltaTime > 4000 then
				RunService:UnbindFromRenderStep(character.Name .. "Bike")
				Wipeout()
			end]]
			
			lastVelocity	= seatVelocity
		else
			bike:Destroy()
			char:Destroy()
			RunService:UnbindFromRenderStep(character.Name .. "Bike")
		end
	end)
	
	-- events
	EVENTS.Trick.Event:connect(function(c, trick)
		if c == character and not currentTrick then
			trick	= require(TRICKS[trick])
			currentTrick	= trick:Create(character, char, bike)
		end
	end)
end

return BIKE