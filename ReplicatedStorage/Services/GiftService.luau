local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local MarketplaceService = require(ReplicatedStorage.Services.MarketplaceService)

assert(ReplicatedStorage:FindFirstChild("Services"), "Required services must be placed into ReplicatedStorage.Services")
assert(ReplicatedStorage.Services:FindFirstChild("DataSaveService"), "DataSaveService must be placed into ReplicatedStorage.Services")
assert(ReplicatedStorage.Services:FindFirstChild("MarketplaceService"), "MarketplaceService must be placed into ReplicatedStorage.Services")

local ConvertImageId = require(ReplicatedStorage.Modules.ConvertImageId)
local Settings = require(script.Settings)
local IsServer = RunService:IsServer()

local GiftService = {}

export type ProductInfo = {
	AssetId: number,
	AssetTypeId: number,
	Created: string,
	Creator: {
		CreatorTargetId: number,
		CreatorType: Enum.CreatorType,
		HasVerifiedBadge: boolean?,
		Name: string,
	},
	DisplayIconImageAssetId: number,
	DisplayName: string,
	IconImageAssetId: number,
	IsForSale: boolean,
	IsLimited: boolean,
	IsLimitedUnique: boolean,
	IsNew: boolean,
	IsPublicDomain: boolean,
	MinimumMembershipLevel: number,
	Name: string,
	PriceInRobux: number,
	ProductId: number,
	ProductType: Enum.InfoType,
	TargetId: number,
	Updated: string,
}

export type GiftReceiptInfo = {
	PurchaseId: number, --A unique identifier for the specific purchase.
	PlayerId: number, --The user ID of the user who received the gift.
	PlayerPurchasedId: number, --The user ID of the user who purchased.
	ProductId: number, --The ID of the purchased product.
	PlaceIdWherePurchased: number, --The place ID in which the purchase was made. Depending on where the user is during gameplay, the purchase place's ID can be the same as or different from the current place's ID.
	CurrencySpent: number, --The amount of currency spent in the transaction.
	CurrencyType: Enum.CurrencyType, --The type of currency spent in the purchase; always Enum.CurrencyType.Robux.
	ProductPurchaseChannel: Enum.ProductPurchaseChannel, --How the user acquired the developer product. One of Enum.ProductPurchaseChannel.
}

type GamePassGifted = {
	Connect: (self: GamePassGifted, (player: Player, playerGiftedId: number, gamePassId: number) -> ()) -> RBXScriptConnection,
	Once: (self: GamePassGifted, (player: Player, playerGiftedId: number, gamePassId: number) -> ()) -> RBXScriptConnection,
	Wait: (self: GamePassGifted, (player: Player, playerGiftedId: number, gamePassId: number) -> ()) -> RBXScriptConnection,
	ConnectParallel: (self: GamePassGifted, (player: Player, playerGiftedId: number, gamePassId: number) -> ()) -> RBXScriptConnection
}

--[[Prompts the Product gifting gui to the given <strong>player</strong>.
<strong>productId</strong> should not the the ProductId of the gift product.]]
function GiftService:PromptProductGift(player: Player, productId: number)
	if player:GetAttribute("Gifting_CurrentGiftId") or player:GetAttribute("Gifting_InPurchase") then return end
	
	if IsServer == true then
		player:SetAttribute("Gifting_CurrentGiftId", Settings.ProductGiftIds[productId])
		script.Events.PromptProductGift:FireClient(player, productId)
	elseif script:GetAttribute("_purchasePromptOpen") == false then
		script.Events.PromptProductGift:FireServer(productId)
	end
end

--[[Prompts the GamePass gifting gui to the given <strong>player</strong>.
<strong>productId</strong> should not the the GamePassId of the gift product.]]
function GiftService:PromptGamePassGift(player: Player, gamePassId: number)
	if player:GetAttribute("Gifting_CurrentGiftId") or player:GetAttribute("Gifting_InPurchase") then return end
	
	local ignoreList: {Player} = {}
	if IsServer then
		ignoreList = script.Events.RequestIgnoreListServer:Invoke(gamePassId)
	else
		ignoreList = script.Events.RequestIgnoreListClient:InvokeServer(gamePassId)
	end
	
	if IsServer == true then
		player:SetAttribute("Gifting_CurrentGiftId", Settings.GamePassGiftIds[gamePassId])
		script.Events.PromptGamePassGift:FireClient(player, gamePassId, ignoreList)
	elseif script:GetAttribute("_purchasePromptOpen") == false then
		script.Events.PromptGamePassGift:FireServer(gamePassId, ignoreList)
	end
