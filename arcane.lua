local bxhnz7tp5bge7wvu = bxhnz7tp5bge7wvu_interface
local SB = s2e6mafdoivyb5x4

--actions.precombat+=/variable,name=aoe_target_count,op=reset,default=3
local aoe_target_count = 3
local aoe_cooldown_phase = false
local blast_below_gcd = false
--actions.precombat+=/variable,name=belor_extended_opener,default=0,op=set,if=variable.belor_extended_opener=1,value=equipped.belorrelos_the_suncaller
local belor_extended_opener = false
local balefire_double_on_use = false
local equipped_belorrelos_the_suncaller = false
local mirror_double_on_use = false
local set_bonus_tier30_4pc = false
local steroid_trinket_equipped = false

local function in_boss_fight()
  local boss_units = { "boss1", "boss2", "boss3", "boss4", "boss5" }
  for _, unit in ipairs( boss_units ) do
    local guid = UnitGUID(unit)
    if guid then
      return true
    end
  end
  return false
end

local function equipted_item(item_id, slot_id)
  local equipted_item_id = GetInventoryItemID("player", slot_id)
  return equipted_item_id == item_id
end

local function equipted_item_ready(item_id, slot_id)
  local start, duration, enable = GetInventoryItemCooldown("player", slot_id)
  return enable == 1 and start == 0 and equipted_item(item_id, slot_id)
end

local function mana_gem_charges()
  return GetItemCount(36799) == 1
end

local bloodlust_buffs = { 32182, 90355, 80353, 2825, 146555 }
local function has_bloodlust(unit)
  for i = 1, #bloodlust_buffs do
    if unit.buff(bloodlust_buffs[i]).up then return true end
  end
end

local function haste_mod()
  local haste = UnitSpellHaste("player")
  return 1 + haste / 100
end

local function gcd_duration()
  return 1.5 / haste_mod()
end

local function gcd_max()
  return gcd_duration()
end

function IsSpellTalented(spellID) -- this could be made to be a lot more efficient, if you already know the relevant nodeID and entryID
    local configID = C_ClassTalents.GetActiveConfigID()
    if configID == nil then return end

    local configInfo = C_Traits.GetConfigInfo(configID)
    if configInfo == nil then return end

    for _, treeID in ipairs(configInfo.treeIDs) do -- in the context of talent trees, there is only 1 treeID
        local nodes = C_Traits.GetTreeNodes(treeID)
        for i, nodeID in ipairs(nodes) do
            local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
            for _, entryID in ipairs(nodeInfo.entryIDsWithCommittedRanks) do -- there should be 1 or 0
                local entryInfo = C_Traits.GetEntryInfo(configID, entryID)
                if entryInfo and entryInfo.definitionID then
                    local definitionInfo = C_Traits.GetDefinitionInfo(entryInfo.definitionID)
                    if definitionInfo.spellID == spellID then
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function is_available(spell)
  return IsSpellKnownOrOverridesKnown(spell) or IsPlayerSpell(spell) or IsSpellTalented(spell)
end

local function has_buff_to_steal_or_purge(unit)
  local has_buffs = false
  for i=1,40 do 
    local name,_,_,_,_,_,_,can_steal_or_purge = UnitAura(unit.unitID, i)
    if name and can_steal_or_purge then
      has_buffs = true
      break
    end
  end
  return has_buffs
end

local function gcd()
end

local function combat()
  local healing_potion = bxhnz7tp5bge7wvu.settings.fetch('arcane_nikopol_healing_potion', false)
  local trinket_13 = bxhnz7tp5bge7wvu.settings.fetch('arcane_nikopol_trinket_13', false)
  local trinket_14 = bxhnz7tp5bge7wvu.settings.fetch('arcane_nikopol_trinket_14', false)
  local main_hand = bxhnz7tp5bge7wvu.settings.fetch('arcane_nikopol_main_hand', false)
  local in_boss_fight = in_boss_fight()
  local raid_boss_or_die_in_8_seconds = in_boss_fight and IsInRaid() or target.time_to_die > 8

  local nether_tempest_and_arcane_echo = is_available(SB.NetherTempest) and is_available(SB.ArcaneEcho) and 1 or 0
  mirror_double_on_use = ( equipted_item(SB.MirrorofFracturedTomorrows, 13) or equipted_item(SB.MirrorofFracturedTomorrows, 14) ) and ( equipted_item(SB.AshesoftheEmbersoul, 13) or equipted_item(SB.AshesoftheEmbersoul, 14) )
  balefire_double_on_use = ( equipted_item(SB.AshesoftheEmbersoul, 13) or equipted_item(SB.AshesoftheEmbersoul, 14) ) and ( equipted_item(SB.BalefireBranch, 13) or equipted_item(SB.BalefireBranch, 14) )
  equipped_belorrelos_the_suncaller = equipted_item(SB.BelorrelostheSuncaller, 13) or equipted_item(SB.BelorrelostheSuncaller, 14)
  steroid_trinket_equipped = ( equipted_item(SB.MirrorofFracturedTomorrows, 13) or equipted_item(SB.MirrorofFracturedTomorrows, 14) ) or ( equipted_item(SB.AshesoftheEmbersoul, 13) or equipted_item(SB.AshesoftheEmbersoul, 14) ) or ( equipted_item(SB.BalefireBranch, 13) or equipted_item(SB.BalefireBranch, 14) )

  if not player.alive then return end

  -- iridal cast
  if player.spell(419278).current then return end
  -- Belor'relos, the Suncaller cast
  if player.spell(422146).current and target.distance >= 10 then
    return macro('/stopcasting')
  end
  if player.spell(422146).current then return end

  if modifier.lshift and castable(SB.DragonsBreath) then
    cancel_queued_spell()
    stopcast()
    return cast_while_casting(SB.DragonsBreath)
  end

  if modifier.lcontrol and castable(SB.BlastWave) then
    cancel_queued_spell()
    stopcast()
    return cast_while_casting(SB.BlastWave)
  end

  if healing_potion and GetItemCooldown(191380) == 0 and player.health.effective < 10 then
    macro('/use Refreshing Healing Potion')
  end

--!gcd.remains&buff.nether_precision.up&mana.pct>30&!buff.arcane_artillery.up
  if player.spell(SB.ArcaneMissiles).current and not ( spell(61304).cooldown == 0 and player.buff(SB.NetherPrecisionBuff).up and player.power.mana.percent > 30 and player.buff(SB.ArcaneArtillery).down ) then 
    return
  end

  if player.spell(SB.Evocation).current or player.spell(SB.ShiftingPower).current then return end
  if SpellIsTargeting() then return end

  if GetCVar("nameplateShowEnemies") == '0' then
    SetCVar("nameplateShowEnemies", 1)
  end

  if GetItemCooldown(5512) == 0 and player.health.effective < 30 then
    macro('/use Healthstone')
  end

  if toggle('dispell', false) and castable(SB.RemoveCurse) and player.dispellable(SB.RemoveCurse) then
    return cast_with_queue(SB.RemoveCurse, player)
  end

