-- UIManager.lua
-- Centralized UI State Management
-- Ensures only one menu is open at a time and handles global close events.

local UIManager = {}
UIManager.RegisteredUIs = {} -- { [Name] = {Frame = ..., ToggleFunc = ...} }
UIManager.CurrentOpenUI = nil

-- Register a UI to be managed
function UIManager.Register(name, frame, toggleFunc)
    UIManager.RegisteredUIs[name] = {
        MainFrame = frame,
        Frame = frame, -- COMPATIBILITY
        ToggleFunc = toggleFunc
    }
    
    print("[UIManager] Registered:", name)
    
    -- Ensure it starts closed if not intended
    -- Smart detection: if frame is ScreenGui, look for MainFrame
    local targetFrame = frame
    if targetFrame:IsA("ScreenGui") and targetFrame:FindFirstChild("MainFrame") then
        targetFrame = targetFrame.MainFrame
    end
    
    if targetFrame:IsA("GuiObject") and targetFrame.Visible then
        targetFrame.Visible = false
    end
end

-- Open a specific UI, closing others
function UIManager.Open(name)
    print("[UIManager] Opening UI:", name)
    local target = UIManager.RegisteredUIs[name]
    if not target then 
        warn("[UIManager] Attempted to open unregistered UI:", name)
        -- Print registered ones for debug
        local registered = ""
        for k, _ in pairs(UIManager.RegisteredUIs) do registered = registered .. k .. ", " end
        print("[UIManager] Currently registered:", registered)
        return 
    end
    
    -- Close current if different
    if UIManager.CurrentOpenUI and UIManager.CurrentOpenUI ~= name then
        print("[UIManager] Closing previous UI:", UIManager.CurrentOpenUI)
        UIManager.Close(UIManager.CurrentOpenUI)
    end

    local mainFrame = target.MainFrame or target.Frame
    
    -- Open target
    local success, err = pcall(function()
        if type(target.ToggleFunc) == "function" then
            target.ToggleFunc(true)
        elseif type(target.ToggleFunc) == "table" then
            if target.ToggleFunc.OnOpen then
                target.ToggleFunc.OnOpen()
            end
            if mainFrame:IsA("ScreenGui") and mainFrame:FindFirstChild("MainFrame") then
                mainFrame.MainFrame.Visible = true
            elseif mainFrame:IsA("GuiObject") then
                mainFrame.Visible = true
            end
        else
            if mainFrame:IsA("ScreenGui") and mainFrame:FindFirstChild("MainFrame") then
                mainFrame.MainFrame.Visible = true
            elseif mainFrame:IsA("GuiObject") then
                mainFrame.Visible = true
            end
        end
    end)

    if success then
        UIManager.CurrentOpenUI = name
    else
        warn("[UIManager] CRITICAL ERROR opening " .. name .. ": " .. tostring(err))
        UIManager.CurrentOpenUI = nil
    end
end

-- Close a specific UI
function UIManager.Close(name)
    local target = UIManager.RegisteredUIs[name]
    if not target then return end
    
    local mainFrame = target.MainFrame or target.Frame
    
    if type(target.ToggleFunc) == "function" then
        target.ToggleFunc(false)
    elseif type(target.ToggleFunc) == "table" then
        if target.ToggleFunc.OnClose then
            target.ToggleFunc.OnClose()
        end
        if mainFrame:IsA("ScreenGui") and mainFrame:FindFirstChild("MainFrame") then
            mainFrame.MainFrame.Visible = false
        elseif mainFrame:IsA("GuiObject") then
            mainFrame.Visible = false
        end
    else
        if mainFrame:IsA("ScreenGui") and mainFrame:FindFirstChild("MainFrame") then
            mainFrame.MainFrame.Visible = false
        elseif mainFrame:IsA("GuiObject") then
            mainFrame.Visible = false
        end
    end
    
    if UIManager.CurrentOpenUI == name then
        UIManager.CurrentOpenUI = nil
    end
end

-- Toggle a specific UI
function UIManager.Toggle(name)
    if UIManager.CurrentOpenUI == name then
        UIManager.Close(name)
    else
        UIManager.Open(name)
    end
end

-- Close whatever is open
function UIManager.CloseAll()
    if UIManager.CurrentOpenUI then
        UIManager.Close(UIManager.CurrentOpenUI)
    end
end

return UIManager
