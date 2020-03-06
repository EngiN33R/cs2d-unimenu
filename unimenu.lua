local unimenu = {
    specs = {},
    historyBack = {},
    historyForward = {},
    currentMenu = {},
    defaults = {
        BACK = {"< Back", ""},
        NEXT = {"Next >", ""},
        TITLE_FORMATTER = function(title, page) return title .. " (Page " .. page .. ")" end,
    },

    exports = {
        __VERSION = 2.0,
    },
}

local function nilTostring(str)
    if (str == nil) then
        return ""
    end
    return tostring(str)
end

local function buildMenu(spec)
    local pages = {}

    -- Previous and next page closures
    local openPrevPage = function(id)
        local current = unimenu.currentMenu[id]
        local rPage = current.page - 1
        if (rPage < 1) then
            if (spec.loop) then
                rPage = #current.pages
            else
                rPage = 1
            end
        end
        if (current.spec.onPrevPage) then current.spec.onPrevPage(id, rPage) end
        unimenu.exports.switchPage(id, rPage)
    end
    local openNextPage = function(id)
        local current = unimenu.currentMenu[id]
        local rPage = current.page + 1
        local maxPage = #current.pages
        if (rPage > maxPage) then
            if (spec.loop) then
                rPage = 1
            else
                rPage = maxPage
            end
        end
        if (current.spec.onNextPage) then current.spec.onNextPage(id, rPage) end
        unimenu.exports.switchPage(id, rPage)
    end
    local onCancel = function(id)
        if (spec.onCancel) then spec.onCancel(id) end
        unimenu.currentMenu[id] = nil
    end

    -- Fixed slot map
    local itemsPerPage = 7
    local fixedSlots = {[8] = "back", [9] = "next"}
    if (spec.fixedItems) then
        for i, _ in pairs(spec.fixedItems) do
            if (i < 8) then itemsPerPage = itemsPerPage - 1 end
            fixedSlots[i] = "fixed"
        end
    end
    -- Allow overriding how many items appear per page, but never try to display more
    -- than there are free slots on a page
    if (spec.perPage) then
        itemsPerPage = math.min(spec.perPage, itemsPerPage)
    end

    -- Process back and forward button overrides
    local backText = spec.backText or unimenu.exports.getDefault("BACK")
    local nextText = spec.nextText or unimenu.exports.getDefault("NEXT")

    -- Calculate how many pages should appear, but show at least one, even if empty
    local totalPages = 0
    if (itemsPerPage > 0) then
        totalPages = math.max(math.ceil(#spec.items / itemsPerPage), 1)
    end
    totalPages = math.max(1, totalPages)
    for page = 1, totalPages do
        pages[page] = {}
        -- Process fixed slots first
        for slot, slotType in pairs(fixedSlots) do
            if (slotType == "back") then
                pages[page][slot] = { backText[1], backText[2], openPrevPage, not spec.loop and page == 1 }
            elseif (slotType == "next") then
                pages[page][slot] = { nextText[1], nextText[2], openNextPage, not spec.loop and page == totalPages }
            elseif (slotType == "fixed") then
                pages[page][slot] = spec.fixedItems[slot]
            end
        end
        -- Fit `itemsPerPage` items into the remaining empty slots
        if (itemsPerPage > 0) then
            local offset = itemsPerPage * (page - 1)
            local offsetItem = 1
            for i = 1, 9 do
                if (pages[page][i] == nil) then
                    local itemId = offset + offsetItem
                    pages[page][i] = spec.items[itemId]
                    offsetItem = offsetItem + 1
                    if (offsetItem > itemsPerPage) then break end
                end
            end
        end
    end

    local function titleFunc(page)
        local title
        if (type(spec.title) == "function") then
            title = spec.title(page)
        else
            title = unimenu.defaults.TITLE_FORMATTER(nilTostring(spec.title), page)
        end
        return title
    end

    -- Constructs a menu string from the spec and a given page
    -- Uses the value of `pages` at construct time; runtime changes will not be picked up
    local function tostringFunc(page)
        local title = titleFunc(page)
        if (spec.invisible) then
            title = title .. "@i"
        elseif (spec.big) then
            title = title .. "@b"
        end
        local items = {}
        for i = 1, 9 do
            local itemSpec = pages[page][i]
            if (not itemSpec) then
                items[i] = ""
            else
                items[i] = nilTostring(itemSpec[1] or itemSpec.caption) .. "|" .. nilTostring(itemSpec[2] or itemSpec.desc)
                if (itemSpec[4] or itemSpec.disabled) then items[i] = "(" .. items[i] .. ")" end
            end
        end
        return title .. "," .. table.concat(items, ",")
    end

    -- Entrypoint for the hook
    local function onSelect(id, page, item)
        if (item == 0) then
            onCancel(id)
        end
        if (not pages[page]) then return end
        local itemSpec = pages[page][item]
        if (not itemSpec) then return end
        local func = itemSpec[3] or itemSpec.func
        if (not func) then return end
        func(id)
    end

    return {
        spec = spec,
        pages = pages,
        page = 1,
        title = titleFunc,
        tostring = tostringFunc,
        onCancel = onCancel,
        onSelect = onSelect,
    }
end

local function initHistory(id)
    if (not unimenu.historyBack[id]) then unimenu.historyBack[id] = {} end
    if (not unimenu.historyForward[id]) then unimenu.historyForward[id] = {} end
end

function unimenu.exports.open(id, spec, page)
    page = page or 1

    local tblSpec
    if (type(spec) == "string") then
        tblSpec = unimenu.specs[spec]
        if (not tblSpec) then
            error("invalid menu spec provided: " .. spec .. " not found in globally registered specs", 2)
        end
    elseif (type(spec) == "table") then
        tblSpec = spec
    else
        error("invalid menu spec provided: table or string expected, got " .. type(spec), 2)
    end

    -- Push current menu to history stack
    initHistory(id)
    if (unimenu.currentMenu[id]) then
        table.insert(unimenu.historyBack[id], unimenu.currentMenu[id])
        if (#unimenu.historyForward[id] > 0) then
            unimenu.historyForward[id] = {}
        end
    end
    -- Set new menu to be current
    unimenu.currentMenu[id] = buildMenu(tblSpec)
    unimenu.currentMenu[id].page = page
    menu(id, unimenu.currentMenu[id].tostring(page))
end

function unimenu.exports.switchPage(id, page)
    local current = unimenu.currentMenu[id]
    if (page > #current.pages) then page = #current.pages end
    if (page < 1) then page = 1 end
    unimenu.currentMenu[id].page = page
    menu(id, unimenu.currentMenu[id].tostring(page))
end

function unimenu.exports.historyBack(id)
    initHistory(id)
    local history = unimenu.historyBack[id]
    local historySize = #history
    if (not history or historySize == 0) then return end
    local current = table.remove(history, historySize)
    table.insert(unimenu.historyForward[id], unimenu.currentMenu[id])
    unimenu.currentMenu[id] = current
    menu(id, current.tostring(current.page))
end

function unimenu.exports.historyForward(id)
    initHistory(id)
    local history = unimenu.historyForward[id]
    local historySize = #history
    if (not history or historySize == 0) then return end
    local current = table.remove(history, historySize)
    table.insert(unimenu.historyBack[id], unimenu.currentMenu[id])
    unimenu.currentMenu[id] = current
    menu(id, current.tostring(current.page))
end

function unimenu.exports.register(name, spec)
    unimenu.specs[name] = spec
end

function unimenu.exports.getSpec(name)
    return unimenu.specs[name]
end

function unimenu.exports.getCurrentPage(id)
    if (not unimenu.currentMenu[id]) then return nil end
    return unimenu.currentMenu[id].page
end

function unimenu.exports.getCurrent(id)
    return unimenu.currentMenu[id]
end

function unimenu.exports.getBackHistory(id)
    return unimenu.historyBack[id]
end

function unimenu.exports.getForwardHistory(id)
    return unimenu.historyForward[id]
end

function unimenu.exports.setDefault(name, value)
    unimenu.defaults[name] = value
end

function unimenu.exports.getDefault(name)
    return unimenu.defaults[name]
end

addhook("menu", "__unimenu_hook")
function __unimenu_hook(id, title, sel)
    local uniMenu = unimenu.currentMenu[id]
    if (not uniMenu) then return 0 end
    local page = uniMenu.page
    local uniTitle = uniMenu.title(page)
    if (title == uniTitle) then
        uniMenu.onSelect(id, page, sel)
    end
end

return unimenu.exports
