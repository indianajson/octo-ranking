--[[
* ----------------------------------------------------------------------- *
              Player Ranking and Matchmaking Script by OctoChris
     https://discord.com/channels/455429604455219211/1273290963099586671
	 	         https://github.com/indianajson/octo-ranking/
* ----------------------------------------------------------------------- *
]]--

--dependencies
local sha = require('scripts/octo-ranking/sha256')
local json = require('scripts/octo-ranking/json')

--defaults
local player_id_ranks = {}
local pvp_areas = {["default"] = false}
local players_in_unranked_matchmaking = {}
local players_in_ranked_matchmaking = {}
local player_challenges = {}
local bbs_type = {}

local function find_in_table(t,v1)
	for i,v2 in pairs(t) do
		if v1 == v2 then
			return i
		end
	end
end

local function load_file(file_path)
	Async.read_file(file_path..".json").and_then(function(value)
		if value ~= "" then
			player_id_ranks = json.decode(value)
			if player_id_ranks ~= nil then
				print("[octo] Matchmaking data loading success.")
			else
				print("[octo] Matchmaking data loading failure.")
				player_id_ranks = {}
			end
		else
			print("[octo] Matchmaking data loading failure.")
		end
	end)
end

local function check_areas()
	local areas = Net.list_areas()
    for i, area_id in next, areas do
        local area_id = tostring(area_id)
		print(Net.get_area_custom_property(area_id, "OctoPVP"))
		if Net.get_area_custom_property(area_id, "OctoPVP") == "true" then
			pvp_areas[area_id] = true
		elseif Net.get_area_custom_property(area_id, "OctoPVP") == "false" then
			pvp_areas[area_id] = false
		else 
			print("The value of OctoPVP in "..area_id.. " is invalid.")
		end
	end
	print(pvp_areas)
end

local function save_file(file_path)
	local json = json.encode(player_id_ranks)
	table.sort(player_id_ranks,function(a,b)
		return a.Points > b.Points
	end)
	local csvdata = "Name,Rank,ELO,Total Games,Wins,Losses"
	for player_id,rank_data in pairs(player_id_ranks) do
		csvdata = csvdata.."\n"..rank_data.Name..","..rank_data.Rank..","..rank_data.Points..","..rank_data.Games..","..rank_data.Win..","..rank_data.Loss
	end
	Async.write_file(file_path..".json",json).and_then(function(value)
		if value then
			print("[octo] Matchmaking data saving success.")
			Async.write_file(file_path..".txt",csvdata).and_then(function(value)
				if value then
					print("[octo] Matchmaking data CSV success.")
				else
					print("[octo] Matchmaking data CSV failure.")
				end
			end)
		else
			print("[octo] Matchmaking data saving failure.")
		end
	end)
end

local function search_rankdata_based_on_name(Name)
	for player_id,rank_data in pairs(player_id_ranks) do
		if rank_data.Secret == Name then
			return player_id,rank_data
		end
	end
end

local function find_nearest_rating_to(player_1_id)
	local target_index = 1
	local target_rating_delta = 0
	local rank_data_1 = player_id_ranks[player_1_id]
	for current_index,player_2_id in pairs(players_in_ranked_matchmaking) do
		local rank_data_2 = player_id_ranks[player_2_id]
		local rating_delta = math.abs(rank_data_1.Points - rank_data_2.Points)
		if target_rating_delta == 0 or rating_delta < target_rating_delta then
			target_rating_delta = rating_delta
			target_index = current_index
		end
	end
	return target_index
end

--start Octo-Ranking
print("[octo] Starting Octo-Ranking")
load_file("scripts/octo-ranking/player_id_ranks")
check_areas()

Net:on("player_connect", function(event)
	if player_id_ranks[event.player_id] == nil then
		local player_id,rank_data = search_rankdata_based_on_name(sha.sha256(Net.get_player_secret(event.player_id)))
		if rank_data ~= nil then
			player_id_ranks[player_id] = nil
			player_id_ranks[event.player_id] = rank_data
		else
			player_id_ranks[event.player_id] = {Secret = sha.sha256(Net.get_player_secret(event.player_id)),Name = Net.get_player_name(event.player_id),Rank = "?",Points = 25000,Games = 0,Win = 0,Loss = 0}
		end
	else
		player_id_ranks[event.player_id].Secret = sha.sha256(Net.get_player_secret(event.player_id))
		player_id_ranks[event.player_id].Name = Net.get_player_name(event.player_id)
	end
	save_file("scripts/octo-ranking/player_id_ranks")
end)