--  if modifier.lalt and castable(SB.PrismaticBarrier) then
--    return cast_with_queue(SB.PrismaticBarrier)
--  end

  if modifier.lalt and castable(SB.RingofFrost) then
    return cast_with_queue(SB.RingofFrost, 'ground')
  end

  if toggle('auto_shield', false) and player.buff(SB.PrismaticBarrier).down and castable(SB.PrismaticBarrier) then
    return cast_with_queue(SB.PrismaticBarrier)
  end
  
  local nearest_target = enemies.match(function (unit)
    return unit.alive and unit.combat and unit.distance <= 5
  end)
  
  if not target.exists and nearest_target and nearest_target.name then
    macro('/target ' .. nearest_target.name)
  end

  if target.enemy and target.alive then

    local active_enemies = enemies.count(function (unit)
        return unit.alive and unit.distance >= target.distance - 5 and unit.distance <= target.distance + 5
      end)

    active_enemies = toggle('multitarget', false) and active_enemies or 1

    local function cooldown_phase()
--actions.cooldown_phase=touch_of_the_magi,use_off_gcd=1,if=prev_gcd.1.arcane_barrage
      if target.castable(SB.TouchoftheMagi) and spell(SB.ArcaneBarrage).lastcast then
        return cast_with_queue(SB.TouchoftheMagi, target)
      end

--actions.cooldown_phase+=/shifting_power,if=buff.arcane_surge.down&!talent.radiant_spark
      if castable(SB.ShiftingPower) and player.buff(SB.ArcaneSurgeBuff).down and not is_available(SB.RadiantSpark) then
        return cast_with_queue(SB.ShiftingPower)
      end

--actions.cooldown_phase+=/arcane_orb,if=(cooldown.radiant_spark.ready|(active_enemies>=2&debuff.radiant_spark_vulnerability.down))&buff.arcane_charge.stack<buff.arcane_charge.max_stack
      if castable(SB.ArcaneOrb) and target.distance <= 40 and ( ( spell(SB.RadiantSpark).ready or ( active_enemies >= 2 and target.debuff(SB.RadiantSparkVulnerability).down ) ) and player.power.arcanecharges.actual < player.power.arcanecharges.max ) then
        return cast_with_queue(SB.ArcaneOrb)
      end

--actions.cooldown_phase+=/arcane_missiles,if=variable.opener&buff.clearcasting.react&buff.clearcasting.stack>0&cooldown.radiant_spark.remains<5&buff.nether_precision.down&(!buff.arcane_artillery.up|buff.arcane_artillery.remains<=(gcd.max*6)),interrupt_if=!gcd.remains&mana.pct>30&buff.nether_precision.up&!buff.arcane_artillery.up,interrupt_immediate=1,interrupt_global=1,chain=1
      if target.castable(SB.ArcaneMissiles) and toggle('opener') and player.buff(SB.Clearcasting).up and player.buff(SB.Clearcasting).count > 0 and spell(SB.RadiantSpark).cooldown_without_gcd < 5 and player.buff(SB.NetherPrecisionBuff).down and ( player.buff(SB.ArcaneArtillery).down or player.buff(SB.ArcaneArtillery).remains <= gcd_max() * 6 ) then
        return cast_with_queue(SB.ArcaneMissiles, target)
      end

--actions.cooldown_phase+=/arcane_blast,if=variable.opener&cooldown.arcane_surge.ready&mana.pct>10&buff.siphon_storm.remains>17&!set_bonus.tier30_4pc
      if target.castable(SB.ArcaneBlast) and toggle('opener') and spell(SB.ArcaneSurge).ready and player.power.mana.percent > 10 and player.buff(SB.SiphonStormBuff).remains > 17 and not set_bonus_tier30_4pc then
        return cast_with_queue(SB.ArcaneBlast, target)
      end

--actions.cooldown_phase+=/arcane_missiles,if=cooldown.radiant_spark.ready&buff.clearcasting.react&(talent.nether_precision&(buff.nether_precision.down|buff.nether_precision.remains<gcd.max*3)),interrupt_if=!gcd.remains&mana.pct>30&buff.nether_precision.up&!buff.arcane_artillery.up,interrupt_immediate=1,interrupt_global=1,chain=1
      if target.castable(SB.ArcaneMissiles) and spell(SB.RadiantSpark).ready and player.buff(SB.Clearcasting).up and ( is_available(SB.NetherPrecision) and ( player.buff(SB.NetherPrecisionBuff).down or player.buff(SB.NetherPrecisionBuff).remains < gcd_max() * 3 ) ) then
        return cast_with_queue(SB.ArcaneMissiles, target)
      end

--actions.cooldown_phase+=/radiant_spark
      if target.castable(SB.RadiantSpark) then
        return cast_with_queue(SB.RadiantSpark, target)
      end

--actions.cooldown_phase+=/nether_tempest,if=talent.arcane_echo,line_cd=30
      if target.castable(SB.NetherTempest) and target.debuff(SB.NetherTempest).refreshable and is_available(SB.ArcaneEcho) then
        return cast_with_queue(SB.NetherTempest, target)
      end

--actions.cooldown_phase+=/arcane_surge
      if target.castable(SB.ArcaneSurge) then
        return cast_with_queue(SB.ArcaneSurge, target)
      end

--actions.cooldown_phase+=/wait,sec=0.05,if=prev_gcd.1.arcane_surge,line_cd=15

--actions.cooldown_phase+=/arcane_barrage,if=prev_gcd.1.arcane_surge|prev_gcd.1.nether_tempest|prev_gcd.1.radiant_spark|(active_enemies>=(4-(2*talent.orb_barrage))&debuff.radiant_spark_vulnerability.stack=4&talent.arcing_cleave)
      if castable(SB.ArcaneBarrage) and target.distance < 40 and ( spell(SB.ArcaneSurge).lastcast or spell(SB.NetherTempest).lastcast or spell(SB.RadiantSpark).lastcast or ( active_enemies >= ( 4 - 2 * ( is_available(SB.OrbBarrage) and 1 or 0 ) ) and target.debuff(SB.RadiantSparkVulnerability).count == 4 and is_available(SB.ArcingCleave) ) ) then
        return cast_with_queue(SB.ArcaneBarrage, target)
      end

--actions.cooldown_phase+=/arcane_blast,if=debuff.radiant_spark_vulnerability.stack>0&(debuff.radiant_spark_vulnerability.stack<4|(variable.blast_below_gcd&debuff.radiant_spark_vulnerability.stack=4))
      if target.castable(SB.ArcaneBlast) and target.debuff(SB.RadiantSparkVulnerability).count > 0 and ( target.debuff(SB.RadiantSparkVulnerability).count < 4 or ( blast_below_gcd and target.debuff(SB.RadiantSparkVulnerability).count == 4 ) ) then
        return cast_with_queue(SB.ArcaneBlast, target)
      end

