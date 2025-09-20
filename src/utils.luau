local Utils = {}
Utils.shouldProfile = false;

function Utils.profiling() 
	if Utils.shouldProfile then return function(label: string) end, function() end end

	return debug.profilebegin :: any, debug.profileend :: any
end

return Utils