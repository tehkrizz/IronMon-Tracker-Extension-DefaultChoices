-- This is a template for a custom code extension for the Ironmon Tracker.
-- To use, first rename both this top-most function and the return value at the bottom: "CodeExtensionTemplate" -> "YourFileNameHere"
-- Then fill in each function you want to use with the code you want executed during Tracker runtime.
-- The name, author, and description attribute fields are used by the Tracker to identify this extension, please always include them.
-- You can safely remove unused functions; they won't be called.

local function DefaultChoices()
	local self = {}

	-- Define descriptive attributes of the custom extension that are displayed on the Tracker settings
	self.name = "Default Choice Maker"
	self.author = "Krizz"
	self.description = "For FireRed only. Let's you set your name, gender, and riva's name. This will only apply the changes to a new game before talking to Mom."
	--self.description = "This extension helps the tracker work with Krizz's self-contained Kaizo IronMon Randomizer ROM."
	self.version = "1.0"
	--self.url = "https://github.com/MyUsername/ExtensionRepo" -- Remove or set to nil if no host website available for this extension
	
	self.Options = {
		settingsName = "DCM", -- to be prepended to all other settings here
		defaultName = "Krizz",
		defaultGender = "Female",
		defaultRival = "Bad",
	}

	self.MemValues = {
		curName = "",
		curGender = "",
		curRival = "",
	}

	self.saveblock1Addr = Utils.getSaveBlock1Addr()
	self.saveblock2Addr = Memory.readdword(GameSettings.gSaveBlock2ptr)
	self.updated = nil
	self.curTrainer = nil

	local function ConvertName(input)
		local reverseCharMap = {}
		for number, cha in pairs(GameSettings.GameCharMap) do
		   local start = 0xA1
		   if number >= start then
				reverseCharMap[cha] = number
			end
		end
		local output = {}
		local length = #input
		local charcount = 0

		for i=1, length, 1 do
			local char = string.sub(input, i, i)
			output[i] = reverseCharMap[char]
		end
		--print(#output)
		if(#output < 7) then
			for i = (#output + 1), 7, 1 do
				output[i] = 0xFF
			end
		end
		return output
	end

	local function updateGame()
		if Program.GameData.mapId == 1 and self.updated == nil then
			--Update player name
			if self.MemValues.CurName ~= self.Options.defaultName then
				print("Name does not match")
				--Inject name
				local newName = ConvertName(self.Options.defaultName)
				--print(newName)
				for i=1, 7, 1 do
					Memory.writebyte((self.saveblock2Addr + i - 1),newName[i])
				end
				self.updated = 1
			end			
			--Update Gender
			if self.MemValues.curGender ~= self.Options.defaultGender then
				print("Gender does not match")
				--Inject gender
				local newGender = 0
				if self.Options.defaultGender == "Male" then 
					newGender = 0 
				elseif self.Options.defaultGender == "Female" then 
					newGender = 1 
				end
				--print(newGender)
				Memory.writebyte((self.saveblock2Addr + 0x08),newGender)
				self.updated = 1
			end
			--Update rival name
			if self.MemValues.curRival ~= self.Options.defaultRival then
				print("Rival name does not match")
				--Inject rival name
				local newRival = ConvertName(self.Options.defaultRival)
				--print(newRival)
				for i=1, 7, 1 do
					Memory.writebyte((self.saveblock1Addr + 0x3A4C + i - 1),newRival[i])
				end
			end
		else
			print("Can only update new games.")
		end
	end

	local function loadOptions()
		-- Load options from the Settings file
		self.Options.defaultName = TrackerAPI.getExtensionSetting(self.Options.settingsName, "defaultName") or self.Options.defaultName
		self.Options.defaultGender = TrackerAPI.getExtensionSetting(self.Options.settingsName, "defaultGender") or self.Options.defaultGender
		self.Options.defaultRival = TrackerAPI.getExtensionSetting(self.Options.settingsName, "defaultRival") or self.Options.defaultRival

		print("Option name: " .. self.Options.defaultName)
		print("Option gender: " .. self.Options.defaultGender)
		print("Option rival: " .. self.Options.defaultRival)

		-- Apply the loaded options
		updateGame()
	end	

	local function checkMemory()
		if GameSettings.game ~= 3 then
			print("Not FR")
		end

		self.saveblock1Addr = Utils.getSaveBlock1Addr()
		self.saveblock2Addr = Memory.readdword(GameSettings.gSaveBlock2ptr)

		--Get cur player name from memory
		local name = ""
		for i=0, 7, 1 do
			local charByte = Memory.readbyte(self.saveblock2Addr + i)
			if charByte ~= 0xFF then -- end of sequence
				name = name .. (GameSettings.GameCharMap[charByte] or Constants.HIDDEN_INFO)
			end
		end
		name = Utils.formatSpecialCharacters(name)
		self.MemValues.curName = name
		print("Current name:" .. self.MemValues.curName)

		--Get cur gender from memory
		local gender = Memory.readbyte(self.saveblock2Addr + 0x08)
		if(gender == 0) then gender = "Male" elseif(gender == 1) then gender = "Female" end
		self.MemValues.curGender = gender
		print("Current gender:" .. self.MemValues.curGender)

		--Get cur rival name from memory
		local rname = ""
		for i=0, 7, 1 do
			local charByte = Memory.readbyte((self.saveblock1Addr + 0x3A4C) + i)
			if charByte ~= 0xFF then -- end of sequence
				rname = rname .. (GameSettings.GameCharMap[charByte] or Constants.HIDDEN_INFO)
			end
		end
		self.MemValues.curRival = rname
		print("Current rival:" .. self.MemValues.curRival)
	end
	
	local function saveOptions()
		-- Save options to the Settings file
		TrackerAPI.saveExtensionSetting(self.Options.settingsName, "defaultName", self.Options.defaultName)
		TrackerAPI.saveExtensionSetting(self.Options.settingsName, "defaultGender", self.Options.defaultGender)
		TrackerAPI.saveExtensionSetting(self.Options.settingsName, "defaultRival", self.Options.defaultRival)
		--Reload Options to pickup new values
		checkMemory()
		loadOptions()
	end
	
	local function applyOptionsCallback(newName, newGender, newRival)
		if newName == nil or newName == "" or newGender == nil or newGender == "" or newRival == nil or newRival == "" then
			return
		end

		if self.Options.defaultName ~= newName then
			self.Options.defaultName = newName
			end
		if self.Options.defaultGender ~= newGender then
			self.Options.defaultGender = newGender
			end
		if self.Options.defaultRival ~= newRival then
			self.Options.defaultRival = newRival
			end
		saveOptions()
	end

	local function openOptionsPopup()
		Program.destroyActiveForm()
		local inputTextboxes = {}
		--Width, Height, Window Label
		local optionsDCM = forms.newform(300, 170, "DCM Settings", function() client.unpause() end)
		Program.activeFormId = optionsDCM
		Utils.setFormLocation(optionsDCM, 100, 50)
		--Form,Text,x,y,width,height
		forms.label(optionsDCM,"Choose default values",10,10,300,20)	
		forms.label(optionsDCM,"Default name:", 32,32,75,20)
		--form, caption,width,height,boxtype,x,y,multiline,fixedwidth,scrollbars
		self.textBoxName = forms.textbox(optionsDCM, self.Options.defaultName, 150, 20, nil, 110, 30)
		forms.label(optionsDCM,"Default gender:", 25,57,80,20)
		--form,items,x,y,w,h
		self.dropdownGender = forms.dropdown(optionsDCM, {"Male","Female"}, 110, 52, 150, 20)

		forms.settext(self.dropdownGender, self.Options.defaultGender)

		forms.label(optionsDCM,"Default rival name:", 10,78,95,20)
		self.textBoxRival = forms.textbox(optionsDCM, self.Options.defaultRival, 150, 20, nil, 110, 75)
		
		--formhandle, caption, clickevent, x, y, width, height
		forms.button(optionsDCM, "Save", function()
			local formInput = 
			applyOptionsCallback(forms.gettext(self.textBoxName),forms.gettext(self.dropdownGender),forms.gettext(self.textBoxRival))
			client.unpause()
			forms.destroy(optionsDCM)
		end, 60, 100)
		forms.button(optionsDCM, "Cancel", function()
			client.unpause()
			forms.destroy(optionsDCM)
		end, 150, 100)
	end
	-- Executed when the user clicks the "Options" button while viewing the extension details within the Tracker's UI
	-- Remove this function if you choose not to include a way for the user to configure options for your extension
	-- NOTE: You'll need to implement a way to save & load changes for your extension options, similar to Tracker's Settings.ini file
	function self.configureOptions()
		openOptionsPopup()
	end
	
	-- Executed when the user clicks the "Check for Updates" button while viewing the extension details within the Tracker's UI
	-- Returns [true, downloadUrl] if an update is available (downloadUrl auto opens in browser for user); otherwise returns [false, downloadUrl]
	-- Remove this function if you choose not to implement a version update check for your extension
	function self.checkForUpdates()
		local versionCheckUrl = "https://api.github.com/repos/tehkrizz/IronMon-Tracker-Extension-DefaultChoices/releases/latest"
		local versionResponsePattern = '"tag_name":%s+"%w+(%d+%.%d+)"' -- matches "1.0" in "tag_name": "v1.0"
		local downloadUrl = "https://github.com/tehkrizz/IronMon-Tracker-Extension-DefaultChoices/releases/latest"

		local isUpdateAvailable = Utils.checkForVersionUpdate(versionCheckUrl, self.version, versionResponsePattern, nil)
		return isUpdateAvailable, downloadUrl
	end

	-- Executed only once: When the extension is enabled by the user, and/or when the Tracker first starts up, after it loads all other required files and code
	function self.startup()
		-- [ADD CODE HERE]
	end



	-- Executed only once: When the extension is disabled by the user, necessary to undo any customizations, if able
	function self.unload()
		-- [ADD CODE HERE]
	end

	-- Executed once every 30 frames, after most data from game memory is read in
	function self.afterProgramDataUpdate()
		if not Program.isValidMapLocation() then
			return
		end
		--Trainer ID is tracked to allow it to run for a new game without a hard reset
		if self.curTrainer == nil or self.curTrainer ~= Tracker.Data.trainerID then
			self.updated = nil
			self.curTrainer = Tracker.Data.trainerID
		end
		--Proceed with extension once in game
		if self.updated == nil and Program.GameData.mapId == 1 then
				checkMemory()
				loadOptions()
		end
	end

	-- Executed once every 30 frames, after any battle related data from game memory is read in
	function self.afterBattleDataUpdate()
		-- [ADD CODE HERE]
	end

	-- Executed once every 30 frames or after any redraw event is scheduled (i.e. most button presses)
	function self.afterRedraw()
		-- [ADD CODE HERE]
	end

	-- Executed before a button's onClick() is processed, and only once per click per button
	-- Param: button: the button object being clicked
	function self.onButtonClicked(button)
		-- [ADD CODE HERE]
	end

	-- Executed after a new battle begins (wild or trainer), and only once per battle
	function self.afterBattleBegins()
		-- [ADD CODE HERE]
	end

	-- Executed after a battle ends, and only once per battle
	function self.afterBattleEnds()
		-- [ADD CODE HERE]
	end

	-- [Bizhawk only] Executed each frame (60 frames per second)
	-- CAUTION: Avoid unnecessary calculations here, as this can easily affect performance.
	function self.inputCheckBizhawk()
		-- Uncomment to use, otherwise leave commented out
			-- local mouseInput = input.getmouse() -- lowercase 'input' pulls directly from Bizhawk API
			-- local joypadButtons = Input.getJoypadInputFormatted() -- uppercase 'Input' uses Tracker formatted input
		-- [ADD CODE HERE]
	end

	-- [MGBA only] Executed each frame (60 frames per second)
	-- CAUTION: Avoid unnecessary calculations here, as this can easily affect performance.
	function self.inputCheckMGBA()
		-- Uncomment to use, otherwise leave commented out
			-- local joypadButtons = Input.getJoypadInputFormatted()
		-- [ADD CODE HERE]
	end

	-- Executed each frame of the game loop, after most data from game memory is read in but before any natural redraw events occur
	-- CAUTION: Avoid code here if possible, as this can easily affect performance. Most Tracker updates occur at 30-frame intervals, some at 10-frame.
	function self.afterEachFrame()
		-- [ADD CODE HERE]
	end

	return self
end
return DefaultChoices