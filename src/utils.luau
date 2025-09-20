local Utils = {}
Utils.shouldProfile = true;

function Utils.profiling() 
	if not Utils.shouldProfile then return function(label: string) end, function() end end

	return debug.profilebegin :: any, debug.profileend :: any
end

return Utils