--actions.cooldown_phase+=/presence_of_mind,if=debuff.touch_of_the_magi.remains<=gcd.max
      if castable(SB.PresenceOfMind) and player.buff(SB.PresenceOfMind).down and target.debuff(SB.TouchoftheMagiDebuff).remains <= gcd_max() then
        return cast_with_queue(SB.PresenceOfMind)
      end

--actions.cooldown_phase+=/arcane_blast,if=buff.presence_of_mind.up
      if target.castable(SB.ArcaneBlast) and player.buff(SB.PresenceOfMind).up then
        return cast_with_queue(SB.ArcaneBlast, target)
      end

--actions.cooldown_phase+=/arcane_missiles,if=((buff.nether_precision.down&buff.clearcasting.react)|(buff.clearcasting.stack>2&debuff.touch_of_the_magi.up))&(debuff.radiant_spark_vulnerability.down|(debuff.radiant_spark_vulnerability.stack=4&prev_gcd.1.arcane_blast)),interrupt_if=!gcd.remains&mana.pct>30&buff.nether_precision.up&!buff.arcane_artillery.up,interrupt_immediate=1,interrupt_global=1,chain=1
      if target.castable(SB.ArcaneMissiles) and ( ( player.buff(SB.NetherPrecisionBuff).down and player.buff(SB.Clearcasting).up) or ( player.buff(SB.Clearcasting).count > 2 and target.debuff(SB.TouchoftheMagiDebuff).up) ) and ( target.debuff(SB.RadiantSparkVulnerability).down or ( target.debuff(SB.RadiantSparkVulnerability).count == 4 and spell(SB.ArcaneBlast).lastcast ) ) then
        return cast_with_queue(SB.ArcaneMissiles, target)
      end

--actions.cooldown_phase+=/arcane_blast
      if target.castable(SB.ArcaneBlast) then
        return cast_with_queue(SB.ArcaneBlast, target)
      end
    end

    local function aoe_cooldown_phase_func()
--actions.aoe_cooldown_phase=cancel_buff,name=presence_of_mind,if=prev_gcd.1.arcane_blast&cooldown.arcane_surge.remains>75
      if player.buff(SB.PresenceOfMind).up and spell(SB.ArcaneBlast).lastcast and spell(SB.ArcaneSurge).cooldown > 75 then
        macro('/cancelaura Presence of Mind')
      end

--actions.aoe_cooldown_phase+=/touch_of_the_magi,use_off_gcd=1,if=prev_gcd.1.arcane_barrage
      if target.castable(SB.TouchoftheMagi) and spell(SB.ArcaneBarrage).lastcast then
        return cast_with_queue(SB.TouchoftheMagi, target)
      end

--actions.aoe_cooldown_phase+=/radiant_spark
      if target.castable(SB.RadiantSpark) then
        return cast_with_queue(SB.RadiantSpark, target)
      end

--actions.aoe_cooldown_phase+=/arcane_orb,if=buff.arcane_charge.stack<3,line_cd=1
      if castable(SB.ArcaneOrb) and target.distance <= 40 and player.power.arcanecharges.actual < 3 then
        return cast_with_queue(SB.ArcaneOrb)
      end

--actions.aoe_cooldown_phase+=/nether_tempest,if=talent.arcane_echo,line_cd=15
      if target.castable(SB.NetherTempest) and target.debuff(SB.NetherTempest).refreshable and is_available(SB.ArcaneEcho) then
        return cast_with_queue(SB.NetherTempest, target)
      end

--actions.aoe_cooldown_phase+=/arcane_surge
      if target.castable(SB.ArcaneSurge) then
        return cast_with_queue(SB.ArcaneSurge, target)
      end

--# Waits are used to simulate players allowing radiant spark to increment in stacks
--actions.aoe_cooldown_phase+=/wait,sec=0.05,if=cooldown.arcane_surge.remains>75&prev_gcd.1.arcane_blast&!talent.presence_of_mind,line_cd=15
--actions.aoe_cooldown_phase+=/wait,sec=0.05,if=prev_gcd.1.arcane_surge,line_cd=15
--actions.aoe_cooldown_phase+=/wait,sec=0.05,if=cooldown.arcane_surge.remains<75&debuff.radiant_spark_vulnerability.stack=3&!talent.presence_of_mind,line_cd=15

--actions.aoe_cooldown_phase+=/arcane_barrage,if=cooldown.arcane_surge.remains<75&debuff.radiant_spark_vulnerability.stack=4&!talent.orb_barrage
      if castable(SB.ArcaneBarrage) and target.distance < 40 and spell(SB.ArcaneSurge).cooldown < 75 and target.debuff(SB.RadiantSparkVulnerability).count == 4 and not is_available(SB.OrbBarrage) then
        return cast_with_queue(SB.ArcaneBarrage, target)
      end

--actions.aoe_cooldown_phase+=/arcane_barrage,if=(debuff.radiant_spark_vulnerability.stack=2&cooldown.arcane_surge.remains>75)|(debuff.radiant_spark_vulnerability.stack=1&cooldown.arcane_surge.remains<75)&!talent.orb_barrage
      if castable(SB.ArcaneBarrage) and target.distance < 40 and ( ( target.debuff(SB.RadiantSparkVulnerability).count == 2 and spell(SB.ArcaneSurge).cooldown > 75 ) or ( target.debuff(SB.RadiantSparkVulnerability).count == 1 and spell(SB.ArcaneSurge).cooldown < 75 and not is_available(SB.OrbBarrage) ) ) then
        return cast_with_queue(SB.ArcaneBarrage, target)
      end

--# Optimize orb barrage procs during spark at the cost of vulnerabilities, except at 5 or fewer targets where you arcane blast on the 3rd spark stack if its up and you have charges
--actions.aoe_cooldown_phase+=/arcane_barrage,if=(debuff.radiant_spark_vulnerability.stack=1|debuff.radiant_spark_vulnerability.stack=2|(debuff.radiant_spark_vulnerability.stack=3&active_enemies>5)|debuff.radiant_spark_vulnerability.stack=4)&buff.arcane_charge.stack=buff.arcane_charge.max_stack&talent.orb_barrage
      if castable(SB.ArcaneBarrage) and target.distance < 40 and ( target.debuff(SB.RadiantSparkVulnerability).count == 1 or target.debuff(SB.RadiantSparkVulnerability).count == 2 or ( target.debuff(SB.RadiantSparkVulnerability).count == 3 and active_enemies > 5 ) or target.debuff(SB.RadiantSparkVulnerability).count == 4) and player.power.arcanecharges.actual == player.power.arcanecharges.max and is_available(SB.OrbBarrage) then
        return cast_with_queue(SB.ArcaneBarrage, target)
      end

--actions.aoe_cooldown_phase+=/presence_of_mind
      if castable(SB.PresenceOfMind) and player.buff(SB.PresenceOfMind).down then
        return cast_with_queue(SB.PresenceOfMind)
      end

