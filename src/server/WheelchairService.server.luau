--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local RojoShared = ReplicatedStorage:WaitForChild("RojoShared")
local WheelchairConfig = require(RojoShared:WaitForChild("WheelchairConfig"))

type DriveInput = WheelchairConfig.DriveInput

type PlayerState = {
	vehicle: Model?,
	rootPart: BasePart?,
	seat: VehicleSeat?,
	driveInput: DriveInput,
	lastInputAt: number,
	lastInputDebugKey: string,
	groundNormal: Vector3,
	jumpQueued: boolean,
	lastJumpAt: number,
	lastMovementDebugAt: number,
}

local playerStates: { [Player]: PlayerState } = {}

local blockedAccessoryTypes = {
	[Enum.AccessoryType.Hat] = true,
	[Enum.AccessoryType.Back] = true,
	[Enum.AccessoryType.Waist] = true,
	[Enum.AccessoryType.Shoulder] = true,
	[Enum.AccessoryType.Front] = true,
	[Enum.AccessoryType.Neck] = true,
	[Enum.AccessoryType.Face] = true,
}

local function getDefaultDriveInput(): DriveInput
	return WheelchairConfig.sanitizeDriveInput(nil)
end

local function getPlayerState(player: Player): PlayerState
	local state = playerStates[player]

	if state == nil then
		state = {
			vehicle = nil,
			rootPart = nil,
			seat = nil,
			driveInput = getDefaultDriveInput(),
			lastInputAt = 0,
			lastInputDebugKey = "",
			groundNormal = Vector3.yAxis,
			jumpQueued = false,
			lastJumpAt = 0,
			lastMovementDebugAt = 0,
		}

		playerStates[player] = state
	end

	return state
end

local function getSharedFolder(): Folder
	local sharedFolder = ReplicatedStorage:WaitForChild(WheelchairConfig.SharedFolderName)

	assert(sharedFolder:IsA("Folder"), "RojoShared must be a Folder")

	return sharedFolder :: Folder
end

local function getOrCreateRemoteFolder(): Folder
	local sharedFolder = getSharedFolder()
	local existingFolder = sharedFolder:FindFirstChild(WheelchairConfig.RemoteFolderName)

	if existingFolder ~= nil then
		assert(existingFolder:IsA("Folder"), "WheelchairRemotes must be a Folder")
		return existingFolder :: Folder
	end

	local folder = Instance.new("Folder")
	folder.Name = WheelchairConfig.RemoteFolderName
	folder.Parent = sharedFolder

	return folder
end

local function getOrCreateDriveInputRemote(): RemoteEvent
	local remoteFolder = getOrCreateRemoteFolder()
	local existingRemote = remoteFolder:FindFirstChild(WheelchairConfig.DriveInputRemoteName)

	if existingRemote ~= nil then
		assert(existingRemote:IsA("RemoteEvent"), "WheelchairDriveInput must be a RemoteEvent")
		return existingRemote :: RemoteEvent
	end

	local remote = Instance.new("RemoteEvent")
	remote.Name = WheelchairConfig.DriveInputRemoteName
	remote.Parent = remoteFolder

	return remote
end

local function getOrCreateWorkspaceFolder(): Folder
	local existingFolder = Workspace:FindFirstChild(WheelchairConfig.WorkspaceFolderName)

	if existingFolder ~= nil then
		assert(existingFolder:IsA("Folder"), "Workspace.Wheelchairs must be a Folder")
		return existingFolder :: Folder
	end

	local folder = Instance.new("Folder")
	folder.Name = WheelchairConfig.WorkspaceFolderName
	folder.Parent = Workspace

	return folder
end

local function findWheelchairTemplate(): Model?
	local templateName = WheelchairConfig.Model.TemplateName
	local candidates = {
		ServerStorage,
		ReplicatedStorage,
		getSharedFolder(),
		Workspace,
	}

	for _, container in ipairs(candidates) do
		local candidate = container:FindFirstChild(templateName)

		if candidate ~= nil and candidate:IsA("Model") then
			return candidate
		end
	end

	return nil
end

