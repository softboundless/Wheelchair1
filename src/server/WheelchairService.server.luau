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
	lastOwnershipRefreshAt: number,
	lastReseatAt: number,
}

local playerStates: { [Player]: PlayerState } = {}

local dynamicVisualPartNames = {
	LeftRearWheel = true,
	RightRearWheel = true,
	LeftFrontCaster = true,
	RightFrontCaster = true,
	LeftFrontCasterPivot = true,
	RightFrontCasterPivot = true,

	LeftWheel = true,
	RightWheel = true,
	LeftCaster = true,
	RightCaster = true,
}

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
			lastOwnershipRefreshAt = 0,
			lastReseatAt = 0,
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

local function getOrCreateFolder(parent: Instance, name: string): Folder
	local existingFolder = parent:FindFirstChild(name)

	if existingFolder ~= nil then
		assert(existingFolder:IsA("Folder"), name .. " must be a Folder")
		return existingFolder :: Folder
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent

	return folder
end

local function getOrCreateDriveInputRemote(): RemoteEvent
	local remoteFolder = getOrCreateFolder(getSharedFolder(), WheelchairConfig.RemoteFolderName)
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

local function findWheelchairTemplate(): Model?
	for _, container in ipairs({ ServerStorage, ReplicatedStorage, getSharedFolder(), Workspace }) do
		local template = container:FindFirstChild(WheelchairConfig.Model.TemplateName)

		if template ~= nil and template:IsA("Model") then
			return template
		end
	end

	return nil
end

local function hasRootWeld(rootPart: BasePart, part: BasePart): boolean
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("WeldConstraint") then
			if
				(child.Part0 == rootPart and child.Part1 == part)
				or (child.Part0 == part and child.Part1 == rootPart)
			then
				return true
			end
		end
	end

	return false
end

