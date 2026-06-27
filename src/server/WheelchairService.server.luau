--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RojoShared = ReplicatedStorage:WaitForChild("RojoShared")
local WheelchairConfig = require(RojoShared:WaitForChild("WheelchairConfig"))

type DriveInput = WheelchairConfig.DriveInput

type PlayerState = {
	driveInput: DriveInput,
	lastInputAt: number,
	seat: VehicleSeat?,
}

local WheelchairService = {}

local playerStates: { [Player]: PlayerState } = {}

local function getDefaultDriveInput(): DriveInput
	return WheelchairConfig.sanitizeDriveInput(nil)
end

local function getSharedFolder(): Folder
	local sharedFolder = ReplicatedStorage:WaitForChild(WheelchairConfig.SharedFolderName)

	assert(sharedFolder:IsA("Folder"), "RojoShared must be a Folder")

	return sharedFolder :: Folder
end

local function getOrCreateRemoteFolder(): Folder
	local sharedFolder = getSharedFolder()
	local remotesFolder = sharedFolder:FindFirstChild(WheelchairConfig.RemoteFolderName)

	if remotesFolder ~= nil then
		assert(remotesFolder:IsA("Folder"), "WheelchairRemotes must be a Folder")
		return remotesFolder :: Folder
	end

	local folder = Instance.new("Folder")
	folder.Name = WheelchairConfig.RemoteFolderName
	folder.Parent = sharedFolder

	return folder
end

local function getOrCreateDriveInputRemote(): RemoteEvent
	local remotesFolder = getOrCreateRemoteFolder()
	local remote = remotesFolder:FindFirstChild(WheelchairConfig.DriveInputRemoteName)

	if remote ~= nil then
		assert(remote:IsA("RemoteEvent"), "WheelchairDriveInput must be a RemoteEvent")
		return remote :: RemoteEvent
	end

	local newRemote = Instance.new("RemoteEvent")
	newRemote.Name = WheelchairConfig.DriveInputRemoteName
	newRemote.Parent = remotesFolder

	return newRemote
end

local function getPlayerState(player: Player): PlayerState
	local state = playerStates[player]

	if state == nil then
		state = {
			driveInput = getDefaultDriveInput(),
			lastInputAt = 0,
			seat = nil,
		}

		playerStates[player] = state
	end

	return state
end

local function isWheelchairModel(model: Model): boolean
	return model:GetAttribute("IsWheelchair") == true
		or model.Name == WheelchairConfig.VehicleModelName
		or model.Name == WheelchairConfig.LegacyVehicleModelName
end

local function getCurrentWheelchairSeat(player: Player): VehicleSeat?
	local character = player.Character

	if character == nil then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if humanoid == nil then
		return nil
	end

	local seatPart = humanoid.SeatPart

	if seatPart == nil or not seatPart:IsA("VehicleSeat") then
		return nil
	end

	local vehicleModel = seatPart:FindFirstAncestorWhichIsA("Model")

	if vehicleModel == nil or not isWheelchairModel(vehicleModel) then
		return nil
	end

	local rootPart = vehicleModel:FindFirstChild(WheelchairConfig.RootPartName)

	if rootPart == nil or not rootPart:IsA("BasePart") then
		return nil
	end

	return seatPart
end

local function getWheelchairRootPart(seat: VehicleSeat): BasePart?
	local vehicleModel = seat:FindFirstAncestorWhichIsA("Model")

	if vehicleModel == nil then
		return nil
	end

	local rootPart = vehicleModel:FindFirstChild(WheelchairConfig.RootPartName)

	if rootPart == nil or not rootPart:IsA("BasePart") then
		return nil
	end

	return rootPart
end

local function hasActiveInput(input: DriveInput): boolean
	return input.throttle ~= 0 or input.steer ~= 0 or input.brake
end

local function applyDriveInput(player: Player, state: PlayerState, deltaTime: number)
	local seat = getCurrentWheelchairSeat(player)
	state.seat = seat

	if seat == nil then
		state.driveInput = getDefaultDriveInput()
		return
	end

	local rootPart = getWheelchairRootPart(seat)

	if rootPart == nil then
		return
	end

	local driveInput = state.driveInput
	local movementConfig = WheelchairConfig.Movement
	local currentVelocity = rootPart.AssemblyLinearVelocity
	local horizontalVelocity = Vector3.new(currentVelocity.X, 0, currentVelocity.Z)
	local verticalVelocity = Vector3.new(0, currentVelocity.Y, 0)

	local maxSpeed = movementConfig.MaxSpeed

	if driveInput.throttle < 0 then
		maxSpeed *= movementConfig.ReverseMultiplier
	end

	local targetHorizontalVelocity = rootPart.CFrame.LookVector * (driveInput.throttle * maxSpeed)
	local acceleration = movementConfig.Acceleration

	if driveInput.brake then
		targetHorizontalVelocity = Vector3.zero
		acceleration = movementConfig.BrakeDeceleration
	end

	local blend = math.clamp((deltaTime * acceleration) / math.max(maxSpeed, 1), 0, 1)
	local newHorizontalVelocity = horizontalVelocity:Lerp(targetHorizontalVelocity, blend)

	rootPart.AssemblyLinearVelocity = newHorizontalVelocity + verticalVelocity

	local speedRatio = math.clamp(newHorizontalVelocity.Magnitude / math.max(movementConfig.MaxSpeed, 1), 0, 1)
	local angularVelocity = rootPart.AssemblyAngularVelocity

	rootPart.AssemblyAngularVelocity = Vector3.new(
		angularVelocity.X,
		driveInput.steer * movementConfig.TurnSpeed * speedRatio,
		angularVelocity.Z
	)
end

local function canAcceptInput(state: PlayerState, input: DriveInput): boolean
	if not hasActiveInput(input) then
		state.lastInputAt = os.clock()
		return true
	end

	local now = os.clock()

	if now - state.lastInputAt < WheelchairConfig.Input.MinSendInterval then
		return false
	end

	state.lastInputAt = now
	return true
end

function WheelchairService.start()
	local driveInputRemote = getOrCreateDriveInputRemote()

	driveInputRemote.OnServerEvent:Connect(function(player: Player, input: unknown)
		local state = getPlayerState(player)
		local nextInput = WheelchairConfig.sanitizeDriveInput(input)

		if not canAcceptInput(state, nextInput) then
			return
		end

		if getCurrentWheelchairSeat(player) == nil then
			state.driveInput = getDefaultDriveInput()
			return
		end

		state.driveInput = nextInput
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		playerStates[player] = nil
	end)

	RunService.Heartbeat:Connect(function(deltaTime: number)
		for player, state in pairs(playerStates) do
			applyDriveInput(player, state, deltaTime)
		end
	end)
end

WheelchairService.start()
