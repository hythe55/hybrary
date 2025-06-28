-- clock.lua
local clock = {}

local timeUnits = {
	{ name = "day", seconds = 86400 },
	{ name = "hour", seconds = 3600 },
	{ name = "minute", seconds = 60 },
	{ name = "second", seconds = 1 },
}

-- Returns os.time
function clock.now(time: DateTypeArg?): number
	return os.time(time)
end

-- Returns a number of seconds between two timestamps
function clock.diff(t1: number, t2: number): number
	return math.abs(t1 - t2)
end

-- Adds time to a base timestamp
function clock.addTime(timestamp: number, seconds: number): number
	return timestamp + seconds
end

-- Parses a date table or time string into a Unix timestamp
function clock.fromDate(date: table): number
	return os.time(date)
end

-- Checks if a year is a leap year
function clock.isLeapYear(year: number): boolean
	return (year % 4 == 0 and year % 100 ~= 0) or (year % 400 == 0)
end

-- Converts seconds to HH:MM AM/PM
function clock.toShortTime(seconds: number): string
	local date = os.date("!*t", seconds)
	local hour = date.hour % 12
	hour = (hour == 0) and 12 or hour
	local ampm = (date.hour >= 12) and "PM" or "AM"
	return string.format("%d:%02d %s", hour, date.min, ampm)
end

-- Gets the day of the week from a timestamp
function clock.getDayOfWeek(timestamp: number): string
	return os.date("%A", timestamp)
end

-- Converts a timestamp to a formatted date string (YYYY-MM-DD)
function clock.toDateString(timestamp: number): string
	return os.date("!%Y-%m-%d", timestamp)
end

-- Converts a timestamp to a formatted time string (HH:MM:SS)
function clock.toTimeString(timestamp: number): string
	return os.date("!%H:%M:%S", timestamp)
end

-- Returns number of days in a given month/year
function clock.getDaysInMonth(month: number, year: number): number
	local days = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
	if month == 2 and clock.isLeapYear(year) then
		return 29
	end
	return days[month]
end

-- Converts a number to a HH:MM:SS string (optional days and hours)
function clock.toTimer(start: number, finish: number?, showDays: boolean?, showHours: boolean?, showMinutes: boolean?): string
	local seconds = finish and math.max(0, math.floor(finish - start)) or math.max(0, math.floor(start))
	local days = math.floor(seconds / 86400)
	seconds = seconds % 86400
	local hours = math.floor(seconds / 3600)
	seconds = seconds % 3600
	local minutes = math.floor(seconds / 60)
	local secs = seconds % 60
	local parts = {}
	local showD = showDays or days > 0
	local showH = showHours or showD or hours > 0
	local showM = showMinutes or showH or minutes > 0
	local rawParts = {}
	if showD then table.insert(rawParts, days) end
	if showH then table.insert(rawParts, hours) end
	if showM then table.insert(rawParts, minutes) end
	table.insert(rawParts, secs)
	for i, val in ipairs(rawParts) do
		if i == 1 then
			if #rawParts == 1 then
				parts[i] = string.format("%02d", val)
			else
				parts[i] = tostring(val)
			end
		else
			parts[i] = string.format("%02d", val)
		end
	end
	return table.concat(parts, ":")
end

-- Converts a timestamp (os.time()) to a table with year, month, day, hour, min, and sec (UTC)
function clock.toDateTime(timestamp: number): table
	local dt = os.date("!*t", timestamp)
	return {
		year = dt.year,
		month = dt.month,
		day = dt.day,
		hour = dt.hour,
		min = dt.min,
		sec = dt.sec,
	}
end

-- Converts a number (os.time()) to MM/DD/YYYY
function clock.toDate(timestamp: number): string
	local date = os.date("!*t", timestamp)
	return string.format("%02d/%02d/%04d", date.month, date.day, date.year)
end

-- Converts a number (os.time()) to HH:MM:SS
function clock.toClock(seconds: number): string
	local hrs = math.floor(seconds / 3600)
	local mins = math.floor((seconds % 3600) / 60)
	local secs = seconds % 60
	return string.format("%02d:%02d:%02d", hrs, mins, secs)
end

-- Converts seconds into a human-readable relative time
function clock.toRelativeTime(timestamp: number): string
	local now = os.time()
	local diff = os.difftime(now, timestamp)
	local future = diff < 0
	diff = math.abs(diff)
	for _, unit in ipairs(timeUnits) do
		local value = math.floor(diff / unit.seconds)
		if value > 0 then
			local label = value == 1 and unit.name or (unit.name .. "s")
			return string.format("%d %s %s", value, label, future and "from now" or "ago")
		end
	end
	return "just now"
end

-- Parses a string "HH:MM:SS" or "MM:SS" into seconds
function clock.parseTimeString(str: string): number
	local parts = {}
	for part in string.gmatch(str, "(%d+)") do
		table.insert(parts, tonumber(part))
	end
	local result = 0
	local multiplier = 1
	for i = #parts, 1, -1 do
		result = result + parts[i] * multiplier
		multiplier = multiplier * 60
	end
	return result
end

-- Converts a timestamp into "YYYY-MM-DD HH:MM:SS"
function clock.toDateTimeString(timestamp: number): string
	return os.date("!%Y-%m-%d %H:%M:%S", timestamp)
end

-- Runs a function after a delay until a specific epoch timestamp
function clock.schedule(timestamp: number, callback: () -> ())
	local delay = math.max(0, timestamp - os.time())
	return task.delay(delay, callback)
end

-- Returns the number of full days since Unix epoch (UTC)
function clock.getDay(): number
	return math.floor(os.time() / 86400)
end

return clock