--actions.aoe_cooldown_phase+=/arcane_blast,if=((debuff.radiant_spark_vulnerability.stack=2|debuff.radiant_spark_vulnerability.stack=3)&!talent.orb_barrage)|(debuff.radiant_spark_vulnerability.remains&talent.orb_barrage)
      if target.castable(SB.ArcaneBlast) and ( ( ( target.debuff(SB.RadiantSparkVulnerability).count == 2 or target.debuff(SB.RadiantSparkVulnerability).count == 3 ) and not is_available(SB.OrbBarrage) ) or (target.debuff(SB.RadiantSpark).up and is_available(SB.OrbBarrage) ) ) then
        return cast_with_queue(SB.ArcaneBlast, target)
      end

--actions.aoe_cooldown_phase+=/arcane_barrage,if=(debuff.radiant_spark_vulnerability.stack=4&buff.arcane_surge.up)|(debuff.radiant_spark_vulnerability.stack=3&buff.arcane_surge.down)&!talent.orb_barrage
      if castable(SB.ArcaneBarrage) and target.distance < 40 and ( ( target.debuff(SB.RadiantSparkVulnerability).count == 4 and player.buff(SB.ArcaneSurgeBuff).up ) or ( target.debuff(SB.RadiantSparkVulnerability).count == 3 and player.buff(SB.ArcaneSurgeBuff).down ) and not is_available(SB.OrbBarrage) ) then
        return cast_with_queue(SB.ArcaneBarrage, target)
      end
    end

    local function aoe_rotation()
--actions.aoe_rotation=shifting_power,if=(!talent.evocation|cooldown.evocation.remains>12)&(!talent.arcane_surge|cooldown.arcane_surge.remains>12)&(!talent.touch_of_the_magi|cooldown.touch_of_the_magi.remains>12)&buff.arcane_surge.down&((!talent.charged_orb&cooldown.arcane_orb.remains>12)|(action.arcane_orb.charges=0|cooldown.arcane_orb.remains>12))&!debuff.touch_of_the_magi.up
      if castable(SB.ShiftingPower) and ( ( not is_available(SB.Evocation) or spell(SB.Evocation).cooldown > 12 ) and ( not is_available(SB.ArcaneSurge) or spell(SB.ArcaneSurge).cooldown > 12 ) and ( not is_available(SB.TouchoftheMagi) or spell(SB.TouchoftheMagi).cooldown > 12 ) and player.buff(SB.ArcaneSurgeBuff).down and ( ( not is_available(SB.ChargedOrb) and spell(SB.ArcaneOrb).cooldown > 12 ) or ( spell(SB.ArcaneOrb).charges == 0 or spell(SB.ArcaneOrb).cooldown > 12 ) ) ) and target.debuff(SB.TouchoftheMagiDebuff).down then
        return cast_with_queue(SB.ShiftingPower)
      end

--actions.aoe_rotation+=/nether_tempest,if=(refreshable|!ticking)&buff.arcane_charge.stack=buff.arcane_charge.max_stack&buff.arcane_surge.down&(active_enemies>6|!talent.orb_barrage)&!debuff.touch_of_the_magi.up
      if castable(SB.NetherTempest) and target.debuff(SB.NetherTempest).refreshable and player.power.arcanecharges.actual == player.power.arcanecharges.max and player.buff(SB.ArcaneSurgeBuff).down and ( active_enemies > 6 or not is_available(SB.OrbBarrage) ) and target.debuff(SB.TouchoftheMagiDebuff).down then
        return cast_with_queue(SB.NetherTempest, target)
      end

--actions.aoe_rotation+=/arcane_missiles,if=buff.arcane_artillery.up&(cooldown.touch_of_the_magi.remains+5)>buff.arcane_artillery.remains
      if target.castable(SB.ArcaneMissiles) and player.buff(SB.ArcaneArtillery).up and spell(SB.TouchoftheMagi).cooldown_without_gcd + 5 > player.buff(SB.ArcaneArtillery).remains then
        return cast_with_queue(SB.ArcaneMissiles, target)
      end

--actions.aoe_rotation+=/arcane_barrage,if=(active_enemies<=4&buff.arcane_charge.stack=3)|buff.arcane_charge.stack=buff.arcane_charge.max_stack|mana.pct<9
      if castable(SB.ArcaneBarrage) and target.distance < 40 and ( active_enemies <= 4 and player.power.arcanecharges.actual == 3 or player.power.arcanecharges.actual == player.power.arcanecharges.max or player.power.mana.percent < 9 ) then
        return cast_with_queue(SB.ArcaneBarrage, target)
      end

--actions.aoe_rotation+=/arcane_orb,if=buff.arcane_charge.stack<2&cooldown.touch_of_the_magi.remains>18
      if castable(SB.ArcaneOrb) and target.distance <= 40 and player.power.arcanecharges.actual < 2 and spell(SB.TouchoftheMagi).cooldown > 18 then
        return cast_with_queue(SB.ArcaneOrb)
      end

--actions.aoe_rotation+=/arcane_explosion
      if castable(SB.ArcaneExplosion) and target.distance <= 10 then
        return cast_with_queue(SB.ArcaneExplosion)
      end
      
      if target.castable(SB.ArcaneBlast) then
        return cast_with_queue(SB.ArcaneBlast, target)
      end
    end

    local function rotation()
--actions.rotation=arcane_orb,if=buff.arcane_charge.stack<3&(buff.bloodlust.down|mana.pct>70)
      if castable(SB.ArcaneOrb) and target.distance <= 40 and player.power.arcanecharges.actual < 3 and ( not has_bloodlust(player) or player.power.mana.percent > 70 ) then
        return cast_with_queue(SB.ArcaneOrb)
      end

--actions.rotation+=/nether_tempest,if=equipped.belorrelos_the_suncaller&trinket.belorrelos_the_suncaller.ready_cooldown&buff.siphon_storm.down&buff.arcane_surge.down&buff.arcane_charge.stack=buff.arcane_charge.max_stack,line_cd=120
      if castable(SB.NetherTempest) and target.debuff(SB.NetherTempest).refreshable and ( equipted_item_ready(SB.BelorrelostheSuncaller, 13) or equipted_item_ready(SB.BelorrelostheSuncaller, 14) ) and player.buff(SB.SiphonStormBuff).down and player.buff(SB.ArcaneSurgeBuff).down and player.power.arcanecharges.actual == player.power.arcanecharges.max then
        return cast_with_queue(SB.NetherTempest, target)
      end

--actions.rotation+=/shifting_power,if=buff.arcane_surge.down&cooldown.arcane_surge.remains>45&fight_remains>15
      if castable(SB.ShiftingPower) and player.buff(SB.ArcaneSurgeBuff).down and spell(SB.ArcaneSurge).cooldown > 45 and target.time_to_die > 15 then
        return cast_with_queue(SB.ShiftingPower)
      end

