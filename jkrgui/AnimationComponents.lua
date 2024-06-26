require "jkrgui.jkrgui"
require "jkrgui.ComTable"

local lerp = function (a, b, t)
	return (a * (1 - t) + t * b) * (1 - t) + b * t
end

local lerp_3f = function(a, b, t)
	return vec3(lerp(a.x, b.x, t), lerp(a.y, b.y, t), lerp(a.z, b.z, t))
end

Com.AnimateSingleTimePosDimen = function (inComponent, inFrom, inTo, inInverseSpeed, inEndFunction)
	Com.NewSimultaneousUpdate()
	local inverseSpeed = 0.01
	if inInverseSpeed then
		inverseSpeed = inInverseSpeed
	end
	local t = 0
	while t <= 1 do
		local from_pos = inFrom.mPosition_3f
		local to_pos = inTo.mPosition_3f
		local from_dimen  = inFrom.mDimension_3f
		local to_dimen = inTo.mDimension_3f
		local current_pos = lerp_3f(from_pos, to_pos, t)
		local current_dimen = lerp_3f(from_dimen, to_dimen, t)

		Com.NewSimultaneousSingleTimeUpdate(
			function ()
				inComponent:Update(current_pos, current_dimen)	
			end
		)

		t = t + inverseSpeed
	end
	if inEndFunction then
		Com.NewSimultaneousSingleTimeUpdate(inEndFunction)
	end
end


Com.AnimateSingleTimePosDimenCallback = function (inFrom, inTo, inInverseSpeed, inCallback_3f3f, inEndFunction)
	Com.NewSimultaneousUpdate()
	local inverseSpeed = 0.01
	if inInverseSpeed then
		inverseSpeed = inInverseSpeed
	end
	local t = 0
	while t <= 1 do
		local from_pos = inFrom.mPosition_3f
		local to_pos = inTo.mPosition_3f
		local from_dimen  = inFrom.mDimension_3f
		local to_dimen = inTo.mDimension_3f
		local current_pos = lerp_3f(from_pos, to_pos, t)
		local current_dimen = lerp_3f(from_dimen, to_dimen, t)

		Com.NewSimultaneousSingleTimeUpdate(
			function ()
		 		inCallback_3f3f(current_pos, current_dimen)	
			end
		)

		t = t + inverseSpeed
	end
	if inEndFunction then
		Com.NewSimultaneousSingleTimeUpdate(inEndFunction)
	end
end