local function ensureWeld(rootPart: BasePart, part: BasePart)
	if part == rootPart then
		return
	end

	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("WeldConstraint") then
			if
				(child.Part0 == rootPart and child.Part1 == part)
				or (child.Part0 == part and child.Part1 == rootPart)
			then
				return
			end
		end
	end

	local weld = Instance.new("WeldConstraint")
	weld.Name = "WheelchairRootWeld"
	weld.Part0 = rootPart
	weld.Part1 = part
	weld.Parent = part
end

local function createDebugPart(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	parent: Instance
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Anchored = false
	part.CanCollide = false
	part.Massless = true
	part.Parent = parent

	return part
end

local function createDebugWheelchair(): Model
	local model = Instance.new("Model")
	model.Name = WheelchairConfig.Model.TemplateName

	local rootPart = Instance.new("Part")
	rootPart.Name = WheelchairConfig.Model.RootPartName
	rootPart.Size = Vector3.new(4, 1, 5)
	rootPart.Transparency = WheelchairConfig.Model.RootTransparency
	rootPart.Anchored = false
	rootPart.CanCollide = true
	rootPart.Massless = false
	rootPart.CustomPhysicalProperties = PhysicalProperties.new(1.2, 0.05, 0.05, 1, 1)
	rootPart.Parent = model

	local seat = Instance.new("VehicleSeat")
	seat.Name = WheelchairConfig.Model.SeatName
	seat.Size = Vector3.new(2, 0.4, 2)
	seat.CFrame = rootPart.CFrame * CFrame.new(0, 1.1, -0.2)
	seat.Transparency = 0.35
	seat.Anchored = false
	seat.CanCollide = false
	seat.Massless = true
	seat.Disabled = false
	seat.Parent = model

	createDebugPart(
		"VisualBase",
		Vector3.new(4.3, 0.3, 4.2),
		rootPart.CFrame * CFrame.new(0, 0.65, 0),
		Color3.fromRGB(54, 61, 71),
		model
	)

	createDebugPart(
		"VisualBackRest",
		Vector3.new(3.4, 3, 0.3),
		rootPart.CFrame * CFrame.new(0, 1.9, 1.65) * CFrame.Angles(math.rad(8), 0, 0),
		Color3.fromRGB(71, 84, 98),
		model
	)

	local leftWheel = createDebugPart(
		"LeftWheel",
		Vector3.new(2.4, 0.28, 2.4),
		rootPart.CFrame * CFrame.new(-2.25, 0.05, 0.55) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(24, 27, 33),
		model
	)
	leftWheel.Shape = Enum.PartType.Cylinder

	local rightWheel = createDebugPart(
		"RightWheel",
		Vector3.new(2.4, 0.28, 2.4),
		rootPart.CFrame * CFrame.new(2.25, 0.05, 0.55) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(24, 27, 33),
		model
	)
	rightWheel.Shape = Enum.PartType.Cylinder

	local leftCaster = createDebugPart(
		"LeftCaster",
		Vector3.new(0.7, 0.18, 0.7),
		rootPart.CFrame * CFrame.new(-1.35, -0.2, -1.75) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(32, 36, 43),
		model
	)
	leftCaster.Shape = Enum.PartType.Cylinder

	local rightCaster = createDebugPart(
		"RightCaster",
		Vector3.new(0.7, 0.18, 0.7),
		rootPart.CFrame * CFrame.new(1.35, -0.2, -1.75) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(32, 36, 43),
		model
	)
	rightCaster.Shape = Enum.PartType.Cylinder

	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") then
			ensureWeld(rootPart, part)
		end
	end

	model.PrimaryPart = rootPart
	return model
end

local function findVehiclePart(model: Model, partName: string): BasePart?
	local instance = model:FindFirstChild(partName, true)

	if instance ~= nil and instance:IsA("BasePart") then
		return instance
	end

	return nil
end

local function findVehicleSeat(model: Model): VehicleSeat?
	local namedSeat = model:FindFirstChild(WheelchairConfig.Model.SeatName, true)

	if namedSeat ~= nil and namedSeat:IsA("VehicleSeat") then
		return namedSeat
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("VehicleSeat") then
			return descendant
		end
	end

	return nil
end

local function getNetworkOwnerName(rootPart: BasePart): string
	local success, owner = pcall(function()
		return rootPart:GetNetworkOwner()
	end)

	if not success then
		return "unknown"
	end

	if owner == nil then
		return "server"
	end

	return owner.Name
end

local function setServerNetworkOwner(player: Player, rootPart: BasePart, context: string)
	local success, errorMessage = pcall(function()
		rootPart:SetNetworkOwner(nil)
	end)

	if success then
		WheelchairConfig.debugPrint(
			"Network owner set to server",
			context,
			player.Name,
			"owner=",
			getNetworkOwnerName(rootPart)
		)
	else
		WheelchairConfig.debugWarn(
			"Could not set server network ownership",
			context,
			player.Name,
			errorMessage
		)
	end
end

local function configureVehicleModel(player: Player, model: Model): (BasePart?, VehicleSeat?)
	local rootPart = findVehiclePart(model, WheelchairConfig.Model.RootPartName)

	if rootPart == nil then
		WheelchairConfig.debugWarn(
			"Wheelchair model is missing root part:",
			WheelchairConfig.Model.RootPartName
		)
		return nil, nil
	end

	local seat = findVehicleSeat(model)

	if seat == nil then
		WheelchairConfig.debugWarn(
			"Wheelchair model is missing VehicleSeat:",
			WheelchairConfig.Model.SeatName
		)
		return nil, nil
	end

	model.PrimaryPart = rootPart
	model:SetAttribute(WheelchairConfig.Model.IsWheelchairAttribute, true)
	model:SetAttribute(WheelchairConfig.Model.OwnerUserIdAttribute, player.UserId)
	model:SetAttribute(WheelchairConfig.Model.OwnerNameAttribute, player.Name)

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false

			if descendant == rootPart then
				descendant.CanCollide = true
				descendant.Massless = false
				descendant.Transparency = WheelchairConfig.Model.RootTransparency
				descendant.CustomPhysicalProperties = PhysicalProperties.new(1.2, 0.05, 0.05, 1, 1)
			else
				descendant.CanCollide = false
				descendant.Massless = true
				ensureWeld(rootPart, descendant)
			end
		end
	end

	seat.Disabled = false

	setServerNetworkOwner(player, rootPart, "configure")

	return rootPart, seat
end

local function logPartTransform(label: string, part: BasePart?)
	if part == nil then
		WheelchairConfig.debugWarn("Spawn diagnostics:", label, "is missing")
		return
	end

	WheelchairConfig.debugPrint(
		"Spawn diagnostics:",
		label,
		"Name=",
		part.Name,
		"CFrame=",
		part.CFrame,
		"Orientation=",
		part.Orientation,
		"LookVector=",
		part.CFrame.LookVector
	)
end

local function logSpawnDiagnostics(
	player: Player,
	model: Model,
	rootPart: BasePart,
	seat: VehicleSeat
)
	local primaryPart = model.PrimaryPart

	WheelchairConfig.debugPrint(
		"Spawn diagnostics for",
		player.Name,
		"rootPart=",
		rootPart.Name,
		"seat=",
		seat.Name,
		"primaryPart=",
		if primaryPart ~= nil then primaryPart.Name else "nil"
	)

	logPartTransform("Frame", rootPart)
	logPartTransform("VehicleSeat", seat)
	logPartTransform("PrimaryPart", primaryPart)

	WheelchairConfig.debugPrint(
		"Spawn diagnostics: root physics",
		"AssemblyMass=",
		rootPart.AssemblyMass,
		"CanCollide=",
		rootPart.CanCollide,
		"Massless=",
		rootPart.Massless,
		"Anchored=",
		rootPart.Anchored
	)

	local seatForwardAlignment = rootPart.CFrame.LookVector:Dot(seat.CFrame.LookVector)

	if math.abs(seatForwardAlignment) < 0.75 then
		WheelchairConfig.debugWarn(
			"Frame.LookVector is not aligned with VehicleSeat.LookVector. Camera and movement use Frame.LookVector.",
			"Dot=",
			seatForwardAlignment
		)
	end
end

local function destroyPlayerVehicle(player: Player)
	local state = getPlayerState(player)

	if state.vehicle ~= nil then
		state.vehicle:Destroy()
		WheelchairConfig.debugPrint("Destroyed old wheelchair for", player.Name)
	end

	state.vehicle = nil
	state.rootPart = nil
	state.seat = nil
	state.driveInput = getDefaultDriveInput()
	state.jumpQueued = false
end

local function setDescriptionProperty(
	description: HumanoidDescription,
	propertyName: string,
	value: any
)
	local success = pcall(function()
		(description :: any)[propertyName] = value
	end)

	if not success then
		WheelchairConfig.debugWarn("Could not set HumanoidDescription property:", propertyName)
	end
end

local function cleanHumanoidDescription(description: HumanoidDescription): HumanoidDescription
	local cleanedDescription = description:Clone() :: HumanoidDescription

	for _, fieldName in ipairs(WheelchairConfig.Avatar.AccessoryDescriptionFieldsToClear) do
		setDescriptionProperty(cleanedDescription, fieldName, "")
	end

	if WheelchairConfig.Avatar.ResetBodyPackages then
		for _, fieldName in ipairs(WheelchairConfig.Avatar.BodyPartFieldsToReset) do
			setDescriptionProperty(cleanedDescription, fieldName, 0)
		end
	end

	for propertyName, value in pairs(WheelchairConfig.Avatar.ScaleProperties) do
		setDescriptionProperty(cleanedDescription, propertyName, value)
	end

	return cleanedDescription
end

local function removeBlockedAccessories(character: Model)
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Accessory") and blockedAccessoryTypes[child.AccessoryType] then
			child:Destroy()
		end
	end
end

local function removeTools(player: Player, character: Model)
	if not WheelchairConfig.Avatar.RemoveTools then
		return
	end

	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			child:Destroy()
		end
	end

	local backpack = player:FindFirstChildOfClass("Backpack")

	if backpack == nil then
		return
	end

	for _, child in ipairs(backpack:GetChildren()) do
		if child:IsA("Tool") then
			child:Destroy()
		end
	end
end

local function disableSeatExitJump(humanoid: Humanoid)
	humanoid.Jump = false
	humanoid.AutoRotate = false

	pcall(function()
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	end)

	pcall(function()
		humanoid.UseJumpPower = true
		humanoid.JumpPower = 0
	end)

	pcall(function()
		humanoid.JumpHeight = 0
	end)
end

local function cleanAvatar(player: Player, character: Model, humanoid: Humanoid)
	task.wait(WheelchairConfig.Avatar.DescriptionApplyDelay)

	local success, appliedDescription = pcall(function()
		return humanoid:GetAppliedDescription()
	end)

	if success and appliedDescription ~= nil then
		local cleanedDescription = cleanHumanoidDescription(appliedDescription)
		local applySuccess, applyError = pcall(function()
			humanoid:ApplyDescription(cleanedDescription)
		end)

		if applySuccess then
			WheelchairConfig.debugPrint("Cleaned avatar for", player.Name)
		else
			WheelchairConfig.debugWarn(
				"Failed to apply cleaned avatar for",
				player.Name,
				applyError
			)
		end
	else
		WheelchairConfig.debugWarn("Could not read avatar description for", player.Name)
	end

	removeBlockedAccessories(character)
	removeTools(player, character)

	if humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		WheelchairConfig.debugWarn(
			player.Name,
			"is not using R15. Wheelchair seating is tuned for normal R15 avatars."
		)
	end

	disableSeatExitJump(humanoid)
end

local function getSpawnCFrame(characterRootPart: BasePart): CFrame
	local lookVector = characterRootPart.CFrame.LookVector
	local flatLookVector = Vector3.new(lookVector.X, 0, lookVector.Z)

	if flatLookVector.Magnitude < 0.05 then
		flatLookVector = Vector3.zAxis * -1
	else
		flatLookVector = flatLookVector.Unit
	end

	local spawnPosition = characterRootPart.Position
		+ Vector3.new(0, WheelchairConfig.Spawn.SpawnHeightOffset, 0)

	return CFrame.lookAt(spawnPosition, spawnPosition + flatLookVector)
end

local function spawnWheelchairForPlayer(
	player: Player,
	_character: Model,
	humanoid: Humanoid,
	characterRootPart: BasePart
)
	destroyPlayerVehicle(player)

	local template = findWheelchairTemplate()
	local vehicle: Model

	if template ~= nil then
		vehicle = template:Clone()
		WheelchairConfig.debugPrint("Cloned Wheelchair template for", player.Name)
	elseif WheelchairConfig.Spawn.UseDebugFallback then
		vehicle = createDebugWheelchair()
		WheelchairConfig.debugWarn(
			"No Wheelchair template found. Created debug fallback for",
			player.Name
		)
	else
		WheelchairConfig.debugWarn("No Wheelchair template found, and debug fallback is disabled.")
		return
	end

	vehicle.Name = player.Name .. "_Wheelchair"
	vehicle.Parent = getOrCreateWorkspaceFolder()

	local rootPart, seat = configureVehicleModel(player, vehicle)

	if rootPart == nil or seat == nil then
		vehicle:Destroy()
		return
	end

	vehicle:PivotTo(getSpawnCFrame(characterRootPart))
	logSpawnDiagnostics(player, vehicle, rootPart, seat)

	local state = getPlayerState(player)
	state.vehicle = vehicle
	state.rootPart = rootPart
	state.seat = seat
	state.groundNormal = Vector3.yAxis
	state.driveInput = getDefaultDriveInput()
	state.lastMovementDebugAt = 0

	task.delay(WheelchairConfig.Spawn.SeatDelay, function()
		if humanoid.Parent == nil or seat.Parent == nil or rootPart.Parent == nil then
			return
		end

		disableSeatExitJump(humanoid)
		seat:Sit(humanoid)
		setServerNetworkOwner(player, rootPart, "after seat")

		task.delay(0.2, function()
			if rootPart.Parent == nil then
				return
			end

			setServerNetworkOwner(player, rootPart, "after seat delay")
		end)

		WheelchairConfig.debugPrint("Seated", player.Name, "in wheelchair")
	end)

	WheelchairConfig.debugPrint("Spawned wheelchair for", player.Name)
end

local function isPlayerSeatedInOwnWheelchair(player: Player, state: PlayerState): boolean
	local character = player.Character

	if character == nil then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if humanoid == nil then
		return false
	end

	if state.seat == nil then
		return false
	end

	return humanoid.SeatPart == state.seat
end

local function buildRaycastParams(player: Player, state: PlayerState): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	local filterInstances: { Instance } = {}

	if state.vehicle ~= nil then
		table.insert(filterInstances, state.vehicle)
	end

	if player.Character ~= nil then
		table.insert(filterInstances, player.Character)
	end

	params.FilterDescendantsInstances = filterInstances

	return params
end

local function getPlanarVector(vector: Vector3, normal: Vector3): Vector3
	return vector - normal * vector:Dot(normal)
end

local function getStableForward(rootPart: BasePart, normal: Vector3): Vector3
	local forward = getPlanarVector(rootPart.CFrame.LookVector, normal)

	if forward.Magnitude < 0.05 then
		forward = getPlanarVector(Vector3.zAxis * -1, normal)
	end

	if forward.Magnitude < 0.05 then
		return Vector3.zAxis * -1
	end

	return forward.Unit
end

local function getGroundInfo(
	player: Player,
	state: PlayerState,
	rootPart: BasePart,
	deltaTime: number
): (boolean, Vector3)
	local rayOrigin = rootPart.Position
	local rayDirection = -state.groundNormal.Unit * WheelchairConfig.Movement.GroundRayLength
	local result = Workspace:Raycast(rayOrigin, rayDirection, buildRaycastParams(player, state))

	if result == nil then
		local fallbackNormal =
			state.groundNormal:Lerp(Vector3.yAxis, math.clamp(deltaTime * 2, 0, 1))
		state.groundNormal = fallbackNormal.Unit
		return false, state.groundNormal
	end

	local distance = (result.Position - rayOrigin).Magnitude
	local grounded = distance <= WheelchairConfig.Movement.GroundedDistance
	local lerpSpeed = WheelchairConfig.Movement.GroundNormalLerpSpeed

	state.groundNormal =
		state.groundNormal:Lerp(result.Normal, math.clamp(deltaTime * lerpSpeed, 0, 1)).Unit

	return grounded, state.groundNormal
end

local function stabilizeRoot(rootPart: BasePart, normal: Vector3, deltaTime: number)
	local forward = getStableForward(rootPart, normal)
	local targetCFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + forward, normal)
	local alpha = math.clamp(deltaTime * WheelchairConfig.Movement.OrientationLerpSpeed, 0, 1)

	rootPart.CFrame = rootPart.CFrame:Lerp(targetCFrame, alpha)
