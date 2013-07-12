-- [[ Ryze script based on iSAC ]] --
-- TODO: seperate ignite/barrier/heal -- ignite damate calc
-- TODO: support exhaust
-- TODO: fix perma show
-- TODO: AA if not orbwalking
-- TODO: finish damaga calc
-- TODO: mana check!!!
-- TODO: Tower Cage
-- TODO: not q during recall
-- TODO: fix drawing kills ingame draws
-- TODO: include iTems if fixxed

if myHero.charName ~= "Ryze" then return end -- check if we have to run the script

require "iSAC" -- include the lib

-- [[ Config ]] --
-- set up all hotkeys
local HK1 = 32 -- Full Combo
local HK2 = string.byte("Y") -- Harass
local HK3 = string.byte("X") -- farm
local HK4 = string.byte("C") -- cage nearest enemy
local HK5 = string.byte("V") -- jungle clearing

-- [[ Variables ]] --
local Orbwalker = iOrbWalker(AARange) -- initialize a orbwalker instance
-- add our four spells to iCaster
local QSpell = iCaster(_Q, 650, SPELL_TARGETED)
local WSpell = iCaster(_W, 625, SPELL_TARGETED)
local ESpell = iCaster(_E, 675, SPELL_TARGETED)
local RSpell = iCaster(_R, nil, SPELL_SELF)
local ts = TargetSelector(TARGET_LOW_HP_PRIORITY, QSpell.range, DAMAGE_MAGIC, true) -- initialize the target selector
local Summoners = iSummoners() -- initialize the summoner spells
local Minions = iMinions(QSpell.range) -- initialize the minion class
local enemyMinions = minionManager(MINION_ENEMY, QSpell.range, player, MINION_SORT_HEALTH_ASC) -- second minion manager, because the iSAC minions are strange; q range
--local items = iTems() -- initialize item class
local levelSequence = {nil,0,3,1,1,4,1,2,1,2,4,2,2,3,3,4,3,3} -- we level the spells that way, first point free
local AARange = myHero.range + GetDistance(myHero.minBBox)
local NearestEnemy = nil