Net:on("board_close", function(event)
	bbs_type[event.player_id] = nil
end)

Net:on("tile_interaction", function(event)
	--If Left Shoulder pressed
	if event.button == 1 then
		local player_id = event.player_id
		if pvp_areas[Net.get_player_area(player_id)] ~= true then return end
		bbs_type[player_id] = "ServerMenu"
		local server_menu = {
			{ id = "Unranked", read = true, title = "Free Battle", author = ""},
			{ id = "Ranked", read = true, title = "Rank Battle: "..(player_id_ranks[player_id].Rank).."/"..(player_id_ranks[player_id].Points), author = ""},
			{ id = "Leaderboard", read = true, title = "View Leaderboard", author = ""},
			{ id = "About Ranking", read = true, title = "About Ranking", author = ""},

		}
		if player_id_ranks[player_id].Games < 5 then
			server_menu = {
				{ id = "Unranked", read = true, title = "Free Battle", author = ""},
				{ id = "Ranked", read = true, title = "Rank Battle: "..(player_id_ranks[player_id].Games).."/5 Games", author = ""},
				{ id = "Leaderboard", read = true, title = "View Leaderboard", author = ""},
				{ id = "About Ranking", read = true, title = "About Ranking", author = ""},

			}
		end
		player_challenges[player_id] = nil
		pcall(function() table.remove(players_in_unranked_matchmaking,find_in_table(players_in_unranked_matchmaking,player_id)) end)
		pcall(function() table.remove(players_in_ranked_matchmaking,find_in_table(players_in_ranked_matchmaking,player_id)) end)
		Net.open_board(player_id,"Matchmaking Settings",{r = 127,g = 127,b = 127},server_menu)
	end 
end)

Net:on("actor_interaction", function(event)
	if event.button == 0 then 
		local player_id = event.player_id
		local actor_id = event.actor_id
		if pvp_areas[Net.get_player_area(player_id)] ~= true then return end
		if not Net.is_player(actor_id) then return end
		bbs_type[player_id] = "ServerMenu"
		local server_menu = {
			--{ id = "Unranked", read = true, title = "Free Battle", author = ""},
			--{ id = "Ranked", read = true, title = "Rank Battle: "..(player_id_ranks[player_id].Rank).."/"..(player_id_ranks[player_id].Points), author = ""},
			{ id = "Challenge1", read = true, title = "Request Battle: "..(Net.get_player_name(actor_id)), author = ""},
			{ id = "Leaderboard", read = true, title = "View Leaderboard", author = ""},
			{ id = "About Ranking", read = true, title = "About Ranking", author = ""},

		}
		if player_id_ranks[player_id].Games < 5 then
			--server_menu[3] = { id = "Ranked", read = true, title = "Rank Battle: "..(player_id_ranks[player_id].Games).."/5 Games", author = ""}
		end
		if player_challenges[actor_id] == player_id and player_challenges[player_id] ~= actor_id then
			server_menu[1] = { id = "Challenge2", read = true, title = "Accept Battle: "..(Net.get_player_name(actor_id)), author = ""}
		end
		player_challenges[player_id] = nil
		pcall(function() table.remove(players_in_unranked_matchmaking,find_in_table(players_in_unranked_matchmaking,player_id)) end)
		pcall(function() table.remove(players_in_ranked_matchmaking,find_in_table(players_in_ranked_matchmaking,player_id)) end)
		local emitter = Net.open_board(player_id,"Matchmaking Request",{r = 127,g = 127,b = 127},server_menu)
		emitter:on("post_selection", function(event)
			if event.post_id == "Challenge1" then
				player_challenges[player_id] = actor_id
				Net.exclusive_player_emote(player_id, actor_id, 7)
			elseif event.post_id == "Challenge2" then
				player_challenges[actor_id] = nil
				Net.initiate_pvp(player_id,actor_id)
			end
		end)
	end 
end)

Net:on("player_disconnect", function(event)
	local player_id = event.player_id
	player_challenges[player_id] = nil
	pcall(function() table.remove(players_in_unranked_matchmaking,find_in_table(players_in_unranked_matchmaking,player_id)) end)
	pcall(function() table.remove(players_in_ranked_matchmaking,find_in_table(players_in_ranked_matchmaking,player_id)) end)
end)

