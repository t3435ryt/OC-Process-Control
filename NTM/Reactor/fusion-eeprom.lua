local fusionAddress = nil
local screenAddress = nil
local gpuAddress = nil
local status = nil
local tripped = false
local textBuffer = nil
local blanketMaxDurability = 0
local com = component
local textArray = {
    "",
    "",
    "        Magnetic Confinement Fusion Reactor",
    "",
    "                Status:",
    "                 Power:",
    "                 Water:",
    "                 Steam:",
    "                Plasma:",
    "           Plasma Type:",
    "                  Temp:",
    "    Blanket Durability:",
    "",
    "           t: Trip  s: Start  x: Stop",
    "",
    ""}

local componentList = com.list()
for address, componentType in componentList do
    if (componentType == "ntm_fusion") and (fusionAddress == nil) then
        fusionAddress = address
    elseif (componentType == "screen") and (screenAddress == nil) then
        screenAddress = address
    elseif (componentType == "gpu") and (gpuAddress == nil) then
        gpuAddress = address
    end
end

if gpuAddress then
    com.invoke(gpuAddress, "bind", screenAddress)
    textBuffer = com.invoke(gpuAddress, "allocateBuffer")
    com.invoke(gpuAddress, "setActiveBuffer", textBuffer)
end

local trip = function()
    tripped = true
    com.invoke(fusionAddress, "setActive", false)
end

local gpuSet = function (x, y, string)
    com.invoke(gpuAddress, "set", x,  y, string)
end

while true do
    local power, maxPower = com.invoke(fusionAddress, "getEnergyInfo")
    local active = com.invoke(fusionAddress, "isActive")
    local water, maxWater, ultraDenseSteam, maxUltraDenseSteam, plasma,
          maxPlasma, plasmaType = com.invoke(fusionAddress, "getFluid")
    local plasmaTemp = com.invoke(fusionAddress, "getPlasmaTemp")
    local maxPlasmaTemp = com.invoke(fusionAddress, "getMaxTemp")
    if maxPlasmaTemp == 3500 then
        blanketMaxDurability = 1080000
    elseif maxPlasmaTemp == 4500 then
        blanketMaxDurability = 2160000
    elseif maxPlasmaTemp == 9000 then
        blanketMaxDurability = 3280000
    else
        blanketMaxDurability = 0
    end
    local blanketDamage = com.invoke(fusionAddress, "getBlanketDamage")
    if blanketDamage == "N/A" then blanketDamage = 0 end
    local blanketDurability = blanketMaxDurability - blanketDamage

    if (not tripped) and ((power <= 3000000) or ((blanketDurability <= 100) and active)) then
        trip()
    end
    local signal = {computer.pullSignal(0.05)}
    if signal[1] == "key_down" then
        local _, _, char, _, _ = table.unpack(signal)
        if char == 0x74 then
            trip()
        elseif char == 0x73 and (not tripped) then
            com.invoke(fusionAddress, "setActive", true)
        elseif char == 0x78 then
            com.invoke(fusionAddress, "setActive", false)
        end
    end
    if gpuAddress ~= nil then
        if tripped then
            status = "Trip"
        elseif active then
            status = "Run"
        else
            status = "Shutdown"
        end
        com.invoke(gpuAddress, "fill", 1, 1, 50, 16, " ")
        for i,v in ipairs(textArray) do
            gpuSet(1, i, v)
        end
        gpuSet(24,  5, status)
        gpuSet(24,  6, power .. "/" .. maxPower)
        gpuSet(24,  7, water .. "/" .. maxWater)
        gpuSet(24,  8, ultraDenseSteam .. "/" .. maxUltraDenseSteam)
        gpuSet(24,  9, plasma .. "/" .. maxPlasma)
        gpuSet(24, 10, plasmaType)
        gpuSet(24, 11, plasmaTemp .. "/" .. maxPlasmaTemp)
        gpuSet(24, 12, blanketDurability .. "/" .. blanketMaxDurability)
        com.invoke(gpuAddress, "bitblt", 0, 1, 1, 50, 16, textBuffer, 1, 1)
    end

end
