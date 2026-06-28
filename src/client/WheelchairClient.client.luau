--!strict

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local RojoShared = ReplicatedStorage:WaitForChild("RojoShared")
local WheelchairConfig = require(RojoShared:WaitForChild("WheelchairConfig"))
local Spring = require(RojoShared:WaitForChild("Spring"))

type DriveInput = WheelchairConfig.DriveInput

type WheelMotors = {
	leftRear: Motor6D?,
	rightRear: Motor6D?,
	leftCaster: Motor6D?,
	rightCaster: Motor6D?,
	leftCasterPivot: Motor6D?,
	rightCasterPivot: Motor6D?,
}

type PoseMotors = {
	neck: Motor6D?,
	waist: Motor6D?,
	rightShoulder: Motor6D?,
	leftShoulder: Motor6D?,
	rightElbow: Motor6D?,
	leftElbow: Motor6D?,
	rightWrist: Motor6D?,
	leftWrist: Motor6D?,
	rightHip: Motor6D?,
	leftHip: Motor6D?,
	rightKnee: Motor6D?,
	leftKnee: Motor6D?,
	rightAnkle: Motor6D?,
	leftAnkle: Motor6D?,
}

local driveInputRemote = RojoShared:WaitForChild(WheelchairConfig.RemoteFolderName)
	:WaitForChild(WheelchairConfig.DriveInputRemoteName) :: RemoteEvent

local actionState = {
	forward = 0,
	backward = 0,
	left = 0,
	right = 0,
	jump = false,
}

local currentDriveInput: DriveInput = WheelchairConfig.sanitizeDriveInput(nil)
local lastSentInput: DriveInput = WheelchairConfig.sanitizeDriveInput(nil)
local lastSentAt = 0
local wasDriving = false
local cameraEnabled = false
local jumpQueued = false
local jumpActive = false
local jumpStartedAt = 0
local jumpStartSpeed = 0
local jumpTargetSpeed = 0
local jumpNormal = Vector3.yAxis
local lastJumpAt = 0

local floorNormal = Vector3.yAxis
local grounded = false
local targetVelocity = Vector3.zero
local orientation = CFrame.new()
local bodyLean = 0

local leftRearRotation = 0
local rightRearRotation = 0
local casterRotation = 0
local casterYaw = 0
local wheelDirection = 1

local cameraYaw = 0
local cameraPitch = 0
local headYaw = 0
local headPitch = 0

local cachedVehicle: Model? = nil
local cachedWheelMotors: WheelMotors? = nil
local cachedCharacter: Model? = nil
local cachedPoseMotors: PoseMotors? = nil

local bodySpring = Spring:Create(1, 10, 2, 2)
local lastPoseVelocity = Vector3.zero
local lastAnimationStopAt = 0

local function lerpNumber(a: number, b: number, alpha: number): number
	return a + (b - a) * alpha
end

local function getAlpha(speed: number, deltaTime: number): number
	return math.clamp(deltaTime * speed, 0, 1)
end

local function lerpAngle(a: number, b: number, alpha: number): number
	local difference = (b - a + math.pi) % (math.pi * 2) - math.pi
	return a + difference * alpha
end

local function clearActionState()
	actionState.forward = 0
	actionState.backward = 0
	actionState.left = 0
	actionState.right = 0
	actionState.jump = false
	currentDriveInput = WheelchairConfig.sanitizeDriveInput(nil)
	jumpQueued = false
	jumpActive = false
end

local function getCharacter(): Model?
	return localPlayer.Character
end

local function getHumanoid(): Humanoid?
	local character = getCharacter()

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

	local vehicle = humanoid.SeatPart:FindFirstAncestorWhichIsA("Model")

	if vehicle == nil then
		return nil, nil
	end

	if vehicle:GetAttribute(WheelchairConfig.Model.IsWheelchairAttribute) ~= true then
		return nil, nil
	end

	if vehicle:GetAttribute(WheelchairConfig.Model.OwnerUserIdAttribute) ~= localPlayer.UserId then
		return nil, nil
	end

	local rootPart = vehicle:FindFirstChild(WheelchairConfig.Model.RootPartName, true)

	if rootPart ~= nil and rootPart:IsA("BasePart") then
		return vehicle, rootPart
	end

	return nil, nil
