--!strict

local WheelchairConfig = {}

export type DriveInput = {
	throttle: number,
	steer: number,
	jump: boolean,
}

WheelchairConfig.Debug = true
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
}

WheelchairConfig.Spawn = {
	UseDebugFallback = true,
	SpawnHeightOffset = 0,
	SeatDelay = 0.2,
}

WheelchairConfig.Input = {
	DeadZone = 0.05,
	MinSendInterval = 1 / 30,
}

WheelchairConfig.World = {
	Gravity = 20,
}

WheelchairConfig.Movement = {
	MaxSpeed = 55,
	ReverseSpeedMultiplier = 0.4,
	Acceleration = 120,
	CoastDeceleration = 70,
	TurnRate = 30,
	GroundRayLength = 7,
	GroundedDistance = 4,
	GroundNormalLerpSpeed = 3,
	OrientationLerpSpeed = 0.5,
	EnableOrientationStabilization = true,
	MaxPlanarVelocity = 58,
	MaxAngularVelocity = 1.7,
	EnableJump = true,
	JumpSpeed = 15,
	JumpCooldown = 0.45,
	DebugLogInterval = 0.5,
}

WheelchairConfig.Camera = {
	Distance = 13,
	Height = 6,
	FocusHeight = 2.5,
	LerpSpeed = 9,
	FieldOfView = 78,
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
	throttle = 0,
	steer = 0,
	jump = false,
}

local function readNumber(value: unknown, fallback: number): number
	if typeof(value) ~= "number" then
		return fallback
	end

	if value ~= value then
		return fallback
	end

	return value
end

local function applyDeadZone(value: number): number
	if math.abs(value) < WheelchairConfig.Input.DeadZone then
		return 0
	end

	return value
end

function WheelchairConfig.sanitizeDriveInput(input: unknown): DriveInput
	if typeof(input) ~= "table" then
		return table.clone(DEFAULT_DRIVE_INPUT)
	end

	local rawInput = input :: any

	return {
		throttle = applyDeadZone(math.clamp(readNumber(rawInput.throttle, 0), -1, 1)),
		steer = applyDeadZone(math.clamp(readNumber(rawInput.steer, 0), -1, 1)),
		jump = rawInput.jump == true,
	}
end

function WheelchairConfig.hasActiveInput(input: DriveInput): boolean
	return input.throttle ~= 0 or input.steer ~= 0 or input.jump
end

function WheelchairConfig.debugPrint(...: any)
	if not WheelchairConfig.Debug then
		return
	end

	print(WheelchairConfig.DebugPrefix, ...)
end

function WheelchairConfig.debugWarn(...: any)
	if not WheelchairConfig.Debug then
		return
	end

	warn(WheelchairConfig.DebugPrefix, ...)
end

return WheelchairConfig