local function ensureWeld(rootPart: BasePart, part: BasePart)
	if part == rootPart or hasRootWeld(rootPart, part) then
		return
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
	parent: Instance,
	transparency: number?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Transparency = transparency or 0
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
	rootPart.Size = Vector3.new(4.4, 1, 5)
	rootPart.Transparency = WheelchairConfig.Model.RootTransparency
	rootPart.Anchored = false
	rootPart.CanCollide = true
	rootPart.Massless = false
	rootPart.CustomPhysicalProperties = WheelchairConfig.Model.RootPhysicalProperties
	rootPart.Parent = model

	local seat = Instance.new("VehicleSeat")
	seat.Name = WheelchairConfig.Model.SeatName
	seat.Size = Vector3.new(2.3, 0.35, 2)
	seat.CFrame = rootPart.CFrame * CFrame.new(0, 1.05, -0.05)
	seat.Transparency = 0.35
	seat.Anchored = false
	seat.CanCollide = false
	seat.Massless = true
	seat.Disabled = false
	seat.Parent = model

	createDebugPart(
		"SeatCushion",
		Vector3.new(3.1, 0.35, 2.25),
		rootPart.CFrame * CFrame.new(0, 0.7, 0),
		Color3.fromRGB(62, 70, 82),
		model
	)
	createDebugPart(
		"BackRest",
		Vector3.new(3.1, 2.6, 0.3),
		rootPart.CFrame * CFrame.new(0, 1.8, 1.35) * CFrame.Angles(math.rad(8), 0, 0),
		Color3.fromRGB(72, 86, 102),
		model
	)
	createDebugPart(
		"FootRest",
		Vector3.new(3.2, 0.18, 0.45),
		rootPart.CFrame * CFrame.new(0, -0.1, -2.25),
		Color3.fromRGB(45, 49, 58),
		model
	)

	for _, frameInfo in ipairs({
		{
			name = "LeftArmRest",
			offset = Vector3.new(-1.85, 1.2, 0),
			size = Vector3.new(0.22, 0.22, 2.7),
		},
		{
			name = "RightArmRest",
			offset = Vector3.new(1.85, 1.2, 0),
			size = Vector3.new(0.22, 0.22, 2.7),
		},
		{
			name = "FrontCrossBar",
			offset = Vector3.new(0, 0.25, -1.35),
			size = Vector3.new(3.4, 0.18, 0.18),
		},
		{
			name = "RearCrossBar",
			offset = Vector3.new(0, 0.35, 1.15),
			size = Vector3.new(3.5, 0.18, 0.18),
		},
	}) do
		createDebugPart(
			frameInfo.name,
			frameInfo.size,
			rootPart.CFrame * CFrame.new(frameInfo.offset),
			Color3.fromRGB(145, 154, 164),
			model
		)
	end

	for _, wheelInfo in ipairs({
		{
			name = "LeftRearWheel",
			offset = Vector3.new(-2.25, 0.02, 0.55),
			diameter = 2.4,
			width = 0.28,
			color = Color3.fromRGB(22, 25, 30),
		},
		{
			name = "RightRearWheel",
			offset = Vector3.new(2.25, 0.02, 0.55),
			diameter = 2.4,
			width = 0.28,
			color = Color3.fromRGB(22, 25, 30),
		},
		{
			name = "LeftFrontCaster",
			offset = Vector3.new(-1.25, -0.43, -1.75),
			diameter = 0.7,
			width = 0.2,
			color = Color3.fromRGB(36, 40, 47),
		},
		{
			name = "RightFrontCaster",
			offset = Vector3.new(1.25, -0.43, -1.75),
			diameter = 0.7,
			width = 0.2,
			color = Color3.fromRGB(36, 40, 47),
		},
	}) do
		local wheel = createDebugPart(
			wheelInfo.name,
			Vector3.new(wheelInfo.diameter, wheelInfo.width, wheelInfo.diameter),
			rootPart.CFrame * CFrame.new(wheelInfo.offset) * CFrame.Angles(0, 0, math.rad(90)),
			wheelInfo.color,
			model
		)
		wheel.Shape = Enum.PartType.Cylinder
	end

	for _, pivotInfo in ipairs({
		{ name = "LeftFrontCasterPivot", offset = Vector3.new(-1.25, -0.08, -1.75) },
		{ name = "RightFrontCasterPivot", offset = Vector3.new(1.25, -0.08, -1.75) },
	}) do
		createDebugPart(
			pivotInfo.name,
			Vector3.new(0.22, 0.7, 0.22),
			rootPart.CFrame * CFrame.new(pivotInfo.offset),
			Color3.fromRGB(145, 154, 164),
			model,
			0.15
		)
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

local function findVehiclePartByNames(model: Model, names: { string }): BasePart?
	for _, partName in ipairs(names) do
		local part = findVehiclePart(model, partName)

		if part ~= nil then
			return part
		end
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

local function ensureVisualMotor(part0: BasePart, part1: BasePart): Motor6D
	local motorName = WheelchairConfig.Model.VisualMotorPrefix .. "_" .. part1.Name
	local existingMotor = part1:FindFirstChild(motorName)

	if existingMotor ~= nil and not existingMotor:IsA("Motor6D") then
		existingMotor:Destroy()
		existingMotor = nil
	end

	local motor = if existingMotor ~= nil then existingMotor :: Motor6D else Instance.new("Motor6D")

	motor.Name = motorName
	motor.Part0 = part0
	motor.Part1 = part1
	motor.C0 = part0.CFrame:ToObjectSpace(part1.CFrame)
	motor.C1 = CFrame.new()
	motor.Transform = CFrame.new()
	motor.Parent = part1

	return motor
end

