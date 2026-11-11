local ADDON_NAME, ns = ...

-- Holiday and AQ war effort pins follow live state. Questie's generated
-- Database/EventPolicy.lua supplies year-less event windows; the client clock
-- decides whether a window is open. Darkmoon Faire has no Forever window and
-- is emitted as disabled.

local function Call(apiTable, name)
    local fn = apiTable and apiTable[name]
    if type(fn) == "function" then
        return fn
    end
end

--- Return the current server calendar time, or nil when no date API exists.
-- @return table|nil with month, day, hour, minute, year, and source
function ns.CalendarNow()
    local current = Call(C_DateAndTime, "GetCurrentCalendarTime")
    if current then
        local ok, value = pcall(current)
        if ok and type(value) == "table" and value.month and value.monthDay then
            return {
                month = value.month,
                day = value.monthDay,
                hour = value.hour or 0,
                minute = value.minute or 0,
                year = value.year,
                source = "C_DateAndTime.GetCurrentCalendarTime",
            }
        end
    end
    local today = Call(C_DateAndTime, "GetTodaysDate")
    if today then
        local ok, month, day, year = pcall(today)
        if ok and month and day then
            return {
                month = month,
                day = day,
                hour = 0,
                minute = 0,
                year = year,
                source = "C_DateAndTime.GetTodaysDate",
            }
        end
    end
    if type(date) == "function" then
        local ok, value = pcall(date, "*t")
        if ok and type(value) == "table" and value.month and value.day then
            return {
                month = value.month,
                day = value.day,
                hour = value.hour or 0,
                minute = value.min or 0,
                year = value.year,
                source = "date",
            }
        end
    end
    return nil
end

--- Comparable year-less stamp for a month/day/hour/minute tuple.
function ns.EventStamp(month, day, hour, minute)
    return ((month * 100 + day) * 100 + hour) * 100 + minute
end

--- Inclusive window test. A start later than its end crosses New Year.
function ns.InWindow(window, stamp)
    if not window or not stamp then
        return false
    end
    local startTuple = window[1]
    local endTuple = window[2]
    if not startTuple or not endTuple then
        return false
    end
    local startStamp = ns.EventStamp(startTuple[1], startTuple[2], startTuple[3], startTuple[4])
    local endStamp = ns.EventStamp(endTuple[1], endTuple[2], endTuple[3], endTuple[4])
    if startStamp <= endStamp then
        return stamp >= startStamp and stamp <= endStamp
    end
    return stamp >= startStamp or stamp <= endStamp
end

local function EventWindowFor(policy, eventName, now)
    if eventName == "Lunar Festival" then
        if not now.year or not policy.lunar[now.year] then
            return nil, "lunar-year-unknown"
        end
        return policy.lunar[now.year], nil
    end
    local window = policy.events[eventName]
    if not window then
        return nil, "event-unknown"
    end
    return window, nil
end

--- Report whether a holiday quest's event is live.
-- @return active boolean
-- @return reason string
-- @return detail table|nil with event, window, override, now, and questID
function ns.GetEventState(questID)
    local policy = ns.EventPolicy
    if not policy or not policy.byQuest then
        return false, "event-unknown"
    end
    local eventName = policy.byQuest[questID]
    if not eventName then
        return false, "event-unknown"
    end
    local detail = {
        event = eventName,
        questID = questID,
        override = policy.overrides and policy.overrides[questID],
    }
    if policy.disabled and policy.disabled[eventName] then
        return false, "event-disabled", detail
    end
    local now = ns.CalendarNow()
    detail.now = now
    if not now then
        return false, "calendar-unknown", detail
    end
    local window, reason = EventWindowFor(policy, eventName, now)
    detail.window = window
    if not window then
        return false, reason, detail
    end
    local stamp = ns.EventStamp(now.month, now.day, now.hour, now.minute)
    detail.stamp = stamp
    if not ns.InWindow(window, stamp) then
        return false, "event-window", detail
    end
    if detail.override and not ns.InWindow(detail.override, stamp) then
        return false, "event-window", detail
    end
    return true, "event-active", detail
end