-- [[ Core ]] --
function OnLoad() -- this things happens once the script loads
	Config = scriptConfig("PQRyze - Yet another Ryze script","PQRyze") -- Create a save file

	Config:addParam("fCombo", "Full Combo", SCRIPT_PARAM_ONKEYDOWN, false, HK1) -- full combo
	Config:addParam("harass", "Harass", SCRIPT_PARAM_ONKEYDOWN, false, HK2) -- harass
	Config:addParam("farm", "Farm", SCRIPT_PARAM_ONKEYDOWN, false, HK3) -- farm
	Config:addParam("cage", "Cage nearest enemy", SCRIPT_PARAM_ONKEYDOWN, false, HK4) -- cage
	Config:addParam("jungle", "Jungle clearing", SCRIPT_PARAM_ONKEYDOWN, false, HK5) -- jungle clearing

	Config:addParam("mMarker", "Minion Marker", SCRIPT_PARAM_ONOFF, true) -- marking killable minions
	Config:addParam("orbWalk", "Orb Walking", SCRIPT_PARAM_ONOFF, true) -- orb walking while farming/combo
	Config:addParam("aUlti", "Use Ulti in Full Combo", SCRIPT_PARAM_ONOFF, true) -- decide if ulti should be used in full combo
	Config:addParam("aItems", "Use Items in Full Combo", SCRIPT_PARAM_ONOFF, true) -- decide if items should be used in full combo
	Config:addParam("aSP", "Use Summoner Spells", SCRIPT_PARAM_ONOFF, true) -- decide if summoner spells should be used automatic
	Config:addParam("hwQ", "Harass with Q", SCRIPT_PARAM_ONOFF, true) -- Harass with Q
	Config:addParam("hwE", "Harass with E", SCRIPT_PARAM_ONOFF, true) -- Harass with E
	Config:addParam("hwW", "Harass with W", SCRIPT_PARAM_ONOFF, false) -- Harass with W
	Config:addParam("aSkills", "Auto Level Skills (Requires Reload)", SCRIPT_PARAM_ONOFF, true) -- auto level skills
	Config:addParam("lhQ", "Last hit with Q", SCRIPT_PARAM_ONOFF, true) -- Last hit with Q
	Config:addParam("lhQM", "Last hit until Mana", SCRIPT_PARAM_SLICE, 50, 0, 100, 2)
	Config:addParam("ks", "KS with all Skills", SCRIPT_PARAM_ONOFF, true) -- KS with Q
	Config:addParam("draw", "Draw Circles", SCRIPT_PARAM_ONOFF, true) -- Draw Circles

	-- perma show HK1-5
	Config:permaShow("fCombo")
	Config:permaShow("harass")
	Config:permaShow("farm")
	Config:permaShow("cage")
	Config:permaShow("jungle")

	ts.name = "Ryze" -- don't know if it's needed but it can't hurt
	Config:addTS(ts) -- add target selector

	Orbwalker:addAA() -- enable auto attacks while orbwalking
	Orbwalker.AARange = AARange -- set our range

	if Config.aSkills then -- setup the skill autolevel
		autoLevelSetSequence(levelSequence)
		autoLevelSetFunction(onChoiceFunction) -- add the callback to choose the first skill
	end

	--[[  Item class somehow buggy, need a apple fix
	items:add("DFG", 3128) -- Deathfire Grasp
	items:add("HXG", 3146) -- Hextech Gunblade
	items:add("SE", 3040) -- Seraph's Embrace
	items:add("LIANDRYS", 3151) -- Liandry's Torment
	]]--

	IgniteSlot = ((myHero:GetSpellData(SUMMONER_1).name:find("SummonerDot") and SUMMONER_1) or (myHero:GetSpellData(SUMMONER_2).name:find("SummonerDot") and SUMMONER_2) or nil) -- do we have ignite?

	print(">>PQRyze - Yet another Ryze script loaded<<") -- say hello
end

function OnTick() -- this things happen with every tick of the script
	if Config.aSP then -- use all summoner spells automatic
		Summoners:AutoIgnite()
		Summoners:AutoBarrier()
	end

	ts.range = ESpell.range -- set the range of our spells
	ts:update() -- to update the enemies within the range

	if GetInventoryHaveItem(3040) and (myHero.health / myHero.maxHealth <= 0.3) then CastItem(3040) end -- use serapths embrace

	if not myHero.dead then
		if Config.ks then KS() end -- Get the kill
		if Config.fCombo then FullCombo() end -- run full combo
		if Config.harass then Harass() end -- harass

		if Config.farm then
			Minions:update() -- get the updated minions around us
			Minions:LastHit(AARange) -- and kill them
		end

		if Config.cage then CageNearestEnemy() end -- cage the nearest enemy
		if Config.jungle then ClearJungle() end -- kill jungle mobs with abilities
		if Config.lhQ and not (Config.fCombo or Config.harass or Config.cage or Config.jungle) and (((myHero.mana/myHero.maxMana)*100) >= Config.lhQM) then QLastHit() end -- Q last hit

		if Config.orbWalk and (Config.fCombo or Config.harass or Config.farm or Config.cage or Config.jungle) then Orbwalker:Orbwalk(mousePos, ts.target) end
	end
end

function OnDraw() -- draws awesome circles
	if Config.mMarker then -- mark killable minions
		Minions:update()
		Minions:marker(50, 0xFF80FF00, 5)
	end

	if not myHero.dead and Config.draw then
		-- Draw the circles for our spell ranges
		if QSpell:Ready() then DrawCircle(myHero.x, myHero.y, myHero.z, QSpell.range, 0x80408000) end
		if WSpell:Ready() then DrawCircle(myHero.x, myHero.y, myHero.z, WSpell.range, 0x80408000) end
		if ESpell:Ready() then DrawCircle(myHero.x, myHero.y, myHero.z, ESpell.range, 0x80408000) end

		-- Assign text to the target, "Murder/Kill/Harass him"
		for i=1, heroManager.iCount do
			local Enemy = heroManager:GetHero(i)
			local PossibleDMG = CalculateDMG(Enemy)
			if ValidTarget(Enemy) then
				if (PossibleDMG / 2) >= Enemy.health then
					PrintFloatText(Enemy, 0, "Murder him")
				else if PossibleDMG >= Enemy.health then
					PrintFloatText(Enemy, 0, "Kill him")
				else
					PrintFloatText(Enemy, 0, "Harass him")
				end
			end
		end
	end
