local Spring = {}

function Spring.Create(_self, mass: number?, force: number?, damping: number?, speed: number?)
	local spring = {
		Target = Vector3.zero,
		Position = Vector3.zero,
		Velocity = Vector3.zero,

		Mass = mass or 1,
		Force = force or 50,
		Damping = damping or 2,
		Speed = speed or 1,
	}

	function spring:Shove(pushForce: Vector3)
		self.Velocity += pushForce
	end

	function spring:Update(deltaTime: number): Vector3
		local scaledDeltaTime = deltaTime * self.Speed
		local springForce = self.Target - self.Position
		local acceleration = (springForce * self.Force) / self.Mass

		acceleration -= self.Velocity * self.Damping

		self.Velocity += acceleration * scaledDeltaTime
		self.Position += self.Velocity * scaledDeltaTime

		return self.Position
	end

	return spring
end

return Spring