local function configureDynamicVisualMotors(model: Model, rootPart: BasePart)
	local leftRear = findVehiclePartByNames(model, { "LeftRearWheel", "LeftWheel" })
	local rightRear = findVehiclePartByNames(model, { "RightRearWheel", "RightWheel" })
	local leftPivot = findVehiclePartByNames(model, { "LeftFrontCasterPivot" })
	local rightPivot = findVehiclePartByNames(model, { "RightFrontCasterPivot" })
	local leftCaster = findVehiclePartByNames(model, { "LeftFrontCaster", "LeftCaster" })
	local rightCaster = findVehiclePartByNames(model, { "RightFrontCaster", "RightCaster" })

	if leftRear ~= nil then
		ensureVisualMotor(rootPart, leftRear)
	end
	if rightRear ~= nil then
		ensureVisualMotor(rootPart, rightRear)
	end
	if leftPivot ~= nil then
		ensureVisualMotor(rootPart, leftPivot)
	end
	if rightPivot ~= nil then
		ensureVisualMotor(rootPart, rightPivot)
	end
	if leftCaster ~= nil then
		ensureVisualMotor(leftPivot or rootPart, leftCaster)
	end
	if rightCaster ~= nil then
		ensureVisualMotor(rightPivot or rootPart, rightCaster)
	end
end

local function getOrCreateAttachment(rootPart: BasePart, name: string): Attachment
	local existingAttachment = rootPart:FindFirstChild(name)

	if existingAttachment ~= nil then
		assert(existingAttachment:IsA("Attachment"), name .. " must be an Attachment")
		return existingAttachment :: Attachment
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Parent = rootPart

	return attachment
end

local function ensureMovementForce(rootPart: BasePart)
	local attachment = getOrCreateAttachment(rootPart, WheelchairConfig.Model.ForceAttachmentName)
	local existingForce = rootPart:FindFirstChild(WheelchairConfig.Model.MoveForceName)

	if existingForce ~= nil and not existingForce:IsA("VectorForce") then
		existingForce:Destroy()
		existingForce = nil
	end

	local force = if existingForce ~= nil
		then existingForce :: VectorForce
		else Instance.new("VectorForce")

	force.Name = WheelchairConfig.Model.MoveForceName
	force.Attachment0 = attachment
	force.ApplyAtCenterOfMass = true
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.Force = Vector3.zero
	force.Parent = rootPart
end

local function ensureAlignOrientation(rootPart: BasePart)
	local attachment =
		getOrCreateAttachment(rootPart, WheelchairConfig.Model.OrientationAttachmentName)
	local existingAlign = rootPart:FindFirstChild(WheelchairConfig.Model.AlignOrientationName)

	if existingAlign ~= nil and not existingAlign:IsA("AlignOrientation") then
		existingAlign:Destroy()
		existingAlign = nil
	end

	local align = if existingAlign ~= nil
		then existingAlign :: AlignOrientation
		else Instance.new("AlignOrientation")

	align.Name = WheelchairConfig.Model.AlignOrientationName
	align.Attachment0 = attachment
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.RigidityEnabled = false
	align.MaxTorque = WheelchairConfig.Movement.RootAlignMaxTorque
	align.Responsiveness = WheelchairConfig.Movement.RootAlignResponsiveness
	align.CFrame = rootPart.CFrame.Rotation
	align.Enabled = true
	align.Parent = rootPart
end

local function setClientNetworkOwner(player: Player, rootPart: BasePart)
	pcall(function()
		rootPart:SetNetworkOwner(player)
	end)
end

local function configureVehicleModel(player: Player, model: Model): (BasePart?, VehicleSeat?)
	local rootPart = findVehiclePart(model, WheelchairConfig.Model.RootPartName)
	local seat = findVehicleSeat(model)

	if rootPart == nil or seat == nil then
		WheelchairConfig.debugWarn("Wheelchair model is missing Frame or VehicleSeat")
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
				descendant.CustomPhysicalProperties = WheelchairConfig.Model.RootPhysicalProperties
			else
				descendant.CanCollide = false
				descendant.Massless = true

				if descendant == seat or dynamicVisualPartNames[descendant.Name] ~= true then
					ensureWeld(rootPart, descendant)
				end
			end
		end
	end

	seat.Disabled = false
	configureDynamicVisualMotors(model, rootPart)
	ensureMovementForce(rootPart)
	ensureAlignOrientation(rootPart)
	setClientNetworkOwner(player, rootPart)

	return rootPart, seat
