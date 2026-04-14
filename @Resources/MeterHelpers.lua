function Initialize()
    dataFile = SELF:GetOption("DataFile")
    resultName = SELF:GetOption("ResultName")
end

local function trim(value)
    return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function readAll(path)
    local handle = io.open(path, "r")
    if not handle then
        return nil
    end

    local content = handle:read("*a")
    handle:close()
    return content
end

local function parseNumber(content, key, defaultValue)
    local pattern = '"' .. key .. '"%s*:%s*([%d%.]+)'
    local match = content and content:match(pattern)
    local value = tonumber(match)
    if value == nil then
        return defaultValue or 0
    end
    return value
end

local function parseString(content, key, defaultValue)
    local pattern = '"' .. key .. '"%s*:%s*"(.-)"'
    local match = content and content:match(pattern)
    if match == nil or trim(match) == "" then
        return defaultValue or ""
    end
    return match
end

local function parseNamedBlock(content, blockName)
    if not content then
        return nil
    end

    local blockPattern = '"' .. blockName .. '"%s*:%s*%b{}'
    return content:match(blockPattern)
end

local function parseServiceBlock(content, service)
    local blockPattern = '"' .. service .. '"%s*:%s*%b{}'
    local serviceBlock = content and content:match(blockPattern)
    if not serviceBlock then
        return nil
    end

    return {
        session = parseNamedBlock(serviceBlock, "session"),
        weekly = parseNamedBlock(serviceBlock, "weekly"),
        weeklyAllModels = parseNamedBlock(serviceBlock, "weeklyAllModels"),
        weeklySonnet = parseNamedBlock(serviceBlock, "weeklySonnet")
    }
end

local function utcToUnix(year, month, day, hour, minute, second)
    local localNow = os.time()
    local utcNow = os.time(os.date("!*t", localNow))
    local offset = os.difftime(localNow, utcNow)
    return os.time({
        year = year,
        month = month,
        day = day,
        hour = hour,
        min = minute,
        sec = second,
        isdst = false
    }) - offset
end

local function parseIsoUtc(value)
    if not value or value == "" then
        return nil
    end

    local year, month, day, hour, minute, second = value:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)Z$")
    if not year then
        return nil
    end

    return utcToUnix(
        tonumber(year),
        tonumber(month),
        tonumber(day),
        tonumber(hour),
        tonumber(minute),
        tonumber(second)
    )
end

local function formatRemaining(resetAt)
    local resetUnix = parseIsoUtc(resetAt)
    if not resetUnix then
        return "reset ?"
    end

    local remaining = math.floor(resetUnix - os.time())
    if remaining <= 0 then
        return "reset now"
    end

    local days = math.floor(remaining / 86400)
    local hours = math.floor((remaining % 86400) / 3600)
    local minutes = math.floor((remaining % 3600) / 60)

    if days > 0 then
        return string.format("reset %dd %02dh", days, hours)
    end

    if hours > 0 then
        return string.format("reset %dh %02dm", hours, minutes)
    end

    return string.format("reset %dm", minutes)
end

local function safePercent(used, maxValue)
    if maxValue <= 0 then
        return 0
    end

    local percent = (used / maxValue) * 100
    if percent < 0 then
        return 0
    end
    if percent > 100 then
        return 100
    end
    return percent
end

local function loadUsage()
    local content = readAll(dataFile)
    if not content then
        return {}
    end

    local function extract(serviceName, windowName)
        local serviceBlock = parseServiceBlock(content, serviceName)
        local windowBlock = serviceBlock and serviceBlock[windowName] or nil

        return {
            used = parseNumber(windowBlock, "used", 0),
            max = parseNumber(windowBlock, "max", 0),
            resetAt = parseString(windowBlock, "resetAtUtc", "")
        }
    end

    local function pctText(used, max)
        return string.format("%.0f%%", safePercent(used, max))
    end

    return {
        ClaudeSessionUsed = extract("claude", "session").used,
        ClaudeSessionMax = extract("claude", "session").max,
        ClaudeSessionPercent = safePercent(extract("claude", "session").used, extract("claude", "session").max),
        ClaudeSessionText = pctText(extract("claude", "session").used, extract("claude", "session").max),
        ClaudeSessionReset = formatRemaining(extract("claude", "session").resetAt),
        ClaudeAllModelsUsed = extract("claude", "weeklyAllModels").used,
        ClaudeAllModelsMax = extract("claude", "weeklyAllModels").max,
        ClaudeAllModelsPercent = safePercent(extract("claude", "weeklyAllModels").used, extract("claude", "weeklyAllModels").max),
        ClaudeAllModelsText = pctText(extract("claude", "weeklyAllModels").used, extract("claude", "weeklyAllModels").max),
        ClaudeAllModelsReset = formatRemaining(extract("claude", "weeklyAllModels").resetAt),
        ClaudeSonnetUsed = extract("claude", "weeklySonnet").used,
        ClaudeSonnetMax = extract("claude", "weeklySonnet").max,
        ClaudeSonnetPercent = safePercent(extract("claude", "weeklySonnet").used, extract("claude", "weeklySonnet").max),
        ClaudeSonnetText = pctText(extract("claude", "weeklySonnet").used, extract("claude", "weeklySonnet").max),
        ClaudeSonnetReset = formatRemaining(extract("claude", "weeklySonnet").resetAt),
        CodexSessionUsed = extract("codex", "session").used,
        CodexSessionMax = extract("codex", "session").max,
        CodexSessionPercent = safePercent(extract("codex", "session").used, extract("codex", "session").max),
        CodexSessionText = pctText(extract("codex", "session").used, extract("codex", "session").max),
        CodexSessionReset = formatRemaining(extract("codex", "session").resetAt),
        CodexWeeklyUsed = extract("codex", "weekly").used,
        CodexWeeklyMax = extract("codex", "weekly").max,
        CodexWeeklyPercent = safePercent(extract("codex", "weekly").used, extract("codex", "weekly").max),
        CodexWeeklyText = pctText(extract("codex", "weekly").used, extract("codex", "weekly").max),
        CodexWeeklyReset = formatRemaining(extract("codex", "weekly").resetAt)
    }
end

function Update()
    local usage = loadUsage()
    if resultName and resultName ~= "" then
        return usage[resultName] or 0
    end
    return 0
end