end

local function logMovementDiagnostics(
	player: Player,
	state: PlayerState,
	rootPart: BasePart,
	driveInput: DriveInput,
	grounded: boolean,
	groundNormal: Vector3,
	targetPlanarVelocity: Vector3,
	newPlanarVelocity: Vector3
)
	local interval = WheelchairConfig.Movement.DebugLogInterval

	if interval <= 0 then
		return
	end

	local now = os.clock()

	if now - state.lastMovementDebugAt < interval then
		return
	end

	state.lastMovementDebugAt = now

	local actualVelocity = rootPart.AssemblyLinearVelocity
	local actualPlanarVelocity = getPlanarVector(actualVelocity, groundNormal)

	WheelchairConfig.debugPrint(
		"Movement diagnostics",
		player.Name,
		"owner=",
		getNetworkOwnerName(rootPart),
		"grounded=",
		grounded,
		"input=",
		string.format(
			"t=%.1f,s=%.1f,j=%s",
			driveInput.throttle,
			driveInput.steer,
			tostring(driveInput.jump)
		),
		"targetPlanarSpeed=",
		targetPlanarVelocity.Magnitude,
		"newPlanarSpeed=",
		newPlanarVelocity.Magnitude,
		"actualPlanarSpeed=",
		actualPlanarVelocity.Magnitude,
		"actualVelocity=",
		actualVelocity,
		"assemblyMass=",
		rootPart.AssemblyMass
	)
