local fileutil = require("util.file")
local inpututil = require("util.input")
local serpent = require("serpent")
local json = require("json")
local System = require("System")
local fs = require("fs")
local log = require("log")
local util = require("util")
local Error = require("Error")
local semver = require("util.semver")
local Globals = require("Globals")
local s = require("schema")
local schema = require("project.projectschema")

local ProjectSettingsFields = {
	audioRouting = AudioChannelRouting,
	midiRouting = MidiChannelRouting,
	layout = SystemLayout,
	saveType = SaveStateType,
	"zoom",
	"includeRom"
}

local SystemSettingsFields = {
	systemType = SystemType,
	"romPath",
	"sramPath"
}

local SameBoySettingsFields = {
	model = GameboyModel,
	"gameLink",
	"skipBootRom"
}

local PROJECT_LUA_FILENAME = "project.lua"

local function readLegacyStateData(base64Data, saveType, version)
	local stateData = base64.decodeBuffer(base64Data)

	if version == semver(0, 1, 0) then
		if saveType == "state" then
			-- Since version 0.1.0 the save state format of sameboy has changed.  This means
			-- states can not be loaded.  In some cases, however (such as lsdj), we can extract
			-- the SRAM data from the state data.

			local version = stateData:readUint32(4)
			log.info("State version: " .. version .. " size: " .. stateData:size())

			local sramOffset = 0x8425
			local sramSize = 128 * 1024
			return stateData:slice(sramOffset, sramSize), "sram"
		end
	end

	return stateData, saveType
end

local function updgrade_json_to_pv100(p, config)
	local systems = {}
	local saveType

	for _, v in ipairs(p.instances) do
		local stateData
		if v.state ~= nil and v.state.data ~= nil and type(v.state.data) == "string" then
			stateData, saveType = readLegacyStateData(v.state.data, p.saveType, semver(p.version))
		end

		--local uiComponents = {}
		local audioComponents = {}
		if v.settings.lsdj then
			local lsdj = v.settings.lsdj
			local syncModes = {
				off = 0,
				midiSync = 1,
				midiSyncArduinoboy = 2,
				midiMap = 3
			}

			local syncMode = syncModes[lsdj.syncMode]
			if syncMode == nil then syncMode = 0 end

			audioComponents["arduinoboy"] = {
				autoPlay = lsdj.autoPlay,
				syncMode = syncMode,
				lastRow = -1,
				playing = false,
				tempoDivisor = 1
			}
		end

		local modelConvert = {
			auto = "auto",
			AGB = "agb",
			DMG_B = "dmgB",
			CGB_C = "cgbC",
			CGB_E = "cgbE"
		}

		table.insert(systems, {
			systemType = "sameBoy",
			romPath = v.romPath,
			sramPath = v.lastSramPath,
			sameBoy = {
				model = modelConvert[v.settings.gameBoy.model] or "auto",
				gameLink = v.settings.gameBoy.gameLink,
				skipBootRom = config.system.sameBoy.skipBootRom
			},
			input = {
				key = config.system.input.key,
				pad = config.system.input.pad
			},
			uiComponents = {},
			audioComponents = audioComponents,
			_stateData = stateData
		})

		v.state = nil
	end

	if p.midiRouting == "sendToall" then p.midiRouting = "sendToAll" end

	return {
		retroPlugVersion = _RETROPLUG_VERSION,
		projectVersion = "1.0.0",
		path = p.lastProjectPath,
		systems = systems,

		settings = {
			saveType = saveType,
			audioRouting = p.audioRouting,
			zoom = config.project.zoom,
			midiRouting = p.midiRouting,
			layout = p.layout,
			includeRom = config.project.includeRom
		}
	}
end

-- Returns true if the project predates the 1.0.0 project format.  A malformed
-- or missing version string makes semver() throw, so failures are treated as
-- "not a legacy project" rather than allowed to escape into the host.
local function isLegacyProject(projectData)
	if projectData.instances == nil then return false end

	local ok, isLegacy = pcall(function()
		return semver(projectData.version) <= semver(0, 2, 0)
	end)

	if ok == false then
		log.warn("Project declares an unreadable version, ignoring legacy upgrade path")
		return false
	end

	return isLegacy
