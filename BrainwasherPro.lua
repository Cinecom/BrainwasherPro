-- BrainwasherPro - Modern Brainwasher Interface for Turtle WoW
-- Compatible with WoW 1.12.1 client

-- Main namespace to avoid global pollution
BrainwasherPro = {}

-- Localization table for future translations
local L = {
    ["TITLE"] = "BrainwasherPro",
    ["AVAILABLE_SLOT"] = "Available Talent Slot",
    ["EDIT"] = "Edit",
    ["SAVE"] = "Save",
    ["RESET_TALENTS"] = "Reset Talents",
    ["EDIT_SPEC"] = "Edit Talent Spec",
    ["SPEC_NAME"] = "Spec Name:",
    ["SPEC_ICON"] = "Spec Icon:",
    ["CANCEL"] = "Cancel",
    ["CONFIRM"] = "Confirm",
    ["SAVE_SPEC_CONFIRM"] = "Save your current talents to this slot?",
    ["LOAD_SPEC_CONFIRM"] = "Load this talent spec? This will cause a brainwasher debuff.",
    ["RESET_TALENTS_CONFIRM"] = "Reset all your talents? This costs gold and causes a debuff.", -- Generic fallback text
    ["YES"] = "Yes",
    ["NO"] = "No",
    ["SHOW_ORIGINAL"] = "Show Original"
}

-- Local variables
local mainFrame = nil
local editFrame = nil
local iconFrame = nil
local specButtons = {}
local gossipSlots = {}
local currentEditSlot = 1
local iconButtons = {}
local macroIcons = {} -- NEW: Table to hold all macro icons
BrainwasherPro.currentSlotAction = nil

-- Utility functions
local function ColorTalentSummary(t1, t2, t3)
    local largest = math.max(t1, t2, t3)
    local smallest = math.min(t1, t2, t3)
    
    local function getColor(value)
        if value == largest then
            return "|cff00ff00"
        elseif value == smallest then
            return "|cff0077ff"
        else
            return "|cffffff00"
        end
    end
    
    return getColor(t1)..t1.."|r/"..getColor(t2)..t2.."|r/"..getColor(t3)..t3.."|r"
end

local function GetTalentCounts()
    local _, _, t1 = GetTalentTabInfo(1)
    local _, _, t2 = GetTalentTabInfo(2)
    local _, _, t3 = GetTalentTabInfo(3)
    return t1 or 0, t2 or 0, t3 or 0
end

local function FetchCurrentTalents()
    local talents = {}
    for tab = 1, 3 do
        local _, _, tcount = GetTalentTabInfo(tab)
        talents[tab] = {}
        for talent = 1, 100 do
            local name, icon, row, col, count, max = GetTalentInfo(tab, talent)
            if not name then break end
            talents[tab][talent] = {
                name = name,
                icon = icon,
                row = row,
                col = col,
                count = count,
                max = max
            }
        end
    end
    return talents
end

-- NEW: Function to load all available macro icons
function BrainwasherPro:PopulateMacroIcons()
    local numIcons = GetNumMacroIcons()
    for i = 1, numIcons do
        tinsert(macroIcons, GetMacroIconInfo(i))
    end
end

