--I'm sure there's a more graceful way of getting this data into my addon's Apollo table
--while keeping the files separate, but I'm too much of a lua scrub to know how.

QtSpellslinger = {}

function QtSpellslinger:LoadSpells()
  local table = 
  {
    [20684] = {
      name = "Charged Shot",
      tiers = {
        t1 = { 34718, 34719 },
        t2 = { 48940, 48949 },
        t3 = { 48941, 48950 },
        t4 = { 48942, 48951 },
        t5 = { 48943, 48952 },
        t6 = { 48944, 48953 },
        t7 = { 48945, 48954 },
        t8 = { 48946, 48955 },
        t9 = { 48947, 48956 }
      }
    },
    [20734] = {
      name = "Wild Barrage",
      tiers = {
        t1 = { 34772, 34773 },
        t2 = { 48904, 48913 },
        t3 = { 48905, 48914 },
        t4 = { 48906, 48915 },
        t5 = { 48907, 48916 },
        t6 = { 48908, 48917 },
        t7 = { 48909, 48918 },
        t8 = { 48910, 48919 },
        t9 = { 48911, 48920 }
      }
    },
    [21056] = {
      name = "Rapid Fire",
      tiers = {
        t1 = { 35356, 35357, 35358, 35359, 38937, 51501 },
        t2 = { 51391, 51400, 51410, 51419 },
        t3 = { 51392, 51401, 51411, 51420 },
        t4 = { 51393, 51402, 51412, 51421 },
        t5 = { 51394, 51403, 51413, 51422 },
        t6 = { 51395, 51404, 51414, 51423 },
        t7 = { 51396, 51405, 51415, 51424 },
        t8 = { 51397, 51406, 51416, 51425 },
        t9 = { 51398, 51407, 51417, 51426 }
      }
    },
    [21490] = {
      name = "Astral Infusion",
      tiers = {
        t1 = { 35870, 54717 },
        t2 = { 49730, 54718 },
        t3 = { 49731, 54719 },
        t4 = { 49732, 54720 },
        t5 = { 49733, 54721 },
        t6 = { 49734, 54722 },
        t7 = { 49735, 54723 },
        t8 = { 49736, 54724 },
        t9 = { 49737, 54725 }
      }
    },
    [21650] = {
      name = "True Shot",
      tiers = {
        t1 = { 36052, 36085 },
        t2 = { 49078, 49114 },
        t3 = { 49079, 49115 },
        t4 = { 49080, 49116 },
        t5 = { 49081, 49117 },
        t6 = { 49082, 49118 },
        t7 = { 49083, 49119 },
        t8 = { 49084, 49121 },
        t9 = { 49085, 49122 }
      }
    },
    [23274] = {
      name = "Assassinate",
      tiers = {
        t1 = { 38905, 39324, 39325, 69215, 69224 },
        t2 = { 49051, 49060, 49069, 69216, 69225 },
        t3 = { 49052, 49061, 49070, 69217, 69226 },
        t4 = { 49053, 49062, 49071, 69218, 69227 },
        t5 = { 49054, 49063, 49072, 69219, 69228 },
        t6 = { 49055, 49064, 49073, 69220, 69229 },
        t7 = { 49056, 49065, 49074, 69221, 69230 },
        t8 = { 49057, 49066, 49075, 69222, 69231 },
        t9 = { 49058, 49067, 49076, 69223, 69232 }
      }
    },
    [23418] = {
      name = "Dual Fire",
      tiers = {
        t1 = { 39068, 53286 },
        t2 = { 49558, 53287 },
        t3 = { 49560, 53288 },
        t4 = { 49561, 53289 },
        t5 = { 49562, 53290 },
        t6 = { 49563, 53291 },
        t7 = { 49564, 53292 },
        t8 = { 49565, 53293 },
        t9 = { 49566, 53294 }
      }
    },
    [23441] = {
      name = "Runes of Protection",
      tiers = {
        t1 = { 39092, 39327, 69761 },
        t2 = { 49225, 49234 },
        t3 = { 49226, 49235 },
        t4 = { 49227, 49236 },
        t5 = { 49228, 49237 },
        t6 = { 49229, 49238 },
        t7 = { 49230, 49239 },
        t8 = { 49231, 49240 },
        t9 = { 49232, 49241 }
      }
    },
    [23463] = {
      name = "Healing Torrent",
      tiers = {
        t1 = { 39116, 39131 },
        t2 = { 49640, 49649 },
        t3 = { 49641, 49650 },
        t4 = { 49642, 49651 },
        t5 = { 49643, 49652 },
        t6 = { 49644, 49653 },
        t7 = { 49645, 49654 },
        t8 = { 49646, 49655 },
        t9 = { 49647, 49656 }
      }
    },
    [23468] = {
      name = "Healing Salve",
      tiers = {
        t1 = { 39121, 47601 },
        t2 = { 49586, 49631 },
        t3 = { 49587, 49632 },
        t4 = { 49588, 49633 },
        t5 = { 49589, 49634 },
        t6 = { 49590, 49635 },
        t7 = { 49591, 49636 },
        t8 = { 49592, 49637 },
        t9 = { 49593, 49638 }
      }
    },
    [23479] = {
      name = "Vitality Burst",
      tiers = {
        t1 = { 39132, 39133 },
        t2 = { 49658, 49667 },
        t3 = { 49659, 49668 },
        t4 = { 49660, 49669 },
        t5 = { 49661, 49670 },
        t6 = { 49662, 49671 },
        t7 = { 49663, 49672 },
        t8 = { 49664, 49673 },
        t9 = { 49665, 49674 }
      }
    },
    [23481] = {
      name = "Voidspring",
      tiers = {
        t1 = { 39134, 47600 },
        t2 = { 51800, 53475 },
        t3 = { 51801, 53476 },
        t4 = { 51802, 53477 },
        t5 = { 51803, 53478 },
        t6 = { 51804, 53479 },
        t7 = { 51805, 53480 },
        t8 = { 51806, 53481 },
        t9 = { 51807, 53482 }
      }
    },
    [27504] = {
      name = "Sustain",
      tiers = {
        t1 = { 43326, 43398 },
        t2 = { 51850, 51863 },
        t3 = { 51851, 51864 },
        t4 = { 51852, 51865 },
        t5 = { 51853, 51866 },
        t6 = { 51854, 51867 },
        t7 = { 51855, 51868 },
        t8 = { 51856, 51869 },
        t9 = { 51857, 51870 }
      }
    },
    [27736] = {
      name = "Arcane Missiles",
      tiers = {
        t1 = { 43570, 43619 },
        t2 = { 54941, 54989 },
        t3 = { 54942, 54990 },
        t4 = { 54943, 54991 },
        t5 = { 54944, 54992 },
        t6 = { 54945, 54993 },
        t7 = { 54946, 54994 },
        t8 = { 54947, 54995 },
        t9 = { 54948, 54996 }
      }
    },
    [27774] = {
      name = "Chill",
      tiers = {
        t1 = { 43609, 43613 },
        t2 = { 49178, 49198 },
        t3 = { 49179, 49199 },
        t4 = { 49180, 49200 },
        t5 = { 49181, 49201 },
        t6 = { 49182, 49202 },
        t7 = { 49183, 49203 },
        t8 = { 49184, 49204 },
        t9 = { 49185, 49205 }
      }
    },
    [23959] = {
      name = "Regenerative Pulse",
      tiers = {
        t1 = { 39646, 47078, 47079, 47080, 47081, 47082, 47090 },
        t2 = { 51691, 51702, 51711, 51720, 51729 },
        t3 = { 51692, 51703, 51712, 51721, 51730 },
        t4 = { 51693, 51704, 51713, 51722, 51731 },
        t5 = { 51695, 51705, 51714, 51723, 51732 },
        t6 = { 51696, 51706, 51715, 51724, 51733 },
        t7 = { 51697, 51707, 51716, 51725, 51734 },
        t8 = { 51698, 51708, 51717, 51726, 51735 },
        t9 = { 51699, 51709, 51718, 51727, 51736 }
      }
    }
  }
  return table
