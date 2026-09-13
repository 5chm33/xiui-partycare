local ROOT = '/home/ubuntu/repos/xiui-partycare/XIUI/'
package.path = ROOT .. '?.lua;' .. ROOT .. '?/init.lua;' .. package.path

local empty_modules = {
    'common', 'libs.memory', 'libs.entity', 'libs.party', 'libs.target',
    'libs.fonts', 'libs.drawing', 'libs.packets', 'libs.texturemanager',
    'libs.hp', 'libs.fastcast', 'libs.format', 'libs.color',
    'libs.statusicons', 'handlers.statushandler', 'libs.bufftable',
}
for _, name in ipairs(empty_modules) do
    package.preload[name] = function() return {} end
end

local x, y = 100, 200
local mouseDown = true
imgui = {
    GetWindowPos = function() return x, y end,
    IsMouseDown = function() return mouseDown end,
}
package.preload['imgui'] = function() return imgui end

gConfig = {windowPositions = {}, appliedPositions = {}}
local diskSaves = 0
SaveSettingsToDisk = function() diskSaves = diskSaves + 1 end
SaveSettingsOnly = function() error('release persistence should prefer disk save') end

require('handlers.helpers')

-- Opening/dragging creates and updates an in-memory coordinate without disk churn.
SaveWindowPosition('PartyList', true)
assert(gConfig.windowPositions.PartyList.x == 100 and gConfig.windowPositions.PartyList.y == 200)
assert(diskSaves == 0, 'must not persist while drag is active')

x, y = 155, 245
SaveWindowPosition('PartyList', true)
assert(gConfig.windowPositions.PartyList.x == 155 and gConfig.windowPositions.PartyList.y == 245)
assert(diskSaves == 0, 'must not persist every drag frame')

-- The release frame keeps the final coordinate and writes exactly once.
mouseDown = false
SaveWindowPosition('PartyList', true)
assert(diskSaves == 1, 'must persist once when drag ends')
SaveWindowPosition('PartyList', true)
assert(diskSaves == 1, 'must not save repeatedly after release')

local displayFile = assert(io.open(ROOT .. 'modules/partylist/display.lua', 'r'))
local displaySource = displayFile:read('*a')
displayFile:close()
assert(displaySource:find('SaveWindowPosition%(windowName, true%)'), 'Party List must opt into drag-release persistence')

print('PASS: XIUI Party List drag-release position persistence')