end

--[[Checks if the given <strong>assetId</strong> has an associated GiftId.]]
function GiftService:HasGiftId(assetId: number, infoType: Enum.InfoType): boolean
	assert(assetId, "Argument 1 is nil")
	assert(infoType == Enum.InfoType.Product or infoType == Enum.InfoType.GamePass, "InfoType must be Product or GamePass")
	for i,v in Settings[infoType.Name.. "GiftIds"] do
		if i == assetId then
			return true
		end
	end
	return false
end

--[[Checks if <strong>assetId</strong> is a <strong>GiftId</strong>.]]
function GiftService:IsGiftId(assetId: number, infoType: Enum.InfoType): boolean
	assert(assetId, "Argument 1 is nil")
	assert(infoType == Enum.InfoType.Product or infoType == Enum.InfoType.GamePass, "InfoType must be Product or GamePass")
	for i,v in Settings[infoType.Name.. "GiftIds"] do
		if v == assetId then
			return true
		end
	end
	return false
end

local function getGiftId(assetId: number, infoType: Enum.InfoType): number?
	return Settings[infoType.Name.. "GiftIds"][assetId]
end

--[[Returns the <strong>GiftId</strong> for <strong>productId</strong>.
Returns <strong>nil</strong> if no <strong>GiftId</strong> is found.]]
function GiftService:GetProductGiftId(productId: number): number?
	assert(productId, "Argument 1 is nil")
	return getGiftId(productId, Enum.InfoType.Product)
end

--[[Returns the <strong>GiftId</strong> for <strong>gamePassId</strong>.
Returns <strong>nil</strong> if no <strong>GiftId</strong> is found.]]
function GiftService:GetGamePassGiftId(gamePassId: number): number?
	assert(gamePassId, "Argument 1 is nil")
	return getGiftId(gamePassId, Enum.InfoType.GamePass)
end

local function getAssetId(giftId: number, infoType: Enum.InfoType): number?
	for i,v in Settings[infoType.Name.. "GiftIds"] do
		if v == giftId then
			return i
		end
	end
end

--[[Returns the <strong>ProductId</strong> associated with <strong>giftId</strong>.
Returns <strong>nil</strong> if no <strong>ProductId</strong> is found.]]
function GiftService:GetProductIdFromGiftId(giftId: number)
	assert(giftId, "Argument 1 is nil")
	return getAssetId(giftId, Enum.InfoType.Product)
end

--[[Returns the <strong>GamePassId</strong> associated with <strong>giftId</strong>.
Returns <strong>nil</strong> if no <strong>GamePassId</strong> is found.]]
function GiftService:GetGamePassIdFromGiftId(giftId: number)
	assert(giftId, "Argument 1 is nil")
	return getAssetId(giftId, Enum.InfoType.GamePass)
end