end

local function findPartByNames(model: Model, names: { string }): BasePart?
	for _, name in ipairs(names) do
		local instance = model:FindFirstChild(name, true)

		if instance ~= nil and instance:IsA("BasePart") then
			return instance
		end
	end

	return nil
end

local function findVisualMotor(part: BasePart?): Motor6D?
	if part == nil then
		return nil
	end

	for _, child in ipairs(part:GetChildren()) do
		if
			child:IsA("Motor6D")
			and string.find(child.Name, WheelchairConfig.Model.VisualMotorPrefix, 1, true) == 1
		then
			return child
		end
	end

	return nil
end

local function getWheelMotors(vehicle: Model): WheelMotors
	if cachedVehicle == vehicle and cachedWheelMotors ~= nil then
		return cachedWheelMotors
	end

	local leftRear = findPartByNames(vehicle, { "LeftRearWheel", "LeftWheel" })
	local rightRear = findPartByNames(vehicle, { "RightRearWheel", "RightWheel" })
	local leftCaster = findPartByNames(vehicle, { "LeftFrontCaster", "LeftCaster" })
	local rightCaster = findPartByNames(vehicle, { "RightFrontCaster", "RightCaster" })
	local leftCasterPivot = findPartByNames(vehicle, { "LeftFrontCasterPivot" })
	local rightCasterPivot = findPartByNames(vehicle, { "RightFrontCasterPivot" })

	cachedVehicle = vehicle
	cachedWheelMotors = {
		leftRear = findVisualMotor(leftRear),
		rightRear = findVisualMotor(rightRear),
		leftCaster = findVisualMotor(leftCaster),
		rightCaster = findVisualMotor(rightCaster),
		leftCasterPivot = findVisualMotor(leftCasterPivot),
		rightCasterPivot = findVisualMotor(rightCasterPivot),
	}

	return cachedWheelMotors
end

local function findMotor(character: Model, name: string): Motor6D?
	local instance = character:FindFirstChild(name, true)

	if instance ~= nil and instance:IsA("Motor6D") then
		return instance
	end

	return nil
end

local function getPoseMotors(character: Model): PoseMotors
	if cachedCharacter == character and cachedPoseMotors ~= nil then
		return cachedPoseMotors
	end

	cachedCharacter = character
	cachedPoseMotors = {
		neck = findMotor(character, "Neck"),
		waist = findMotor(character, "Waist"),
		rightShoulder = findMotor(character, "RightShoulder"),
		leftShoulder = findMotor(character, "LeftShoulder"),
		rightElbow = findMotor(character, "RightElbow"),
		leftElbow = findMotor(character, "LeftElbow"),
		rightWrist = findMotor(character, "RightWrist"),
		leftWrist = findMotor(character, "LeftWrist"),
		rightHip = findMotor(character, "RightHip"),
		leftHip = findMotor(character, "LeftHip"),
		rightKnee = findMotor(character, "RightKnee"),
		leftKnee = findMotor(character, "LeftKnee"),
		rightAnkle = findMotor(character, "RightAnkle"),
		leftAnkle = findMotor(character, "LeftAnkle"),
	}

	return cachedPoseMotors
end

local function setMotorTransform(motor: Motor6D?, transform: CFrame)
	if motor ~= nil then
		motor.Transform = transform
	end
end

local function resetPoseMotors()
	if cachedPoseMotors == nil then
		return
	end

	for _, motor in pairs(cachedPoseMotors) do
		if motor ~= nil then
			motor.Transform = CFrame.new()
		end
	end
end

local function getMoveForce(rootPart: BasePart): VectorForce?
	local force = rootPart:FindFirstChild(WheelchairConfig.Model.MoveForceName)

	if force ~= nil and force:IsA("VectorForce") then
		return force
	end

	return nil
end

local function getAlignOrientation(rootPart: BasePart): AlignOrientation?
	local align = rootPart:FindFirstChild(WheelchairConfig.Model.AlignOrientationName)

	if align ~= nil and align:IsA("AlignOrientation") then
		return align
	end

	return nil
end