-- UI Creation Functions
function BrainwasherPro:CreateMainFrame()
    if mainFrame then return end
    
    mainFrame = CreateFrame("Frame", "BrainwasherProFrame", UIParent)
    mainFrame:SetWidth(200)
    mainFrame:SetHeight(220)
    mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    mainFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = {left = 2, right = 2, top = 2, bottom = 2}
    })
    mainFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    mainFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", function() this:StartMoving() end)
    mainFrame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    mainFrame:Hide()
    
    tinsert(UISpecialFrames, "BrainwasherProFrame")
    
    local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", mainFrame, "TOP", 0, -8)
    title:SetText(L["TITLE"])
    title:SetTextColor(0.9, 0.9, 0.9, 1)
    
    local closeButton = CreateFrame("Button", nil, mainFrame)
    closeButton:SetWidth(12)
    closeButton:SetHeight(12)
    closeButton:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -6, -6)
    closeButton:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 4,
        insets = {left = 1, right = 1, top = 1, bottom = 1}
    })
    closeButton:SetBackdropColor(0.8, 0.2, 0.2, 0.8)
    closeButton:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    
    local closeText = closeButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    closeText:SetPoint("CENTER", closeButton, "CENTER", 0, 0)
    closeText:SetText("X")
    closeText:SetTextColor(1, 1, 1, 1)
    
    closeButton:SetScript("OnEnter", function() closeButton:SetBackdropColor(1, 0.3, 0.3, 1) end)
    closeButton:SetScript("OnLeave", function() closeButton:SetBackdropColor(0.8, 0.2, 0.2, 0.8) end)
    closeButton:SetScript("OnClick", function() 
        mainFrame:Hide()
        CloseGossip()
    end)
    
    for i = 1, 4 do
        self:CreateSpecSlot(i)
    end
    
    local bottomPanel = CreateFrame("Frame", nil, mainFrame)
    bottomPanel:SetWidth(180)
    bottomPanel:SetHeight(20)
    bottomPanel:SetPoint("BOTTOM", mainFrame, "BOTTOM", 0, 8)

    local resetButton = CreateFrame("Button", nil, bottomPanel)
    resetButton:SetWidth(100)
    resetButton:SetHeight(18)
    resetButton:SetPoint("LEFT", bottomPanel, "LEFT", 0, 0)
    resetButton:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 4,
        insets = {left = 1, right = 1, top = 1, bottom = 1}
    })
    resetButton:SetBackdropColor(0.6, 0.2, 0.2, 0.8)
    resetButton:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    
    local resetText = resetButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    resetText:SetPoint("CENTER", resetButton, "CENTER", 0, 0)
    resetText:SetText(L["RESET_TALENTS"])
    resetText:SetTextColor(1, 1, 1, 1)
    
    self.mainResetButton = resetButton
    self.mainResetText = resetText
    
    resetButton:SetScript("OnEnter", function() resetButton:SetBackdropColor(0.8, 0.3, 0.3, 1) end)
    resetButton:SetScript("OnLeave", function() resetButton:SetBackdropColor(0.6, 0.2, 0.2, 0.8) end)
    resetButton:SetScript("OnClick", function()
        local price = gossipSlots.resetPrice or 0
        if price > 0 then
            StaticPopupDialogs["BRAINWASHERPRO_RESET_TALENTS"].text = "Reset all your talents? This will cost " .. price .. " gold and causes a debuff."
        else
            StaticPopupDialogs["BRAINWASHERPRO_RESET_TALENTS"].text = L["RESET_TALENTS_CONFIRM"]
        end
        StaticPopup_Show("BRAINWASHERPRO_RESET_TALENTS")
    end)

    local showOriginalButton = CreateFrame("Button", nil, bottomPanel)
    showOriginalButton:SetWidth(75)
    showOriginalButton:SetHeight(18)
    showOriginalButton:SetPoint("RIGHT", bottomPanel, "RIGHT", 0, 0)
    showOriginalButton:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 4,
        insets = {left = 1, right = 1, top = 1, bottom = 1}
    })
    showOriginalButton:SetBackdropColor(0.3, 0.3, 0.3, 0.8)
    showOriginalButton:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    local originalText = showOriginalButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    originalText:SetPoint("CENTER", showOriginalButton, "CENTER", 0, 0)
    originalText:SetText(L["SHOW_ORIGINAL"])
    originalText:SetTextColor(0.8, 0.8, 0.8, 1)

    showOriginalButton:SetScript("OnEnter", function() showOriginalButton:SetBackdropColor(0.5, 0.5, 0.5, 1) end)
    showOriginalButton:SetScript("OnLeave", function() showOriginalButton:SetBackdropColor(0.3, 0.3, 0.3, 0.8) end)
    showOriginalButton:SetScript("OnClick", function()
        mainFrame:Hide()
        if GossipFrame then
            GossipFrame:SetAlpha(1)
        end
    end)
end