end

local function destroyPlayerVehicle(player: Player)
	local state = getPlayerState(player)

	if state.vehicle ~= nil then
		state.vehicle:Destroy()
	end

	state.vehicle = nil
	state.rootPart = nil
	state.seat = nil
	state.driveInput = getDefaultDriveInput()
	state.lastInputDebugKey = ""
	state.lastOwnershipRefreshAt = 0
	state.lastReseatAt = 0
end

local function setDescriptionProperty(
	description: HumanoidDescription,
	propertyName: string,
	value: any
)
	pcall(function()
		(description :: any)[propertyName] = value
	end)
end

local function disableSeatExitJump(humanoid: Humanoid)
	humanoid.Jump = false
	humanoid.AutoRotate = false
	humanoid.WalkSpeed = 0

	pcall(function()
		humanoid.AutoJumpEnabled = false
	end)
	pcall(function()
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	end)
	pcall(function()
		humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
	end)
	pcall(function()
		humanoid.UseJumpPower = true
		humanoid.JumpPower = 0
	end)
	pcall(function()
		humanoid.JumpHeight = 0
	end)
end

local function disableCharacterAnimate(character: Model)
	local animate = character:FindFirstChild("Animate")

	if animate ~= nil and animate:IsA("LocalScript") then
		animate.Disabled = true
	end
end

local function cleanAvatar(player: Player, character: Model, humanoid: Humanoid): boolean
	task.wait(WheelchairConfig.Avatar.DescriptionApplyDelay)

	if character.Parent == nil or humanoid.Parent == nil then
		return false
	end

	local success, description = pcall(function()
		return humanoid:GetAppliedDescription()
	end)

	if success and description ~= nil then
		local cleanedDescription = description:Clone()

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

		pcall(function()
			humanoid:ApplyDescription(cleanedDescription)
		end)
	end

	for _, child in ipairs(character:GetChildren()) do
		local shouldDestroy = false

		if child:IsA("Accessory") then
			shouldDestroy = blockedAccessoryTypes[child.AccessoryType] == true
		elseif child:IsA("Tool") then
			shouldDestroy = WheelchairConfig.Avatar.RemoveTools
		end

		if shouldDestroy then
			child:Destroy()
		end
	end

	local backpack = player:FindFirstChildOfClass("Backpack")

	if WheelchairConfig.Avatar.RemoveTools and backpack ~= nil then
		for _, child in ipairs(backpack:GetChildren()) do
			if child:IsA("Tool") then
				child:Destroy()
			end
		end
	end

	disableSeatExitJump(humanoid)
	disableCharacterAnimate(character)

	return true
end

local function getSpawnCFrame(characterRootPart: BasePart): CFrame
	local forward =
		Vector3.new(characterRootPart.CFrame.LookVector.X, 0, characterRootPart.CFrame.LookVector.Z)

	if forward.Magnitude < 0.05 then
		forward = Vector3.zAxis * -1
	else
		forward = forward.Unit
	end

	local position = characterRootPart.Position
		+ Vector3.new(0, WheelchairConfig.Spawn.SpawnHeightOffset, 0)

	return CFrame.lookAt(position, position + forward)
end

