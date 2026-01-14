-- {"id":101121,"ver":"1.0.3","libVer":"1.0.0","author":""}

local json = Require("dkjson")
local bigint = Require("bigint")

local id = 101121  -- Update with your extension ID
local name = "MVLEMPYR"
local chapterType = ChapterType.HTML
local imageURL = "https://assets.mvlempyr.app/images/asset/LogoMage.webp"

---@param v Element
local text = function(v)
    return v:text()
end

--base Url for the site
local baseURL = "https://www.mvlempyr.com/"

local function shrinkURL(url, _)
    return url
end

local function expandURL(url, _)
    return url
end

local function getPassage(chapterURL)
    local url = expandURL(chapterURL):gsub("(%w+://[^/]+)%.net", "%1.space")
    local doc = GETDocument(url)
    local title = doc:selectFirst("h2.ChapterName span"):text()
    local htmlElement = doc:selectFirst("#chapter")
    local ht = "<h1>" .. title .. "</h1>"
    local pTagList = map(htmlElement:select("p"), text)
    local htmlContent = ""
    for _, v in pairs(pTagList) do
        htmlContent = htmlContent .. "<br><br>" .. v
    end
    ht = ht .. htmlContent
    return pageOfElem(Document(ht), true)
end

local function calculateTagId(novel_code)
    local t = bigint.new("1999999997")
    local c = bigint.modulus(bigint.new("7"), t);
    local d = tonumber(novel_code);
    local u = bigint.new(1);
    while d > 0 do
        if (d % 2) == 1 then
            u = bigint.modulus((u * c), t)
        end
        c = bigint.modulus((c * c), t);
        d = math.floor(d/2);
    end
    return bigint.unserialize(u, "string")
end

local function parseNovel(novelURL)
    local doc = GETDocument(novelURL)
    local desc = ""
    map(doc:select(".synopsis p"), function(p) desc = desc .. '\n' .. p:text() end)
    local img = doc:selectFirst("img.novel-image2")
    img = img and img:attr("src") or imageURL
    local novel_code = doc:selectFirst("#novel-code"):text()
    local headers = HeadersBuilder():add("Origin", "https://www.mvlempyr.com"):build()
    local chapters, page = {}, 1
    repeat
        local chapter_data = json.GET("https://chap.heliosarchive.online/wp-json/wp/v2/posts?tags=" .. calculateTagId(novel_code) .. "&per_page=500&page=" .. page, headers)
        for i, v in next, chapter_data do
            table.insert(chapters, NovelChapter {
                order = v.acf.chapter_number,
                title = v.acf.ch_name,
                link = shrinkURL(v.link):gsub("chap.heliosarchive.online", "www.mvlempyr.app")
            })
        end
        page = page + 1
    until #chapter_data < 500
    return NovelInfo({
        title = doc:selectFirst(".novel-title2"):text():gsub("\n", "www.mvlempyr.app"),
        imageURL = img,
        description = desc,
        chapters = chapters
    })
end

local function getListing(data)
    local data = json.GET("https://chap.heliosarchive.online/wp-json/wp/v2/mvl-novels?per_page=100&page=" .. data[PAGE])
    local novels = {}
    for _, novel in next, data do
        table.insert(novels, Novel {
            title = novel.name,
            link = "https://www.mvlempyr.app/novel/" .. novel.slug,
            imageURL = "https://assets.mvlempyr.app/images/600/" .. novel["novel-code"] .. ".webp"
        })
    end
    return novels
end

local function search(data)
    local query = data[QUERY]
    local data = json.GET("https://chap.heliosarchive.online/wp-json/wp/v2/mvl-novels?per_page=5000&page=" .. data[PAGE])
    local novels = {}
    for _, novel in next, data do
        if novel.name:match(query) then
            table.insert(novels, Novel {
                title = novel.name,
                link = "https://www.mvlempyr.app/novel/" .. novel.slug,
                imageURL = "https://assets.mvlempyr.app/images/600/" .. novel["novel-code"] .. ".webp"
            })
        end
    end
    return novels
end

-- Return all properties in a lua table.
return {
	id = id,
	name = name,
	baseURL = baseURL,
	listings = {
        Listing("Default", true, getListing)
    },
	getPassage = getPassage,
	parseNovel = parseNovel,
	shrinkURL = shrinkURL,
	expandURL = expandURL,
    hasSearch = true,
    isSearchIncrementing = true,
    hasCloudFlare = true,
    search = search,
	imageURL = imageURL,
	chapterType = chapterType,
	startIndex = startIndex,
}