local function buildDriveInput(): DriveInput
	if UserInputService:GetFocusedTextBox() ~= nil then
		return WheelchairConfig.sanitizeDriveInput(nil)
	end

	return WheelchairConfig.sanitizeDriveInput({
		moveX = actionState.right - actionState.left,
		moveZ = actionState.backward - actionState.forward,
		jump = actionState.jump,
	})
end

local function hasInputChanged(nextInput: DriveInput, previousInput: DriveInput): boolean
	return nextInput.moveX ~= previousInput.moveX
		or nextInput.moveZ ~= previousInput.moveZ
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

local function buildRaycastParams(vehicle: Model): RaycastParams
	local params = RaycastParams.new()
	local filterInstances: { Instance } = { vehicle }
	local character = getCharacter()

	if character ~= nil then
		table.insert(filterInstances, character)
	end

	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = filterInstances

	return params
end

local function getFlatLookVector(rootPart: BasePart): Vector3
	local camera = Workspace.CurrentCamera
	local lookVector = if camera ~= nil
		then camera.CFrame.LookVector
		else rootPart.CFrame.LookVector
	local flatLookVector = Vector3.new(lookVector.X, 0, lookVector.Z)

	if flatLookVector.Magnitude < 0.05 then
		local rootForward =
			Vector3.new(rootPart.CFrame.LookVector.X, 0, rootPart.CFrame.LookVector.Z)

		if rootForward.Magnitude < 0.05 then
			return Vector3.zAxis * -1
		end

		return rootForward.Unit
	end

	return flatLookVector.Unit
end

local function getFloorCFrame(rootPart: BasePart, normal: Vector3): CFrame
	local floorCFrame = CFrame.new(Vector3.zero, getFlatLookVector(rootPart))
	local localFloor = floorCFrame:VectorToObjectSpace(normal)

	local x = math.atan2(-localFloor.X, localFloor.Y)
	local y = math.atan2(localFloor.Z, localFloor.Y)
	local cfA = CFrame.Angles(y, 0, 0) * CFrame.Angles(0, 0, x)
	local cfB = CFrame.Angles(0, 0, x) * CFrame.Angles(y, 0, 0)

	return floorCFrame * cfA:Lerp(cfB, 0.5)
end

local function clampPlanarVelocity(rootPart: BasePart, normal: Vector3)
	local velocity = rootPart.AssemblyLinearVelocity
	local normalVelocity = normal * velocity:Dot(normal)
	local planarVelocity = velocity - normalVelocity

	if planarVelocity.Magnitude <= WheelchairConfig.Movement.MaxPlanarVelocity then
		return
	end

	rootPart.AssemblyLinearVelocity = planarVelocity.Unit
			* WheelchairConfig.Movement.MaxPlanarVelocity
		+ normalVelocity
end

local function queueJump()
	jumpQueued = true
end

local function getJumpTargetSpeed(
	peakHeight: number,
	takeoffTime: number,
	startSpeedRatio: number
): number
	local gravity = math.max(Workspace.Gravity, 0.001)
	local height = math.max(peakHeight, 0)
	local safeTakeoffTime = math.max(takeoffTime, 0)
	local safeStartSpeedRatio = math.clamp(startSpeedRatio, 0, 0.95)

	if height <= 0 then
		return 0
	end

	if safeTakeoffTime <= 0 then
		return math.sqrt(2 * gravity * height)
	end

	local rampTerm = (1 + safeStartSpeedRatio) * safeTakeoffTime

	return math.max(
		gravity * (math.sqrt(rampTerm * rampTerm + (8 * height) / gravity) - rampTerm) * 0.5,
		0
	)
end

local function setNormalSpeed(rootPart: BasePart, normal: Vector3, targetSpeed: number)
	local velocity = rootPart.AssemblyLinearVelocity
	local normalSpeed = velocity:Dot(normal)

	if normalSpeed >= targetSpeed then
		return
	end

	rootPart.AssemblyLinearVelocity = velocity + normal * (targetSpeed - normalSpeed)
end