Net:on("player_area_transfer", function(event)
	local player_id = event.player_id
	if pvp_areas[Net.get_player_area(player_id)] ~= true then
		player_challenges[player_id] = nil
		pcall(function() table.remove(players_in_unranked_matchmaking,find_in_table(players_in_unranked_matchmaking,player_id)) end)
		pcall(function() table.remove(players_in_ranked_matchmaking,find_in_table(players_in_ranked_matchmaking,player_id)) end)
	end
end)

Net:on("post_selection", function(event)
	local player_id = event.player_id
	local post_id = event.post_id
	if bbs_type[player_id] ~= "ServerMenu" then return end
	if post_id == "About Ranking" then
		Net.message_player(player_id, "This Server Menu is where you can matchmake with other players and battle. There are two rooms for battle matchmaking; Ranked and Unranked. Ranked matchmaking has both opponents fight with HP forced at 1000. Your ELO rating determines your rank. Your ELO goes up when you win a match and vice versa. If either player quits a ranked battle, neither player's ELO will be affected. Don't leave your matches if you can help it! Free Battle lets you battle with no HP restriction. Have fun!")
	elseif post_id == "RankedLocked" then
		Net.message_player(player_id, "Please set your nickname for Rank Battle. To do this, bring up the pause menu and choose Config.")
	elseif post_id == "Leaderboard" then
		pcall(function() Net.close_bbs(player_id) end)
		local post_index = 0
		local leaderboard = {}
		for player_id,rank_data in pairs(player_id_ranks) do
			if rank_data.Games >= 5 then
				table.insert(leaderboard,rank_data)
			end
		end
		bbs_type[player_id] = "Leaderboard"
		local post_data_array = {}
		for n,rank_data in pairs(leaderboard) do
			post_index = post_index + 1
			local post_data = {}
			post_data.id = tostring(post_index)
			post_data.read = true
			post_data.title = post_index..". "..rank_data.Name.." "..rank_data.Rank.."/"..rank_data.Points
			post_data.author = ""
			table.insert(post_data_array,post_data)
		end
		Async.sleep(0.1).and_then(function(value)
			local emitter = Net.open_board(player_id,"PVP Leaderboard",{r = 127,g = 127,b = 127},post_data_array)
			emitter:on("post_request", function()
				if post_index < #leaderboard then
					post_index = post_index + 1
					local rank_data = leaderboard[post_index]
					local post_data = {{}}
					post_data[1].id = tostring(post_index)
					post_data[1].read = true
					post_data[1].title = post_index..". "..rank_data.Name.." "..rank_data.Rank.."/"..rank_data.Points
					post_data[1].author = ""
					Net.append_posts(player_id, post_data)
				end
			end)
		end)
	elseif post_id == "Ranked" and (find_in_table(players_in_unranked_matchmaking,player_id) == nil and find_in_table(players_in_ranked_matchmaking,player_id) == nil) then
		pcall(function() Net.close_bbs(player_id) end)
		Async.message_player(player_id, "Started ranked matchmaking... open Matchmaking Settings to cancel.").and_then(function(value)
			table.insert(players_in_ranked_matchmaking,player_id)
			if #players_in_ranked_matchmaking >= 2 then
				Async.sleep(4.9).and_then(function(value)
					if #players_in_ranked_matchmaking < 2 then
						while #players_in_ranked_matchmaking > 0 do
							local player_id = table.remove(players_in_ranked_matchmaking,1)
							Net.message_player(player_id, "No other players in matchmaking!")
						end
						return
					end
					local player_ids = {table.remove(players_in_ranked_matchmaking,1)}
					table.insert(player_ids,table.remove(players_in_ranked_matchmaking,find_nearest_rating_to(player_ids[1])))
					local hps = {Net.get_player_max_health(player_ids[1]),Net.get_player_max_health(player_ids[2])}
					for n,player_id in pairs(player_ids) do
						if Net.is_player_battling(player_id) then return end
					end
					for n,player_id in pairs(player_ids) do
						local mhp = 1000
						Net.set_player_max_health(player_id,mhp)
						Net.set_player_health(player_id,mhp)
					end
					Async.sleep(0.1).and_then(function(value)
						Async.initiate_pvp(player_ids[1], player_ids[2]).and_then(function(value)
							if value.ran then
								save_file("scripts/octo-ranking/player_id_ranks")
								return
							end
							local winner = 0
							if value.health > 0 then
								winner = 1
							else
								winner = 2
							end
							for n,player_id in pairs(player_ids) do
								local hp = hps[n]
								player_id_ranks[player_id].Name = Net.get_player_name(player_id)
								player_id_ranks[player_id].Games = player_id_ranks[player_id].Games + 1
								if winner == n then
									player_id_ranks[player_id].Win = player_id_ranks[player_id].Win + 1
								else
									player_id_ranks[player_id].Loss = player_id_ranks[player_id].Loss + 1
								end
								player_id_ranks[player_id].Points = math.ceil(((((player_id_ranks[player_id].Win - player_id_ranks[player_id].Loss) / player_id_ranks[player_id].Games) * 0.5) + 0.5) * 50000)
								if player_id_ranks[player_id].Points < 0 then
									player_id_ranks[player_id].Points = 0
								elseif player_id_ranks[player_id].Points > 50000 then
									player_id_ranks[player_id].Points = 50000
								end
								if player_id_ranks[player_id].Points < 2500 then
									player_id_ranks[player_id].Rank = "D-"
								end
								if player_id_ranks[player_id].Points >= 2500 then
									player_id_ranks[player_id].Rank = "D"
								end
								if player_id_ranks[player_id].Points >= 5000 then
									player_id_ranks[player_id].Rank = "D+"
								end
								if player_id_ranks[player_id].Points >= 7500 then
									player_id_ranks[player_id].Rank = "C-"
								end
								if player_id_ranks[player_id].Points >= 10000 then
									player_id_ranks[player_id].Rank = "C"
								end
								if player_id_ranks[player_id].Points >= 12500 then
									player_id_ranks[player_id].Rank = "C+"
								end
								if player_id_ranks[player_id].Points >= 15000 then
									player_id_ranks[player_id].Rank = "B-"
								end
								if player_id_ranks[player_id].Points >= 17500 then
									player_id_ranks[player_id].Rank = "B"
								end
								if player_id_ranks[player_id].Points >= 20000 then
									player_id_ranks[player_id].Rank = "B+"
								end
								if player_id_ranks[player_id].Points >= 22500 then
									player_id_ranks[player_id].Rank = "A-"
								end
								if player_id_ranks[player_id].Points >= 25000 then
									player_id_ranks[player_id].Rank = "A"
								end
								if player_id_ranks[player_id].Points >= 27500 then
									player_id_ranks[player_id].Rank = "A+"
								end
								if player_id_ranks[player_id].Points >= 30000 then
									player_id_ranks[player_id].Rank = "S-"
								end
								if player_id_ranks[player_id].Points >= 32500 then
									player_id_ranks[player_id].Rank = "S"
								end
								if player_id_ranks[player_id].Points >= 35000 then
									player_id_ranks[player_id].Rank = "S+"
								end
								if player_id_ranks[player_id].Points >= 37500 then
									player_id_ranks[player_id].Rank = "SS"
								end
								if player_id_ranks[player_id].Points >= 40000 then
									player_id_ranks[player_id].Rank = "U"
								end
								if player_id_ranks[player_id].Points >= 42500 then
									player_id_ranks[player_id].Rank = "W"
								end
								if player_id_ranks[player_id].Points >= 45000 then
									player_id_ranks[player_id].Rank = "X"
								end
								if player_id_ranks[player_id].Points >= 47500 then
									player_id_ranks[player_id].Rank = "Z"
								end
								Net.set_player_max_health(player_id, hp)
								Net.set_player_health(player_id, hp)
							end
							save_file("scripts/octo-ranking/player_id_ranks")
						end)
					end)
				end)
			end
		end)
	elseif post_id == "Unranked" and (find_in_table(players_in_unranked_matchmaking,player_id) == nil and find_in_table(players_in_ranked_matchmaking,player_id) == nil) then
		pcall(function() Net.close_bbs(player_id) end)
		Async.message_player(player_id, "Started unranked matchmaking... open Matchmaking Settings to cancel.").and_then(function(value)
			table.insert(players_in_unranked_matchmaking,player_id)
			if #players_in_unranked_matchmaking >= 2 then
				Async.sleep(4.9).and_then(function(value)
					if #players_in_unranked_matchmaking < 2 then
						while #players_in_unranked_matchmaking > 0 do
							local player_id = table.remove(players_in_unranked_matchmaking,1)
							Net.message_player(player_id, "No other players in matchmaking!")
						end
						return
					end
					local player_ids = {table.remove(players_in_unranked_matchmaking,1),table.remove(players_in_unranked_matchmaking,1)}
					for n,player_id in pairs(player_ids) do
						if Net.is_player_battling(player_id) then return end
					end
					Async.sleep(0.1).and_then(function(value)
						Net.initiate_pvp(player_ids[1],player_ids[2])
					end)
				end)
			end
		end)
	end
end)