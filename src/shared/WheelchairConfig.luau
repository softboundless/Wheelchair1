--!strict

local WheelchairConfig = {}

export type DriveInput = {
	moveX: number,
	moveZ: number,
	jump: boolean,
}

WheelchairConfig.Debug = false
WheelchairConfig.DebugPrefix = "[Wheelchair]"

WheelchairConfig.SharedFolderName = "RojoShared"
WheelchairConfig.RemoteFolderName = "WheelchairRemotes"
WheelchairConfig.DriveInputRemoteName = "WheelchairDriveInput"
WheelchairConfig.WorkspaceFolderName = "Wheelchairs"

WheelchairConfig.Model = {
	TemplateName = "Wheelchair",
	RootPartName = "Frame",
	SeatName = "VehicleSeat",
	IsWheelchairAttribute = "IsWheelchair",
	OwnerUserIdAttribute = "OwnerUserId",
	OwnerNameAttribute = "OwnerName",
	RootTransparency = 1,
	RootPhysicalProperties = PhysicalProperties.new(1.2, 0.05, 0.05, 1, 1),
	ForceAttachmentName = "WheelchairForceAttachment",
	MoveForceName = "WheelchairMoveForce",
	OrientationAttachmentName = "WheelchairOrientationAttachment",
	AlignOrientationName = "WheelchairAlignOrientation",
	VisualMotorPrefix = "WheelchairVisualMotor",
}

WheelchairConfig.Spawn = {
	UseDebugFallback = true,
	SpawnHeightOffset = 0,
	SeatDelay = 0.2,
	ReseatInterval = 0.2,
	OwnershipRefreshInterval = 1,
}

WheelchairConfig.Input = {
	DeadZone = 0.05,
	MinSendInterval = 1 / 100,
}

WheelchairConfig.World = {
	Gravity = 50,
}

WheelchairConfig.Movement = {
	MaxSpeed = 115,
	ForceAcceleration = 0.55,
	MaxPlanarVelocity = 125,

	GroundRayLength = 10,
	GroundedDistance = 3.8,
	GroundNormalAirLerpSpeed = 5,
	OrientationLerpSpeed = 10,
	RootAlignResponsiveness = 18,
	RootAlignMaxTorque = 120000,
	MaxBodyLean = math.rad(4),

	EnableJump = true,
	JumpSpeed = 20,
	JumpCooldown = 0.35,
	JumpTakeoffTime = 0.25,
	JumpStartSpeedRatio = 0.45,
	AirControlAcceleration = 0.72,
	AirMaxSpeedMultiplier = 0.85,
	AirBackwardBrakeAcceleration = 0.65,

	RearWheelRadius = 1.2,
	FrontCasterRadius = 0.35,
	CasterYawLerpSpeed = 12,
	WheelTurnSpinBias = 0.35,
}

WheelchairConfig.Camera = {
	Distance = 10,
	FocusHeight = 4.5,
	FieldOfView = 80,
	SpeedFovBoost = 1,
	LerpSpeed = 35,
	Sensitivity = 1 / 260,
	MinPitch = -1.25,
	MaxPitch = 1.15,
	CollisionPadding = 0.3,
}

WheelchairConfig.Pose = {
	AnimationStopInterval = 0.35,
	HeadYawLimit = math.rad(45),
	HeadPitchLimit = math.rad(25),
	HeadLerpSpeed = 10,
	PushCycleScale = 0.6,
}

WheelchairConfig.Avatar = {
	DescriptionApplyDelay = 0.25,
	RemoveTools = true,
	ResetBodyPackages = true,
	AccessoryDescriptionFieldsToClear = {
		"HatAccessory",
		"BackAccessory",
		"WaistAccessory",
		"ShouldersAccessory",
		"ShoulderAccessory",
		"FrontAccessory",
		"NeckAccessory",
		"FaceAccessory",
	},
	BodyPartFieldsToReset = {
		"Head",
		"Torso",
		"LeftArm",
		"RightArm",
		"LeftLeg",
		"RightLeg",
	},
	ScaleProperties = {
		BodyTypeScale = 0,
		DepthScale = 1,
		HeadScale = 1,
		HeightScale = 1,
		ProportionScale = 0,
		WidthScale = 1,
	},
}

local DEFAULT_DRIVE_INPUT: DriveInput = {
	moveX = 0,
	moveZ = 0,
	jump = false,
}

local function readNumber(value: unknown): number
	if typeof(value) ~= "number" or value ~= value then
		return 0
	end

	return value
end

local function sanitizeMove(x: number, z: number): (number, number)
	local move = Vector2.new(math.clamp(x, -1, 1), math.clamp(z, -1, 1))

	if move.Magnitude < WheelchairConfig.Input.DeadZone then
		return 0, 0
	end

	if move.Magnitude > 1 then
		move = move.Unit
	end

	return move.X, move.Y
end

function WheelchairConfig.sanitizeDriveInput(input: unknown): DriveInput
	if typeof(input) ~= "table" then
		return table.clone(DEFAULT_DRIVE_INPUT)
	end

	local rawInput = input :: any
	local moveX, moveZ = sanitizeMove(readNumber(rawInput.moveX), readNumber(rawInput.moveZ))

	return {
		moveX = moveX,
		moveZ = moveZ,
		jump = rawInput.jump == true,
	}
end

function WheelchairConfig.hasActiveInput(input: DriveInput): boolean
	return input.moveX ~= 0 or input.moveZ ~= 0 or input.jump
end

function WheelchairConfig.debugPrint(...: any)
	if WheelchairConfig.Debug then
		print(WheelchairConfig.DebugPrefix, ...)
	end
end

function WheelchairConfig.debugWarn(...: any)
	if WheelchairConfig.Debug then
		warn(WheelchairConfig.DebugPrefix, ...)
	end
end

return WheelchairConfig