local function startJump(rootPart: BasePart, normal: Vector3)
	local movement = WheelchairConfig.Movement
	local now = os.clock()

	if not movement.EnableJump or not grounded or now - lastJumpAt < movement.JumpCooldown then
		return
	end

	jumpNormal = normal.Unit
	jumpTargetSpeed = getJumpTargetSpeed(
		movement.JumpSpeed,
		movement.JumpTakeoffTime,
		movement.JumpStartSpeedRatio
	)
	jumpStartSpeed = jumpTargetSpeed * math.clamp(movement.JumpStartSpeedRatio, 0, 0.95)
	jumpStartedAt = now
	jumpActive = jumpTargetSpeed > 0
	lastJumpAt = now
	grounded = false

	setNormalSpeed(rootPart, jumpNormal, jumpStartSpeed)
end

local function updateJumpRamp(rootPart: BasePart)
	if not jumpActive then
		return
	end

	local movement = WheelchairConfig.Movement
	local takeoffTime = math.max(movement.JumpTakeoffTime, 0.001)
	local progress = math.clamp((os.clock() - jumpStartedAt) / takeoffTime, 0, 1)
	local easedProgress = progress * progress * (3 - 2 * progress)
	local desiredSpeed = lerpNumber(jumpStartSpeed, jumpTargetSpeed, easedProgress)

	setNormalSpeed(rootPart, jumpNormal, desiredSpeed)

	if progress >= 1 then
		jumpActive = false
	end
end

local function getAirInputVector(inputVector: Vector3): Vector3
	if inputVector.Magnitude > 1 then
		return inputVector.Unit
	end

	return inputVector
end

local function getAirControlForce(
	rootPart: BasePart,
	floorCFrame: CFrame,
	inputVector: Vector3
): Vector3
	local movement = WheelchairConfig.Movement
	local velocity = rootPart.AssemblyLinearVelocity
	local normalVelocity = floorNormal * velocity:Dot(floorNormal)
	local planarVelocity = velocity - normalVelocity
	local localPlanarVelocity = floorCFrame:VectorToObjectSpace(planarVelocity)
	local airInput = getAirInputVector(inputVector)

	localPlanarVelocity = Vector3.new(localPlanarVelocity.X, 0, localPlanarVelocity.Z)

	if airInput.Magnitude > WheelchairConfig.Input.DeadZone then
		local airMaxSpeed = movement.MaxSpeed * movement.AirMaxSpeedMultiplier
		targetVelocity = floorCFrame:VectorToWorldSpace(airInput * airMaxSpeed)

		return (targetVelocity - planarVelocity)
			* rootPart.AssemblyMass
			* movement.AirControlAcceleration
	end

	if localPlanarVelocity.Z > 0 then
		targetVelocity = floorCFrame:VectorToWorldSpace(Vector3.new(localPlanarVelocity.X, 0, 0))

		return (targetVelocity - planarVelocity)
			* rootPart.AssemblyMass
			* movement.AirBackwardBrakeAcceleration
	end

	return Vector3.zero
end

local function updateBmxMovement(
	vehicle: Model,
	rootPart: BasePart,
	moveForce: VectorForce,
	alignOrientation: AlignOrientation?,
	deltaTime: number
)
	local movement = WheelchairConfig.Movement
	local raycastResult = Workspace:Raycast(
		rootPart.Position,
		-floorNormal.Unit * movement.GroundRayLength,
		buildRaycastParams(vehicle)
	)

	if raycastResult ~= nil then
		local floorDistance = (raycastResult.Position - rootPart.Position).Magnitude
		grounded = floorDistance <= movement.GroundedDistance

		if grounded then
			floorNormal = raycastResult.Normal
		else
			floorNormal = floorNormal:Lerp(
				raycastResult.Normal,
				getAlpha(movement.GroundNormalAirLerpSpeed, deltaTime)
			).Unit
		end
	else
		grounded = false
		floorNormal = floorNormal:Lerp(Vector3.yAxis, getAlpha(1, deltaTime)).Unit
	end

	local floorCFrame = getFloorCFrame(rootPart, floorNormal)
	local inputVector = Vector3.new(currentDriveInput.moveX, 0, currentDriveInput.moveZ)

	if inputVector.Magnitude > 1 then
		inputVector = inputVector.Unit
	end

	if jumpQueued then
		startJump(rootPart, floorNormal)
		jumpQueued = false
	end

	updateJumpRamp(rootPart)

	if jumpActive then
		grounded = false
	end

	if grounded then
		targetVelocity = floorCFrame:VectorToWorldSpace(inputVector * movement.MaxSpeed)
		moveForce.Force = (targetVelocity - rootPart.AssemblyLinearVelocity)
			* rootPart.AssemblyMass
			* movement.ForceAcceleration
	else
		moveForce.Force = getAirControlForce(rootPart, floorCFrame, inputVector)
	end

	clampPlanarVelocity(rootPart, floorNormal)

	local localVelocity = floorCFrame:VectorToObjectSpace(rootPart.AssemblyLinearVelocity)
	local planarLocalVelocity = Vector3.new(localVelocity.X, 0, localVelocity.Z)

	if planarLocalVelocity.Magnitude > 1 then
		orientation = orientation:Lerp(
			CFrame.new(Vector3.zero, planarLocalVelocity),
			getAlpha(movement.OrientationLerpSpeed, deltaTime)
		)
	end

	local targetLean =
		math.clamp(-localVelocity.X / 45, -movement.MaxBodyLean, movement.MaxBodyLean)
	bodyLean = lerpNumber(bodyLean, targetLean, getAlpha(5, deltaTime))

	if alignOrientation ~= nil then
		alignOrientation.Enabled = true
		alignOrientation.CFrame = floorCFrame * orientation * CFrame.Angles(0, 0, bodyLean)
	end