end

local function upgradeAndValidateProject(projectData, config)
	local err

	if type(projectData) ~= "table" then
		return nil, "Failed to load project: Project data is not a table"
	end

	if isLegacyProject(projectData) then
		-- Legacy documents are only shape-checked by the schema below, so the
		-- upgrade itself has to tolerate arbitrary malformed input.
		local ok, upgraded, upgradeErr = pcall(updgrade_json_to_pv100, projectData, config)
		if ok == false then
			return nil, "Failed to load project: Unable to upgrade legacy project"
		end

		projectData, err = upgraded, upgradeErr
		--log.obj(projectData)
	end

	local projectSchema = schema["1.0.0"]
	local valErr = s.CheckSchema(projectData, projectSchema)
	if valErr then
		log.obj(projectData)
		local err = tostring(valErr)
		return nil, err
	end

	return projectData, err
end

local function zipEntryExists(entries, name)
	for _, v in ipairs(entries) do
		if v.name == name then return true end
	end

	return false
end

local function loadSystemResources(projectData, inst, idx, zip)
	local t = {}
	local idxStr = tostring(idx)
	local st = util.fromEnumString(SaveStateType, projectData.settings.saveType)

	if zip ~= nil then
		t.rom = zip:read(idxStr .. ".gb")
		t.state = zip:read(idxStr .. ".state")
		t.sram = zip:read(idxStr .. ".sav")
	end

	if inst._stateData ~= nil then
		if st == SaveStateType.Sram then
			t.sram = inst._stateData
		elseif st == SaveStateType.State then
			t.state = inst._stateData
		end
	end

	if t.rom == nil or isNullPtr(t.rom) then
		if fs.exists(inst.romPath) then
			t.rom = fs.load(inst.romPath)
		end
	end

	if t.sram == nil or isNullPtr(t.sram) then
		if fs.exists(inst.sramPath) then
			t.sram = fs.load(inst.sramPath)
		end
	end

	if t.rom == nil or isNullPtr(t.rom) then t.rom = nil; log.warn("Couldn't find ROM") end
	--if t.state == nil or isNullPtr(t.state) then t.state = nil; log.warn("Couldn't find state data") end
	--if t.sram == nil or isNullPtr(t.sram) then t.sram = nil; log.warn("Couldn't find SRAM data") end

	return t
end

local function createProjectSystems(projectData, zip)
	local systems = {}
	for i, inst in ipairs(projectData.systems) do
		local res = loadSystemResources(projectData, inst, i, zip)

		local system = SystemDesc.new()
		system.idx = -1
		system.fastBoot = true
		util.copyStringFields(inst, SystemSettingsFields, system)
		util.copyStringFields(inst.sameBoy, SameBoySettingsFields, system.sameBoySettings)

		if res.rom then
			system.state = SystemState.Initialized
			system.romData = res.rom
			system.romName = util.getRomName(res.rom)
		else
			system.state = SystemState.RomMissing
		end

		if projectData.settings.saveType == "state" then
			if res.state then
				log.info("Loading from save state")
				system.stateData = res.state
			elseif res.sram then
				log.info("Loading from SRAM (specified state")
				system.sramData = res.sram
			end
		elseif projectData.settings.saveType == "sram" then
			if res.sram then
				log.info("Loading from SRAM")
				system.sramData = res.sram
			elseif res.state then
				log.info("Loading from save state (specified SRAM)")
				system.stateData = res.state
			end
		end

		system.audioComponentState = serpent.dump(inst.audioComponents)
		system.uiComponentState = serpent.dump(inst.uiComponents)

		local sys = System.fromSystemDesc(system)
		sys:setInputMap(inpututil.getInputMap(Globals.inputConfigs, inst.input))

		table.insert(systems, sys)
	end

	return systems
