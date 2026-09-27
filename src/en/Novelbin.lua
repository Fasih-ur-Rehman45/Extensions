-- {"id":10121,"ver":"2.0.6","libVer":"1.0.0","author":"Confident-hate"}

local json = Require("dkjson")

local baseURL = "https://novelping.com"
local novelarrowURL = "https://novelarrow.com"

---@param v Element
local text = function(v)
    return v:text()
end

---@param url string
---@param type int
local function shrinkURL(url)
    return tostring(url):gsub("^https?://[^/]+", ""):gsub("^/", "")
end

---@param url string
---@param type int
local function expandURL(url)
    return baseURL .. "/" .. url
end

local function normalizeNovelURL(novelURL)
    novelURL = tostring(novelURL):gsub("^/+", "")
    novelURL = novelURL:gsub("^b/", "novel/")
    novelURL = novelURL:gsub("^book/", "novel/")
    if not novelURL:match("^novel/") then
        novelURL = "novel/" .. novelURL
    end
    return novelURL
end

local function getNovelSlug(novelURL)
    return normalizeNovelURL(novelURL):gsub("^novel/", "")
end

local function isFreeChapter(chapter)
    return not chapter.premium_content and not chapter.platinum_content and tonumber(chapter.coin_price or 0) == 0
end

local function safeJsonGet(url)
    local ok, res = pcall(json.GET, url)
    if not ok or not res then
        return nil
    end
    if type(res) == "string" then
        local decoded = json.decode(res)
        if decoded then
            return decoded
        end
        return nil
    end
    return res
end

local GENRE_FILTER = 2
local STATUS_FILTER = 3
local SORT_FILTER = 4
local GENRE_PARAMS = {
    "",
    "/novelping-genres/action",
    "/novelping-genres/adult",
    "/novelping-genres/adventure",
    "/novelping-genres/anime",
    "/novelping-genres/arts",
    "/novelping-genres/comedy",
    "/novelping-genres/drama",
    "/novelping-genres/eastern",
    "/novelping-genres/ecchi",
    "/novelping-genres/fan-fiction",
    "/novelping-genres/fantasy",
    "/novelping-genres/game",
    "/novelping-genres/gender-bender",
    "/novelping-genres/harem",
    "/novelping-genres/historical",
    "/novelping-genres/horror",
    "/novelping-genres/isekai",
    "/novelping-genres/josei",
    "/novelping-genres/lgbt+",
    "/novelping-genres/magic",
    "/novelping-genres/magical-realism",
    "/novelping-genres/manhua",
    "/novelping-genres/martial-arts",
    "/novelping-genres/mature",
    "/novelping-genres/mecha",
    "/novelping-genres/military",
    "/novelping-genres/modern-life",
    "/novelping-genres/movies",
    "/novelping-genres/mystery",
    "/novelping-genres/psychological",
    "/novelping-genres/realistic-fiction",
    "/novelping-genres/reincarnation",
    "/novelping-genres/romance",
    "/novelping-genres/school-life",
    "/novelping-genres/sci-fi",
    "/novelping-genres/seinen",
    "/novelping-genres/shoujo",
    "/novelping-genres/shoujo-ai",
    "/novelping-genres/shounen",
    "/novelping-genres/shounen-ai",
    "/novelping-genres/slice-of-life",
    "/novelping-genres/smut",
    "/novelping-genres/sports",
    "/novelping-genres/supernatural",
    "/novelping-genres/system",
    "/novelping-genres/tragedy",
    "/novelping-genres/urban-life",
    "/novelping-genres/video-games",
    "/novelping-genres/war",
    "/novelping-genres/wuxia",
    "/novelping-genres/xianxia",
    "/novelping-genres/xuanhuan",
    "/novelping-genres/yaoi",
    "/novelping-genres/yuri"
}
local GENRE_VALUES = {
    "None",
    "Action",
    "Adult",
    "Adventure",
    "Anime",
    "Arts",
    "Comedy",
    "Drama",
    "Eastern",
    "Ecchi",
    "Fan-fiction",
    "Fantasy",
    "Game",
    "Gender bender",
    "Harem",
    "Historical",
    "Horror",
    "Isekai",
    "Josei",
    "Lgbt+",
    "Magic",
    "Magical realism",
    "Manhua",
    "Martial arts",
    "Mature",
    "Mecha",
    "Military",
    "Modern life",
    "Movies",
    "Mystery",
    "Psychological",
    "Realistic fiction",
    "Reincarnation",
    "Romance",
    "School life",
    "Sci-fi",
    "Seinen",
    "Shoujo",
    "Shoujo ai",
    "Shounen",
    "Shounen ai",
    "Slice of life",
    "Smut",
    "Sports",
    "Supernatural",
    "System",
    "Tragedy",
    "Urban life",
    "Video games",
    "War",
    "Wuxia",
    "Xianxia",
    "Xuanhuan",
    "Yaoi",
    "Yuri"
}

local STATUS_VALUES = {
    "All",
    "Ongoing",
    "Completed"
}