--Handles PromptProductGift and PromptGamePassGift being fired from the client
if IsServer then
	local DataSaveService = require(ReplicatedStorage.Services.DataSaveService)
	local profileStore = DataSaveService:GetProfileStore()
	DataSaveService:AddToTemplate("Gifting_OwnedGamepasses", {})
	
	local function convertReceiptInfo(receiptInfo: GiftReceiptInfo, toDataStore: boolean): GiftReceiptInfo
		if toDataStore then
			for i,v in receiptInfo do
				if typeof(v) == "EnumItem" then
					receiptInfo[i] = {v.EnumType, v.Name}
				end
			end
		else
			for i,v in receiptInfo do
				if i[1] and Enum[i[1]] then
					receiptInfo[i] = Enum[i[1]][i[2]]
				end
			end
		end
		return receiptInfo
	end
	
	local function requestIgnoreList(gamePassId: number)
		local ignoreList = {}
		for player, profile in DataSaveService:GetProfiles() do
			--pcall(function()
				print(profile.Data.Gifting_OwnedGamepasses, gamePassId)
				if table.find(profile.Data.Gifting_OwnedGamepasses, gamePassId) then
					table.insert(ignoreList, player)
				end
			--end)
		end
		return ignoreList
	end
	
	script.Events.RequestIgnoreListClient.OnServerInvoke = function(player, gamePassId: number)
		return requestIgnoreList(gamePassId)
	end
	script.Events.RequestIgnoreListServer.OnInvoke = function(gamePassId: number)
		return requestIgnoreList(gamePassId)
	end
	
	--Product handling
	--ProductId shouldn't be the gift Id.
	local Functions = {}

	function GiftService:CreateReceipt(productId: number, f: (giftReceiptInfo: GiftReceiptInfo) -> Enum.ProductPurchaseDecision)
		assert(productId ~= nil, "Argument 1 is nil")
		assert(f ~= nil, "Argument 2 is nil")
		assert(IsServer, "CreateReceipt can only be called from the server")
		assert(GiftService:HasGiftId(productId, Enum.InfoType.Product), "ProductId does not have an associated GiftId.")

		Functions[productId] = f
		MarketplaceService:CreateReceipt(GiftService:GetProductGiftId(productId), function(receiptInfo)
			if f then
				local playerPurchased = Players:GetPlayerByUserId(receiptInfo.PlayerId)
				local player = Players:GetPlayerByUserId(playerPurchased:GetAttribute("Gifting_PlayerToGift"))
				receiptInfo.PlayerPurchasedId = receiptInfo.PlayerId
				receiptInfo.PlayerId = playerPurchased:GetAttribute("Gifting_PlayerToGift")
				
				if player then --player who got gift is still in game
					playerPurchased:SetAttribute("Gifting_PlayerToGift", nil)
					playerPurchased:SetAttribute("Gifting_CurrentGiftId", nil)
					playerPurchased:SetAttribute("Gifting_InPurchase", nil)
					return f(receiptInfo)
				else
					local profile_key = DataSaveService:GetProfileKey(playerPurchased:GetAttribute("Gifting_PlayerToGift"))
					local message = {
						ReceiptInfo = convertReceiptInfo(receiptInfo, true),
						Type = "Product",

						--TODO talk to ethan about making this a standard on all of our ProfileStore stuff
						["Metadata"] = {
							["Location"] = "Gifting_Gift"
						}
					}
					profileStore:MessageAsync(profile_key, message)

					playerPurchased:SetAttribute("Gifting_PlayerToGift", nil)
					playerPurchased:SetAttribute("Gifting_CurrentGiftId", nil)
					playerPurchased:SetAttribute("Gifting_InPurchase", nil)
					return Enum.ProductPurchaseDecision.PurchaseGranted
				end
			end
		end)
	end
	
	--Adding gamepass handling
	for i,v in Settings.GamePassGiftIds do
		MarketplaceService:CreateReceipt(v, function(receiptInfo)
			local playerPurchased = Players:GetPlayerByUserId(receiptInfo.PlayerId)
			local player = Players:GetPlayerByUserId(playerPurchased:GetAttribute("Gifting_PlayerToGift"))
			
			if player then --the player who got the gift is still in the server
				local profile = DataSaveService:GetProfile(player)
				table.insert(profile.Data.Gifting_OwnedGamepasses, GiftService:GetGamePassIdFromGiftId(receiptInfo.ProductId))
				script.Events.GamePassGifted:Fire(player, receiptInfo.PlayerId, GiftService:GetGamePassIdFromGiftId(receiptInfo.ProductId))
			else
				local profile_key = DataSaveService:GetProfileKey(playerPurchased:GetAttribute("Gifting_PlayerToGift"))
				local message = {
					ReceiptInfo = convertReceiptInfo(receiptInfo, true),
					Type = "GamePass",

					--TODO talk to ethan about making this a standard on all of our ProfileStore stuff
					["Metadata"] = {
						["Location"] = "Gifting_Gift"
					}
				}
				profileStore:MessageAsync(profile_key, message)
			end
			
			playerPurchased:SetAttribute("Gifting_PlayerToGift", nil)
			playerPurchased:SetAttribute("Gifting_CurrentGiftId", nil)
			playerPurchased:SetAttribute("Gifting_InPurchase", nil)
		end)
	end

	script.Events.PromptProductGift.OnServerEvent:Connect(function(...)
		GiftService:PromptProductGift(...)
	end)
	script.Events.PromptGamePassGift.OnServerEvent:Connect(function(...)
		GiftService:PromptGamePassGift(...)
	end)

	--Canceling from the client
	script.Events.ClientCanceledPurchase.OnServerEvent:Connect(function(player)
		player:SetAttribute("Gifting_PlayerToGift", nil)
		player:SetAttribute("Gifting_CurrentGiftId", nil)
	end)

	--Handles buying the actual product
	script.Events.ClientSelectedGift.OnServerEvent:Connect(function(player, playerToGift: Player)
		if not player:GetAttribute("Gifting_CurrentGiftId") then return end
		player:SetAttribute("Gifting_PlayerToGift", playerToGift.UserId)
		script.Events.PromptGiftFinished:FireClient(player)
		script.Events.PromptPurchaseStarted:FireClient(player)
		MarketplaceService:PromptProductPurchase(player, player:GetAttribute("Gifting_CurrentGiftId"))
	end)

	--Removing attributes if they cancel the prompt instead of purchasing
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(userId, _, wasPurchased) --might need to change this a bit to be like products
		local player = Players:GetPlayerByUserId(userId)
		if player then
			player:SetAttribute("Gifting_PlayerToGift", nil)
			player:SetAttribute("Gifting_CurrentGiftId", nil)
			player:SetAttribute("Gifting_InPurchase", nil)
		end
	end)
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, _, wasPurchased)
		local player = Players:GetPlayerByUserId(userId)
		if player and not wasPurchased then
			player:SetAttribute("Gifting_PlayerToGift", nil)
			player:SetAttribute("Gifting_CurrentGiftId", nil)
			player:SetAttribute("Gifting_InPurchase", nil)
		end
	end)

	--Getting gifts from when the player wasn't in the game
	local function profileAdded(player: Player, profile: DataSaveService.Profile)
		profile:MessageHandler(function(message, processed)
			print('GIFTED', message)
			message.ReceiptInfo = convertReceiptInfo(message.ReceiptInfo)
			if message.Metadata and message.Metadata.Location == "Gifting_Gift" then
				if message.Type == "Product" then
					local productId = GiftService:GetProductIdFromGiftId(message.ReceiptInfo.ProductId)
					local function checkForFunction()
						if Functions[productId] then
							if Functions[productId](message.ReceiptInfo) == Enum.ProductPurchaseDecision.PurchaseGranted then
								processed()
								return
							end
						else
							warn("Function for product ".. message.ReceiptInfo.ProductId.. " not found")
							task.wait(5)
							checkForFunction()
						end
					end
					if not Functions[productId] then
						task.wait(5)
					end
					checkForFunction()
					
					--warn("No function for id ".. productId.. " found", debug.traceback())
				else --gamepass
					table.insert(profile.Data.Gifting_OwnedGamepasses, GiftService:GetGamePassIdFromGiftId(message.ReceiptInfo.ProductId))
					script.Events.GamePassGifted:Fire(player.UserId, message.ReceiptInfo.PlayerId, GiftService:GetGamePassIdFromGiftId(message.ReceiptInfo.ProductId))
					processed()
				end
			end
		end)
	end

	DataSaveService.ProfileAdded:Connect(function(player)
		profileAdded(player, DataSaveService:GetProfile(player))
	end)
	for player, profile in DataSaveService:GetProfiles() do
		task.spawn(profileAdded, player, profile)
	end

	--MarketplaceService.ProcessReceipt = script.Events.ProcessReceipt
	--Returns true if the player with the given UserId owns the pass with the given gamePassId.
	function GiftService:UserOwnsGamePassAsync(userId: number, gamePassId: number): boolean
		if MarketplaceService:UserOwnsGamePassAsync(userId, gamePassId) == true then
			return true
		end
		local profile = profileStore:GetAsync(DataSaveService:GetProfileKey(userId))
		if profile then
			if table.find(profile.Data.Gifting_OwnedGamepasses) then
				return true
			end
		end
		return false
	end
	GiftService.GamePassGifted = script.Events.GamePassGifted.Event:: GamePassGifted