--actions.rotation+=/nether_tempest,if=(refreshable|!ticking)&buff.arcane_charge.stack=buff.arcane_charge.max_stack&(((buff.temporal_warp.up|mana.pct<10|!talent.shifting_power)&buff.arcane_surge.down)|equipped.neltharions_call_to_chaos)&!variable.opener&fight_remains>=12
      if castable(SB.NetherTempest) and target.debuff(SB.NetherTempest).refreshable and player.power.arcanecharges.actual == player.power.arcanecharges.max and ( has_bloodlust(player) or player.power.mana.percent < 10 or not is_available(SB.ShiftingPower) ) and player.buff(SB.ArcaneSurgeBuff).down and not toggle('opener') and target.time_to_die >= 12 then
        return cast_with_queue(SB.NetherTempest, target)
      end

--actions.rotation+=/arcane_barrage,if=buff.arcane_charge.stack=buff.arcane_charge.max_stack&mana.pct<70&(((cooldown.arcane_surge.remains>30&cooldown.touch_of_the_magi.remains>10)&buff.bloodlust.up&cooldown.touch_of_the_magi.remains>5&fight_remains>30)|(!talent.evocation&fight_remains>20))
      if castable(SB.ArcaneBarrage) and target.distance < 40 and player.power.arcanecharges.actual == player.power.arcanecharges.max and player.power.mana.percent < 70 and ( spell(SB.ArcaneSurge).cooldown > 30 and spell(SB.TouchoftheMagi).cooldown > 10 and has_bloodlust(player) and target.time_to_die > 30 or not is_available(SB.Evocation) and target.time_to_die > 20 ) then
        return cast_with_queue(SB.ArcaneBarrage, target)
      end

--actions.rotation+=/presence_of_mind,if=buff.arcane_charge.stack<3&target.health.pct<35&talent.arcane_bombardment
      if castable(SB.PresenceOfMind) and player.buff(SB.PresenceOfMind).down and player.power.arcanecharges.actual < 3 and target.health.percent < 35 and is_available(SB.ArcaneBombardment) then
        return cast_with_queue(SB.PresenceOfMind)
      end

--actions.rotation+=/arcane_blast,if=(buff.arcane_charge.stack=buff.arcane_charge.max_stack&buff.nether_precision.up)|(talent.time_anomaly&buff.arcane_surge.up&buff.arcane_surge.remains<=6)
      if target.castable(SB.ArcaneBlast) and ( player.power.arcanecharges.actual == player.power.arcanecharges.max and player.buff(SB.NetherPrecisionBuff).up or is_available(SB.TimeAnomaly) and player.buff(SB.ArcaneSurgeBuff).up and player.buff(SB.ArcaneSurgeBuff).remains <= 6 ) then
        return cast_with_queue(SB.ArcaneBlast, target)
      end

--actions.rotation+=/arcane_missiles,if=buff.clearcasting.react&buff.nether_precision.down&(!variable.opener|(equipped.belorrelos_the_suncaller&variable.steroid_trinket_equipped)),interrupt_if=!gcd.remains&buff.nether_precision.up&mana.pct>30&!buff.arcane_artillery.up,interrupt_immediate=1,interrupt_global=1,chain=1
      if target.castable(SB.ArcaneMissiles) and player.buff(SB.Clearcasting).up and player.buff(SB.NetherPrecisionBuff).down and (not toggle('opener') or equipped_belorrelos_the_suncaller and steroid_trinket_equipped) then
        return cast_with_queue(SB.ArcaneMissiles, target)
      end

--actions.rotation+=/arcane_blast
      if target.castable(SB.ArcaneBlast) then
        return cast_with_queue(SB.ArcaneBlast, target)
      end

--actions.rotation+=/arcane_barrage
      if castable(SB.ArcaneBarrage) and target.distance < 40 then
        return cast_with_queue(SB.ArcaneBarrage, target)
      end
    end

    if toggle('spellsteal', false) and target.castable(SB.SpellSteal) and target.dispellable(SB.SpellSteal) then
      return cast_with_queue(SB.SpellSteal, target)
    end

    if toggle('interrupts', false) and target.interrupt(80) and target.castable(SB.Counterspell) then
      cast_with_queue(SB.Counterspell, target)
    end
    
    if player.debuff(SB.Burst).count >= 2 and target.time_to_die < player.debuff(SB.Burst).remains then
      return macro('/stopcasting')
    end

--actions+=/time_warp,if=talent.temporal_warp&buff.exhaustion.up&(cooldown.arcane_surge.ready|fight_remains<=40|(buff.arcane_surge.up&fight_remains<=(cooldown.arcane_surge.remains+14)))
--actions+=/berserking,if=(prev_gcd.1.arcane_surge&!(buff.temporal_warp.up&buff.bloodlust.up))|(buff.arcane_surge.up&debuff.touch_of_the_magi.up)
    if castable(SB.Berserking) and ( ( spell(SB.ArcaneSurge).lastcast and not has_bloodlust(player) ) or ( player.buff(SB.ArcaneSurgeBuff).up and target.debuff(SB.TouchoftheMagiDebuff).up ) ) then
      return cast_with_queue(SB.Berserking)
    end

--# Use trinkets in single target after surge without t30, after touch with t30, and before Surge in AOE, except 20-second trinkets which are used with spark without t30.  Non-steroid trinkets are used whenever you don't have cooldowns active and double steroid trinkets are used in order of power level in sims with max ilevel.
--actions+=/use_items,if=prev_gcd.1.arcane_surge|((active_enemies>=variable.aoe_target_count)&cooldown.arcane_surge.ready&prev_gcd.1.nether_tempest)|fight_remains<=15
--actions+=/use_item,name=timebreaching_talon,if=(((!set_bonus.tier30_4pc&cooldown.arcane_surge.remains<=(gcd.max*4)&cooldown.radiant_spark.remains)|(set_bonus.tier30_4pc&prev_gcd.1.arcane_surge))&(!variable.irideus_double_on_use|!buff.bloodlust.up))|fight_remains<=20|((active_enemies>=variable.aoe_target_count)&cooldown.arcane_surge.ready&prev_gcd.1.nether_tempest)
--actions+=/use_item,name=obsidian_gladiators_badge_of_ferocity,if=((variable.badgebalefire_double_on_use&(debuff.touch_of_the_magi.up|buff.arcane_surge.up|(buff.siphon_storm.up&variable.opener)))|(!variable.badgebalefire_double_on_use&prev_gcd.1.arcane_surge))||fight_remains<=15|((active_enemies>=variable.aoe_target_count)&cooldown.arcane_surge.ready&prev_gcd.1.nether_tempest)

