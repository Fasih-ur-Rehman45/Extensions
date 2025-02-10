-- {"id":10255,"ver":"1.0.0","libVer":"1.0.0","author":""}

local json = Require("dkjson")

--- Identification number of the extension.
local id = 10255  -- Update with your extension ID

--- Name of extension to display to the user.
local name = "WTR-LAB"

--- Base URL of the extension.
local baseURL = "https://wtr-lab.com/"

--- URL of the logo.
local imageURL = "https://i.imgur.com/ObQtFVW.png"  -- Update correct path

--- Cloudflare protection status.
local hasCloudFlare = false

--- Search configuration.
local hasSearch = true
local isSearchIncrementing = true

--- Filters configuration.
local ORDER_FILTER_ID = 2
local ORDER_PERM = {
    "view",
    "name",
    "date",
    "reader",
    "chapter"
}
local ORDER_VALUE = {
    "View",
    "Name",
    "Addition Date",
    "Reader",
    "Chapter"
}
local SORT_FILTER_ID = 4
local SORT_PERM = {
    "desc",
    "asc"
}
local SORT_VALUE = {
    "Descending",
    "Ascending"
}
local STATUS_FILTER_ID = 3
local FILTER_VALUE = {
    "All",
    "Ongoing",
    "Completed"
}
local FILTER_PERM = {
    "all",
    "ongoing",
    "completed"
}

--- Filters configuration.
local searchFilters = {
    DropdownFilter(ORDER_FILTER_ID, "Order by", ORDER_VALUE),
    DropdownFilter(SORT_FILTER_ID, "Sort by", SORT_VALUE),
    DropdownFilter(STATUS_FILTER_ID, "Status", FILTER_VALUE)
}

--- URL handling functions.
local function shrinkURL(url, type)
    return url:gsub(baseURL, ""):gsub("^en", "")
end

local function expandURL(url, type)
    url = url:gsub("^/", "")
    return baseURL .. url
end

--- Chapter content extraction.
local function getPassage(chapterURL)
    local url = expandURL(chapterURL, KEY_CHAPTER_URL)
    local doc = GETDocument(url)
    local script = doc:selectFirst("script#__NEXT_DATA__"):html()
    local data = json.decode(script)
    local content = data.props.pageProps.serie.chapter_data.data.body
    local html = table.concat(map(content, function(v) return "<p>" .. v .. "</p>" end))
    return html
end

--- Novel parsing function.
local function parseNovel(novelURL)
    local url = expandURL(novelURL, KEY_NOVEL_URL)
    local doc = GETDocument(url)
    local script = doc:selectFirst("#__NEXT_DATA__"):html()
    local data = json.decode(script)
    local serie = data.props.pageProps.serie

    local novelInfo = NovelInfo {
        title = doc:selectFirst("h1.text-uppercase"):text(),
        imageURL = doc:selectFirst(".img-wrap img"):attr("src"),
        description = doc:selectFirst(".lead"):text(),
        authors = {doc:select("td:matches(^Author$) + td a"):text()},
        status = ({
            Ongoing = NovelStatus.PUBLISHING,
            Completed = NovelStatus.COMPLETED,
        })[doc:selectFirst("td:matches(^Status$) + td"):text()],
    }

    local chapters = {}
    for i, ch in ipairs(serie.chapters) do
        chapters[#chapters+1] = NovelChapter {
            title = ch.title,
            link = "serie-" .. serie.serie_data.raw_id .. "/" .. serie.serie_data.slug .. "/chapter-" .. ch.order .. "?service=google",
            order = i
        }
    end
    novelInfo:setChapters(chapters)
    return novelInfo
end
--- Search function.
local function search(data)
    local query = data[QUERY]
    local page = data[PAGE]
    -- Use json.POST to send a POST request with JSON data
    local doc = GETDocument(baseURL .. "novel-finder?text=" .. query .. "&page=" .. page)
    local script = doc:selectFirst("#__NEXT_DATA__"):html()
    local data = json.decode(script)
    local serie = data.props.pageProps.series
    -- Map the results to Novel objects
    return map(serie, function(v)
        return Novel {
            title = v.data.title,
            link = "serie-" .. v.raw_id .. "/" .. v.slug,
            imageURL = v.data.image
        }
    end)
end

--- Listings configuration.
local listings = {
        Listing("Popular Novels", true, function(data)
            -- Retrieve filters from the data object
            local page = data[PAGE]
            local order = data[ORDER_FILTER_ID]
            local orderValue = ""
            if order ~= nil then
                orderValue = ORDER_PERM[order + 1]
            end
            local sort= data[SORT_FILTER_ID]
            local sortValue = ""
            if sort ~= nil then
                sortValue = SORT_PERM[sort + 1]
            end
            local status = data[STATUS_FILTER_ID]
            local statusValue = ""
            if status ~= nil then
                statusValue = FILTER_PERM[status + 1]
            end
            local url = baseURL .. "en/novel-list?orderBy=" .. orderValue .. "&order=" .. sortValue .. "&status=" .. statusValue .. "&page=" .. page
            local doc = GETDocument(url)
        
        return map(doc:select(".serie-item"), function(el)
            return Novel {
                title = el:select(".title-wrap a"):text():gsub(el:select(".rawtitle"):text(), ""),
                link = shrinkURL(el:select("a"):attr("href"), KEY_NOVEL_URL),
                imageURL = el:select("img"):attr("src")
            }
        end)
    end),
        Listing("Latest Novels", true, function(data)
        local page = data[PAGE]
        local url = baseURL .. "en/trending?page=" .. page
        local doc = GETDocument(url)
        return map(doc:select(".serie-item"), function(el)
            return Novel {
                title = el:select(".title-wrap a"):text():gsub(el:select(".rawtitle"):text(), ""),
                link = shrinkURL(el:select("a"):attr("href"), KEY_NOVEL_URL),
                imageURL = el:select("img"):attr("src")
            }
        end)
    end)
}
return {
    id = id,
    name = name,
    baseURL = baseURL,
    imageURL = imageURL,
    listings = listings,
    getPassage = getPassage,
    parseNovel = parseNovel,
    shrinkURL = shrinkURL,
    expandURL = expandURL,
    hasSearch = hasSearch,
    search = search,
    searchFilters = searchFilters,
    chapterType = ChapterType.HTML
}