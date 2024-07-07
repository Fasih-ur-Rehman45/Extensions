-- {"id":5055,"ver":"1.2.4","libVer":"1.0.0","author":"Doomsdayrs","dep":["url>=1.0.0"]}
--- @author Doomsdayrs
--- @version 1.2.0

local baseURL = "https://yomou.syosetu.com"
local passageURL = "https://ncode.syosetu.com"
local encode = Require("url").encode

local function getTotalPages(html)
    local lastPageLink = html:select("a.novelview_pager-last"):attr("href")
    if lastPageLink then
        local totalPages = tonumber(lastPageLink:match("p=(%d+)"))
        return totalPages or 1  -- Return at least 1 if parsing fails
    end
    return 1  -- Return 1 if no last page link found (assuming only one page)
end

---@param url string
local function shrinkURL(url)
	return url:gsub(passageURL, "")
end

---@param url string
local function expandURL(url)
	return passageURL .. url
end

return {
	id = 5055,
	name = "Syosetsu",
	baseURL = baseURL,
	imageURL = "https://github.com/shosetsuorg/extensions/raw/dev/icons/Syosetsu.png",
	listings = {
		Listing("Latest", true, function(data)
			if data[PAGE] == 0 then
				data[PAGE] = 1
			end
			return map(GETDocument(
					baseURL .. "/search.php?&search_type=novel&order_former=search&order=new&notnizi=1&p=" .. data[PAGE])
					:select("div.searchkekka_box"), function(v)
				local novel = Novel()
				local e = v:selectFirst("div.novel_h"):selectFirst("a.tl")
				novel:setLink(shrinkURL(e:attr("href")))
				novel:setTitle(e:text())
				return novel
			end)
		end)
	},

	-- Default functions that had to be set
	getPassage = function(chapterURL)
		local e = first(GETDocument(passageURL .. chapterURL):select("div"), function(v)
			return v:id() == "novel_contents"
		end)
		if not e then
			return "INVALID PARSING, CONTACT DEVELOPERS"
		end
		return table.concat(map(e:select("p"), function(v)
			return v:text()
		end), "\n") :gsub("<br>", "\n\n")
	end,

	parseNovel = function(novelURL, loadChapters)
		local novelPage = NovelInfo()
		local document = GETDocument(passageURL .. novelURL)

		novelPage:setAuthors({ document:selectFirst("div.novel_writername"):text():gsub("作者：", "") })
		novelPage:setTitle(document:selectFirst("p.novel_title"):text())

		-- Description
		local e = first(document:select("div"), function(v)
			return v:id() == "novel_color"
		end)
		if e then
			novelPage:setDescription(e:text():gsub("<br>\n<br>", "\n"):gsub("<br>", "\n"))
		end
		-- Chapters
		if loadChapters then
            local chapters = {}
            local totalPages = getTotalPages(document)

            -- Loop through all pages to collect chapters
            for page = 1, totalPages do
                local pageURL = novelURL .. "?p=" .. page
                local pageDocument = GETDocument(passageURL .. pageURL)
                
                -- Parse chapters from the current page
                map(pageDocument:select("dl.novel_sublist2"), function(v, i)
                    local chap = NovelChapter()
                    chap:setTitle(v:selectFirst("a"):text())
                    chap:setLink(v:selectFirst("a"):attr("href"))
                    chap:setRelease(v:selectFirst("dt.long_update"):text())
                    chap:setOrder(i)
                    table.insert(chapters, chap)
                end)
            end

            novelPage:setChapters(AsList(chapters))
        end

        return novelPage
    end,
	shrinkURL = shrinkURL,
	expandURL = expandURL,
	getTotalPages = getTotalPages,
	search = function(data)
		return map(GETDocument(baseURL .. "/search.php?&word=" .. encode(data[0]) .. "&p=" .. data[PAGE])
				:select("div.searchkekka_box"),
				function(v)
					local novel = Novel()
					local e = v:selectFirst("div.novel_h"):selectFirst("a.tl")
					novel:setLink(shrinkURL(e:attr("href")))
					novel:setTitle(e:text())
					return novel
				end)
	end,
}