local function spawnWheelchairForPlayer(
	player: Player,
	humanoid: Humanoid,
	characterRootPart: BasePart
)
	destroyPlayerVehicle(player)

	local template = findWheelchairTemplate()
	local vehicle = if template ~= nil
		then template:Clone()
		elseif WheelchairConfig.Spawn.UseDebugFallback then createDebugWheelchair()
		else nil

	if vehicle == nil then
		WheelchairConfig.debugWarn("No Wheelchair template found")
		return
	end

	vehicle.Name = player.Name .. "_Wheelchair"
	vehicle.Parent = getOrCreateFolder(Workspace, WheelchairConfig.WorkspaceFolderName)

	local rootPart, seat = configureVehicleModel(player, vehicle)

	if rootPart == nil or seat == nil then
		vehicle:Destroy()
		return
	end

	vehicle:PivotTo(getSpawnCFrame(characterRootPart))
	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero

	local state = getPlayerState(player)
	state.vehicle = vehicle
	state.rootPart = rootPart
	state.seat = seat
	state.driveInput = getDefaultDriveInput()
	state.lastOwnershipRefreshAt = 0
	state.lastReseatAt = 0

	task.delay(WheelchairConfig.Spawn.SeatDelay, function()
		if humanoid.Parent == nil or seat.Parent == nil or rootPart.Parent == nil then
			return
		end

		disableSeatExitJump(humanoid)
		seat:Sit(humanoid)
		setClientNetworkOwner(player, rootPart)
	end)
end

local function isPlayerSeatedInOwnWheelchair(player: Player, state: PlayerState): boolean
	local character = player.Character
	local seat = state.seat

	if character == nil or seat == nil then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")

	return humanoid ~= nil and humanoid.SeatPart == seat
end

local function canAcceptInput(
	state: PlayerState,
	nextInput: DriveInput,
	isJumpEdge: boolean
): boolean
	local now = os.clock()

	if isJumpEdge or not WheelchairConfig.hasActiveInput(nextInput) then
		state.lastInputAt = now
		return true
	end

	if now - state.lastInputAt < WheelchairConfig.Input.MinSendInterval then
		return false
	end

	state.lastInputAt = now
	return true
end

local function getDebugInputKey(input: DriveInput): string
	return string.format("x=%.2f,z=%.2f,j=%s", input.moveX, input.moveZ, tostring(input.jump))
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
		return
	end

	state.driveInput = nextInput

	local debugKey = getDebugInputKey(nextInput)

	if debugKey ~= state.lastInputDebugKey then
		state.lastInputDebugKey = debugKey
		WheelchairConfig.debugPrint("Input from", player.Name, debugKey)
	end
end

local function keepPlayerAttached(player: Player, state: PlayerState)
	local rootPart = state.rootPart
	local seat = state.seat
	local character = player.Character

	if rootPart == nil or rootPart.Parent == nil or seat == nil or seat.Parent == nil then
		return
	end

	if character == nil then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if humanoid == nil then
		return
	end

	local now = os.clock()
	disableSeatExitJump(humanoid)
	disableCharacterAnimate(character)

	if now - state.lastOwnershipRefreshAt >= WheelchairConfig.Spawn.OwnershipRefreshInterval then
		state.lastOwnershipRefreshAt = now
		setClientNetworkOwner(player, rootPart)
	end

	if
		humanoid.SeatPart ~= seat
		and now - state.lastReseatAt >= WheelchairConfig.Spawn.ReseatInterval
	then
		state.lastReseatAt = now
		seat.Disabled = false
		seat:Sit(humanoid)
		setClientNetworkOwner(player, rootPart)
	end
end

local function handleCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local characterRootPart = character:WaitForChild("HumanoidRootPart", 10)

	if
		humanoid == nil
		or characterRootPart == nil
		or not humanoid:IsA("Humanoid")
		or not characterRootPart:IsA("BasePart")
	then
		WheelchairConfig.debugWarn("Character missing Humanoid or HumanoidRootPart")
		return
	end

	if not cleanAvatar(player, character, humanoid) then
		return
	end

	spawnWheelchairForPlayer(player, humanoid, characterRootPart)
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
	getOrCreateDriveInputRemote().OnServerEvent:Connect(onDriveInput)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player: Player)
		destroyPlayerVehicle(player)
		playerStates[player] = nil
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		task.defer(onPlayerAdded, player)
	end

	RunService.Heartbeat:Connect(function()
		for player, state in pairs(playerStates) do
			keepPlayerAttached(player, state)
		end
	end)
end

start()