end

local function applyWheelchairMovement(player: Player, state: PlayerState, deltaTime: number)
	local rootPart = state.rootPart

	if rootPart == nil or rootPart.Parent == nil then
		return
	end

	if not isPlayerSeatedInOwnWheelchair(player, state) then
		state.driveInput = getDefaultDriveInput()
		state.jumpQueued = false
		return
	end

	local grounded, groundNormal = getGroundInfo(player, state, rootPart, deltaTime)
	local driveInput = state.driveInput
	local movement = WheelchairConfig.Movement
	local currentVelocity = rootPart.AssemblyLinearVelocity
	local planarVelocity = getPlanarVector(currentVelocity, groundNormal)
	local verticalVelocity = currentVelocity - planarVelocity
	local maxSpeed = movement.MaxSpeed

	if driveInput.throttle < 0 then
		maxSpeed *= movement.ReverseSpeedMultiplier
	end

	local forward = getStableForward(rootPart, groundNormal)
	local targetPlanarVelocity = forward * (driveInput.throttle * maxSpeed)
	local acceleration = if driveInput.throttle == 0
		then movement.CoastDeceleration
		else movement.Acceleration
	local blend = math.clamp((deltaTime * acceleration) / math.max(maxSpeed, 1), 0, 1)
	local newPlanarVelocity = planarVelocity:Lerp(targetPlanarVelocity, blend)

	if newPlanarVelocity.Magnitude > movement.MaxPlanarVelocity then
		newPlanarVelocity = newPlanarVelocity.Unit * movement.MaxPlanarVelocity
	end

	rootPart.AssemblyLinearVelocity = newPlanarVelocity + verticalVelocity

	local speedRatio =
		math.clamp(newPlanarVelocity.Magnitude / math.max(movement.MaxSpeed, 1), 0, 1)
	local turnVelocity = groundNormal
		* (driveInput.steer * movement.TurnRate * math.max(speedRatio, 0.25))

	if turnVelocity.Magnitude > movement.MaxAngularVelocity then
		turnVelocity = turnVelocity.Unit * movement.MaxAngularVelocity
	end

	rootPart.AssemblyAngularVelocity = turnVelocity

	if movement.EnableOrientationStabilization then
		if grounded then
			stabilizeRoot(rootPart, groundNormal, deltaTime)
		else
			stabilizeRoot(rootPart, Vector3.yAxis, deltaTime * 0.35)
		end
	end

	logMovementDiagnostics(
		player,
		state,
		rootPart,
		driveInput,
		grounded,
		groundNormal,
		targetPlanarVelocity,
		newPlanarVelocity
	)

	if state.jumpQueued and movement.EnableJump and grounded then
		local now = os.clock()

		if now - state.lastJumpAt >= movement.JumpCooldown then
			local velocity = rootPart.AssemblyLinearVelocity
			rootPart.AssemblyLinearVelocity =
				Vector3.new(velocity.X, math.max(velocity.Y, movement.JumpSpeed), velocity.Z)
			state.lastJumpAt = now
			WheelchairConfig.debugPrint("Wheelchair jump for", player.Name)
		end
	end

	state.jumpQueued = false