end

local function updateWheelVisuals(vehicle: Model, rootPart: BasePart, deltaTime: number)
	local wheelMotors = getWheelMotors(vehicle)
	local movement = WheelchairConfig.Movement
	local velocity = rootPart.AssemblyLinearVelocity
	local flatSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local inputMagnitude = Vector2.new(currentDriveInput.moveX, currentDriveInput.moveZ).Magnitude

	if inputMagnitude > WheelchairConfig.Input.DeadZone then
		if
			currentDriveInput.moveZ > 0.15
			and math.abs(currentDriveInput.moveZ) >= math.abs(currentDriveInput.moveX)
		then
			wheelDirection = -1
		else
			wheelDirection = 1
		end
	end

	local signedDistance = flatSpeed * wheelDirection * deltaTime
	local turnBias = currentDriveInput.moveX * flatSpeed * movement.WheelTurnSpinBias * deltaTime

	leftRearRotation += (signedDistance - turnBias) / movement.RearWheelRadius
	rightRearRotation += (signedDistance + turnBias) / movement.RearWheelRadius
	casterRotation += signedDistance / movement.FrontCasterRadius

	setMotorTransform(wheelMotors.leftRear, CFrame.Angles(-leftRearRotation, 0, 0))
	setMotorTransform(wheelMotors.rightRear, CFrame.Angles(-rightRearRotation, 0, 0))

	local localVelocity = rootPart.CFrame:VectorToObjectSpace(velocity)
	local casterTargetYaw = 0

	if Vector2.new(localVelocity.X, localVelocity.Z).Magnitude > 1 then
		casterTargetYaw = math.atan2(localVelocity.X, -localVelocity.Z)
	elseif inputMagnitude > WheelchairConfig.Input.DeadZone then
		casterTargetYaw = math.atan2(currentDriveInput.moveX, -currentDriveInput.moveZ)
	end

	casterYaw =
		lerpAngle(casterYaw, casterTargetYaw, getAlpha(movement.CasterYawLerpSpeed, deltaTime))

	setMotorTransform(wheelMotors.leftCasterPivot, CFrame.Angles(0, casterYaw, 0))
	setMotorTransform(wheelMotors.rightCasterPivot, CFrame.Angles(0, casterYaw, 0))

	if wheelMotors.leftCasterPivot ~= nil then
		setMotorTransform(wheelMotors.leftCaster, CFrame.Angles(-casterRotation, 0, 0))
	else
		setMotorTransform(
			wheelMotors.leftCaster,
			CFrame.Angles(0, casterYaw, 0) * CFrame.Angles(-casterRotation, 0, 0)
		)
	end

	if wheelMotors.rightCasterPivot ~= nil then
		setMotorTransform(wheelMotors.rightCaster, CFrame.Angles(-casterRotation, 0, 0))
	else
		setMotorTransform(
			wheelMotors.rightCaster,
			CFrame.Angles(0, casterYaw, 0) * CFrame.Angles(-casterRotation, 0, 0)
		)
	end
end