end

local function loadProject(data, config)
	local projectData
	local err

	local zip = ZipReader.new(data)

	-- Every failure below has to close the reader before returning.  This runs
	-- on host-supplied state chunks, which may be truncated or corrupt, so a
	-- leaked reader here would accumulate on every failed project restore.
	local function fail(msg)
		if zip then zip:close() end
		return nil, nil, Error(msg)
	end

	if zip:isValid() then
		local entries = zip:entries()

		if zipEntryExists(entries, PROJECT_LUA_FILENAME) then
			local fileData = zip:read(PROJECT_LUA_FILENAME)
			if fileData == nil or isNullPtr(fileData) then
				return fail("Failed to load project: Project file unreadable")
			end

			local ok, loadedData = serpent.load(fileData:toString(), { safe = true })

			if ok == false then
				return fail("Failed to load project: Unable to parse lua project")
			end

			projectData = loadedData
		else
			return fail("Failed to load project: Project file missing")
		end
	else
		zip:close()
		zip = nil

		log.info("Failed to load zip, trying to load legacy project")
		local fileData, loadErr = fileutil.loadPathOrData(data)
		if loadErr ~= nil then return nil, nil, loadErr end
		if fileData == nil or isNullPtr(fileData) then
			return nil, nil, Error("Failed to load project: Unable to read file")
		end

		-- Old projects (<= v0.2.0) are encoded using JSON rather than lua.
		-- Arbitrary bytes reach this path whenever the data is not a valid zip.
		local stringData = fileData:toString()
		local ok, decoded = pcall(json.decode, stringData)
		if ok == false then decoded = nil end

		projectData = decoded
		if projectData == nil then
			return nil, nil, Error("Failed to load project: Unable to deserialize file")
		end

		log.info("Legacy project loaded")
	end

	projectData, err = upgradeAndValidateProject(projectData, config)
	if err ~= nil then
		return fail(err)
	end

	-- Resource loading touches ROM/SRAM payloads of attacker-controllable size
	-- and shape; a throw here must not leak the reader either.
	local ok, systems = pcall(createProjectSystems, projectData, zip)
	if ok == false then
		return fail("Failed to load project: Unable to create systems")
	end

	if zip then zip:close() end

	return projectData, systems, nil
end

local function saveProject(path, projectData, systems, systemStates, zipSettings, includeRom)
	local ok

	local zip
	if type(path) == "string" and path ~= "" then
		zip = ZipWriter.new(path, zipSettings)
		if not zip:isValid() then return Error("Failed to open output file") end
	else
		zip = ZipWriter.new(zipSettings)
	end

	-- Any bail-out below must still close and release the writer, otherwise a
	-- file-backed save leaves a partially written project on disk.
	local function fail(msg)
		zip:close()
		zip:free()
		return Error(msg)
	end

	ok = zip:add(PROJECT_LUA_FILENAME, projectData)
	if ok == false then return fail("Failed to add project config") end

	for i, system in ipairs(systems) do
		local idx = tostring(i)

		if systemStates.srams[i] ~= nil then
			ok = zip:add(idx .. ".sav", systemStates.srams[i])
			if ok == false then return fail("Failed to add system SRAM") end
		end

		if systemStates.states[i] ~= nil then
			ok = zip:add(idx .. ".state", systemStates.states[i])
			if ok == false then return fail("Failed to add system state") end
		end

		if includeRom == true and not isNullPtr(system.desc.romData) then
			ok = zip:add(idx .. ".gb", system.desc.romData)
			if ok == false then return fail("Failed to add system ROM") end
		end
	end

	zip:close()

	if type(path) == "userdata" then
		zip:copyTo(path)
	end

	zip:free()
end

return {
	loadProject = loadProject,
	ProjectSettingsFields = ProjectSettingsFields,
	SystemSettingsFields = SystemSettingsFields,
	SameBoySettingsFields = SameBoySettingsFields,
	saveProject = saveProject,
	createProjectSystems = createProjectSystems
}