function BrainwasherPro:CreateSpecSlot(slotIndex)
    local yOffset = -25 - ((slotIndex - 1) * 42)
    
    local slotFrame = CreateFrame("Frame", "BrainwasherProSlot"..slotIndex, mainFrame)
    slotFrame:SetWidth(185)
    slotFrame:SetHeight(38)
    slotFrame:SetPoint("TOP", mainFrame, "TOP", 0, yOffset)
    slotFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = nil,
        tile = true, tileSize = 16,
        insets = {left = 0, right = 0, top = 0, bottom = 0}
    })
    slotFrame:SetBackdropColor(0.15, 0.15, 0.15, 0.6)
    
    slotFrame:EnableMouse(true)
    slotFrame:SetScript("OnEnter", function() slotFrame:SetBackdropColor(0.25, 0.35, 0.45, 0.8) end)
    slotFrame:SetScript("OnLeave", function() slotFrame:SetBackdropColor(0.15, 0.15, 0.15, 0.6) end)
    
    local iconButton = CreateFrame("Button", "BrainwasherProIcon"..slotIndex, slotFrame)
    iconButton:SetWidth(20)
    iconButton:SetHeight(20)
    iconButton:SetPoint("LEFT", slotFrame, "LEFT", 6, 0)
    iconButton:RegisterForClicks("LeftButtonUp")
    
    local iconTexture = iconButton:CreateTexture(nil, "ARTWORK")
    iconTexture:SetAllPoints()
    iconTexture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    iconButton.iconTexture = iconTexture

    local glowTexture = iconButton:CreateTexture(nil, "OVERLAY")
    glowTexture:SetAllPoints(iconTexture)
    glowTexture:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    glowTexture:SetBlendMode("ADD")
    glowTexture:Hide()
    iconButton.glowTexture = glowTexture
    
    iconButton:SetScript("OnEnter", function()
        iconButton:SetWidth(22)
        iconButton:SetHeight(22)
        iconTexture:SetVertexColor(1.2, 1.2, 1.2)
        iconButton.glowTexture:Show()
    end)
    
    iconButton:SetScript("OnLeave", function()
        iconButton:SetWidth(20)
        iconButton:SetHeight(20)
        iconTexture:SetVertexColor(1, 1, 1)
        iconButton.glowTexture:Hide()
    end)
    
    local nameText = slotFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("LEFT", iconButton, "RIGHT", 6, 4)
    nameText:SetWidth(85)
    nameText:SetJustifyH("LEFT")
    nameText:SetText(L["AVAILABLE_SLOT"])
    nameText:SetTextColor(0.7, 0.7, 0.7, 1)
    
    local summaryText = slotFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    summaryText:SetPoint("LEFT", iconButton, "RIGHT", 6, -6)
    summaryText:SetWidth(85)
    summaryText:SetJustifyH("LEFT")
    summaryText:SetText("")
    
    local buttonPanel = CreateFrame("Frame", nil, slotFrame)
    buttonPanel:SetWidth(60)
    buttonPanel:SetHeight(36)
    buttonPanel:SetPoint("RIGHT", slotFrame, "RIGHT", -4, 0)
    
    local editButton = CreateFrame("Button", nil, buttonPanel)
    editButton:SetWidth(40)
    editButton:SetHeight(14)
    editButton:SetPoint("TOPRIGHT", buttonPanel, "TOPRIGHT", 0, -2)
    editButton:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 2,
        insets = {left = 1, right = 1, top = 1, bottom = 1}
    })
    editButton:SetBackdropColor(0.8, 0.7, 0.2, 0.8)
    editButton:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    
    local editText = editButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    editText:SetPoint("CENTER", editButton, "CENTER", 0, 0)
    editText:SetText(L["EDIT"])
    editText:SetTextColor(1, 1, 1, 1)
    
    editButton:SetScript("OnEnter", function() editButton:SetBackdropColor(1, 0.9, 0.4, 1) end)
    editButton:SetScript("OnLeave", function() editButton:SetBackdropColor(0.8, 0.7, 0.2, 0.8) end)
    
    local saveButton = CreateFrame("Button", nil, buttonPanel)
    saveButton:SetWidth(40)
    saveButton:SetHeight(14)
    saveButton:SetPoint("BOTTOMRIGHT", buttonPanel, "BOTTOMRIGHT", 0, 2)
    saveButton:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 2,
        insets = {left = 1, right = 1, top = 1, bottom = 1}
    })
    saveButton:SetBackdropColor(0.2, 0.5, 0.8, 0.8)
    saveButton:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    
    local saveText = saveButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    saveText:SetPoint("CENTER", saveButton, "CENTER", 0, 0)
    saveText:SetText(L["SAVE"])
    saveText:SetTextColor(1, 1, 1, 1)
    
    saveButton:SetScript("OnEnter", function() saveButton:SetBackdropColor(0.4, 0.7, 1, 1) end)
    saveButton:SetScript("OnLeave", function() saveButton:SetBackdropColor(0.2, 0.5, 0.8, 0.8) end)
    
    specButtons[slotIndex] = {
        frame = slotFrame,
        icon = iconButton,
        name = nameText,
        summary = summaryText,
        edit = editButton,
        save = saveButton,
        slotIndex = slotIndex
    }
    
    iconButton:SetScript("OnClick", function() BrainwasherPro:OnSpecClicked(slotIndex) end)
    editButton:SetScript("OnClick", function() BrainwasherPro:OnEditClicked(slotIndex) end)
    saveButton:SetScript("OnClick", function() BrainwasherPro:OnSaveClicked(slotIndex) end)