local function stopDefaultAnimations(character: Model, humanoid: Humanoid)
	local animate = character:FindFirstChild("Animate")

	if animate ~= nil and animate:IsA("LocalScript") then
		animate.Disabled = true
	end

	local now = os.clock()

	if now - lastAnimationStopAt < WheelchairConfig.Pose.AnimationStopInterval then
		return
	end

	lastAnimationStopAt = now

	local animator = humanoid:FindFirstChildOfClass("Animator")

	if animator == nil then
		return
	end

	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		track:Stop(0.15)
	end
end

local function updateCharacterPose(rootPart: BasePart, deltaTime: number)
	local character = getCharacter()
	local humanoid = getHumanoid()

	if character == nil or humanoid == nil then
		return
	end

	stopDefaultAnimations(character, humanoid)

	local motors = getPoseMotors(character)
	local camera = Workspace.CurrentCamera
	local targetHeadYaw = 0
	local targetHeadPitch = 0

	if camera ~= nil then
		local localLook = rootPart.CFrame:VectorToObjectSpace(camera.CFrame.LookVector)
		targetHeadYaw = math.clamp(
			math.atan2(localLook.X, -localLook.Z),
			-WheelchairConfig.Pose.HeadYawLimit,
			WheelchairConfig.Pose.HeadYawLimit
		)
		targetHeadPitch = math.clamp(
			math.asin(math.clamp(localLook.Y, -1, 1)),
			-WheelchairConfig.Pose.HeadPitchLimit,
			WheelchairConfig.Pose.HeadPitchLimit
		)
	end

	local headAlpha = getAlpha(WheelchairConfig.Pose.HeadLerpSpeed, deltaTime)
	headYaw = lerpAngle(headYaw, targetHeadYaw, headAlpha)
	headPitch = lerpNumber(headPitch, targetHeadPitch, headAlpha)

	local velocity = rootPart.AssemblyLinearVelocity
	local acceleration = velocity - lastPoseVelocity
	lastPoseVelocity = velocity

	bodySpring:Shove(-acceleration * 0.035)
	local springPosition = rootPart.CFrame:VectorToObjectSpace(bodySpring:Update(deltaTime))
	local speedRatio =
		math.clamp(velocity.Magnitude / math.max(WheelchairConfig.Movement.MaxSpeed, 1), 0, 1)
	local pushPhase = (leftRearRotation + rightRearRotation) * 0.5
	local push = math.sin(pushPhase) * speedRatio * WheelchairConfig.Pose.PushCycleScale
	local pushReturn = math.cos(pushPhase) * speedRatio * WheelchairConfig.Pose.PushCycleScale

	setMotorTransform(
		motors.waist,
		CFrame.Angles(math.rad(-6) - springPosition.Z * 0.03, 0, bodyLean * 0.35)
	)
	setMotorTransform(motors.neck, CFrame.Angles(headPitch, headYaw, 0))

	setMotorTransform(
		motors.rightShoulder,
		CFrame.Angles(math.rad(28) + push * 0.35, math.rad(-12), math.rad(48))
	)
	setMotorTransform(
		motors.leftShoulder,
		CFrame.Angles(math.rad(28) - push * 0.35, math.rad(12), math.rad(-48))
	)
	setMotorTransform(motors.rightElbow, CFrame.Angles(math.rad(-82) + pushReturn * 0.28, 0, 0))
	setMotorTransform(motors.leftElbow, CFrame.Angles(math.rad(-82) - pushReturn * 0.28, 0, 0))
	setMotorTransform(motors.rightWrist, CFrame.Angles(math.rad(-8), 0, math.rad(-10)))
	setMotorTransform(motors.leftWrist, CFrame.Angles(math.rad(-8), 0, math.rad(10)))

	setMotorTransform(motors.rightHip, CFrame.Angles(math.rad(-72), 0, math.rad(8)))
	setMotorTransform(motors.leftHip, CFrame.Angles(math.rad(-72), 0, math.rad(-8)))
	setMotorTransform(motors.rightKnee, CFrame.Angles(math.rad(82), 0, 0))
	setMotorTransform(motors.leftKnee, CFrame.Angles(math.rad(82), 0, 0))
	setMotorTransform(motors.rightAnkle, CFrame.Angles(math.rad(-12), 0, math.rad(-4)))
	setMotorTransform(motors.leftAnkle, CFrame.Angles(math.rad(-12), 0, math.rad(4)))