--actions+=/use_item,name=mirror_of_fractured_tomorrows,if=
--((cooldown.arcane_surge.remains<=gcd.max&buff.siphon_storm.remains<20))
--|fight_remains<=20|
--((active_enemies>=variable.aoe_target_count)&cooldown.arcane_surge.ready&prev_gcd.1.nether_tempest)
    if toggle('cooldowns', false) and trinket_13 and equipted_item_ready(SB.MirrorofFracturedTomorrows, 13) and ( ( spell(SB.ArcaneSurge).cooldown_without_gcd <= gcd_max() and player.buff(SB.SiphonStormBuff).remains < 20 ) or target.time_to_die <= 20 or ( active_enemies >= aoe_target_count and spell(SB.ArcaneSurge).ready and spell(SB.NetherTempest).lastcast ) ) and raid_boss_or_die_in_8_seconds then
      return macro('/use 13')
    end

    if toggle('cooldowns', false) and trinket_14 and equipted_item_ready(SB.MirrorofFracturedTomorrows, 14) and ( ( spell(SB.ArcaneSurge).cooldown_without_gcd <= gcd_max() and player.buff(SB.SiphonStormBuff).remains < 20 ) or target.time_to_die <= 20 or ( active_enemies >= aoe_target_count and spell(SB.ArcaneSurge).ready and spell(SB.NetherTempest).lastcast ) ) and raid_boss_or_die_in_8_seconds then
      return macro('/use 14')
    end

--actions+=/use_item,name=balefire_branch,if=
--(buff.siphon_storm.up&((buff.siphon_storm.remains<15&variable.balefire_double_on_use)|(buff.siphon_storm.remains<20&!variable.balefire_double_on_use))
--  &(cooldown.arcane_surge.remains<10|buff.arcane_surge.up)
--  &(debuff.touch_of_the_magi.remains>8|cooldown.touch_of_the_magi.remains<8))
--|fight_remains<=15|((active_enemies>=variable.aoe_target_count)&((cooldown.arcane_surge.ready&prev_gcd.1.nether_tempest)|buff.siphon_storm.remains>15))
    if toggle('cooldowns', false) and trinket_13 and equipted_item_ready(SB.BalefireBranch, 13) and ( ( player.buff(SB.SiphonStormBuff).up and ( player.buff(SB.SiphonStormBuff).remains < 15 and balefire_double_on_use or player.buff(SB.SiphonStormBuff).remains < 20 and not balefire_double_on_use ) and ( spell(SB.ArcaneSurge).cooldown < 10 or player.buff(SB.ArcaneSurgeBuff).up ) and ( target.debuff(SB.TouchoftheMagiDebuff).remains > 8 or spell(SB.TouchoftheMagi).cooldown < 8 ) ) or target.time_to_die <= 15 or ( active_enemies >= aoe_target_count and ( spell(SB.ArcaneSurge).ready and spell(SB.NetherTempest).lastcast or player.buff(SB.SiphonStormBuff).remains > 15 ) ) ) and raid_boss_or_die_in_8_seconds then
      return macro('/use 13')
    end

    if toggle('cooldowns', false) and trinket_14 and equipted_item_ready(SB.BalefireBranch, 14) and ( ( player.buff(SB.SiphonStormBuff).up and ( player.buff(SB.SiphonStormBuff).remains < 15 and balefire_double_on_use or player.buff(SB.SiphonStormBuff).remains < 20 and not balefire_double_on_use ) and ( spell(SB.ArcaneSurge).cooldown < 10 or player.buff(SB.ArcaneSurgeBuff).up ) and ( target.debuff(SB.TouchoftheMagiDebuff).remains > 8 or spell(SB.TouchoftheMagi).cooldown < 8 ) ) or target.time_to_die <= 15 or ( active_enemies >= aoe_target_count and ( spell(SB.ArcaneSurge).ready and spell(SB.NetherTempest).lastcast or player.buff(SB.SiphonStormBuff).remains > 15 ) ) ) and raid_boss_or_die_in_8_seconds then
      return macro('/use 14')
    end

--actions+=/use_item,name=ashes_of_the_embersoul,if=
--(prev_gcd.1.arcane_surge&!equipped.belorrelos_the_suncaller&(!variable.mirror_double_on_use|!variable.opener)&(!variable.balefire_double_on_use|!variable.opener))
--|fight_remains<=20
--|((active_enemies>=variable.aoe_target_count)&cooldown.arcane_surge.ready&prev_gcd.1.nether_tempest)
--|(equipped.belorrelos_the_suncaller&(buff.arcane_surge.remains>12|(prev_gcd.1.arcane_surge&variable.opener))&cooldown.evocation.remains>60)
    if toggle('cooldowns', false) and trinket_13 and equipted_item_ready(SB.AshesoftheEmbersoul, 13) and ( ( spell(SB.ArcaneSurge).lastcast and not equipped_belorrelos_the_suncaller and ( not mirror_double_on_use or not toggle('opener') ) and ( not balefire_double_on_use or not toggle('opener') ) ) or target.time_to_die <= 20 or ( active_enemies >= aoe_target_count and spell(SB.ArcaneSurge).ready and spell(SB.NetherTempest).lastcast ) or ( equipped_belorrelos_the_suncaller and ( player.buff(SB.ArcaneSurgeBuff).remains > 12 or spell(SB.ArcaneSurge).lastcast and toggle('opener') ) and spell(SB.Evocation).cooldown > 60 ) ) and raid_boss_or_die_in_8_seconds then
      return macro('/use 13')
    end

    if toggle('cooldowns', false) and trinket_14 and equipted_item_ready(SB.AshesoftheEmbersoul, 14) and ( ( spell(SB.ArcaneSurge).lastcast and not equipped_belorrelos_the_suncaller and ( not mirror_double_on_use or not toggle('opener') ) and ( not balefire_double_on_use or not toggle('opener') ) ) or target.time_to_die <= 20 or ( active_enemies >= aoe_target_count and spell(SB.ArcaneSurge).ready and spell(SB.NetherTempest).lastcast ) or ( equipped_belorrelos_the_suncaller and ( player.buff(SB.ArcaneSurgeBuff).remains > 12 or spell(SB.ArcaneSurge).lastcast and toggle('opener') ) and spell(SB.Evocation).cooldown > 60 ) ) and raid_boss_or_die_in_8_seconds then
      return macro('/use 14')
    end

--actions+=/use_item,name=nymues_unraveling_spindle,if=(((!variable.opener&!set_bonus.tier30_4pc&cooldown.arcane_surge.remains<=(gcd.max*4)&cooldown.radiant_spark.ready)|(set_bonus.tier30_4pc&cooldown.arcane_surge.remains<=(gcd.max*4)&cooldown.radiant_spark.ready)|(variable.opener&!set_bonus.tier30_4pc&(mana<=variable.opener_min_mana|buff.siphon_storm.remains<19)))&(!variable.mirror_double_on_use|!buff.bloodlust.up)&(!variable.balefire_double_on_use|!buff.bloodlust.up)&(!variable.ashes_double_on_use|!buff.bloodlust.up))|fight_remains<=24|((active_enemies>=variable.aoe_target_count)&cooldown.arcane_surge.ready&prev_gcd.1.nether_tempest)|(equipped.belorrelos_the_suncaller&cooldown.touch_of_the_magi.remains<(gcd.max*6))