end
end

function OnProcessSpell(unit, spell) -- is fired if a spell is used
	Orbwalker:OnProcessSpell(unit, spell) -- helps with the auto attacks
end

function OnSendPacket(packet) -- VIP only, is fired if a packed is send
	--if VIP_USER then Orbwalker:ManualBlock(packet) end
	--if VIP_USER then ManualOrbwalk(packet) end
end

function KS() -- get the kills
	for i=1, heroManager.iCount do
		local killableEnemy = heroManager:GetHero(i)
		if ValidTarget(killableEnemy, QSpell.range) and QSpell:Ready() and (getDmg("Q", killableEnemy, myHero) >= killableEnemy.health) then QSpell:Cast(killableEnemy) end
		if ValidTarget(killableEnemy, ESpell.range) and ESpell:Ready() and (getDmg("E", killableEnemy, myHero) >= killableEnemy.health) then ESpell:Cast(killableEnemy) end
		if ValidTarget(killableEnemy, WSpell.range) and WSpell:Ready() and (getDmg("W", killableEnemy, myHero) >= killableEnemy.health) then WSpell:Cast(killableEnemy) end
	end
end

function FullCombo() -- our full combo
	local cdr = math.abs(myHero.cdr*100) -- our cooldown reduction

	if cdr <= 20 then -- if we have a low cdr
		QSpell:Cast(ts.target)
		if Config.orbWalk then Orbwalker:Orbwalk(mousePos, ts.target) end
		WSpell:Cast(ts.target)
		if Config.orbWalk then Orbwalker:Orbwalk(mousePos, ts.target) end
		ESpell:Cast(ts.target)
		if Config.orbWalk then Orbwalker:Orbwalk(mousePos, ts.target) end
		UseUlti(ts.target)
		if Config.orbWalk then Orbwalker:Orbwalk(mousePos, ts.target) end
	else if cdr > 20 and cdr < 30 then -- if we are in mid game
		QSpell:Cast(ts.target)
		if Config.orbWalk then Orbwalker:Orbwalk(mousePos, ts.target) end
		ESpell:Cast(ts.target)
		if Config.orbWalk then Orbwalker:Orbwalk(mousePos, ts.target) end
		WSpell:Cast(ts.target)
		if Config.orbWalk then Orbwalker:Orbwalk(mousePos, ts.target) end
		UseUlti(ts.target)
		if Config.orbWalk then Orbwalker:Orbwalk(mousePos, ts.target) end
	else -- if we are endgeared
		QSpell:Cast(ts.target)
		if Config.orbWalk then Orbwalker:Orbwalk(mousePos, ts.target) end
		UseUlti(ts.target)
		if Config.orbWalk then Orbwalker:Orbwalk(mousePos, ts.target) end
		WSpell:Cast(ts.target)
		if Config.orbWalk then Orbwalker:Orbwalk(mousePos, ts.target) end
		ESpell:Cast(ts.target)
		if Config.orbWalk then Orbwalker:Orbwalk(mousePos, ts.target) end
	end
end
end

function UseUlti(Unit) -- Checks different situations where it should use ulti
	if ValidTarget(Unit) and Config.aUlti then
		local PossibleDMG = CalculateDMG(ts.target)
		local EnemysInRange = CountEnemyHeroInRange()
		if ((PossibleDMG >= ts.target.health) and ((PossibleDMG /2) <= ts.target.health)) or EnemysInRange >= 2 or (myHero.health / myHero.maxHealth <= 0.5)
			then RSpell:Cast(nil)
		end
	end
