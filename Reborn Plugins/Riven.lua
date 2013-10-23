class 'Plugin'
if myHero.charName ~= "Riven" then return end

local QData = {Count = 0, Next = 0, Last = 0}
local RData = {Start = 0, Up = false}
local Passive = {Count = 0, Last = 0}
local Skills, Keys, Items, Data, Jungle, Helper, MyHero, Minions, Crosshair, Orbwalker = AutoCarry.Helper:GetClasses()
local enemyLastDistance = {}
local direction_towards = 1
local direction_away = 2

function Plugin:__init()
	PrintChat("PQRiven loaded!")
	for _, Enemy in pairs(Helper.EnemyTable) do
		enemyLastDistance[Enemy.networkID] = 0
	end
end

function Plugin:OnTick()
	Crosshair:SetSkillCrosshairRange(myHero.range + GetDistance(myHero.minBBox) + (self:GetQRadius()*2))
	if myHero:CanUseSpell(_Q) ~= READY and os.clock() > QData.Last + 1 then QData.Count = 0 end
	if Menu.ksR then self:ksR() end
	if Keys.AutoCarry then self:Combo() end
	if Menu.harass and Keys.MixedMode then self:Harass() end
end

function Plugin:GetQRadius()
	if RData.Up then
		if QData.Count == 2 then
			return 112.5
		else
			return 150
		end
	else
		if QData.Count == 2 then
			return 200
		else
			return 162.5
		end
	end
end

function Plugin:Combo()
	local Target = Crosshair:GetTarget()

	if ValidTarget(Target) then
		local Distance = myHero:GetDistance(Target)
		local Radius = self:GetQRadius()

		if Menu.useR then
			if not RData.Up and (Target.health/Target.maxHealth)*100 <= Menu.useRHealth and Passive.Count < 3 then
				CastSpell(_R)
			end
			if RData.Up and myHero:CanUseSpell(_R) == READY and Distance <= 870 and getDmg("R", Target, myHero) >= Target.health then
				CastSpell(_R, Target.x, Target.z)
			end
		end
		local GPDistance = 0
		if myHero:CanUseSpell(_Q) == READY then
			GPDistance = 260
		elseif myHero:CanUseSpell(_W) == READY then
			GPDistance = 250
		end
		if myHero:CanUseSpell(_E) == READY and Distance > 250 and Distance < 325 + GPDistance then
			CastSpell(_E, Target.x, Target.z)
		end
		if myHero:CanUseSpell(_W) == READY and Distance <= 250 and Passive.Count < 3 then
			CastSpell(_W)
		end
		if QData.Next == 0 then QData.Next = Orbwalker:GetNextAttackTime() end
		local enemyDirection = self:EnemyDirection(Target)
		if enemyDirection == direction_away and Distance > 200 and myHero:CanUseSpell(_E) ~= READY and myHero:CanUseSpell(_W) ~= READY then
			if Distance <= 260 then
				CastSpell(_Q, Target.x, Target.z)
			end
		else
			if Orbwalker:IsAfterAttack() and Distance <= 260 and Passive.Count < 3 and GetTickCount() > QData.Next then
				CastSpell(_Q, Target.x, Target.z)
				QData.Next = Orbwalker:GetNextAttackTime()
			end
		end
	end
end

function Plugin:Harass()
	local Target = Crosshair:GetTarget()

	if ValidTarget(Target) then
		local Distance = myHero:GetDistance(Target)
		local GPDistance = (myHero:CanUseSpell(_W) == READY and 250 or 0)

		if myHero:CanUseSpell(_E) == READY and Distance > 250 and Distance < 325 + GPDistance then
			CastSpell(_E, Target.x, Target.z)
		end
		if myHero:CanUseSpell(_W) == READY and Distance <= 250 then
			CastSpell(_W)
		end
	end
end

function Plugin:ksR()
	if myHero:CanUseSpell(_R) == READY then
		for _, Enemy in pairs(Helper.EnemyTable) do
			if ValidTarget(Enemy, 870) and getDmg("R", Enemy, myHero) >= Enemy.health then
				if RData.Up and myHero:CanUseSpell(_R) == READY then
					CastSpell(_R, Enemy.x, Enemy.z)
				else
					CastSpell(_R)
				end
			end
		end
	end
end

AdvancedCallback:bind('OnGainBuff', function(unit, buff)
	if unit.isMe then
		if buff.name == "rivenpassiveaaboost" then
			Passive.Count = buff.stack
			Passive.Last = GetTickCount()
		elseif buff.name == "RivenFengShuiEngine" then
			RData.Start = os.clock()
			RData.Up = true
		elseif buff.name == "riventricleavesoundone" then
			QData.Count = 1
			QData.Last = os.clock()
		elseif buff.name == "riventricleavesoundtwo" then
			QData.Count = 2
			QData.Last = os.clock()
		elseif buff.name == "riventricleavesoundthree" then
			QData.Count = 3
			QData.Last = os.clock()
		end
	end
end)

AdvancedCallback:bind('OnUpdateBuff', function(unit, buff)
	if unit.isMe then
		if buff.name == "rivenpassiveaaboost" then
			Passive.Count = buff.stack
			Passive.Last = GetTickCount()
		end
	end
end)

AdvancedCallback:bind('OnLoseBuff', function(unit, buff)
	if unit.isMe then
		if buff.name == "rivenpassiveaaboost" then
			Passive.Count = 0
			Passive.Last = GetTickCount()
		elseif buff.name == "RivenFengShuiEngine" then
			RData.Up = false
		end
	end
end)

function Plugin:GetEnemyLastDistance(enemy)
	if enemy and not enemy.dead then
		return enemyLastDistance[enemy.networkID]
	end

	return false
end

function Plugin:UpdateEnemyDistance(enemy)
	if enemy and not enemy.dead then
		enemyLastDistance[enemy.networkID] = myHero:GetDistance(enemy)
	end
end

function Plugin:EnemyDirection(enemy)
	if enemy and not enemy.dead then
		local lastDistance = self:GetEnemyLastDistance(enemy)
		local currentDistance = myHero:GetDistance(enemy)

		if currentDistance then
			self:UpdateEnemyDistance(enemy)
		end

		if currentDistance < lastDistance then
			return direction_towards
		elseif currentDistance > lastDistance then
			return direction_away
		end
	end

	return false
end

Menu = AutoCarry.Plugins:RegisterPlugin(Plugin(), "PQRiven")
Menu:addParam("harass", "Harass in Mixed Mode", SCRIPT_PARAM_ONKEYTOGGLE, true, GetKey("Y"))
Menu:addParam("useR", "Use R in Combo", SCRIPT_PARAM_ONOFF, true)
Menu:addParam("useRHealth", "Activate R at % enemy hp", SCRIPT_PARAM_SLICE, 60, 0, 100, 0)
Menu:addParam("ksR", "KS with R", SCRIPT_PARAM_ONOFF, true)