end

function BrainwasherPro:CreateEditFrame()
    if editFrame then return end
    
    editFrame = CreateFrame("Frame", "BrainwasherProEditFrame", UIParent)
    editFrame:SetWidth(220)
    editFrame:SetHeight(280)
    editFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    editFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = {left = 2, right = 2, top = 2, bottom = 2}
    })
    editFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    editFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    editFrame:SetFrameStrata("DIALOG")
    editFrame:SetMovable(true)
    editFrame:EnableMouse(true)
    editFrame:RegisterForDrag("LeftButton")
    editFrame:SetScript("OnDragStart", function() this:StartMoving() end)
    editFrame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    editFrame:Hide()
    
    local title = editFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOP", editFrame, "TOP", 0, -8)
    title:SetText(L["EDIT_SPEC"])
    title:SetTextColor(0.9, 0.9, 0.9, 1)
    
    local closeButton = CreateFrame("Button", nil, editFrame)
    closeButton:SetWidth(12)
    closeButton:SetHeight(12)
    closeButton:SetPoint("TOPRIGHT", editFrame, "TOPRIGHT", -6, -6)
    closeButton:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 4,
        insets = {left = 1, right = 1, top = 1, bottom = 1}
    })
    closeButton:SetBackdropColor(0.8, 0.2, 0.2, 0.8)
    closeButton:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    
    local closeText = closeButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    closeText:SetPoint("CENTER", closeButton, "CENTER", 0, 0)
    closeText:SetText("X")
    closeText:SetTextColor(1, 1, 1, 1)
    
    closeButton:SetScript("OnEnter", function() closeButton:SetBackdropColor(1, 0.3, 0.3, 1) end)
    closeButton:SetScript("OnLeave", function() closeButton:SetBackdropColor(0.8, 0.2, 0.2, 0.8) end)
    closeButton:SetScript("OnClick", function() editFrame:Hide() end)
    
    local iconButton = CreateFrame("Button", nil, editFrame)
    iconButton:SetWidth(24)
    iconButton:SetHeight(24)
    iconButton:SetPoint("TOPLEFT", editFrame, "TOPLEFT", 15, -30)
    
    local iconTexture = iconButton:CreateTexture(nil, "ARTWORK")
    iconTexture:SetAllPoints()
    iconTexture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    iconButton.iconTexture = iconTexture
    editFrame.iconButton = iconButton
    
    local nameEdit = CreateFrame("EditBox", nil, editFrame)
    nameEdit:SetWidth(140)
    nameEdit:SetHeight(20)
    nameEdit:SetPoint("LEFT", iconButton, "RIGHT", 8, 0)
    nameEdit:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 4,
        insets = {left = 2, right = 2, top = 2, bottom = 2}
    })
    nameEdit:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    nameEdit:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    nameEdit:SetFont("Fonts\\FRIZQT__.TTF", 11)
    nameEdit:SetTextColor(1, 1, 1, 1)
    nameEdit:SetAutoFocus(false)
    nameEdit:SetMaxLetters(20)
    editFrame.nameEdit = nameEdit
    
    local scrollFrame = CreateFrame("ScrollFrame", "BrainwasherProIconScrollFrame", editFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", iconButton, "BOTTOMLEFT", -5, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", editFrame, "BOTTOMRIGHT", -30, 40)
    
    local content = CreateFrame("Frame", "BrainwasherProIconContent", scrollFrame)
    content:SetWidth(180)
    scrollFrame:SetScrollChild(content)
    editFrame.iconScrollFrame = scrollFrame
    editFrame.iconContent = content
    
    -- CHANGE: Use the new dynamic macroIcons table
    local iconsPerRow = 8
    local iconSize = 20
    local iconSpacing = 22
    local totalRows = math.ceil(table.getn(macroIcons) / iconsPerRow)
    
    content:SetHeight(totalRows * iconSpacing + 10)
    
    for i = 1, table.getn(macroIcons) do
        local row = math.ceil(i / iconsPerRow) - 1
        local col = i - 1 - (row * iconsPerRow)
        
        local iconBtn = CreateFrame("Button", nil, content)
        iconBtn:SetWidth(iconSize)
        iconBtn:SetHeight(iconSize)
        iconBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 5 + (col * iconSpacing), -5 - (row * iconSpacing))
        
        local btnTexture = iconBtn:CreateTexture(nil, "ARTWORK")
        btnTexture:SetAllPoints()
        btnTexture:SetTexture(macroIcons[i])
        iconBtn.iconTexture = btnTexture
        
        iconBtn:SetScript("OnClick", (function(iconIndex)
            return function()
                if iconIndex <= table.getn(macroIcons) and editFrame and editFrame.iconButton and editFrame.iconButton.iconTexture then
                    editFrame.iconButton.iconTexture:SetTexture(macroIcons[iconIndex])
                end
            end
        end)(i))
        
        iconBtn:SetScript("OnEnter", function() iconBtn.iconTexture:SetVertexColor(1.2, 1.2, 1.2) end)
        iconBtn:SetScript("OnLeave", function() iconBtn.iconTexture:SetVertexColor(1, 1, 1) end)
        
        iconButtons[i] = iconBtn
    end
    
    local buttonPanel = CreateFrame("Frame", nil, editFrame)
    buttonPanel:SetWidth(200)
    buttonPanel:SetHeight(20)
    buttonPanel:SetPoint("BOTTOM", editFrame, "BOTTOM", 0, 10)
    
    local confirmButton = CreateFrame("Button", nil, buttonPanel)
    confirmButton:SetWidth(70)
    confirmButton:SetHeight(18)
    confirmButton:SetPoint("LEFT", buttonPanel, "LEFT", 20, 0)
    confirmButton:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 4,
        insets = {left = 1, right = 1, top = 1, bottom = 1}
    })
    confirmButton:SetBackdropColor(0.3, 0.6, 0.3, 0.8)
    confirmButton:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    
    local confirmText = confirmButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    confirmText:SetPoint("CENTER", confirmButton, "CENTER", 0, 0)
    confirmText:SetText(L["CONFIRM"])
    confirmText:SetTextColor(1, 1, 1, 1)
    
    confirmButton:SetScript("OnEnter", function() confirmButton:SetBackdropColor(0.4, 0.8, 0.4, 1) end)
    confirmButton:SetScript("OnLeave", function() confirmButton:SetBackdropColor(0.3, 0.6, 0.3, 0.8) end)
    confirmButton:SetScript("OnClick", function() BrainwasherPro:ConfirmEdit() end)
    
    local cancelButton = CreateFrame("Button", nil, buttonPanel)
    cancelButton:SetWidth(70)
    cancelButton:SetHeight(18)
    cancelButton:SetPoint("RIGHT", buttonPanel, "RIGHT", -20, 0)
    cancelButton:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 4,
        insets = {left = 1, right = 1, top = 1, bottom = 1}
    })
    cancelButton:SetBackdropColor(0.6, 0.3, 0.3, 0.8)
    cancelButton:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    
    local cancelText = cancelButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cancelText:SetPoint("CENTER", cancelButton, "CENTER", 0, 0)
    cancelText:SetText(L["CANCEL"])
    cancelText:SetTextColor(1, 1, 1, 1)
    
    cancelButton:SetScript("OnEnter", function() cancelButton:SetBackdropColor(0.8, 0.4, 0.4, 1) end)
    cancelButton:SetScript("OnLeave", function() cancelButton:SetBackdropColor(0.6, 0.3, 0.3, 0.8) end)
    cancelButton:SetScript("OnClick", function() editFrame:Hide() end)
