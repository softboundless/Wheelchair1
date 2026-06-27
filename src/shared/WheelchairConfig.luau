--!strict

local WheelchairConfig = {}

export type DriveInput = {
	throttle: number,
	steer: number,
	brake: boolean,
}

WheelchairConfig.SharedFolderName = "RojoShared"
WheelchairConfig.RemoteFolderName = "WheelchairRemotes"
WheelchairConfig.DriveInputRemoteName = "WheelchairDriveInput"

WheelchairConfig.VehicleModelName = "Wheelchair"
WheelchairConfig.LegacyVehicleModelName = "Bike"
WheelchairConfig.RootPartName = "Frame"
WheelchairConfig.SeatName = "Seat"

WheelchairConfig.Input = {
	DeadZone = 0.05,
	MinSendInterval = 1 / 30,
}

WheelchairConfig.Movement = {
	MaxSpeed = 34,
	Acceleration = 70,
	TurnSpeed = 2.2,
	ReverseMultiplier = 0.45,
	BrakeDeceleration = 100,
}

local DEFAULT_DRIVE_INPUT: DriveInput = {
	throttle = 0,
	steer = 0,
	brake = false,
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
		brake = rawInput.brake == true,
	}
end

return WheelchairConfig