end

local function initializeCameraAngles(rootPart: BasePart)
	local camera = Workspace.CurrentCamera
	local lookVector = if camera ~= nil
		then camera.CFrame.LookVector
		else rootPart.CFrame.LookVector
	local flatLookVector = Vector3.new(lookVector.X, 0, lookVector.Z)

	if flatLookVector.Magnitude < 0.05 then
		flatLookVector = Vector3.new(rootPart.CFrame.LookVector.X, 0, rootPart.CFrame.LookVector.Z)
	end

	if flatLookVector.Magnitude < 0.05 then
		cameraYaw = 0
	else
		cameraYaw = math.atan2(-flatLookVector.X, -flatLookVector.Z)
	end

	cameraPitch = math.clamp(
		math.asin(math.clamp(lookVector.Y, -1, 1)),
		WheelchairConfig.Camera.MinPitch,
		WheelchairConfig.Camera.MaxPitch
	)
end

local function enableRacingCamera(rootPart: BasePart)
	if cameraEnabled then
		return
	end

	cameraEnabled = true
	initializeCameraAngles(rootPart)

	local camera = Workspace.CurrentCamera

	if camera ~= nil then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = WheelchairConfig.Camera.FieldOfView
	end

	UserInputService.MouseIconEnabled = false
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
end

local function restoreDefaultCamera()
	cameraEnabled = false

	local camera = Workspace.CurrentCamera
	local humanoid = getHumanoid()

	if camera ~= nil then
		camera.CameraType = Enum.CameraType.Custom

		if humanoid ~= nil then
			camera.CameraSubject = humanoid
		end
	end

	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
end

local function updateCamera(vehicle: Model, rootPart: BasePart, deltaTime: number)
	enableRacingCamera(rootPart)

	local camera = Workspace.CurrentCamera

	if camera == nil then
		return
	end

	local cameraConfig = WheelchairConfig.Camera
	local focus = rootPart.Position + Vector3.new(0, cameraConfig.FocusHeight, 0)
	local desiredCFrame = CFrame.new(focus)
		* CFrame.Angles(0, cameraYaw, 0)
		* CFrame.Angles(cameraPitch, 0, 0)
		* CFrame.new(0, 0, cameraConfig.Distance)
	local rotation = desiredCFrame - desiredCFrame.Position
	local desiredPosition = desiredCFrame.Position
	local raycastResult =
		Workspace:Raycast(focus, desiredPosition - focus, buildRaycastParams(vehicle))
	local cameraPosition = desiredPosition

	if raycastResult ~= nil then
		cameraPosition = raycastResult.Position
			+ raycastResult.Normal * cameraConfig.CollisionPadding
	end

	local targetCFrame = CFrame.new(cameraPosition) * rotation
	local alpha = getAlpha(cameraConfig.LerpSpeed, deltaTime)

	camera.CFrame = camera.CFrame:Lerp(targetCFrame, alpha)
	camera.Focus = CFrame.new(focus)
	camera.FieldOfView = lerpNumber(
		camera.FieldOfView,
		cameraConfig.FieldOfView
			+ rootPart.AssemblyLinearVelocity.Magnitude * cameraConfig.SpeedFovBoost,
		getAlpha(5, deltaTime)
	)
end

local function beginDriving(rootPart: BasePart)
	wasDriving = true
	floorNormal = Vector3.yAxis
	grounded = false
	targetVelocity = Vector3.zero
	bodyLean = 0
	jumpQueued = false
	jumpActive = false
	jumpStartedAt = 0
	jumpStartSpeed = 0
	jumpTargetSpeed = 0
	jumpNormal = Vector3.yAxis
	lastPoseVelocity = rootPart.AssemblyLinearVelocity

	local flatForward = Vector3.new(rootPart.CFrame.LookVector.X, 0, rootPart.CFrame.LookVector.Z)

	if flatForward.Magnitude < 0.05 then
		flatForward = Vector3.zAxis * -1
	end

	orientation = CFrame.new(Vector3.zero, flatForward.Unit)
	initializeCameraAngles(rootPart)
end