end

--Client Handling
if IsServer then return GiftService end

local Player = Players.LocalPlayer
local PurchaseDebounce = false
local SelectedPlayer: Player? = nil

local function createGui()
	if not Player.PlayerGui:FindFirstChild("GiftPrompt") then
		local promptGui = script.GiftPrompt:Clone()
		promptGui.ProductPurchaseContainer.Animator.Prompt.AlertContents.TitleContainer.TitleArea.Title.Text = Settings.Prompt.Title
		promptGui.Parent = Player.PlayerGui
		return promptGui
	end
end

local GiftPromptMain: typeof(script.GiftPrompt) = createGui() or Player.PlayerGui:FindFirstChild("GiftPrompt")
local GiftPrompt = GiftPromptMain.ProductPurchaseContainer.Animator.Prompt.AlertContents
local ConfirmButton = GiftPrompt.Footer.Buttons.Confirm

local function selectPlayer(option: typeof(GiftPrompt.PlayerList.ScrollingFrame.Template))
	if option then
		local newSelection = Players:GetPlayerByUserId(tonumber(option.Name))
		if newSelection then
			if PurchaseDebounce == false then
				for i,v: Frame in CollectionService:GetTagged("Gifting_PlayerOption") do
					v.BackgroundColor3 = Color3.fromRGB(123, 122, 125)
				end
				option.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				GiftPrompt.Footer.FooterContent.Content.PlayerToGift.Text = string.gsub(Settings.Prompt.Footer.Selected, "<TO_GIFT>", newSelection.Name) --"This purchase will be gifted to @".. newSelection.Name.. "."
				SelectedPlayer = newSelection
				ConfirmButton:SetAttribute("Enabled", true)
			end
		else
			option:Destroy() --i dont think this should ever actually run but i put it here just in case
		end
	else
		for i,v in GiftPrompt.PlayerList.ScrollingFrame:GetChildren() do
			if not v:IsA("TextButton") or v.Name == "Template" then continue end
			v:Destroy()
		end
		SelectedPlayer = nil
		ConfirmButton:SetAttribute("Enabled", false)
		GiftPrompt.Footer.FooterContent.Content.PlayerToGift.Text = Settings.Prompt.Footer.NoSelection
	end
