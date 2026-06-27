--!strict

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local RojoShared = ReplicatedStorage:WaitForChild("RojoShared")
local WheelchairConfig = require(RojoShared:WaitForChild("WheelchairConfig"))

type DriveInput = WheelchairConfig.DriveInput

local remotesFolder = RojoShared:WaitForChild(WheelchairConfig.RemoteFolderName)
local driveInputRemote = remotesFolder:WaitForChild(WheelchairConfig.DriveInputRemoteName) :: RemoteEvent

local actionState = {
	forward = 0,
	backward = 0,
	left = 0,
	right = 0,
	brake = false,
}

local lastInput: DriveInput = WheelchairConfig.sanitizeDriveInput(nil)
local lastSentAt = 0

local function clearActionState()
	actionState.forward = 0
	actionState.backward = 0
	actionState.left = 0
	actionState.right = 0
	actionState.brake = false
end

local function isWheelchairModel(model: Model): boolean
	return model:GetAttribute("IsWheelchair") == true
		or model.Name == WheelchairConfig.VehicleModelName
		or model.Name == WheelchairConfig.LegacyVehicleModelName
end

local function isDrivingWheelchair(): boolean
	local character = localPlayer.Character

	if character == nil then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if humanoid == nil then
		return false
	end

	local seatPart = humanoid.SeatPart

	if seatPart == nil then
		return false
	end

	local vehicleModel = seatPart:FindFirstAncestorWhichIsA("Model")

	if vehicleModel == nil then
		return false
	end

	return isWheelchairModel(vehicleModel)
end

local function buildDriveInput(): DriveInput
	return WheelchairConfig.sanitizeDriveInput({
		throttle = actionState.forward - actionState.backward,
		steer = actionState.right - actionState.left,
		brake = actionState.brake,
	})
end

local function hasInputChanged(nextInput: DriveInput, previousInput: DriveInput): boolean
	return nextInput.throttle ~= previousInput.throttle
		or nextInput.steer ~= previousInput.steer
		or nextInput.brake ~= previousInput.brake
end

local function hasActiveInput(input: DriveInput): boolean
	return input.throttle ~= 0 or input.steer ~= 0 or input.brake
end

local function sendDriveInput(input: DriveInput)
	local now = os.clock()

	if now - lastSentAt < WheelchairConfig.Input.MinSendInterval then
		return
	end

	driveInputRemote:FireServer(input)
	lastInput = input
	lastSentAt = now
end

local function handleDriveAction(actionName: string, inputState: Enum.UserInputState): Enum.ContextActionResult
	if not isDrivingWheelchair() then
		clearActionState()
		return Enum.ContextActionResult.Pass
	end

	local isPressed = inputState == Enum.UserInputState.Begin
	local isReleased = inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel

	if not isPressed and not isReleased then
		return Enum.ContextActionResult.Pass
	end

	local axisValue = 0

	if isPressed then
		axisValue = 1
	end

	if actionName == "WheelchairForward" then
		actionState.forward = axisValue
	elseif actionName == "WheelchairBackward" then
		actionState.backward = axisValue
	elseif actionName == "WheelchairLeft" then
		actionState.left = axisValue
	elseif actionName == "WheelchairRight" then
		actionState.right = axisValue
	elseif actionName == "WheelchairBrake" then
		actionState.brake = isPressed
	end

	return Enum.ContextActionResult.Sink
end

ContextActionService:BindAction("WheelchairForward", handleDriveAction, false, Enum.KeyCode.W, Enum.KeyCode.Up)
ContextActionService:BindAction("WheelchairBackward", handleDriveAction, false, Enum.KeyCode.S, Enum.KeyCode.Down)
ContextActionService:BindAction("WheelchairLeft", handleDriveAction, false, Enum.KeyCode.A, Enum.KeyCode.Left)
ContextActionService:BindAction("WheelchairRight", handleDriveAction, false, Enum.KeyCode.D, Enum.KeyCode.Right)
ContextActionService:BindAction("WheelchairBrake", handleDriveAction, false, Enum.KeyCode.Space, Enum.KeyCode.LeftShift)

RunService.RenderStepped:Connect(function()
	if not isDrivingWheelchair() then
		clearActionState()

		local stopInput = WheelchairConfig.sanitizeDriveInput(nil)

		if hasInputChanged(stopInput, lastInput) then
			sendDriveInput(stopInput)
		end

		return
	end

	local nextInput = buildDriveInput()

	if hasInputChanged(nextInput, lastInput) or hasActiveInput(nextInput) then
		sendDriveInput(nextInput)
	end
end)