local SORT_VALUES = {
    "Popular this week",
    "Last updated",
    "Recently added",
    "Top (most viewed)",
    "Top rated",
    "Most chapters"
}

local searchFilters = {
    DropdownFilter(GENRE_FILTER, "Genre", GENRE_VALUES),
    DropdownFilter(STATUS_FILTER, "Status", STATUS_VALUES),
    DropdownFilter(SORT_FILTER, "Sort by", SORT_VALUES),
}

--- @param chapterURL string @url of the chapter
--- @return string @of chapter
local function getPassage(chapterURL)
    local cleanedURL = tostring(chapterURL):gsub("^/+", ""):gsub("^chapter/", "")
    local novelSlug, chapterSlug = cleanedURL:match("([^/]+)/([^/]+)")
    
    if not novelSlug or not chapterSlug then return "" end
    
    local apiEndpoint = novelarrowURL .. "/api-web/novels/" .. novelSlug .. "/chapters/" .. chapterSlug
    local response = safeJsonGet(apiEndpoint)
    
    local finalHtmlContent = ""
    
    if response and response.item and response.item.chapterInfo then
        local chapterTitle = response.item.chapterInfo.chapter_name or ""
        if chapterTitle ~= "" then
            finalHtmlContent = "<h1>" .. chapterTitle .. "</h1>"
        end
        
        local rawContent = response.item.chapterInfo.chapter_content or ""
        local doc = Document(rawContent)
        local pTags = doc:select("p")
        
        for i = 0, pTags:size() - 1 do
            local p = pTags:get(i)
            local t = p:text()
            if t and t ~= "" then
                t = t:gsub("<", "&lt;"):gsub(">", "&gt;")
                finalHtmlContent = finalHtmlContent .. "<br><br>" .. t
            end
        end
    end
    
    return finalHtmlContent
end

local function parseListing(listingURL)
    local document = GETDocument(listingURL)
    local novels = {}
    local seen = {}

    -- New site structure: title in h3.novel-title > a, image in img.cover
    local anchors = document:select("h3.novel-title a")
    local covers = document:select("img.cover")

    for i = 0, anchors:size() - 1 do
        local anchor = anchors:get(i)
        local href = tostring(anchor:attr("href") or "")
        if href ~= "" and not seen[href] then
            seen[href] = true
            local title = anchor:attr("title") and tostring(anchor:attr("title")) or anchor:text()
            local imageURL = ""
            if covers and i < covers:size() then
                imageURL = tostring(covers:get(i):attr("src") or "")
            end
            if title ~= "" then
                novels[#novels + 1] = Novel {
                    title = title,
                    imageURL = imageURL,
                    link = shrinkURL(href)
                }
            end
        end
    end
    return novels
end

--- Resolves the sort query parameter based on whether a genre is active
local function getSortParam(sortIndex, isGenre)
    if isGenre then
        if sortIndex == 0 then return "" end -- Popular this week (default on genre)
        if sortIndex == 1 then return "LASTEST" end -- Last updated
        if sortIndex == 2 then return "NEW" end
        if sortIndex == 3 then return "ALL_TIME" end
        if sortIndex == 4 then return "RATING" end
        if sortIndex == 5 then return "CHAPTERS" end
    else
        if sortIndex == 0 then return "POPULAR" end -- Popular this week (default)
        if sortIndex == 1 then return "" end -- Last updated (default on /sort/updates)
        if sortIndex == 2 then return "NEW" end
        if sortIndex == 3 then return "ALL_TIME" end
        if sortIndex == 4 then return "RATING" end
        if sortIndex == 5 then return "CHAPTERS" end
    end
    return ""
end

--- Builds the URL combining Genre, Status, Sort, and Page
local function buildListingURL(data, defaultBase)
    local page = data[PAGE] or 1
    local genre = data[GENRE_FILTER]
    local status = data[STATUS_FILTER]
    local sort = data[SORT_FILTER]

    local basePath = defaultBase or "/sort/updates"
    local isGenre = false

    -- If a specific genre is selected (index > 0)
    if genre ~= nil and genre > 0 and GENRE_PARAMS[genre + 1] and GENRE_PARAMS[genre + 1] ~= "" then
        basePath = GENRE_PARAMS[genre + 1]
        isGenre = true
    end

    -- Append status subpath
    local statusPath = ""
    if status == 1 then
        statusPath = "/ongoing"
    elseif status == 2 then
        statusPath = "/completed"
    end

    -- Resolve sort query
    local sortParam = getSortParam(sort or 0, isGenre)

    -- Assemble query string (?sort=...&page=...)
    local queryParts = {}
    if sortParam ~= "" then
        table.insert(queryParts, "sort=" .. sortParam)
    end
    if page then
        table.insert(queryParts, "page=" .. page)
    end

    local queryString = ""
    if #queryParts > 0 then
        queryString = "?" .. table.concat(queryParts, "&")
    end

    return baseURL .. basePath .. statusPath .. queryString
end

