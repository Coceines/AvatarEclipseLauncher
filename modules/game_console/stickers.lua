Stickers = {}
Stickers.activeStickers = {}

Stickers.stickersConfig = {
	[":1:"] = {
		name = "test",
		imagePath = "/images/stickers/test1.png",
		displayTime = 5000,
		offset = { x = 6, y = 6 },
		bubbleOffset = { x = 35, y = -100 },
		size = { width = 64, height = 64 },
	},
	[":2:"] = {
		imagePath = "/images/stickers/test2.png",
		displayTime = 5000
	},
	[":3:"] = {
		imagePath = "/images/stickers/test3.png",
		displayTime = 5000
	},
	[":4:"] = {
		imagePath = "/images/stickers/test4.png",
		displayTime = 5000
	},
	[":5:"] = {
		imagePath = "/images/stickers/test5.png",
		displayTime = 5000
	},
	[":6:"] = {
		imagePath = "/images/stickers/test6.png",
		displayTime = 5000
	},
	[":7:"] = {
		imagePath = "/images/stickers/test7.png",
		displayTime = 5000
	},
	[":8:"] = {
		imagePath = "/images/stickers/test8.png",
		displayTime = 5000
	},
	[":9:"] = {
		imagePath = "/images/stickers/test9.png",
		displayTime = 5000
	}
}

function Stickers.createStickersPanel()
	Stickers.stickersPanel = g_ui.createWidget("StickersPanel", modules.game_interface.getRootPanel())
	Stickers.stickersPanel:addAnchor(AnchorBottom, "gameBottomPanel", AnchorBottom)
	Stickers.stickersPanel:addAnchor(AnchorLeft, "gameBottomPanel", AnchorLeft)
	Stickers.stickersPanel:setOn(false)
	Stickers.stickersPanel:setVisible(false)

	for key, config in pairs(Stickers.stickersConfig) do
		local stickerWidget = g_ui.createWidget("StickersEntry", Stickers.stickersPanel.stickersUIScrollArea)
		stickerWidget:setImageSource(config.imagePath)
		if config.name then stickerWidget:setTooltip(config.name) end
		stickerWidget.onClick = function()
			Stickers.sendSticker(key)
		end
	end

	consolePanel:recursiveGetChildById("stickerButton").onClick = function()
		Stickers.stickersPanel:setOn(not Stickers.stickersPanel:isOn())
		Stickers.stickersPanel:setVisible(Stickers.stickersPanel:isOn())
	end
end

function Stickers.sendSticker(text)
	g_game.talk(text)
end

function Stickers.createSticker(tile, config)
	local offsetX = config.offset and config.offset.x or 6
	local offsetY = config.offset and config.offset.y or 6
	local bubbleOffsetX = config.bubbleOffset and config.bubbleOffset.x or 35
	local bubbleOffsetY = config.bubbleOffset and config.bubbleOffset.y or -100
	local displayTime = config.displayTime or 5000
	local width = config.size and config.size.width or 64
	local height = config.size and config.size.height or 64

	local bubbleWidget = g_ui.createWidget("StickerBubble", modules.game_interface.getMapPanel())
	bubbleWidget:setMarginLeft(bubbleOffsetX)
	bubbleWidget:setMarginTop(bubbleOffsetY)
	bubbleWidget:setSize({height = height * 1.7, width = width * 1.7})
	bubbleWidget:setId("Sticker")

	bubbleWidget.Sticker:setImageSource(config.imagePath)
	bubbleWidget.Sticker:setMarginRight(offsetX)
	bubbleWidget.Sticker:setMarginTop(offsetY)
	bubbleWidget.Sticker:setSize({height = height, width = width})

	tile:setWidget(bubbleWidget)
	bubbleWidget:setVisible(true)

	table.insert(Stickers.activeStickers, {widget = bubbleWidget, tile = tile})

	scheduleEvent(
		function()
			if bubbleWidget and tile then
				tile:removeWidget(bubbleWidget)
				for i, stickerData in ipairs(Stickers.activeStickers) do
					if stickerData.widget == bubbleWidget then
						table.remove(Stickers.activeStickers, i)
						break
					end
				end
			end
		end,
		displayTime
	)
end
