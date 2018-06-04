--[[
    Copyright: Omar Saleh Assadi, Brian Hang 2014-2018; Licensed under the EUPL, with extension of article 5
    (compatibility clause) to any licence for distributing derivative works that have been
    produced by the normal use of the Work as a library
--]]
include("sh_util.lua")
include("sh_language.lua")
include("sh_moderator.lua")
AddCSLuaFile("sh_util.lua")
AddCSLuaFile("sh_language.lua")
AddCSLuaFile("sh_moderator.lua")
util.AddNetworkString("mod_NotifyAction")
util.AddNetworkString("mod_Notify")
util.AddNetworkString("mod_AdminMessage")
util.AddNetworkString("mod_AllMessage")

function moderator.NotifyAction(client, target, action)
    local hasNoTarget = target == nil
    net.Start("mod_NotifyAction")
    net.WriteUInt(IsValid(client) and client:EntIndex() or 0, 7)

    if (type(target) ~= "table") then
        target = {target}
    end

    net.WriteTable(target)
    net.WriteString(action)
    net.WriteBit(hasNoTarget)
    net.Broadcast()
end

function moderator.Notify(receiver, message)
    net.Start("mod_Notify")
    net.WriteString(message)

    if (receiver) then
        if (type(receiver) == "Entity" and not IsValid(receiver)) then return MsgN("[moderator] " .. message:sub(1, 1):upper() .. message:sub(2)) end
        net.Send(receiver)
    else
        net.Broadcast()
    end
end

hook.Add("PlayerSay", "mod_PlayerSay", function(client, text)
    if (text:sub(1, 1) == "!") then
        if (utf8) then
            text = string.utf8sub(text, 2)
        else
            text = text:sub(2)
        end

        local ffs
        if (utf8) then
            ffs = string.utf8sub(text, 1, 4)
        else
            ffs = text:sub(1, 4)
        end
        
        if (ffs:lower() == "menu") then
            client:ConCommand("mod_menu")

            return ""
        end

        if (ffs:lower() == "help") then
            client:ChatPrint("[moderator] Help has been printed in your console.")
            client:ConCommand("mod help")

            return ""
        end

        local command = text:match("([_%w가-힝]+)")

        local commandLen
        if (utf8) then
            commandLen = string.utf8len(command)
        else
            commandLen = #command
        end

        if (command) then
            command = command:lower()
            
            local arguments
            if (utf8) then
                arguments = string.utf8sub(text, commandLen + 1)
            else
                arguments = text:sub(commandLen + 1)
            end

            local result, message = moderator.ParseCommand(client, command, arguments)

            if (message) then
                moderator.Notify(client, message .. ".")
            end
        end

        return ""
    elseif (text:sub(1, 1) == "@") then
        local players = moderator.GetPlayersByGroup("moderator")
        players[#players + 1] = client
        text = text:sub(2)

        if (text:sub(1, 1) == " ") then
            text = text:sub(2)
        elseif (text:sub(1, 1) == "@" and client:CheckGroup("moderator")) then
            text = text:sub(2)

            if (text:sub(1, 1) == " ") then
                text = text:sub(2)
            end

            net.Start("mod_AllMessage")
            net.WriteUInt(client:EntIndex(), 8)
            net.WriteString(text)
            net.Broadcast()

            return ""
        end

        net.Start("mod_AdminMessage")
        net.WriteUInt(client:EntIndex(), 8)
        net.WriteString(text)
        net.Send(players)

        return ""
    end
end)