end

local function canAcceptInput(
	state: PlayerState,
	nextInput: DriveInput,
	isJumpEdge: boolean
): boolean
	if isJumpEdge then
		return true
	end

	if not WheelchairConfig.hasActiveInput(nextInput) then
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

local function getDebugInputKey(input: DriveInput): string
	return string.format("t=%.1f,s=%.1f,j=%s", input.throttle, input.steer, tostring(input.jump))
end

local function onDriveInput(player: Player, input: unknown)
	local state = getPlayerState(player)
	local nextInput = WheelchairConfig.sanitizeDriveInput(input)
	local isJumpEdge = nextInput.jump and not state.driveInput.jump

	if not canAcceptInput(state, nextInput, isJumpEdge) then
		return
	end

	if not isPlayerSeatedInOwnWheelchair(player, state) then
		state.driveInput = getDefaultDriveInput()
		state.jumpQueued = false
		return
	end

	if isJumpEdge then
		state.jumpQueued = true
	end

	state.driveInput = nextInput

	local debugKey = getDebugInputKey(nextInput)

	if debugKey ~= state.lastInputDebugKey then
		state.lastInputDebugKey = debugKey
		WheelchairConfig.debugPrint("Input from", player.Name, debugKey)
	end
end

local function handleCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local characterRootPart = character:WaitForChild("HumanoidRootPart", 10)

	if humanoid == nil or characterRootPart == nil then
		WheelchairConfig.debugWarn(
			"Character missing Humanoid or HumanoidRootPart for",
			player.Name
		)
		return
	end

	if not humanoid:IsA("Humanoid") or not characterRootPart:IsA("BasePart") then
		WheelchairConfig.debugWarn("Invalid character parts for", player.Name)
		return
	end

	cleanAvatar(player, character, humanoid)
	spawnWheelchairForPlayer(player, character, humanoid, characterRootPart)
end

local function onPlayerAdded(player: Player)
	getPlayerState(player)

	player.CharacterAdded:Connect(function(character: Model)
		task.defer(handleCharacter, player, character)
	end)

	player.CharacterRemoving:Connect(function()
		destroyPlayerVehicle(player)
	end)

	if player.Character ~= nil then
		task.defer(handleCharacter, player, player.Character)
	end
end

local function start()
	Workspace.Gravity = WheelchairConfig.World.Gravity

	local driveInputRemote = getOrCreateDriveInputRemote()

	driveInputRemote.OnServerEvent:Connect(onDriveInput)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player: Player)
		destroyPlayerVehicle(player)
		playerStates[player] = nil
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		task.defer(onPlayerAdded, player)
	end

	RunService.Heartbeat:Connect(function(deltaTime: number)
		for player, state in pairs(playerStates) do
			applyWheelchairMovement(player, state, deltaTime)
		end
	end)

	WheelchairConfig.debugPrint("WheelchairService started")
end

start()