end
function Harass()
	-- check with which spells we should harass and fire them
	if Config.hwQ then QSpell:Cast(ts.target) end
	if Config.orbWalk then Orbwalker:Orbwalk(mousePos, ts.target) end
	if Config.hwE then ESpell:Cast(ts.target) end
	if Config.orbWalk then Orbwalker:Orbwalk(mousePos, ts.target) end
	if Config.hwW then WSpell:Cast(ts.target) end
	if Config.orbWalk then Orbwalker:Orbwalk(mousePos, ts.target) end
end

function CageNearestEnemy() -- Credits to NerdyRyze for the base
	-- Find the nearest enemy
	for i=1, heroManager.iCount do
		local Enemy = heroManager:GetHero(i)
        if ValidTarget(NearestEnemy) and ValidTarget(Enemy) then
        	if GetDistance(Enemy) < GetDistance(NearestEnemy) then
            	NearestEnemy = Enemy
            end
    	else
            NearestEnemy = Enemy
    	end
	end

	if myHero:GetDistance(NearestEnemy) <= WSpell.range then WSpell:Cast(NearestEnemy) end -- Cage him
end

function ClearJungle() -- Credits to GloryRyze for the obj list
	for i = 1, objManager.maxObjects do
		local obj = objManager:getObject(i)
		if obj ~= nil and obj.type == "obj_AI_Minion" and obj.name ~= nil then
			if obj.name == "TT_Spiderboss7.1.1"
			or obj.name == "Worm12.1.1"
			or obj.name == "AncientGolem1.1.1"
			or obj.name == "AncientGolem7.1.1"
			or obj.name == "LizardElder4.1.1"
			or obj.name == "LizardElder10.1.1"
			or obj.name == "GiantWolf2.1.3"
			or obj.name == "GiantWolf8.1.3"
			or obj.name == "Wraith3.1.3"
			or obj.name == "Wraith9.1.3"
			or obj.name == "Golem5.1.2"
			or obj.name == "Golem11.1.2" then
				if ValidTarget(obj) then
					QSpell:Cast(obj)
					if Config.orbWalk then Orbwalker:Orbwalk(mousePos, obj) end
					ESpell:Cast(obj)
					if Config.orbWalk then Orbwalker:Orbwalk(mousePos, obj) end
					WSpell:Cast(obj)
					if Config.orbWalk then Orbwalker:Orbwalk(mousePos, obj) end
				end
			end
		end
	end
end

function QLastHit()
	enemyMinions:update() -- get the newest minions
	for index, minion in pairs(enemyMinions.objects) do -- loop through the minions
    	if ValidTarget(minion) and QSpell:Ready() then -- check if q is ready and the minion attackable
        	if minion.health <= getDmg("Q", minion, myHero) then -- check if we do enough dmg
            	QSpell:Cast(minion)	-- kill the minion
            end 
        end
    end
end

function onChoiceFunction() -- our callback function for the ability leveling
	if QSpell.spellData.level < WSpell.spellData.level then
		return 1
	else
		return 2
	end
end

function CalculateDMG(Unit) -- Calculates the damage we could deal to a specific Unit
	local QDamage = getDmg("Q",Unit,myHero)
	local WDamage = getDmg("W",Unit,myHero)
	local EDamage = getDmg("E",Unit,myHero)
	local HitDamage = getDmg("AD",Unit,myHero)
	--[[
	local DFGDamage = (items:Dmg(3128, Unit) or 0)
	local HXGDamage = (items:Dmg(3146, Unit) or 0)
	local LIANDRYSDamage = (items:Dmg(3151, Unit) or 0)
	local PossibleDMG = QDamage+WDamage+EDamage+HitDamage+DFGDamage+HXGDamage+LIANDRYSDamage
	--]]
	local PossibleDMG = QDamage+WDamage+EDamage+HitDamage
		
	return PossibleDMG
end