--actions+=/use_item,name=belorrelos_the_suncaller,use_off_gcd=1,if=gcd.remains&!dot.radiant_spark.remains&(!variable.steroid_trinket_equipped|(buff.siphon_storm.down|equipped.nymues_unraveling_spindle))
    if toggle('cooldowns', false) and trinket_13 and equipted_item_ready(SB.BelorrelostheSuncaller, 13) and target.distance < 10 and target.debuff(SB.RadiantSpark).down and player.buff(SB.SiphonStormBuff).down and target.time_to_die > 4 then
      return macro('/use 13')
    end

    if toggle('cooldowns', false) and trinket_14 and equipted_item_ready(SB.BelorrelostheSuncaller, 14) and target.distance < 10 and target.debuff(SB.RadiantSpark).down and player.buff(SB.SiphonStormBuff).down and target.time_to_die > 4 then
      return macro('/use 14')
    end

--actions+=/use_item,name=dreambinder_loom_of_the_great_cycle
--actions+=/use_item,name=iridal_the_earths_master,use_off_gcd=1,if=gcd.remains
    if main_hand and equipted_item_ready(208321, 16) and target.health.percent < 35 then
      return macro('/use 16')
    end

--actions+=/variable,name=aoe_cooldown_phase,op=set,value=1,if=active_enemies>=variable.aoe_target_count&(action.arcane_orb.charges>0|buff.arcane_charge.stack>=3)&(cooldown.radiant_spark.ready|!talent.radiant_spark)&(cooldown.touch_of_the_magi.remains<=(gcd.max*2)|!talent.touch_of_the_magi)
    if toggle('cooldowns', false) and active_enemies >= aoe_target_count and ( spell(SB.ArcaneOrb).charges > 0 or player.power.arcanecharges.actual >= 3 ) and spell(SB.RadiantSpark).ready and raid_boss_or_die_in_8_seconds and spell(SB.TouchoftheMagi).cooldown_without_gcd <= gcd_max() * 2 then
      aoe_cooldown_phase = true
    end

--actions+=/variable,name=aoe_cooldown_phase,op=set,value=0,if=variable.aoe_cooldown_phase&((debuff.radiant_spark_vulnerability.down&dot.radiant_spark.remains<7&cooldown.radiant_spark.remains)|!talent.radiant_spark&debuff.touch_of_the_magi.up)
    if aoe_cooldown_phase and target.debuff(SB.RadiantSparkVulnerability).down and target.debuff(SB.RadiantSpark).remains < 7 and spell(SB.RadiantSpark).cooldown_without_gcd > gcd_max() then
      aoe_cooldown_phase = false
    end

--actions+=/variable,name=opener,op=set,if=debuff.touch_of_the_magi.up&variable.opener,value=0
    if target.debuff(SB.TouchoftheMagiDebuff).up and toggle('opener') then
      button_toggle_off('opener')
    end
--actions+=/variable,name=blast_below_gcd,op=set,value=action.arcane_blast.cast_time<gcd.max
    blast_below_gcd = spell(SB.ArcaneBlast).castingtime < gcd_max()

--# Cancel Evo if we have enough mana and don't have Siphon Storm talented or if the fight duration is running out
--actions+=/cancel_action,if=action.evocation.channeling&mana.pct>=95&!talent.siphon_storm
--actions+=/cancel_action,if=action.evocation.channeling&(mana.pct>fight_remains*4)&!(fight_remains>10&cooldown.arcane_surge.remains<1)

--actions+=/arcane_barrage,if=fight_remains<2
    if castable(SB.ArcaneBarrage) and target.distance < 40 and target.boss and target.time_to_die < 2 then
      return cast_with_queue(SB.ArcaneBarrage, target)
    end

--actions+=/evocation,if=buff.arcane_surge.down&debuff.touch_of_the_magi.down&((mana.pct<10&cooldown.touch_of_the_magi.remains<20)|cooldown.touch_of_the_magi.remains<15)&((buff.bloodlust.remains<31&buff.bloodlust.up)|!variable.belor_extended_opener|!variable.opener)
    if toggle('cooldowns', false) and castable(SB.Evocation) and player.buff(SB.ArcaneSurgeBuff).down and target.debuff(SB.TouchoftheMagiDebuff).down and ( ( player.power.mana.percent < 10 and spell(SB.TouchoftheMagi).cooldown < 20 ) or spell(SB.TouchoftheMagi).cooldown < 15 ) and ( has_bloodlust(player) or not belor_extended_opener or not toggle('opener') ) and raid_boss_or_die_in_8_seconds then
      return cast_with_queue(SB.Evocation)
    end

--# Make a new gem if the encounter is long enough and use it after surge to recoup mana quickly
--actions+=/conjure_mana_gem,if=debuff.touch_of_the_magi.down&buff.arcane_surge.down&cooldown.arcane_surge.remains<30&cooldown.arcane_surge.remains<fight_remains&!mana_gem_charges
    if castable(SB.ConjureManaGem) and target.debuff(SB.TouchoftheMagiDebuff).down and player.buff(SB.ArcaneSurgeBuff).down and spell(SB.ArcaneSurge).cooldown < 30 and spell(SB.ArcaneSurge).cooldown_without_gcd < target.time_to_die and not mana_gem_charges() then
      return cast_with_queue(SB.ConjureManaGem)
    end

--actions+=/use_mana_gem,if=talent.cascading_power&buff.clearcasting.stack<2&buff.arcane_surge.up
    if mana_gem_charges() and GetItemCooldown(36799) == 0 and player.power.mana.percent < 100 and is_available(SB.CascadingPower) and player.buff(SB.Clearcasting).count < 2 and player.buff(SB.ArcaneSurgeBuff).up then
      return macro('/use Mana Gem')
    end

--actions+=/use_mana_gem,if=!talent.cascading_power&prev_gcd.1.arcane_surge
    if mana_gem_charges() and GetItemCooldown(36799) == 0 and player.power.mana.percent < 100 and not is_available(SB.CascadingPower) and spell(SB.ArcaneSurge).lastcast then
      return macro('/use Mana Gem')
    end

--# Enter cooldown phase when cds are available or coming off cooldown otherwise default to rotation priority
--actions+=/call_action_list,name=cooldown_phase,if=(cooldown.arcane_surge.remains<=(gcd.max*(1+(talent.nether_tempest&talent.arcane_echo)))|(buff.arcane_surge.remains>(3*(set_bonus.tier30_2pc&!set_bonus.tier30_4pc)))|buff.arcane_overload.up)&cooldown.evocation.remains>45&((cooldown.touch_of_the_magi.remains<gcd.max*4)|cooldown.touch_of_the_magi.remains>20)&active_enemies<variable.aoe_target_count
    if toggle('cooldowns', false) and ( spell(SB.ArcaneSurge).cooldown_without_gcd <= gcd_max() * ( 1 + nether_tempest_and_arcane_echo ) and raid_boss_or_die_in_8_seconds or player.buff(SB.ArcaneSurgeBuff).remains > 0 or player.buff(SB.ArcaneOverload).up ) and spell(SB.Evocation).cooldown > 45 and ( spell(SB.TouchoftheMagi).cooldown_without_gcd < gcd_max() * 4 or spell(SB.TouchoftheMagi).cooldown > 20 ) and active_enemies < aoe_target_count then
      return cooldown_phase()
    end
