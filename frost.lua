local bxhnz7tp5bge7wvu = bxhnz7tp5bge7wvu_interface
local SB = s2e6mafdoivyb5x4

local function hekili_cooldown_ready(spell)
  return Hekili.State.cooldown[spell].remains == 0
end

local function hekili_castable(spell)
  local usable, noMana = IsUsableSpell(spell)
  
  if usable and hekili_cooldown_ready(spell) == 0 then
    return true
  else
    return false
  end
end

local function hekili_unit_castable(spell, unit)
  local spellName = GetSpellInfo(spell)
  local inRange = IsSpellInRange(spellName, unit.unitID)
  
  if inRange == 1 and hekili_castable(spell) then
    return true
  else
    return false
  end
end

local function is_available(spell)
  return IsSpellKnown(spell, false) or IsPlayerSpell(spell)
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
  if player.casting() or player.channeling() then return end
  
  local ability_to_cast = Hekili_GetRecommendedAbility( "Primary", 1 )
  
  if ability_to_cast and ability_to_cast == -164 then
    return macro('/use 13')
  end
  
  if ability_to_cast and (ability_to_cast == -365 or ability_to_cast == -341) then
    return macro('/use 14')
  end
end

local function combat()
  if not player.alive then return end
  
  if modifier.lshift and hekili_castable(SB.DragonsBreath) then
    cancel_queued_spell()
    stopcast()
    return cast_while_casting(SB.DragonsBreath)
  end
  
  if modifier.lcontrol and hekili_castable(SB.BlastWave) then
    cancel_queued_spell()
    stopcast()
    return cast_while_casting(SB.BlastWave)
  end
  
  if player.channeling() then return end
  if SpellIsTargeting() then return end
    
  if GetCVar("nameplateShowEnemies") == '0' then
    SetCVar("nameplateShowEnemies", 1)
  end
  
  local healing_potion = bxhnz7tp5bge7wvu.settings.fetch('frost_nikopol_healing_potion', false)
  local trinket_13 = bxhnz7tp5bge7wvu.settings.fetch('frost_nikopol_trinket_13', false)
  local trinket_14 = bxhnz7tp5bge7wvu.settings.fetch('frost_nikopol_trinket_14', false)
  
  cancel_queued_spell()
  
  if GetItemCooldown(5512) == 0 and player.health.effective < 30 then
    macro('/use Healthstone')
  end
  
  if healing_potion and GetItemCooldown(191380) == 0 and player.health.effective < 10 then
    macro('/use Refreshing Healing Potion')
  end
    
  local ability_to_cast = Hekili_GetRecommendedAbility( "Primary", 1 )
  
  if toggle('dispell', false) and castable(SB.RemoveCurse) and player.dispellable(SB.RemoveCurse) then
    return cast_with_queue(SB.RemoveCurse, player)
  end
    
  if modifier.lalt and castable(SB.IceBarrier) then
    return cast_with_queue(SB.IceBarrier)
  end
    
  if target.enemy and target.alive then  
    --actions+=/use_item,slot=trinket1
    --actions+=/use_item,slot=trinket2
    local start, duration, enable = GetInventoryItemCooldown("player", 13)
    local trinket13_id = GetInventoryItemID("player", 13)
    if trinket_13 and enable == 1 and start == 0 then
      return macro('/use 13')
    end
    
    if ability_to_cast and ability_to_cast == -164 then
      return macro('/use 13')
    end
    
    if ability_to_cast and (ability_to_cast == -365 or ability_to_cast == -341) then
      return macro('/use 14')
    end
    
    start, duration, enable = GetInventoryItemCooldown("player", 14)
    local trinket14_id = GetInventoryItemID("player", 14)
    if trinket_14 and enable == 1 and start == 0 then
      return macro('/use 14')
    end
    
    if toggle('spellsteal', false) and hekili_unit_castable(SB.SpellSteal, target) and target.dispellable(SB.SpellSteal) then
      return cast_with_queue(SB.SpellSteal, target)
    end
    
    if toggle('interrupts', false) and target.interrupt(80) and hekili_unit_castable(SB.Counterspell, target) then
      cast_with_queue(SB.Counterspell, target)
    end
    
    if ability_to_cast and ability_to_cast > 0 then
      if ability_to_cast == SB.CometStorm or ability_to_cast == SB.IceNova then
        return cast_with_queue(ability_to_cast, target)
      elseif ability_to_cast == SB.Blizzard then
        return cast_with_queue(ability_to_cast, 'ground')
      else
        return cast_with_queue(ability_to_cast, player)
      end
    end
  end
end

local function resting()
end

local function interface()
    local frost_gui = {
    key = 'frost_nikopol',
    title = 'frost',
    width = 250,
    height = 320,
    resize = true,
    show = false,
    template = {
      { type = 'header', text = 'Frost Settings' },
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

  configWindow = bxhnz7tp5bge7wvu.interface.builder.buildGUI(frost_gui)
  
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
    name = 'all_interrupts',
    label = 'Use all interrupts',
    on = {
      label = 'AINT',
      color = bxhnz7tp5bge7wvu.interface.color.green,
      color2 = bxhnz7tp5bge7wvu.interface.color.green
    },
    off = {
      label = 'aint',
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
  spec = bxhnz7tp5bge7wvu.rotation.classes.mage.frost,
  name = 'frost_nikopol',
  label = 'Frost',
  gcd = gcd,
  combat = combat,
  resting = resting,
  interface = interface
})