end

local function createPlayerOption(player: Player)
	if GiftPrompt.PlayerList.ScrollingFrame:FindFirstChild(player.UserId) then return end
	local option = GiftPrompt.PlayerList.ScrollingFrame.Template:Clone()
	option.Name = player.UserId
	option.Text = "@".. player.Name
	
	option.MouseButton1Click:Connect(function()
		selectPlayer(option)
	end)
	option.Visible = true
	option.Parent = GiftPrompt.PlayerList.ScrollingFrame
end

local function removePlayerOption(player: Player)
	for i,v in CollectionService:GetTagged("Gifting_PlayerOption") do --did this because im too lazy to actually path to it
		if v.Name == tostring(player.UserId) then
			v:Destroy()
		end
	end
	if SelectedPlayer == player then
		SelectedPlayer = nil
		ConfirmButton:SetAttribute("Enabled", false)
	end
end

local updatePlayerOptionsConnections: {RBXScriptConnection} = {}

local function updatePlayerOptions(ignoreList: {Player}?)
	for i,v in Players:GetPlayers() do
		if v == Player or (ignoreList and table.find(ignoreList, v)) then continue end
		createPlayerOption(v)
	end
	table.insert(updatePlayerOptionsConnections, Players.PlayerAdded:Connect(function(v)
		if v == Player or (ignoreList and table.find(ignoreList, v)) then return end
		createPlayerOption(v)
	end))
	table.insert(updatePlayerOptionsConnections, Players.PlayerRemoving:Connect(function(v)
		removePlayerOption(v)
	end))
end

