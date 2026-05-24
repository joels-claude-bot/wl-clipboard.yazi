--- @since 25.5.31
-- wlclipboard: copy files to Wayland clipboard
-- Single image  -> wl-copy with exact mime type (preserves gif animation, works in browsers/Discord)
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
		if #urls == 0 then
			return notify("No file selected", "warn")
		end

		if copy_uri_list(urls) then
			local msg = #urls == 1 and urls[1]:match("[^/]+$") or (#urls .. " file(s)")
			return notify("Copied: " .. msg)
		end
		notify("Failed to copy file(s)", "error")
	end,
}
