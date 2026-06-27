--!strict

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local camera = Workspace.CurrentCamera

if camera == nil then
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Wait()
	camera = Workspace.CurrentCamera
end

assert(camera ~= nil, "CurrentCamera must exist for WheelchairClient")

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
	jump = false,
}

local lastSentInput: DriveInput = WheelchairConfig.sanitizeDriveInput(nil)
local lastSentAt = 0
local cameraEnabled = false
local wasDriving = false

local function clearActionState()
	actionState.forward = 0
	actionState.backward = 0
	actionState.left = 0
	actionState.right = 0
	actionState.jump = false
end

local function getHumanoid(): Humanoid?
	local character = localPlayer.Character

	if character == nil then
		return nil
	end

	return character:FindFirstChildOfClass("Humanoid")
end

local function getDrivingWheelchair(): (Model?, BasePart?)
	local humanoid = getHumanoid()

	if humanoid == nil or humanoid.SeatPart == nil then
		return nil, nil
	end

	local vehicleModel = humanoid.SeatPart:FindFirstAncestorWhichIsA("Model")

	if vehicleModel == nil then
		return nil, nil
	end

	if vehicleModel:GetAttribute(WheelchairConfig.Model.IsWheelchairAttribute) ~= true then
		return nil, nil
	end

	if vehicleModel:GetAttribute(WheelchairConfig.Model.OwnerUserIdAttribute) ~= localPlayer.UserId then
		return nil, nil
	end

	local rootPart = vehicleModel:FindFirstChild(WheelchairConfig.Model.RootPartName, true)

	if rootPart == nil or not rootPart:IsA("BasePart") then
		return vehicleModel, nil
	end

	return vehicleModel, rootPart
end

local function buildDriveInput(): DriveInput
	return WheelchairConfig.sanitizeDriveInput({
		throttle = actionState.forward - actionState.backward,
		steer = actionState.right - actionState.left,
		jump = actionState.jump,
	})
end

local function hasInputChanged(nextInput: DriveInput, previousInput: DriveInput): boolean
	return nextInput.throttle ~= previousInput.throttle
		or nextInput.steer ~= previousInput.steer
		or nextInput.jump ~= previousInput.jump
end

local function sendDriveInput(input: DriveInput, forceSend: boolean?)
	local now = os.clock()

	if not forceSend and now - lastSentAt < WheelchairConfig.Input.MinSendInterval then
		return
	end

	driveInputRemote:FireServer(input)
	lastSentInput = input
	lastSentAt = now
end

local function restoreDefaultCamera()
	if not cameraEnabled then
		return
	end

	cameraEnabled = false
	camera.CameraType = Enum.CameraType.Custom

	local humanoid = getHumanoid()

	if humanoid ~= nil then
		camera.CameraSubject = humanoid
	end

	WheelchairConfig.debugPrint("Racing camera disabled")
end

local function updateRacingCamera(rootPart: BasePart, deltaTime: number)
	if not cameraEnabled then
		cameraEnabled = true
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = WheelchairConfig.Camera.FieldOfView
		WheelchairConfig.debugPrint("Racing camera enabled")
	end

	local lookVector = rootPart.CFrame.LookVector
	local forward = Vector3.new(lookVector.X, 0, lookVector.Z)

	if forward.Magnitude < 0.05 then
		forward = Vector3.zAxis * -1
	else
		forward = forward.Unit
	end

	local focus = rootPart.Position + Vector3.new(0, WheelchairConfig.Camera.FocusHeight, 0)
	local cameraPosition = focus - forward * WheelchairConfig.Camera.Distance + Vector3.new(0, WheelchairConfig.Camera.Height, 0)
	local targetCFrame = CFrame.lookAt(cameraPosition, focus)
	local alpha = math.clamp(deltaTime * WheelchairConfig.Camera.LerpSpeed, 0, 1)

	camera.CFrame = camera.CFrame:Lerp(targetCFrame, alpha)
	camera.Focus = CFrame.new(focus)
end

local function handleDriveAction(actionName: string, inputState: Enum.UserInputState): Enum.ContextActionResult
	local _, rootPart = getDrivingWheelchair()

	if rootPart == nil then
		clearActionState()
		return Enum.ContextActionResult.Pass
	end

	local isPressed = inputState == Enum.UserInputState.Begin
	local isReleased = inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel

	if not isPressed and not isReleased then
		return Enum.ContextActionResult.Sink
	end

	local axisValue = if isPressed then 1 else 0

	if actionName == "WheelchairForward" then
		actionState.forward = axisValue
	elseif actionName == "WheelchairBackward" then
		actionState.backward = axisValue
	elseif actionName == "WheelchairLeft" then
		actionState.left = axisValue
	elseif actionName == "WheelchairRight" then
		actionState.right = axisValue
	elseif actionName == "WheelchairJump" then
		actionState.jump = isPressed
	end

	sendDriveInput(buildDriveInput(), actionName == "WheelchairJump")

	return Enum.ContextActionResult.Sink
end

local actionPriority = Enum.ContextActionPriority.High.Value + 100

ContextActionService:BindActionAtPriority("WheelchairForward", handleDriveAction, false, actionPriority, Enum.KeyCode.W, Enum.KeyCode.Up)
ContextActionService:BindActionAtPriority("WheelchairBackward", handleDriveAction, false, actionPriority, Enum.KeyCode.S, Enum.KeyCode.Down)
ContextActionService:BindActionAtPriority("WheelchairLeft", handleDriveAction, false, actionPriority, Enum.KeyCode.A, Enum.KeyCode.Left)
ContextActionService:BindActionAtPriority("WheelchairRight", handleDriveAction, false, actionPriority, Enum.KeyCode.D, Enum.KeyCode.Right)
ContextActionService:BindActionAtPriority("WheelchairJump", handleDriveAction, false, actionPriority, Enum.KeyCode.Space)

RunService.RenderStepped:Connect(function(deltaTime: number)
	local _, rootPart = getDrivingWheelchair()

	if rootPart == nil then
		if wasDriving then
			wasDriving = false
			clearActionState()
			sendDriveInput(WheelchairConfig.sanitizeDriveInput(nil), true)
			WheelchairConfig.debugPrint("Stopped driving wheelchair")
		end

		restoreDefaultCamera()
		return
	end

	if not wasDriving then
		wasDriving = true
		WheelchairConfig.debugPrint("Started driving wheelchair")
	end

	local nextInput = buildDriveInput()

	if hasInputChanged(nextInput, lastSentInput) or WheelchairConfig.hasActiveInput(nextInput) then
		sendDriveInput(nextInput, false)
	end

	updateRacingCamera(rootPart, deltaTime)
end)

WheelchairConfig.debugPrint("WheelchairClient started")