end

--[[
--This ugly bit of code, when run logged in as a spellslinger, loops through our ability book and dumps
--the spellsurged spellids of each tier of every ability and stores it in a global table.  Use GeminiConsole
--to retreive a neat copyable Lua table that can be pasted into this file.
--
--Regenerative Pulse is not picked up by this code unless you remove the cooldown check from dfindabilities
--
--The timer is necessary because takes too long to execute and Wildstar kills it early if we try to loop
--through everything all in one go.
local continueFrom = -1
function QtCooldown:dspelldump()
  if (continueFrom == -1) then
    continueFrom = 1
    _G["dumptable"] = {}
  end

  local i = continueFrom
  
  local ab = AbilityBook.GetAbilitiesList()
  if (ab[i] ~= nil) then
    Print("Processing ability "..i.." ("..ab[i].strName..")")
    if (ab[i].nMaxTiers > 1 and (ab[i].tTiers[1].splObject:GetCooldownTime() > 0 or ab[i].tTiers[1].splObject:GetAbilityCharges().nChargesMax > 0) and string.match(ab[i].tTiers[1].splObject:GetFlavor(), "Surge")) then
      local altabilities = self:dfindabilities(ab[i].strName, ab[i].tTiers[1].splObject:GetIcon())
      _G["dumptable"][ab[i].nId] = {name = ab[i].strName, tiers=altabilities}
    end
    continueFrom = continueFrom + 1
    self:dstarttimer() --for whatever reason, calling starttimer from inside a timer's event handler does not do anything
  else
    continueFrom = -2
    Print("Done")
  end
end

function QtCooldown:dstarttimer()
  Apollo.RegisterTimerHandler("dspellsurgedumptimer", "dspelldump", self)
  Apollo.CreateTimer("dspellsurgedumptimer", 1, false)
  Apollo.StartTimer("dspellsurgedumptimer")
end

function QtCooldown:dfindabilities(name, icon)
  local ret = {}
  for i = 1,99999 do
    local spl = GameLib.GetSpell(i)
    if (spl:GetName() == name and spl:GetIcon() == icon and (spl:GetCooldownTime() > 0 or spl:GetAbilityCharges().nChargesMax > 0) and spl:GetTier() <= 9) then
      local tierstr = "t"..spl:GetTier()
      if (ret[tierstr] == nil) then
        ret[tierstr] = {}
      end
      tinsert(ret[tierstr], spl:GetId())
    end
  end 
  return ret
end
]]--