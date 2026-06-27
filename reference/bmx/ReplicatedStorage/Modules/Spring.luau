--[[
	
	Author:		x_o
	Created:	03.09.2018
	Modified:	03.09.2018
	
	Spring module
	
--]]

-- Constants

-- Module

local SPRING	= {}

-- Functions

function SPRING.Create(self, mass, force, damping, speed)
	local spring	= {
		Target		= Vector3.new();
		Position	= Vector3.new();
		Velocity	= Vector3.new();
		
		Mass		= mass or 1;
		Force		= force or 50;
		Damping		= damping or 2;
		Speed		= speed or 1;
	}
	
	function spring.Shove(self, force)
		self.Velocity	= self.Velocity + force
	end
	
	function spring.Update(self, dt)
		local scaledDeltaTime	= dt * self.Speed
		
		local force			= self.Target - self.Position
		local acceleration	= (force * self.Force) / self.Mass
		
		acceleration		= acceleration - self.Velocity * self.Damping
		
		self.Velocity	= self.Velocity + acceleration * scaledDeltaTime
		self.Position	= self.Position + self.Velocity * scaledDeltaTime
		
		return self.Position
	end
	
	return spring
end

-- Return

return SPRING