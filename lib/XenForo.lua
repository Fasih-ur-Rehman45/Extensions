-- {"ver":"1.0.8","author":"JFronny","dep":["unhtml>=1.0.0","url>=1.0.0"]}

local HTMLToString = Require("unhtml").HTMLToString
local qs = Require("url").querystring

-- concatenate two lists
---@param list1 table
---@param list2 table
local function concatLists(list1, list2)
    for i = 1, #list2 do
        table.insert(list1, list2[i])
    end
    return list1
end

---@param v Element
local text = function(v)
    return v:text()
end

local defaults = {
    hasCloudFlare = false,
    hasSearch = true,
    isSearchIncrementing = true,
    chapterType = ChapterType.HTML,
    startIndex = 1,
    orderByModes = {
        { "Relevance", "relevance" },
        { "Date", "date" },
        { "Most recent", "last_update" },
        { "Most replies", "replies" },
        { "Words", "word_count" }
    }
}

function defaults:shrinkURL(url)
    return url:gsub("https?://.-/threads/", ""):gsub("/$", "")
end

function defaults:expandURL(url)
    return self.baseURL .. "threads/" .. url
end

function defaults:getPassage(url)
    --- Chapter page, extract info from it.
    local doc = GETDocument(self.expandURL(url, KEY_CHAPTER_URL))
    local id = url:gsub(".*#", "")
    local post = doc:selectFirst("#js-" .. id)
    local message = post:selectFirst(".bbWrapper")
    message:select(".bbCodeBlock-expandLink, .bbCodeBlock-shrinkLink"):remove()
    message:prepend("<h1>" .. post:selectFirst(".threadmarkLabel"):text() .. "</h1>")

    return pageOfElem(message, true)
end

local function extractImage(baseURL, element)
    if element == nil then return "" end
    local img = element:attr("src")
    if img == nil then return "" end
    img = img:gsub("^/", baseURL):gsub("?[0-9]*$", "")
    return img
end

local function extractTitle(element)
    map(element:select(".unreadLink"), function(v) v:remove() end)
    map(element:select(".labelLink"), function(v) v:remove() end)
    map(element:select(".label"), function(v) v:remove() end)
    map(element:select(".label-append"), function(v) v:remove() end)
    return element:text()
end

function defaults:parseNovel(novelURL, loadChapters)
    local threadmarks = GETDocument(self.expandURL(novelURL, KEY_NOVEL_URL) .. "/threadmarks?per_page=200")
    local head = threadmarks:selectFirst("head")

    local s = first(threadmarks:select(".threadmarkListingHeader-stats dl.pairs"), function(v)
        local headerTitle = v:selectFirst("dt"):text()
        return headerTitle == "Status" or headerTitle == "Index progress"
    end):selectFirst("dd"):text()

    s = s and ({
        Ongoing = NovelStatus.PUBLISHING,
        Incomplete = NovelStatus.PUBLISHING,
        Completed = NovelStatus.COMPLETED,
        Hiatus = NovelStatus.PAUSED
    })[s] or NovelStatus.UNKNOWN

    local username = threadmarks:select(".username")
    local img = threadmarks:selectFirst(".threadmarkListingHeader-icon img")
    if img == nil and username:size() > 0 then
        -- this _does_ mean that we have to make an additional request for most novels, but it's the only way to get the avatar here
        img = GETDocument(self.baseURL .. "members/." .. username:get(0):attr("data-user-id") .. "?tooltip=true"):selectFirst(".memberTooltip-avatar img")
    end
    local title = threadmarks:select(".p-title-value")
    if title == nil then
        title = head:selectFirst("meta[property='og:title']"):attr("content")
    else
        title = extractTitle(title)
    end
    local description = threadmarks:select(".threadmarkListingHeader-extraInfo .bbWrapper")
    if description == nil then
        description = head:selectFirst("meta[name='description']"):attr("content")
    else
        description = HTMLToString(description)
    end
    local novel = NovelInfo {
        title = title,
        imageURL = extractImage(self.baseURL, img),
        description = description,
        authors = map(username, text),
        status = s
    }

    if loadChapters then
        local threadmarkContainer = first(threadmarks:select(".threadmarkListingHeader-stats dl.pairs"), function(v)
            return v:selectFirst("dt"):text() == "Threadmarks"
        end)
        local count = threadmarkContainer:selectFirst("dd"):text():gsub(",", "")
        count = tonumber(count)
        count = count - count % 200
        count = count / 200 + 1
        local function parseChapters(novelDoc, page)
            local i = 0
            return mapNotNil(novelDoc:select(".structItemContainer .structItem"), function(v)
                local linkElement = v:selectFirst(".structItem-title a")
                local timeElement = v:selectFirst("time.structItem-latestDate")
                i = i + 1
                return NovelChapter {
                    order = (page - 1) * 200 + i,
                    title = linkElement:text(),
                    link = self.shrinkURL(linkElement:attr("href")):sub(10),
                    release = (timeElement and (timeElement:attr("title") or timeElement:attr("unixtime")))
                }
            end)
        end
        local chaps = parseChapters(threadmarks, 1)
        for i = 2, count do
            local next = GETDocument(self.expandURL(novelURL, KEY_NOVEL_URL) .. "/threadmarks?per_page=200&page=" .. i)
            chaps = concatLists(chaps, parseChapters(next, i))
        end
        novel:setChapters(AsList(chaps))
    end

    return novel