--- @param data table
local function search(data)
    local queryContent = data[QUERY]
    local page = data[PAGE]
    if queryContent and queryContent ~= "" then
        local searchURL = baseURL .. "/search?keyword=" .. queryContent .. "&page=" .. page
        return parseListing(searchURL)
    end
    return parseListing(buildListingURL(data, "/sort/updates"))
end

--- @param novelURL string @URL of novel
--- @return NovelInfo
local function parseNovel(novelURL)
    local novelPath = normalizeNovelURL(novelURL)
    local novelSlug = getNovelSlug(novelURL)
    
    -- 1. Get the Cover Image from HTML
    local url = novelarrowURL .. "/" .. novelPath
    local document = GETDocument(url)
    local imageElement = document:selectFirst("main img")
    local finalImageURL = imageElement and imageElement:attr("src") or ""
    local finalGenres = {}

    -- 2. Get Metadata from the JSON API
    local metadataEndpoint = novelarrowURL .. "/api-web/novels/" .. novelSlug
    local metaResponse = safeJsonGet(metadataEndpoint)

    local finalTitle = ""
    local finalAuthor = "Author: Unknown"
    local finalStatus = NovelStatus.UNKNOWN
    local finalDesc = ""

    if metaResponse and metaResponse.item and metaResponse.item.novelInfo then
        local info = metaResponse.item.novelInfo

        -- Title & Author
        finalTitle = info.novel_name or ""
        local rawAuthor = info.novel_author or "Unknown"
        finalAuthor = "Author: " .. rawAuthor
        -- Status (0 = Ongoing, others usually complete)
        if info.novel_status == 0 then
            finalStatus = NovelStatus.PUBLISHING
        else
            finalStatus = NovelStatus.COMPLETED
        end
        
        -- Description (Parse HTML <p> tags into plain text from the API payload)
        if info.novel_desc then
            local doc = Document(info.novel_desc)
            local pTags = doc:select("p")
            if pTags:size() > 0 then
                for i = 0, pTags:size() - 1 do
                    local pText = pTags:get(i):text()
                    if pText and pText ~= "" then
                        finalDesc = finalDesc .. pText .. "\n\n"
                    end
                end
            else
                -- Plain text with no HTML tags — use as-is
                finalDesc = info.novel_desc
            end
        end

        -- Genres from API
        local rawGenres = info.novel_genres or {}
        for _, g in ipairs(rawGenres) do
            local titled = g:sub(1,1):upper() .. g:sub(2):lower()
            finalGenres[#finalGenres + 1] = titled
        end
    end

    -- HTML Fallback (Just in case the API fails for the title)
    if finalTitle == "" then
        local titleElement = document:selectFirst("h1")
        finalTitle = titleElement and titleElement:text() or ""
    end

    -- 3. Get Chapters List from JSON API
    local chaptersEndpoint = novelarrowURL .. "/api-web/novels/" .. novelSlug .. "/chapters"
    local chaptersResponse = safeJsonGet(chaptersEndpoint)
    local chapterItems = chaptersResponse and (chaptersResponse.items or chaptersResponse) or {}
    
    local chapters = {}
    local chapterOrder = 0

    for _, chapter in ipairs(chapterItems) do
        if isFreeChapter(chapter) then
            chapterOrder = chapterOrder + 1
            local chapterId = tostring(chapter.chapter_id or "")
            if chapterId ~= "" then
                chapters[#chapters + 1] = NovelChapter {
                    order = chapterOrder,
                    title = tostring(chapter.chapter_name or chapterId),
                    release = tostring(chapter.release_date or chapter.published_at or chapter.created_at or ""),
                    link = shrinkURL("/chapter/" .. novelSlug .. "/" .. chapterId)
                }
            end
        end
    end

    -- Chapter Fallback (If API is empty)
    if #chapters == 0 then
        local chapterLink = document:selectFirst("a[href^='/chapter/'][href*='chapter-1']") or document:selectFirst("a[href^='/chapter/']")
        local chapterHref = chapterLink and chapterLink:attr("href") or ""
        chapters = {
            NovelChapter {
                order = 1,
                title = chapterLink and chapterLink:text() or "Chapter 1",
                release = "",
                link = shrinkURL(chapterHref)
            }
        }
    end

    return NovelInfo {
        title = finalTitle,
        description = finalDesc,
        imageURL = finalImageURL,
        status = finalStatus,
        authors = { finalAuthor },
        genres = finalGenres,
        chapters = AsList(chapters)
    }
end

return {
    id = 10121,
    name = "Novelbin",
    baseURL = baseURL,
    imageURL = "https://i.imgur.com/KQOwfMt.png",
    hasSearch = true,
    listings = {
        Listing("All Novels", true, function(data)
            return parseListing(buildListingURL(data, "/sort/updates"))
        end)
    },
    parseNovel = parseNovel,
    getPassage = getPassage,
    chapterType = ChapterType.HTML,
    search = search,
    shrinkURL = shrinkURL,
    expandURL = expandURL,
    searchFilters = searchFilters
}