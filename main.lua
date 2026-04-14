--- @since 25.5.31
-- wlclipboard.yazi: copy files to Wayland clipboard
-- Single image  -> raw bytes via copyq (serves all image MIME types to XWayland apps)
-- Anything else -> file:// URI list via wl-copy

local selected_or_hovered = ya.sync(function(_)
	local tab, paths = cx.active, {}
	for _, u in pairs(tab.selected) do
		paths[#paths + 1] = tostring(u)
	end
	if #paths == 0 and tab.current.hovered then
		paths[1] = tostring(tab.current.hovered.url)
	end
	return paths
end)

local function encode_uri(uri)
	return uri:gsub("([^%w%-%._~:/])", function(c)
		return string.format("%%%02X", string.byte(c))
	end)
end

local function notify(msg, level)
	ya.notify({ title = "System Clipboard", content = msg, level = level or "info", timeout = 5 })
end

local function get_mime(path)
	local out = Command("file"):arg({ "--brief", "--mime-type", path }):stdout(Command.PIPED):output()
	return out and out.stdout:gsub("%s+$", "") or nil
end

-- Animated formats need first-frame extraction to PNG before copyq,
-- otherwise copyq only offers image/gif which Slack/Discord can't paste.
local NEEDS_CONVERT = { ["image/gif"] = true, ["image/webp"] = true }

-- Copy image to clipboard via copyq (advertises all image MIME types).
-- For gif/webp: extracts first frame as PNG via magick.
-- All done in one sh command to avoid os.tmpname/io.open (broken in yazi async).
local function copy_image(path, mime)
	local cmd
	if NEEDS_CONVERT[mime] then
		cmd = "tmp=$(mktemp --suffix=.png) && magick '" .. path .. "[0]' png:\"$tmp\" && copyq copy image/png - < \"$tmp\"; rm -f \"$tmp\""
	else
		cmd = "copyq copy " .. mime .. " - < '" .. path .. "'"
	end
	local status = Command("sh"):arg({ "-c", cmd }):spawn():wait()
	return status and status.success
end

local function copy_uri_list(paths)
	local formatted = ""
	for _, path in ipairs(paths) do
		formatted = formatted .. "file://" .. encode_uri(path) .. "\r\n"
	end
	local status = Command("wl-copy"):arg("--type"):arg("text/uri-list"):arg(formatted):spawn():wait()
	return status and status.success
end

return {
	entry = function()
		local urls = selected_or_hovered()
		if #urls == 0 then return notify("No file selected", "warn") end

		if #urls == 1 then
			local mime = get_mime(urls[1])
			if mime and mime:find("^image/") then
				if copy_image(urls[1], mime) then
					return notify("Copied image: " .. urls[1]:match("[^/]+$"))
				end
				return notify("Failed to copy image", "error")
			end
		end

		if copy_uri_list(urls) then
			local msg = #urls == 1 and urls[1]:match("[^/]+$") or (#urls .. " file(s)")
			return notify("Copied: " .. msg)
		end
		notify("Failed to copy file(s)", "error")
	end,
}