end

local function handleNovelURL(url)
    url = url:gsub("?.*$", "")
            :gsub("/$", "")
            :gsub("/threadmarks$", "")
            :gsub("/unread$", "")
            :sub(10)
    return url
end

local CATEGORY_FILTER_KEY = 100
local ORDER_BY_FILTER_KEY = 200

-- We need to find the search ID to get pages greater than 1.
-- It can change per search request, so we must keep it in memory
-- so when the next page is requested it doesn't get stuck in the first page
local searchID = "1"
local totalPages = 1 -- Store the total amount of search pages to avoid duplication
function defaults:search(data)
    -- The search ID can change what is shown, most probably any value higher than 0 works,
    -- but for safety, let's reset it to "1" because it is sure that it always will yield the first page of the search results
    if data[PAGE] == 1 then
        searchID = "1"
    end
    if data[PAGE] > totalPages then return {} end

    local forum = self.forums[1].forum
    if data[CATEGORY_FILTER_KEY] ~= 0 then
        forum = (map(self.forums, function(v)
            return v.forum
        end))[data[CATEGORY_FILTER_KEY] + 1]
    end
    local order = self.orderByModes[1][2]
    if data[ORDER_BY_FILTER_KEY] ~= 0 then
        order = self.orderByModes[data[ORDER_BY_FILTER_KEY] + 1][2]
    end

    -- Example search URLs (from SpaceBattles):
    -- Creative Writing: https://forums.spacebattles.com/search/1/?t=post&c[child_nodes]=1&c[nodes][0]=18&c[threadmark_categories][0]=1&c[threadmark_only]=1&c[title_only]=1&o=relevance&g=1&q=Josh
    -- Quests:           https://forums.spacebattles.com/search/1/?t=post&c[child_nodes]=1&c[nodes][0]=240&c[threadmark_categories][0]=1&c[threadmark_only]=1&c[title_only]=1&o=relevance&g=1&q=Josh
    local page = GETDocument(self.baseURL .. "search/" .. searchID .. "/?" .. qs({
        page = data[PAGE],
        q = data[QUERY],
        t = "post",
        ["c[child_nodes]"] = 1,
        ["c[nodes][0]"] = forum,
        ["c[threadmark_categories][0]"] = 1,
        ["c[threadmark_only]"] = 1,
        ["c[title_only]"] = 1,
        o = order,
        g = 1
    }))

    -- The only way I found to get it is through the URL directly.
    searchID = page:selectFirst('meta[property="og:url"]'):attr("content")
    searchID = searchID:match("search/(%d+)/")

    totalPages = page:selectFirst(".pageNav-main .pageNav-page:last-of-type a")
    totalPages = tonumber(totalPages and totalPages:text() or 1)

    return map(page:select(".block-body .contentRow"), function(v)
        local a = v:selectFirst(".contentRow-title a")
        return Novel {
            title = extractTitle(a),
            link = handleNovelURL(a:attr("href")),
            imageURL = extractImage(self.baseURL, v:selectFirst(".contentRow-figure img"))
        }
    end)
end

return function(baseURL, _self)
    _self = setmetatable(_self or {}, { __index = function(_, k)
        local d = defaults[k]
        return (type(d) == "function" and wrap(_self, d) or d)
    end })

    _self["baseURL"] = baseURL
    local novelUrlBlacklist = _self["novelUrlBlacklist"] or "^$"
    _self["listings"] = map(_self.forums, function(v)
        return Listing(v.title, true, function(data)
            --- @type int
            local page = data[PAGE]
            local url = baseURL .. "forums/." .. v.forum .. "/page-" .. page .. "/"
            local doc = GETDocument(url)

            local pageCount = tonumber(doc:selectFirst(".pageNav-main .pageNav-page:last-of-type a"):text())
            if page > pageCount then return {} end

            return mapNotNil(doc:select(".js-threadList .structItem--thread"), function(v)
                local href = v:selectFirst(".structItem-title a"):attr("href")
                href = handleNovelURL(href)
                if href:match(novelUrlBlacklist) then return nil end
                return Novel {
                    title = extractTitle(v:selectFirst(".structItem-title")),
                    link = href,
                    imageURL = extractImage(baseURL, v:selectFirst(".structItem-cell--icon img"))
                }
            end)
        end)
    end)
    _self["searchFilters"] = {
        DropdownFilter(CATEGORY_FILTER_KEY, "Category", map(_self.forums, function(v)
            return v.title
        end)),
        DropdownFilter(ORDER_BY_FILTER_KEY, "Order by", map(_self.orderByModes, function(v)
            return v[1]
        end)),
    }

    return _self
end