end

-- Event Handlers
function BrainwasherPro:OnSpecClicked(slotIndex)
    local hasBuyOption = gossipSlots.buy and gossipSlots.buy[slotIndex]
    local hasLoadOption = gossipSlots.load and gossipSlots.load[slotIndex]
    
    if hasBuyOption then
        gossipSlots.buy[slotIndex].button:Click()
    elseif hasLoadOption then
        BrainwasherPro.currentSlotAction = slotIndex
        StaticPopup_Show("BRAINWASHERPRO_LOAD_SPEC")
    end
end

function BrainwasherPro:OnEditClicked(slotIndex)
    local spec = BrainwasherProDB.specs[slotIndex]
    if not spec then return end
    
    currentEditSlot = slotIndex
    
    if not editFrame then
        self:CreateEditFrame()
    end
    
    editFrame.nameEdit:SetText(spec.name or "Spec " .. slotIndex)
    editFrame.iconButton.iconTexture:SetTexture(spec.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    editFrame:Show()
end

function BrainwasherPro:OnSaveClicked(slotIndex)
    local hasSaveOption = gossipSlots.save and gossipSlots.save[slotIndex]
    if hasSaveOption then
        BrainwasherPro.currentSlotAction = slotIndex
        StaticPopup_Show("BRAINWASHERPRO_SAVE_SPEC")
    end
end

function BrainwasherPro:ConfirmEdit()
    local slotIndex = currentEditSlot
    local spec = BrainwasherProDB.specs[slotIndex]
    
    if spec then
        spec.name = editFrame.nameEdit:GetText()
        spec.icon = editFrame.iconButton.iconTexture:GetTexture()
        self:UpdateSpecDisplay(slotIndex)
    end
    
    editFrame:Hide()
end

-- Core Functions
function BrainwasherPro:UpdateSpecDisplay(slotIndex)
    local button = specButtons[slotIndex]
    local spec = BrainwasherProDB.specs[slotIndex]
    local hasLoadOption = gossipSlots.load and gossipSlots.load[slotIndex]
    local hasSaveOption = gossipSlots.save and gossipSlots.save[slotIndex] 
    local hasBuyOption = gossipSlots.buy and gossipSlots.buy[slotIndex]
    
    if hasBuyOption then
        button.icon.iconTexture:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
        local price = gossipSlots.buy[slotIndex].price
        button.name:SetText("Buy Slot " .. slotIndex .. " (" .. price .. "g)")
        button.name:SetTextColor(1, 0.8, 0, 1)
        button.summary:SetText("Click to purchase")
        button.edit:Hide()
        button.save:Hide()
        
    elseif hasLoadOption and spec then
        button.icon.iconTexture:SetTexture(spec.icon or "Interface\\Icons\\Spell_ChargePositive")
        button.name:SetText(spec.name or "Saved Spec " .. slotIndex)
        button.name:SetTextColor(0.5, 1, 0.5, 1)
        button.summary:SetText("Click to load spec")
        button.edit:Show()
        button.save:Show()
        
    elseif hasSaveOption then
        button.icon.iconTexture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        button.name:SetText(L["AVAILABLE_SLOT"])
        button.name:SetTextColor(0.7, 0.7, 0.7, 1)
        button.summary:SetText("Empty slot")
        button.edit:Hide()
        button.save:Show()
        
    else
        button.icon.iconTexture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        button.name:SetText("Unknown State")
        button.name:SetTextColor(1, 0, 0, 1)
        button.summary:SetText("")
        button.edit:Hide()
        button.save:Hide()
    end
end

function BrainwasherPro:UpdateAllDisplays()
    for i = 1, 4 do
        self:UpdateSpecDisplay(i)
    end
end

function BrainwasherPro:SaveCurrentSpec(slotIndex)
    if not slotIndex then return end
    local t1, t2, t3 = GetTalentCounts()
    local talents = FetchCurrentTalents()
    
    local spec = BrainwasherProDB.specs[slotIndex] or {}
    
    spec.t1 = t1
    spec.t2 = t2
    spec.t3 = t3
    spec.talents = talents

    if not spec.name then
        spec.name = "Spec " .. slotIndex
    end
    if not spec.icon then
        spec.icon = "Interface\\Icons\\INV_Misc_QuestionMark"
    end
    
    BrainwasherProDB.specs[slotIndex] = spec
    
    if gossipSlots.save and gossipSlots.save[slotIndex] then
        gossipSlots.save[slotIndex]:Click()
    end
end

function BrainwasherPro:LoadSpec(slotIndex)
    if not slotIndex then return end
    if gossipSlots.load and gossipSlots.load[slotIndex] then
        gossipSlots.load[slotIndex]:Click()
    end
end

function BrainwasherPro:ResetTalents()
    if gossipSlots.reset then
        gossipSlots.reset:Click()
    end
end

-- Gossip Integration
function BrainwasherPro:ParseGossipOptions()
    gossipSlots = {
        save = {},
        load = {},
        buy = {},
        reset = nil,
        resetPrice = 0
    }
    
    for i = 1, NUMGOSSIPBUTTONS do
        local titleButton = getglobal("GossipTitleButton" .. i)
        
        if titleButton and titleButton:IsVisible() then
            local text = titleButton:GetText()
            
            local _, _, saveSpec = string.find(text, "Save (%d+).. Specialization")
            local _, _, loadSpec = string.find(text, "Activate (%d+).. Specialization")
            local _, _, buySpec, buyPrice = string.find(text, "Buy (%d+).. Specialization.* (%d+) gold")
            local resetMatch = string.find(text, "Reset my talents")
            
            local _, _, resetPrice = string.find(text, "Reset my talents.* (%d+) gold")
            
            if saveSpec then
                local slotNum = tonumber(saveSpec)
                gossipSlots.save[slotNum] = titleButton
                
            elseif loadSpec then
                local slotNum = tonumber(loadSpec)
                gossipSlots.load[slotNum] = titleButton
                if not BrainwasherProDB.specs[slotNum] then
                    BrainwasherProDB.specs[slotNum] = {
                        name = "Spec " .. slotNum,
                        icon = "Interface\\Icons\\INV_Misc_QuestionMark",
                        t1 = 0, t2 = 0, t3 = 0, talents = {}
                    }
                end
                
            elseif buySpec and buyPrice then
                local slotNum = tonumber(buySpec)
                gossipSlots.buy[slotNum] = {
                    button = titleButton,
                    price = tonumber(buyPrice) or 0
                }
                
            elseif resetMatch then
                gossipSlots.reset = titleButton
                if resetPrice then
                    gossipSlots.resetPrice = tonumber(resetPrice) or 0
                end
            end
        end
    end
end

function BrainwasherPro:OnGossipShow()
    local npcName = GossipFrameNpcNameText:GetText()
    if npcName ~= "Goblin Brainwashing Device" then
        return
    end
    
    self:ParseGossipOptions()
    GossipFrame:SetAlpha(0)
    
    if not mainFrame then
        self:CreateMainFrame()
    end
    
    if self.mainResetButton and self.mainResetText then
        if gossipSlots.reset then
            self.mainResetButton:Show()
            if gossipSlots.resetPrice and gossipSlots.resetPrice > 0 then
                self.mainResetText:SetText(L["RESET_TALENTS"] .. " (" .. gossipSlots.resetPrice .. "g)")
            else
                self.mainResetText:SetText(L["RESET_TALENTS"])
            end
        else
            self.mainResetButton:Hide()
        end
    end
    
    mainFrame:Show()
    self:UpdateAllDisplays()
end

function BrainwasherPro:OnGossipClosed()
    if mainFrame then
        mainFrame:Hide()
    end
end

-- Static Popup Dialogs
StaticPopupDialogs["BRAINWASHERPRO_LOAD_SPEC"] = {
    text = L["LOAD_SPEC_CONFIRM"],
    button1 = L["YES"],
    button2 = L["NO"],
    OnAccept = function()
        BrainwasherPro:LoadSpec(BrainwasherPro.currentSlotAction)
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3
}

StaticPopupDialogs["BRAINWASHERPRO_SAVE_SPEC"] = {
    text = L["SAVE_SPEC_CONFIRM"],
    button1 = L["YES"], 
    button2 = L["NO"],
    OnAccept = function()
        BrainwasherPro:SaveCurrentSpec(BrainwasherPro.currentSlotAction)
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3
}

StaticPopupDialogs["BRAINWASHERPRO_RESET_TALENTS"] = {
    text = L["RESET_TALENTS_CONFIRM"],
    button1 = L["YES"],
    button2 = L["NO"],
    OnAccept = function()
        BrainwasherPro:ResetTalents()
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3
}

-- Event Frame Setup
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("GOSSIP_SHOW")
eventFrame:RegisterEvent("GOSSIP_CLOSED")

eventFrame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "BrainwasherPro" then
        if not BrainwasherProDB then
            BrainwasherProDB = {
                specs = {}
            }
        end
        if not BrainwasherProDB.specs then
            BrainwasherProDB.specs = {}
        end
        
        -- NEW: Populate the icons table when the addon loads
        BrainwasherPro:PopulateMacroIcons()
        
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00BrainwasherPro loaded! Interact with a Brainwashing Device to use.|r")
        
    elseif event == "GOSSIP_SHOW" then
        BrainwasherPro:OnGossipShow()
        
    elseif event == "GOSSIP_CLOSED" then
        BrainwasherPro:OnGossipClosed()
    end
end)
