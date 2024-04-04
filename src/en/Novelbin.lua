-- {"id":10121,"ver":"1.0.0","libVer":"1.0.0","author":"Demarcussee"}

local baseURL = "https://binnovel.com"

---@param v Element
local text = function(v)
    return v:text()
end


---@param url string
---@param type int
local function shrinkURL(url)
    return url:gsub("https://binnovel.com/", "")
end

---@param url string
---@param type int
local function expandURL(url)
    return baseURL .. "/" .. url
end

local GENRE_FILTER = 2
local GENRE_PARAMS = { 
    "",
    "/genre/action",
    "/genre/adult",
    "/genre/adventure",
    "/genre/anime",
    "/genre/arts",
    "/genre/comedy",
    "/genre/drama",
    "/genre/eastern",
    "/genre/ecchi",
    "/genre/fan-fiction",
    "/genre/fantasy",
    "/genre/game",
    "/genre/gender-bender",
    "/genre/harem",
    "/genre/historical",
    "/genre/horror",
    "/genre/isekai",
    "/genre/josei",
    "/genre/lgbt+",
    "/genre/magic",
    "/genre/magical-realism",
    "/genre/manhua",
    "/genre/martial-arts",
    "/genre/mature",
    "/genre/mecha",
    "/genre/military",
    "/genre/modern-life",
    "/genre/movies",
    "/genre/mystery",
    "/genre/psychological",
    "/genre/realistic-fiction",
    "/genre/reincarnation",
    "/genre/romance",
    "/genre/school-life",
    "/genre/sci-fi",
    "/genre/seinen",
    "/genre/shoujo",
    "/genre/shoujo-ai",
    "/genre/shounen",
    "/genre/shounen-ai",
    "/genre/slice-of-life",
    "/genre/smut",
    "/genre/sports",
    "/genre/supernatural",
    "/genre/system",
    "/genre/tragedy",
    "/genre/urban-life",
    "/genre/video-games",
    "/genre/war",
    "/genre/wuxia",
    "/genre/xianxia",
    "/genre/xuanhuan",
    "/genre/yaoi",
    "/genre/yuri"
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

local searchFilters = {
    DropdownFilter(GENRE_FILTER, "Genre", GENRE_VALUES),
}

--- @param chapterURL string @url of the chapter
--- @return string @of chapter
local function getPassage(chapterURL)
    local htmlElement = GETDocument(chapterURL)
    local title = htmlElement:selectFirst(".chr-title"):attr("title")
    htmlElement = htmlElement:selectFirst("#chr-content")
    local toRemove = {}
    htmlElement:traverse(NodeVisitor(function(v)
        if v:tagName() == "p" and v:text() == "" then
            toRemove[#toRemove+1] = v
        end
    end, nil, true))
    for _,v in pairs(toRemove) do
        v:remove()
    end
    local ht = "<h1>" .. title .. "</h1>"
    local pTagList = ""
    pTagList = map(htmlElement:select("p"), text)
    for k,v in pairs(pTagList) do ht = ht .. "<br><br>" .. v end
    return pageOfElem(Document(ht), true)
end

--- @param data table
local function search(data)
    local queryContent = data[QUERY]
    local page = data[PAGE]
    local doc = GETDocument(baseURL .. "/search/?keyword=" .. queryContent .. "&page=" .. page)
    return map(doc:selectFirst(".list.list-novel"):select(".row"), function(v)
        return Novel {
            title = v:selectFirst(".novel-title"):text(),
            imageURL = v:selectFirst(".cover"):attr("data-src"),
            link = shrinkURL(v:selectFirst(".novel-title a"):attr("href"))
        }
    end)
end

--- @param novelURL string @URL of novel
--- @return NovelInfo
local function parseNovel(novelURL)
    local url = baseURL .. "/" .. novelURL
    local document = GETDocument(url)
    local chID = string.match(url, ".*novel.book/(.*)")
    local chapterURL = baseURL .. "/ajax/chapter-archive?novelId=" .. chID
    local chapterDoc = GETDocument(chapterURL)
    return NovelInfo {
        title = document:selectFirst(".title"):text(),
        description = document:selectFirst(".desc-text"):text(),
        imageURL = document:selectFirst(".books .book img"):attr("data-src"),
        status = ({
            Ongoing = NovelStatus.PUBLISHING,
            Completed = NovelStatus.COMPLETED,
        })[document:selectFirst(".info .text-primary"):text()],
        chapters = AsList(
                map(chapterDoc:select(".list-chapter li a"), function(v)
                    return NovelChapter {
                        order = v,
                        title = v:attr("title"),
                        link = v:attr("href")
                    }
                end)
        )
    }
end

local function parseListing(listingURL)
    local document = GETDocument(listingURL)
    return map(document:selectFirst(".list.list-novel"):select(".row"), function(v)
        return Novel {
            title = v:selectFirst(".novel-title"):text(),
            imageURL = v:selectFirst(".cover"):attr("data-src"),
            link = shrinkURL(v:selectFirst(".novel-title a"):attr("href"))
        }
    end)
end


-- local function getListing(data)
local function getListing(name, inc, sortString)
    return Listing(name, inc, function(data)
        local genre = data[GENRE_FILTER]
        local page = data[PAGE]
        local genreValue = ""
        if genre ~= nil then
            genreValue = GENRE_PARAMS[genre+1]
        end
        local url = baseURL .. genreValue .. "?page=" .. page
        if genreValue == "" then
            url = baseURL .. sortString .. "?page=" .. page
        end
        return parseListing(url)
    end)
end

return {
    id = 10121,
    name = "Novelbin",
    baseURL = baseURL,
    imageURL = "https://i.imgur.com/KQOwfMt.png",
    hasSearch = true,
    listings = {
        getListing("Hot Novel", true, "/sort/top-hot"),
        getListing("Completed", true, "/sort/completed"),
        getListing("Most Popular", true, "/sort/top-view"),
        getListing("Latest Release", true, "/sort/daily-update")
    },
    parseNovel = parseNovel,
    getPassage = getPassage,
    chapterType = ChapterType.HTML,
    search = search,
    shrinkURL = shrinkURL,
    expandURL = expandURL,
    searchFilters = searchFilters
}
