﻿--[[
    Copyright: Omar Saleh Assadi, Brian Hang 2014-2018; Licensed under the EUPL, with extension of article 5
    (compatibility clause) to any licence for distributing derivative works that have been
    produced by the normal use of the Work as a library
--]]
moderator.commands = moderator.commands or {}

if (SERVER) then
    util.AddNetworkString("mod_Command")

    function moderator.GetArguments(text, noArrays, delimiter)
        delimiter = delimiter or " "
        local arguments = {}
        local curString = ""
        local inString = false
        local escaping = 0
        local inArray = false
        local length

        if (utf8) then
            length = string.utf8len(text)
        else
            length = #text
        end

        for i = 1, length do
            local char
            if (utf8) then
                char = string.utf8sub(text, i, i)
            else
                char = text:sub(i, i)
            end

            if (escaping > i) then continue end

            if (char == "\\") then
                escaping = i + 1
            elseif (not noArrays and not inString and char == "[") then
                local match
                if (utf8) then
                    match = string.utf8sub(text, i)
                else
                    match = text:sub(i)
                end
                local match = match:match("%b[]")

                if (match) then
                    local arg
                    if (utf8) then
                        arg = string.utf8sub(text, 2, -2)
                    else
                        arg = text:sub(2, -2)
                    end

                    local exploded = moderator.GetArguments(arg, nil, ",")

                    local prefix
                    if (utf8) then
                        prefix = string.utf8sub(text, 1, 1)
                    else
                        prefix = text:sub(1, 1)
                    end

                    for k, v in pairs(exploded) do
                        if (type(v) == "string" and (prefix == " " or prefix == delimiter)) then
                            if (utf8) then
                                exploded[k] = string.utf8sub(v, 2)
                            else
                                exploded[k] = v:sub(2)
                            end
                        end
                    end

                    arguments[#arguments + 1] = exploded
                    curString = ""
                    escaping = i + #match
                end
            elseif (char == "'" or char == "\"") then
                if (inString) then
                    arguments[#arguments + 1] = curString
                    curString = ""
                    inString = false
                else
                    inString = true
                end
            elseif (inString) then
                curString = curString .. char
            elseif (char == delimiter and curString ~= "" and not inString) then
                arguments[#arguments + 1] = curString
                curString = ""
            elseif (char ~= " " and char ~= delimiter) then
                curString = curString .. char
            end
        end

        if (curString ~= "") then
            arguments[#arguments + 1] = curString
        end

        return arguments
    end

    local targetPrefix = "#"
    local targets = {}

    targets["this"] = function(client)
        local target = client:GetEyeTraceNoCursor().Entity
        if (IsValid(target) and target:IsPlayer()) then return target end
    end

    targets["all"] = function(client) return player.GetAll() end

    targets["alive"] = function(client)
        local target = {}

        for k, v in pairs(player.GetAll()) do
            if (v:Alive()) then
                target[#target + 1] = v
            end
        end

        return target
    end

    targets["dead"] = function(client)
        local target = {}

        for k, v in pairs(player.GetAll()) do
            if (not v:Alive()) then
                target[#target + 1] = v
            end
        end

        return target
    end

    targets["rand"] = function(client) return table.Random(player.GetAll()) end
    targets["random"] = targets["rand"]
    targets["me"] = function(client) return client end
    targets["last"] = function(client) return client.modLastTarget end

    local function GetTargeter(client, info)
        local prefix
        local targetSub 
        if (utf8) then
            prefix = string.utf8sub(info, 1, 1)
            targetSub = string.utf8sub(info:lower(), 2)
        else
            prefix = info:sub(1, 1)
            targetSub = info:lower():sub(2)
        end

        if (info and prefix == targetPrefix) then
            local targeter = targetSub:match("([_%w]+)")
            local result = targets[targeter]

            if (result) then
                return result(client)
            elseif (targeter) then
                local players = {}

                for k, v in pairs(player.GetAll()) do
                    if (moderator.StringMatches(v:GetNWString("usergroup", "user"), targeter)) then
                        players[#players + 1] = v
                    end
                end

                if (#players > 0) then return players end
            end
        end
    end

    function moderator.FindCommandTable(command)
        local commandTable = moderator.commands[command]
        local alias

        if (not commandTable) then
            local aliases = {}

            for k, v in pairs(moderator.commands) do
                if (v.aliases) then
                    for k2, v2 in pairs(v.aliases) do
                        aliases[v2] = k
                    end
                end
            end

            if (aliases[command]) then
                alias = command
            end

            command = aliases[command]
            commandTable = moderator.commands[command]
        end

        return commandTable, command, alias
    end

    function moderator.ParseCommand(client, command, arguments)
        local commandTable, command, alias = moderator.FindCommandTable(command)

        if (commandTable) then
            if (not moderator.HasPermission(command, client)) then return false, "you are not allowed to use this command" end
            arguments = moderator.GetArguments(arguments, commandTable.noArrays)
            local target
            local targetIsArgument

            if (not commandTable.noTarget) then
                target = arguments[1]

                if (type(target) == "table") then
                    for i = 1, #target do
                        local name = target[i]
                        if (type(name) ~= "string") then continue end
                        local result = GetTargeter(client, name)

                        if (result) then
                            if (type(result) == "table") then
                                target[i] = nil
                                table.Add(target, result)
                                continue
                            else
                                target[i] = result
                                continue
                            end
                        end

                        local found = moderator.FindPlayerByName(name, nil, commandTable.findLimit)

                        if (IsValid(found) and moderator.HasInfluence(client, found, commandTable.strictTargetting)) then
                            target[i] = found
                        else
                            target[i] = nil
                        end
                    end

                    if (table.Count(target) == 0) then
                        if (commandTable.targetIsOptional) then
                            targetIsArgument = true
                        else
                            return false, "you are not allowed to target any of these players"
                        end
                    end
                elseif (target) then
                    local result = GetTargeter(client, target)

                    if (result) then
                        target = result
                    else
                        target = moderator.FindPlayerByName(target, nil, commandTable.findLimit)
                    end

                    if (type(target) == "table") then
                        for k, v in pairs(target) do
                            if (not moderator.HasInfluence(client, v, commandTable.strictTargetting)) then
                                target[k] = nil
                            end
                        end

                        if (table.Count(target) == 0) then
                            if (commandTable.targetIsOptional) then
                                targetIsArgument = true
                            else
                                return false, "you are not allowed to target any of these players"
                            end
                        end
                    else
                        if (IsValid(target)) then
                            if (not moderator.HasInfluence(client, target, commandTable.strictTargetting)) then return false, "you are not allowed to target this player" end
                        elseif (not commandTable.targetIsOptional) then
                            return false, "you provided an invalid player"
                        end
                    end
                elseif (not commandTable.targetIsOptional) then
                    return false, "you provided an invalid player"
                end

                if (not targetIsArgument) then
                    table.remove(arguments, 1)
                end
            end

            moderator.RunCommand(client, command, arguments, target, alias)
        else
            return false, "you have entered an invalid command"
        end

        return true
    end

    function moderator.RunCommand(client, command, arguments, target, alias)
        local commandTable = moderator.commands[command]

        if (commandTable) then
            if (not moderator.HasPermission(command, client)) then return moderator.Notify(client, "you are not allowed to do that.") end

            if (IsValid(client) and client:GetInfoNum("mod_clearoncommand", 1) > 0) then
                client:ConCommand("mod_clearselected")
            end

            local result, message = commandTable:OnRun(client, arguments, target, alias)

            if (IsValid(client)) then
                client.modLastTarget = target
            end

            if (result == false) then
                moderator.Notify(client, message)

                return result, message
            end
        else
            moderator.Notify(client, "you have entered an invalid command.")

            return "you have entered an invalid command"
        end
    end

    function moderator.Print(client, message)
        if (not IsValid(client)) then
            MsgN(message)
        else
            client:PrintMessage(2, message)
        end
    end

    net.Receive("mod_Command", function(length, client)
        local command = net.ReadString()
        local arguments = net.ReadTable()
        local target = net.ReadTable()

        if (#target == 1) then
            target = target[1]
        end

        moderator.RunCommand(client, command, arguments, target)
    end)

    concommand.Add("mod", function(client, command, arguments)
        if (IsValid(client) and arguments[1] == "menu") then return client:ConCommand("mod_menu") end
        local command = arguments[1]
        table.remove(arguments, 1)

        if (command and command ~= "help") then
            command = command:lower()
            local result, message = moderator.ParseCommand(client, command, table.concat(arguments, " "))

            if (message) then
                moderator.Notify(client, message .. ".")
            end
        elseif ((client.modNextHelp or 0) < CurTime()) then
            client.modNextHelp = CurTime() + 5
            local command = arguments[1]

            if (command) then
                local commandTable, command = moderator.FindCommandTable(command:lower())

                if (commandTable) then
                    local usage = commandTable.usage or "[none]"

                    if (not commandTable.usage and not commandTable.noTarget) then
                        usage = "<player> " .. usage
                    end

                    moderator.Print(client, "\n\n [moderator] Command Help for: " .. command)
                    moderator.Print(client, " \t• Name: " .. (commandTable.name or "No name available."))
                    moderator.Print(client, " \t• Description: " .. (commandTable.tip or "No description available."))
                    moderator.Print(client, " \t• Usage: " .. usage)

                    if (commandTable.example) then
                        moderator.Print(client, " \t• Example: " .. commandTable.example)
                    end

                    if (commandTable.aliases) then
                        moderator.Print(client, " \t• Alias" .. (#commandTable.aliases > 0 and "es" or "") .. ": " .. table.concat(commandTable.aliases, ", "))
                    end
                else
                    moderator.Print(client, " [moderator] That command does not exist.")
                end

                return
            end

            moderator.Print(client, [[
       __   __   ___  __       ___  __   __
 |\/| /  \ |  \ |__  |__)  /\   |  /  \ |__)
 |  | \__/ |__/ |___ |  \ /--\  |  \__/ |  \
 Created by Chessnut - Version ]] .. moderator.version .. [[
			]])
            moderator.Print(client, " Command Help:")

            for k, v in SortedPairsByMemberValue(moderator.commands, "name") do
                if (moderator.HasPermission(k, client)) then
                    moderator.Print(client, " " .. k .. "			" .. (v.tip or "No help available."))
                end
            end

            moderator.Print(client, "\n Type 'mod help <command>' to get help with a specific command.\n\n")
        end
    end)
else
    function moderator.SendCommand(command, target, ...)
        if (type(target) ~= "table") then
            target = {target}
        end

        net.Start("mod_Command")
        net.WriteString(command)
        net.WriteTable({...})
        net.WriteTable(target)
        net.SendToServer()
    end
end