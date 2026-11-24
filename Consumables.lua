local _, addon = ...

addon.Lures = {
    { id = 6533, bonus = 100 }, -- Aquadynamic Fish Attractor
    { id = 6532, bonus = 75 },  -- Bright Baubles
    { id = 7307, bonus = 75 },  -- Flesh Eating Worm
    { id = 6530, bonus = 50 },  -- Nightcrawlers
    { id = 6811, bonus = 50 },  -- Aquadynamic Fish Lens
    { id = 268880, bonus = 25 }, -- "Secret" Bait
    { id = 6529, bonus = 25 },  -- Shiny Bauble
}

-- IDs identify the bag item. Rules apply to its target, not to the item's own subclass.
addon.WeaponEnhancements = {
    { id = 12404, rule = "sharp" }, -- Dense Sharpening Stone
    { id = 7964, rule = "sharp" },  -- Solid Sharpening Stone
    { id = 2871, rule = "sharp" },  -- Heavy Sharpening Stone
    { id = 2863, rule = "sharp" },  -- Coarse Sharpening Stone
    { id = 2862, rule = "sharp" },  -- Rough Sharpening Stone
    { id = 12643, rule = "blunt" }, -- Dense Weightstone
    { id = 7965, rule = "blunt" },  -- Solid Weightstone
    { id = 3241, rule = "blunt" },  -- Heavy Weightstone
    { id = 3240, rule = "blunt" },  -- Coarse Weightstone
    { id = 3239, rule = "blunt" },  -- Rough Weightstone
    { id = 18262, rule = "melee" }, -- Elemental Sharpening Stone
    { id = 23122, rule = "melee" }, -- Consecrated Sharpening Stone
    { id = 20749, rule = "melee" }, -- Brilliant Wizard Oil
    { id = 20750, rule = "melee" }, -- Wizard Oil
    { id = 20746, rule = "melee" }, -- Lesser Wizard Oil
    { id = 20744, rule = "melee" }, -- Minor Wizard Oil
    { id = 23123, rule = "melee" }, -- Blessed Wizard Oil
    { id = 20748, rule = "melee" }, -- Brilliant Mana Oil
    { id = 20747, rule = "melee" }, -- Lesser Mana Oil
    { id = 20745, rule = "melee" }, -- Minor Mana Oil
    { id = 3829, rule = "melee" },  -- Frost Oil
    { id = 3824, rule = "melee" },  -- Shadow Oil
    { id = 8928, rule = "poison" }, -- Instant Poison VI
    { id = 8927, rule = "poison" }, -- Instant Poison V
    { id = 8926, rule = "poison" }, -- Instant Poison IV
    { id = 6950, rule = "poison" }, -- Instant Poison III
    { id = 6949, rule = "poison" }, -- Instant Poison II
    { id = 6947, rule = "poison" }, -- Instant Poison I
    { id = 20844, rule = "poison" }, -- Deadly Poison V
    { id = 8985, rule = "poison" }, -- Deadly Poison IV
    { id = 8984, rule = "poison" }, -- Deadly Poison III
    { id = 2893, rule = "poison" }, -- Deadly Poison II
    { id = 2892, rule = "poison" }, -- Deadly Poison I
    { id = 10922, rule = "poison" }, -- Wound Poison IV
    { id = 10921, rule = "poison" }, -- Wound Poison III
    { id = 10920, rule = "poison" }, -- Wound Poison II
    { id = 10918, rule = "poison" }, -- Wound Poison I
    { id = 3776, rule = "poison" }, -- Crippling Poison II
    { id = 3775, rule = "poison" }, -- Crippling Poison I
    { id = 9186, rule = "poison" }, -- Mind-numbing Poison III
    { id = 6951, rule = "poison" }, -- Mind-numbing Poison II
    { id = 5237, rule = "poison" }, -- Mind-numbing Poison I
}