local function showPrompt(assetId: number, giftId: number, infoType: Enum.InfoType, ignoreList: {Player}?)
	if script:GetAttribute("_open") == false then
		script:SetAttribute("_open", true)
		updatePlayerOptions(ignoreList)
		
		local assetInfo = MarketplaceService:GetProductInfo(assetId, infoType)
		local giftInfo = MarketplaceService:GetProductInfo(giftId, Enum.InfoType.Product)
		
		GiftPrompt.MiddleContent.Content.ItemName.Text = string.gsub(Settings.Prompt.Display, "<ASSET_NAME>", assetInfo.Name, 1)
		GiftPrompt.MiddleContent.Content.ItemIcon.Image = "rbxassetid://".. tostring(giftInfo.IconImageAssetId)
		GiftPromptMain.Enabled = true
		TweenService:Create(GiftPromptMain.ProductPurchaseContainer, TweenInfo.new(.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Position = UDim2.fromScale(0, 0)}):Play()
		return true
	end
end
local closing = false
local function closePrompt()
	if script:GetAttribute("_open") == true and closing == false then
		closing = true
		local tween = TweenService:Create(GiftPromptMain.ProductPurchaseContainer, TweenInfo.new(.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Position = UDim2.fromScale(0, -1)})
		tween:Play()
		tween.Completed:Wait()
		GiftPromptMain.Enabled = false
		for i,v in updatePlayerOptionsConnections do
			v:Disconnect()
		end
		selectPlayer() --nil to unselect all
		script:SetAttribute("_open", false)
		closing = false
	end
end

local function updateConfirmButton()
	if ConfirmButton:GetAttribute("Enabled") == true then
		ConfirmButton.ImageColor3 = Color3.fromRGB(247, 247, 248)
	else
		ConfirmButton.ImageColor3 = Color3.fromRGB(123, 122, 125)
	end
end

ConfirmButton.MouseButton1Click:Connect(function()
	if PurchaseDebounce == false and ConfirmButton:GetAttribute("Enabled") == true and script:GetAttribute("_open") == true then
		PurchaseDebounce = true
		ConfirmButton:SetAttribute("Enabled", false)
		script.Events.ClientSelectedGift:FireServer(SelectedPlayer)
	end
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(userId)
	if Player.UserId == userId then
		PurchaseDebounce = false
		script:SetAttribute("_purchasePromptOpen", false)
	end
end)
MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId)
	if Player.UserId == userId then
		PurchaseDebounce = false
		script:SetAttribute("_purchasePromptOpen", false)
	end
end)

updateConfirmButton()
ConfirmButton:GetAttributeChangedSignal("Enabled"):Connect(updateConfirmButton)

script.Events.PromptProductGift.OnClientEvent:Connect(function(productId: number)
	local giftId = Settings.ProductGiftIds[productId]
	if not showPrompt(productId, giftId, Enum.InfoType.Product) then
		script.Events.ClientCanceledPurchase:FireServer()
	end
end)
script.Events.PromptGamePassGift.OnClientEvent:Connect(function(gamePassId: number, ignoreList)
	local giftId = Settings.GamePassGiftIds[gamePassId]
	if not showPrompt(gamePassId, giftId, Enum.InfoType.GamePass, ignoreList) then
		script.Events.ClientCanceledPurchase:FireServer()
	end
end)
script.Events.PromptGiftFinished.OnClientEvent:Connect(function()
	closePrompt()
end)
script.Events.HideGiftPrompt.OnClientEvent:Connect(closePrompt)
script.Events.PromptPurchaseStarted.OnClientEvent:Connect(function()
	script:SetAttribute("_purchasePromptOpen", true)
end)

GiftPrompt.Footer.Buttons.Cancel.MouseEnter:Connect(function()
	GiftPrompt.Footer.Buttons.Cancel.ButtonContent.ButtonMiddleContent.Text.TextTransparency = 0
	GiftPrompt.Footer.Buttons.Cancel.ImageTransparency = 0
end)
GiftPrompt.Footer.Buttons.Cancel.MouseLeave:Connect(function()
	GiftPrompt.Footer.Buttons.Cancel.ButtonContent.ButtonMiddleContent.Text.TextTransparency = 0.3
	GiftPrompt.Footer.Buttons.Cancel.ImageTransparency = 0.3
end)
GiftPrompt.Footer.Buttons.Cancel.MouseButton1Click:Connect(function()
	script.Events.ClientCanceledPurchase:FireServer()
	closePrompt()
end)

return GiftService