--actions+=/call_action_list,name=cooldown_phase,if=cooldown.arcane_surge.remains>30&(cooldown.radiant_spark.ready|dot.radiant_spark.remains|debuff.radiant_spark_vulnerability.up)&(cooldown.touch_of_the_magi.remains<=(gcd.max*3)|debuff.touch_of_the_magi.up)&active_enemies<variable.aoe_target_count
    if toggle('cooldowns', false) and spell(SB.ArcaneSurge).cooldown > 30 and ( spell(SB.RadiantSpark).ready and raid_boss_or_die_in_8_seconds or target.debuff(SB.RadiantSpark).up or target.debuff(SB.RadiantSparkVulnerability).up ) and ( spell(SB.TouchoftheMagi).cooldown_without_gcd <= gcd_max() * 3 or target.debuff(SB.TouchoftheMagiDebuff).up ) and active_enemies < aoe_target_count then
      return cooldown_phase()
    end

--actions+=/call_action_list,name=aoe_cooldown_phase,if=variable.aoe_cooldown_phase&(cooldown.arcane_surge.remains<(gcd.max*4)|cooldown.arcane_surge.remains>40)
    if toggle('cooldowns', false) and aoe_cooldown_phase and ( spell(SB.ArcaneSurge).cooldown_without_gcd < gcd_max() * 4 or spell(SB.ArcaneSurge).cooldown > 40 ) then
      return aoe_cooldown_phase_func()
    end

--actions+=/call_action_list,name=aoe_rotation,if=active_enemies>=variable.aoe_target_count
    if active_enemies >= aoe_target_count then
      return aoe_rotation()
    end

--actions+=/call_action_list,name=rotation
    return rotation()
  end
end

local function resting()
--actions.precombat+=/variable,name=aoe_target_count,op=set,value=9,if=!talent.arcing_cleave
  if not is_available(SB.ArcingCleave) then
    aoe_target_count = 9
  end

--actions.precombat+=/variable,name=aoe_target_count,op=set,value=5,if=talent.arcing_cleave&(!talent.orb_barrage|!talent.arcane_bombardment)
  if is_available(SB.ArcingCleave) and ( not is_available(SB.OrbBarrage) or not is_available(SB.ArcaneBombardment) ) then
    aoe_target_count = 5
  end

  if equipted_item(SB.BelorrelostheSuncaller, 13) or equipted_item(SB.BelorrelostheSuncaller, 14) then
    belor_extended_opener = true
  end

  if not player.alive then return end
  if player.channeling() then return end
  if SpellIsTargeting() then return end

  if toggle('auto_shield', false) and player.buff(SB.PrismaticBarrier).down and castable(SB.PrismaticBarrier) then
    return cast_with_queue(SB.PrismaticBarrier)
  end
end

local function interface()
  local arcane_gui = {
    key = 'arcane_nikopol',
    title = 'arcane',
    width = 250,
    height = 320,
    resize = true,
    show = false,
    template = {
      { type = 'header', text = 'Arcane Settings' },
      { type = 'rule' },   
      { type = 'text', text = 'Healing Settings' },
      { key = 'healing_potion', type = 'checkbox', text = 'Refreshing Healing Potion', desc = 'Use Refreshing Healing Potion when below 10% health', default = false },
      { type = 'rule' },  
      { type = 'text', text = 'Items' },
      { key = 'trinket_13', type = 'checkbox', text = '13', desc = 'use first trinket', default = false },
      { key = 'trinket_14', type = 'checkbox', text = '14', desc = 'use second trinket', default = false },
      { key = 'main_hand', type = 'checkbox', text = '16', desc = 'use main_hand', default = false },
    }
  }

  configWindow = bxhnz7tp5bge7wvu.interface.builder.buildGUI(arcane_gui)

  bxhnz7tp5bge7wvu.interface.buttons.add_toggle({
      name = 'dispell',
      label = 'Auto Dispell',
      on = {
        label = 'DSP',
        color = bxhnz7tp5bge7wvu.interface.color.green,
        color2 = bxhnz7tp5bge7wvu.interface.color.green
      },
      off = {
        label = 'dsp',
        color = bxhnz7tp5bge7wvu.interface.color.grey,
        color2 = bxhnz7tp5bge7wvu.interface.color.dark_grey
      }
    })
  bxhnz7tp5bge7wvu.interface.buttons.add_toggle({
      name = 'spellsteal',
      label = 'Auto Spellsteal',
      on = {
        label = 'SS',
        color = bxhnz7tp5bge7wvu.interface.color.green,
        color2 = bxhnz7tp5bge7wvu.interface.color.green
      },
      off = {
        label = 'ss',
        color = bxhnz7tp5bge7wvu.interface.color.grey,
        color2 = bxhnz7tp5bge7wvu.interface.color.dark_grey
      }
    })
  bxhnz7tp5bge7wvu.interface.buttons.add_toggle({
      name = 'auto_shield',
      label = 'Auto Shield',
      on = {
        label = 'AS',
        color = bxhnz7tp5bge7wvu.interface.color.green,
        color2 = bxhnz7tp5bge7wvu.interface.color.green
      },
      off = {
        label = 'as',
        color = bxhnz7tp5bge7wvu.interface.color.grey,
        color2 = bxhnz7tp5bge7wvu.interface.color.dark_grey
      }
    })
  bxhnz7tp5bge7wvu.interface.buttons.add_toggle({
      name = 'opener',
      label = 'Opener',
      on = {
        label = 'OP',
        color = bxhnz7tp5bge7wvu.interface.color.green,
        color2 = bxhnz7tp5bge7wvu.interface.color.green
      },
      off = {
        label = 'op',
        color = bxhnz7tp5bge7wvu.interface.color.grey,
        color2 = bxhnz7tp5bge7wvu.interface.color.dark_grey
      }
    })
  bxhnz7tp5bge7wvu.interface.buttons.add_toggle({
      name = 'settings',
      label = 'Rotation Settings',
      font = 'bxhnz7tp5bge7wvu_icon',
      on = {
        label = bxhnz7tp5bge7wvu.interface.icon('cog'),
        color = bxhnz7tp5bge7wvu.interface.color.cyan,
        color2 = bxhnz7tp5bge7wvu.interface.color.dark_cyan
      },
      off = {
        label = bxhnz7tp5bge7wvu.interface.icon('cog'),
        color = bxhnz7tp5bge7wvu.interface.color.grey,
        color2 = bxhnz7tp5bge7wvu.interface.color.dark_grey
      },
      callback = function(self)
        if configWindow.parent:IsShown() then
          configWindow.parent:Hide()
        else
          configWindow.parent:Show()
        end
      end
    })
end

bxhnz7tp5bge7wvu.rotation.register({
    spec = bxhnz7tp5bge7wvu.rotation.classes.mage.arcane,
    name = 'arcane_nikopol',
    label = 'Arcane',
    gcd = gcd,
    combat = combat,
    resting = resting,
    interface = interface
  })