local function endDriving(rootPart: BasePart?)
	wasDriving = false
	clearActionState()
	sendDriveInput(WheelchairConfig.sanitizeDriveInput(nil), true)
	resetPoseMotors()
	restoreDefaultCamera()

	if rootPart ~= nil then
		local force = getMoveForce(rootPart)

		if force ~= nil then
			force.Force = Vector3.zero
		end
	end
end

local function handleDriveAction(
	actionName: string,
	inputState: Enum.UserInputState
): Enum.ContextActionResult
	local _, rootPart = getDrivingWheelchair()

	if rootPart == nil then
		clearActionState()
		return Enum.ContextActionResult.Pass
	end

	local isPressed = inputState == Enum.UserInputState.Begin
	local isReleased = inputState == Enum.UserInputState.End
		or inputState == Enum.UserInputState.Cancel

	if not isPressed and not isReleased then
		return Enum.ContextActionResult.Sink
	end

	local value = if isPressed then 1 else 0

	if actionName == "WheelchairForward" then
		actionState.forward = value
	elseif actionName == "WheelchairBackward" then
		actionState.backward = value
	elseif actionName == "WheelchairLeft" then
		actionState.left = value
	elseif actionName == "WheelchairRight" then
		actionState.right = value
	elseif actionName == "WheelchairJump" then
		actionState.jump = isPressed

		if isPressed then
			queueJump()
		end
	end

	currentDriveInput = buildDriveInput()
	sendDriveInput(currentDriveInput, actionName == "WheelchairJump")

	return Enum.ContextActionResult.Sink
end

local actionPriority = Enum.ContextActionPriority.High.Value + 100

ContextActionService:BindActionAtPriority(
	"WheelchairForward",
	handleDriveAction,
	false,
	actionPriority,
	Enum.KeyCode.W,
	Enum.KeyCode.Up
)
ContextActionService:BindActionAtPriority(
	"WheelchairBackward",
	handleDriveAction,
	false,
	actionPriority,
	Enum.KeyCode.S,
	Enum.KeyCode.Down
)
ContextActionService:BindActionAtPriority(
	"WheelchairLeft",
	handleDriveAction,
	false,
	actionPriority,
	Enum.KeyCode.A,
	Enum.KeyCode.Left
)
ContextActionService:BindActionAtPriority(
	"WheelchairRight",
	handleDriveAction,
	false,
	actionPriority,
	Enum.KeyCode.D,
	Enum.KeyCode.Right
)
ContextActionService:BindActionAtPriority(
	"WheelchairJump",
	handleDriveAction,
	false,
	actionPriority,
	Enum.KeyCode.Space
)

UserInputService.InputChanged:Connect(function(inputObject: InputObject, processed: boolean)
	if
		processed
		or not cameraEnabled
		or inputObject.UserInputType ~= Enum.UserInputType.MouseMovement
	then
		return
	end

	cameraYaw = (cameraYaw - inputObject.Delta.X * WheelchairConfig.Camera.Sensitivity)
		% (math.pi * 2)
	cameraPitch = math.clamp(
		cameraPitch - inputObject.Delta.Y * WheelchairConfig.Camera.Sensitivity,
		WheelchairConfig.Camera.MinPitch,
		WheelchairConfig.Camera.MaxPitch
	)
end)

RunService.RenderStepped:Connect(function(deltaTime: number)
	local vehicle, rootPart = getDrivingWheelchair()

	if vehicle == nil or rootPart == nil then
		if wasDriving then
			endDriving(rootPart)
		end

		return
	end

	if not wasDriving then
		beginDriving(rootPart)
	end

	currentDriveInput = buildDriveInput()

	if
		hasInputChanged(currentDriveInput, lastSentInput)
		or WheelchairConfig.hasActiveInput(currentDriveInput)
	then
		sendDriveInput(currentDriveInput, false)
	end

	local moveForce = getMoveForce(rootPart)

	if moveForce == nil then
		return
	end

	updateBmxMovement(vehicle, rootPart, moveForce, getAlignOrientation(rootPart), deltaTime)
	updateWheelVisuals(vehicle, rootPart, deltaTime)
	updateCharacterPose(rootPart, deltaTime)
	updateCamera(vehicle, rootPart, deltaTime)
end)
