script_name("police++")
script_version('0.01')

require 'libstd.deps' {
	'fyp:mimgui',
	'fyp:fa-icons-4',
	'donhomka:mimgui-addons',
	'fyp:samp-lua',
	'donhomka:extensions-lite@1.0.2'
}


require 'libstd.moonloader'
local imgui = require 'mimgui'
local faicons = require 'fa-icons'
local mimgui_addons = require 'mimgui_addons'
require 'extensions-lite'

local ffi = require 'ffi'
local encoding = require 'encoding'
local memory = require 'memory'
local bitex = require 'bitex'
local vkeys = require 'vkeys'

local sampev = require 'lib.samp.events'


encoding.default = 'CP1251'
local u8 = encoding.UTF8

local getBonePosition = ffi.cast("int (__thiscall*)(void*, float*, int, bool)", 0x5E4280) -- WallHack
ffi.cdef[[
     void keybd_event(int keycode, int scancode, int flags, int extra); 
]] -- EmulateKey(key, isDown) 

ffi.cdef[[
  struct HICON__ { int unused; };
  typedef struct HICON__ *HICON;
  typedef HICON HCURSOR;
  bool SetCursorPos(int X, int Y);
  HCURSOR SetCursor(HCURSOR hCursor);
]]

-- Search: Variables
local smallFont = renderCreateFont("Segoe UI", 9, FCR_BORDER + FCR_BOLD)
local bigFont = renderCreateFont("Tahoma", 30, FCR_BORDER + FCR_BOLD)
local resX, resY = getScreenResolution()	
local wallHack = false
local isWorkInBackground = imgui.new.bool(false)
local isFixLiterText = imgui.new.bool(false)
local workingDirectory = getWorkingDirectory()

local take_aim = false -- Автоприцеливание

-- [[ Массивы для исправления литерации в чатах/командах ]] --
local literCmd = {
	{"/r", true, true}, 
	{"/do", true, true}, 
	{"/b", true, true}, 
	{"/dep", true, true}, 
	{"/fb", true, true}, 
	{"/w", true, true}, 
	{"/aquestion", true, true}, 
	{"/m", true, true}, 
	{"/f", true, true}, 
	{"/me", false, false},
	{"/seeMe", false, true},
}
local blackWords = {"xd", ":d", "чв", "хд", "ку", "q"}

local imguiHelperWindow = imgui.new.bool()
local SuspectPlayerID = imgui.new.int(0)
local searchBuf = imgui.new.char[256]()
local scrollToReason = false
local list_ids = {}
local listArr = {}

local btn_size        = imgui.ImVec2(110,47) --размер кнопки
local selectable_size = imgui.ImVec2(147,40)
local btnlives_size   = imgui.ImVec2(100,40)
local btnadw_size     = imgui.ImVec2(90,60)
local adws_btn        = imgui.ImVec2(273,40)
local btn_size        = imgui.ImVec2(110,47)

local myName = ""
local myID = 0
local currentDate = ""
local currentTime = ""
local mySquare = ""
local myZone = ""
local myCompas = ""

local targetName = ""
local targetID = 0


local Ukodeks = {
	{"Нарушение порядка", "УК, 1", "1"},
	{"Хранение ключей", "УК, 2", "2"},
	{"Драка", "УК, 3", "2"},
	{"Ношение оружия в открытом виде", "УК, 4", "2"},
	{"Клевета", "УК, 5", "2"},
	{"Продажа оружия", "УК, 6", "2"},
	{"Подделка", "УК, 7", "2"},
	{"Неуплата штрафа", "УК, 8", "2"},
	{"Манифестация", "УК, 9", "2"},
	{"Порча имущества", "УК, 10", "2"},
	{"Угон", "УК, 11", "2"},
	{"Наезд на пешехода", "УК, 12", "3"},
	{"Выращивание наркотических веществ", "УК, 13", "3"},
	{"Проникновение", "УК, 14", "3"},
	{"Помеха", "УК, 15", "2"},
	{"Взятка", "УК, 16", "2"},
	{"Ношение оружия без лицензии", "УК, 17", "2"},
	{"Оскорбление", "УК, 18", "2"},
	{"Неподчинение", "УК, 19", "2"},
	{"Продажа гос. имущества", "УК, 20", "3"},
	{"Продажа наркотиков", "УК, 21", "3"},
	{"Хранение зап. веществ", "УК, 22", "3"},
	{"Употребление наркотиков", "УК, 23", "3"},
	{"Разбой", "УК, 24", "3"},
	{"Уход", "УК, 25", "3"},
	{"Кража", "УК, 26", "3"},
	{"Похищение", "УК, 27", "4"},
	{"Побег", "УК, 28", "4"},
	{"Нападение на военнослужащего", "УК, 29", "4"},
	{"Нападение на полицейского", "УК, 30", "5"},
	{"Нападение на Агента ФБР / Мэра", "УК, 31", "6"},
	{"Терроризм", "УК, 32", "6"},
	{"Срыв спец.операции", "УК, 34", "4"},
	{"Агитация", "УК, 35", "3"},
	{"Занятие проституцией", "УК, 36", "3"},
	{"Изнасилование", "УК, 37", "4"},
	{"Ложный вызов", "АК, 1", "1"},
}

local side_of_the_world_list = {
    "Север",
    "Северо-запад",
    "Запад",
    "Юго-запад",
    "Юг",
    "Юго-восток",
    "Восток",
    "Северо-восток"
}

local clickBinds = {
	{ "ПОЛИЦИЯ", 
		{
			{"Представиться", 
				{"Здравствуйте. Сотрудник полиции {myName}."}
			}, 
			{"Значок", 
				{"/do На груди значок Police Department LS."}
			},
			{"Миранда",  
				{"Вы имеете право хранить молчание. Всё, что вы скажете, может и будет использовано против вас в суде.", 
					"Ваш адвокат может присутствовать при допросе. Если вы не можете оплатить услуги адвоката...",
					"...он будет предоставлен вам государством. Вы понимаете свои права?"}
			}
		}
	},
	{ "КОМАНДЫ", 
		{
			{"Админы Online", 
				{"/admins"}
			}, 
			{"Members", 
				{"/members 1"}
			},
			{"Саппорты", 
				{"/supports"}
			}, 
			{"Strobe ON", 
				{"/strobe 0"}
			},
			{"Strobe OFF", 
				{"/strobe -1"}
			},
			{"CLIST [0]", 
				{"/clist 0"}
			},
			{"CLIST [19]", 
				{"/clist 19"}
			},
		}
	},
	{	"ТАКСИСТ", 
		{
			{"Приветствие", 
				{"Здравствуйте. Рад Вас видеть! Куда едем?"}
			}, 
			{"Уточнить", 
				{"Уточните конечную точку маршрута."}
			}, 
			{"Принять заказ", 
				{"Заказ принят! Выдвигаемся."}
			}, 
		}
	},
}

local tenCodes_1 = u8[[• 10-1 - Встреча всех офицеров на дежурстве >> локацию и код.
• 10-2 - Патрулирование >> Район/Округ и напарник.
• 10-3 - Радиомолчание >> Передаются только срочные сообщения.
• 10-4 - Принято/Так точно.
• 10-5 - Повторите последнее сообщение.
• 10-6 - Не принято/Не верно/Нет.
• 10-7 - Ожидайте.
• 10-8 - В настоящее время занят/не доступен >> Причина.
• 10-9 - В настоящее время занят/не доступен (детективы на ситуации).
• 10-11 - Режим Stand-by (Ожидание).
• 10-14 - Запрос транспортировки >> локацию и цель транспортировки.
• 10-15 - Подозреваемые арестованы >> количество задержанных и локацию.
• 10-18 - Требуется поддержка дополнительных юнитов.
• 10-20 - Локация.
• 10-21 - Сообщение о статусе и местонахождении, описание ситуации.
• 10-22 - Направление на локацию >> локацию и к кому идет обращение.
• 10-27 - Меняю маркировку патруля >> старую и новую маркировку.
• 10-40 - Большое скопление людей (4 и больше) >> локацию.
• 10-41 - Нелегальная активность.
• 10-46 - Проведение обыска.
• 10-55 - Траффик стоп.
• 10-56 - Запрос информации о подозреваемом (mdc) >> 
			   номер и марку машины / Имя Фамилию.
• 10-57 - Погоня за автомобилем >> номер/марку/цвет транспорта и его направление.
• 10-58 - Пешая погоня >> приметы подозреваемого, вооружен ли он и направление.
• 10-60 - Информация об автомобиле >> номер/марку/цвет транспорта, 
		       информацию о владельце и кол-во пассажиров.
• 10-61 - Информация о пешем подозреваемом >> пол/расу, 
			   одежду и Имя Фамилию(если известно).
• 10-66 - Остановка повышенного риска (подозреваемый вооружен/совершил 
			   преступление. Если остановка после погони).
• 10-70 - Запрос поддержки >> требуемое количество юнитов 
			   и код описывающий ситуацию.
• 10-71 - Запрос медицинской поддержки.
• 10-99 - Ситуация урегулирована.]]
local tenCodes_2 = u8[[• CODE 0 - Необходима немедленная поддержка. Подаётся когда офицер на земле 
			       (ранен/убит). Офицеры не имею права не реагировать на данный сигнал.
• CODE 1 - Офицер в бедственном положении и ему требуется немедленная 
			       поддержка.
• CODE 2 - Срочный вызов (без сирен/стробоскопов)
• CODE 3 - Срочный вызов (с сиренами/стробоскопами)
• CODE 4 - Помощь не требуется.
• CODE 4.1 - Подозреваемый скрылся, все, кто присоединился, 
			          должны отправиться на поиски в указанном районе.
• CODE 6 - Задерживаюсь на (включая локацию)
• CODE 7 - К офицерам применили смертоносное оружие (( ДБ/ДМ ))

• ADAM (A) — Юнит из двух вооруженных офицеров на маркированном транспорте. 
			             От Офицера совместно с Офицер и выше.
• LINCOLN (L) — Юнит из одного вооруженного офицера на маркированном 
			                 транспорте. От Сержант и выше.
• MARY (M) MOTORCYCLE UNIT — Мотоцикл патруль-дивизиона, для 
			                контроля трафика и преследования двухколесного т/с.
 • AIR (AIR) — Вертолет воздушной поддержки. Для пилотов соотв. дивизиона.]]
 
 
local items = {
      ["Char"] = {
        {
          title = u8"Наручники",
          func = function ()
			lua_thread.create(function()
				sampSendChat("/me достал из чехла на поясе наручники")
				wait(1700)
				sampSendChat("/cuff {targetid}")
			end)
          end
        },
        {
          title = u8"Обыскать",
          func = function ()
				lua_thread.create(function()
					sampSendChat("/me надел перчатки, похлопал {targetName} по рукам и туловищу")
					wait(1700)
					sampSendChat("/frisk {targetid}")
				end)
			end
        },
        {
          title = u8"Вести за собой",
          func = function ()
            	lua_thread.create(function()
					sampSendChat("/me схватил {targetName} и повёл за собой")
					wait(1700)
					sampSendChat("/follow {targetid}")
				end)
          end
        },
        {
          title = u8"Усадить в тачку",
          func = function ()
            lua_thread.create(function()
				sampSendChat("/me затащил {targetName} в транспорт")
				wait(1700)
				sampSendChat("/cput {targetid}")
			end)
          end
        },
        {
          title = u8"Арестовать",
          func = function ()
            	lua_thread.create(function()
				sampSendChat("/me сунул руку в карман, достал из него связку ключей и открыл камеру")
				wait(1700)
				sampSendChat("/arrest {targetid}")
				wait(1700)
				sampSendChat("/me толкнул {targetName} в камеру, после чего закрыл её")
			end)
          end
        },
		{
          title = u8"Изъять лицензию",
          func = function ()
            	lua_thread.create(function()
				sampSendChat("/me достал КПК и аннулировал лицензию {targetName} по базе данных")
				wait(1700)
				sampSendChat("/take {targetid}")
			end)
          end
        },
		{
          title = u8"Протокол допроса",
          func = function ()
            	lua_thread.create(function()
				sampSendChat("/me начал заполнять протокол на имя {targetName} под номером {targetid}")
				wait(1700)
				sampSendChat("/do На столе лежит мокрая печать участка LSPD.")
				wait(1700)
				sampSendChat("/me поставил печать на протоколе и закрыл дело {targetid}")
			end)
          end
        },
      },
      ["Car"] = {
        {
          title = faicons.ICON_CAR .. u8" Заправить",
          func = function ()
            sampSendChat("/fill")
          end
        },
        {
          title = faicons.ICON_TINT .. u8" Канистра",
          func = function ()
            sampSendChat("/fillcar")
          end
        },
        {
          title = faicons.ICON_LOCK .. u8" Дверной замок",
          func = function ()
            sampSendChat("/lock")
          end
        },
      }
    }

function main()
	if not isSampfuncsLoaded() or not isSampLoaded() then return end
	while not isSampAvailable() do wait(100) end
	
	--autoupdate("https://gist.githubusercontent.com/unkface/93b4968c827ac6a69b6af82d3c6f0d36/raw/d0256a43fac47725fb675c607f9038bafe57e3ac/test", '['..string.upper(thisScript().name)..']: ', "http://vk.com/dobrovr")
	
	while true do	
		getVariables()
		Binder()
		screenRender()
		renderSkelets()	
		other()		

		wait(0)
	end
end

function getVariables()	
	myName = sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))):gsub("_", " ")
	myID = select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))
	
	if sampIsPlayerConnected(targetID) == false then
		targetID = myID
	end
	
	targetName = sampGetPlayerNickname(targetID):gsub("_", " ")
	
	currentDate = os.date("%d/%m/%Y")
	currentTime = os.date("%X")
	
	
	local myX, myY, myZ = getCharCoordinates(PLAYER_PED)	

	mySquare = getMySquareName()
	myZone = calculateZone(myX, myY, myZ)
	myCompas = side_of_the_world_list[GetPlayerFacingDirection(PLAYER_PED, getCharHeading(PLAYER_PED))]
	
	args = {
	{	"{myName}", "Ваш ник", myName	},
	{	"{myid}", "Ваш ID", myID	},
	
	{	"{targetid}", "ID цели", targetID	},
	{	"{targetName}", "Ник цели", targetName	},
	
	{	"{date}", "Дата", currentDate	},
	{	"{time}", "Время", currentTime	},
	{	"{square}", "Сектор", mySquare	},
	{	"{zone}", "Район", myZone	},
	{	"{compas}", "Компас", myCompas	},
	{	"{partners}", "Напарники", getMyPassengers() }
}
end

function screenRender()
	--local _, rr, gg, bb = explode_argb(sampGetPlayerColor(playerPed))
	--local color = join_argb(255, rr, gg, bb)
	--renderFontDrawText(bigFont, playerPed, resX - 40, 2, color)
	--[[local in1 = getStructElement(sampGetInputInfoPtr(), 0x8, 4)
	local in2 = getStructElement(in1, 0x8, 4) + 10	
	local in3 = getStructElement(in1, 0xC, 4) + 50]]

	if isPauseMenuActive() and isKeyDown(VK_F8) then	
		if wallHack == true then wallHackSet(false) end
		while isPauseMenuActive() or isKeyDown(VK_F8) do wait(0) end
		if wallHack == true then wallHackSet(true) end	

			--[[   СЕКЦИЯ #2    ]]
			--[[renderFontDrawText(smallFont, "ДОКЛАДЫ", centerTextOnScreen(smallFont, "ДОКЛАДЫ"), resY, 0xFF4D4D4D)
			
			resY = resY + indent
			if drawClickableText(smallFont, "Принять запрос", centerTextOnScreen(smallFont, "Принять запрос"), resY, 0xFFC4C4C4, 0xFFFFDA00) then
				if isEmpty(getMyPassengers()) then
					sampSendChat("/r Принял. Напарник: "..getMyPassengers())
				else
					sampSendChat("/r Принял.")
				end
			end	]]								
	end
end


function Binder()
	local veh = getCarCharIsUsing(PLAYER_PED)
	if isKeyJustPressed(VK_DELETE) then
		take_aim = not take_aim
	end				
	if take_aim and veh == -1 then
		setGameKeyState(6, 65535)
	end
		
	--[[local handle = select(2, getCharPlayerIsTargeting(PLAYER_HANDLE))
	local result_handle, id = sampGetPlayerIdByCharHandle(handle)		
	if result_handle then 
		if getDistanceToPlayer(id) <= 8 then	
			local string = ""
			for i = 1, #targetBinds do
				string = string.format("%s {%s}[%s] %s\n", string, i % 2 == 0 and "B8B8B8" or "FFAB00", vkeys.id_to_name(targetBinds[i][1]), targetBinds[i][2])
				if isKeyJustPressed(targetBinds[i][1]) then
					lua_thread.create(function()
						for d = 1, #targetBinds[i][3] do
							sampSendChat(targetBinds[i][3][d])
							wait(1800)
						end
					end)
				end
			end

			renderFontDrawText(smallFont, string, resX/2.5, resY/2, 0xFFFFFFFF)
			targetSuspectPlayerID[0] = id			
		end		


	else]]
	if not sampIsChatInputActive() and not isSampfuncsConsoleActive() then
		if sampIsDialogActive() then
			if sampGetCurrentDialogId() == 245 then
				for i = VK_1, VK_7 do
					if isKeyJustPressed(i) then 
						sampSendDialogResponse(245, 1, vkeys.id_to_name(i) - 1, nil)
					end
				end	
			end
		else
			if isKeyJustPressed(VK_L) then
				sampSendChat("/lock")	
				
			elseif isKeyDown(VK_MENU) and isKeyJustPressed(VK_1) then
				sampSendChat("Оставайтесь на месте!")	

			elseif isKeyJustPressed(VK_NUMPAD0) then
				sampSendChat("/seeMe коснулся задней части автомобиля")	
			
			elseif isKeyDown(VK_MENU) and isKeyJustPressed(VK_R) then
				sampSetChatInputEnabled(true) sampSetChatInputText("/r [PS:PO-I]: ")	
				
				
			elseif isKeyJustPressed(VK_F2) then
				imguiHelperWindow[0] = not imguiHelperWindow[0]

			elseif isKeyJustPressed(VK_F3) then
				if imguiHelperWindow[0] == false then
					imguiHelperWindow[0] = true
					selected = 1
					selectedd = 3
				else
					imguiHelperWindow[0] = false
				end
				
											
			elseif isKeyJustPressed(VK_DECIMAL) then -- Num .
				sampSendChat("/me резким движением снял контактно-дистанционный электрошокер с пояса")			
				
			elseif isKeyJustPressed(VK_X) then
				wallHack = not wallHack
				wallHackSet(wallHack)	
				
			--sampTextdrawCreate(102, "VK-Int", 600, 435) sampTextdrawDelete(102)
								
			elseif isKeyDown(VK_MENU) and isKeyJustPressed(VK_3) then -- ALT + 3
				lua_thread.create(function()
					targetID = getnear()	
					local result, target_handle = sampGetCharHandleBySampPlayerId(targetID)
					if result and getDistanceToPlayer(targetID) <= 4 then

						if isCharOnAnyBike(target_handle) then
							sampSendChat("/me заломал руку {targetName} и стащил с мотоцикла")
						else
							sampSendChat("/me открыл дверь транспорта и потащил {targetName} за собой")
						end
						wait(1600)
						sampSendChat("/ceject {targetid}")
					end
				end)
				
			elseif wasKeyPressed(VK_ESCAPE) then
			--	imguiHelperWindow[0] = false	
				
			end	
			if veh ~= -1 then	
				if isKeyJustPressed(VK_NUMPAD1) then -- NUM1
					sampSendChat("/m Водитель, прижмитесь правее и остановитесь!")
				elseif isKeyJustPressed(VK_NUMPAD2) then
					sampSendChat("/m Водитель, заглушите двигатель и положите руки на руль.")
				end
				
				if getDriverOfCar(veh) == PLAYER_PED then
					if isKeyJustPressed(VK_C) then
						switchCarSiren(veh, not isCarSirenOn(veh) )
					end
				end	
			end
		end
	end
end


function other()
--[[
	if str2 ~= nil then
			wait(1800)
			sampSendChat(str2)	
			str2 = nil
	end
]]
end

function openSuspectWindow()
	suspect[0] = not suspect[0]
	if suspect[0] == false then
		imgui.StrCopy(searchBuf, '')
	end
end


function getnear()
    local lastchar = {}
    local mx, my, mz = getCharCoordinates(PLAYER_PED)

    for _, v in pairs( getAllChars() ) do
        if doesCharExist(v) and v ~= 1 then
			local id = select(2, sampGetPlayerIdByCharHandle(v))
			if not IsPlayerCop(id)  then
				local x, y, z = getCharCoordinates(v)
				if lastchar[1] == nil then
					local distance = getDistanceBetweenCoords2d(mx, my, x, y)
					lastchar = {v, distance}
				else
					local distance = getDistanceBetweenCoords2d(mx, my, x, y)
					if tonumber(lastchar[2]) > tonumber(distance) then
						lastchar = {v, distance}
					end
				end
			end
        end
    end

    if lastchar[1] ~= nil then	
		return select(2, sampGetPlayerIdByCharHandle(lastchar[1]))
    end
end



function getNearCarAndDriver()
	local lastcar = {}
	local mx, my, mz = getCharCoordinates(PLAYER_PED)

	for _, v in pairs( getAllVehicles() ) do
		if doesVehicleExist(v) and v ~= getCarCharIsUsing(PLAYER_PED) and getDriverOfCar(v) ~= -1 and getCarSpeed(v) > 3 then

			local x, y, z = getCarCoordinates(v)
			local distance = getDistanceBetweenCoords2d(mx, my, x, y)
			if lastcar[1] == nil then
				lastcar = {v, distance}
			else
				if tonumber(lastcar[2]) > tonumber(distance) then
					lastcar = {v, distance}
				end
			end

		end
	end

	if lastcar[1] ~= nil then	
		local driverid = select(2, sampGetPlayerIdByCharHandle(getDriverOfCar(lastcar[1])))
		return lastcar[1], driverid
	end
end



function IsPlayerCop(playerid) 
	local result, skinid = sampGetPlayerSkin(playerid)
	if result then 
		local police_skins = {76, 280, 281, 266, 284, 307, 265, 282, 267, 285, 288, 283, 265, 267, 309, 310, 311, 303, 304, 305, 306, 300, 301, 302}
		for i = 1, #police_skins do
			if police_skins[i] == skinid then return 1 end
		end
	end
end

function sampGetPlayerSkin(id)
    if not id or not sampIsPlayerConnected(tonumber(id)) and not tonumber(id) == myID then return false end -- проверяем параметр
    local isLocalPlayer = tonumber(id) == myID -- проверяем, является ли цель локальным игроком
    local result, handle = sampGetCharHandleBySampPlayerId(tonumber(id)) -- получаем CharHandle по SAMP-ID
    if not result and not isLocalPlayer then return false end -- проверяем, валиден ли наш CharHandle
    local skinid = getCharModel(isLocalPlayer and PLAYER_PED or handle) -- получаем скин нашего CharHandle
    if skinid < 0 or skinid > 311 then return false end -- проверяем валидность нашего скина, сверяя ID существующих скинов SAMP
    return true, skinid -- возвращаем статус и ID скина
end

function writeChatLog(string)
	local chatLogFile = io.open(workingDirectory.."\\HELPER\\chatbox_all.txt", "a")
	chatLogFile:write(string.format("[%s] %s\n", os.date("%d-%m-%Y || %X"), string))
	chatLogFile:close()
end

function onSystemInitialized()
	writeChatLog(("Session started at %s"):format(os.date("%d/%m/%Y")))
end

function onScriptTerminate(script, quitGame) -- действия при отключении скрипта
	if script == thisScript() then
		if quitGame then			
			writeChatLog("Logging ended\n")
		else
			if wallHack == true then wallHackSet(false) end
			if isWorkInBackground[0] == true then isWorkInBackground[0] = false workInBackgroundSet() end
		end
	end
end

function sampev.onServerMessage(color, text)
	writeChatLog(text)	
end

function sampev.onSendCommand(command)
	for i = 1, #literCmd do 
		local text = string.match(command, "^%"..literCmd[i][1].." (.*)") 
		if text then
			command = string.format("%s %s", literCmd[i][1], fixLiterText(text, literCmd[i][2], literCmd[i][3]))
		end
	end		
	return { string.format("%s", tags(command)) }
end

function sampev.onSendChat(message)
	for i = 1, #blackWords do 
		if string.lower2(message) == blackWords[i] then
			return true
		end
	end	
	--[[if string.len(message) >= 75 then
		local str = string.sub(message, 0, 75)
		str2 = string.gsub(message, str, "...", 1)
		message = str.."..."
	end]]

	return {fixLiterText(tags(message), true, true)}
end

function fixLiterText(s, upcorrect, pointcorrect)
	if string.find(s, "%S+$") then
		if upcorrect == true then 
			s = s:gsub("%S", string.upper2, 1)
		end
		if pointcorrect == true then
			if string.find(s, "%P$") then
				s = s.."."
			end
		end
	else
		s = s:gsub("%s+$", "")
	end
	return s
end

function isEmpty(x)
	return not tostring(x):find("^%s*$")
end

function join_argb(a, r, g, b)
	local argb = b  -- b
	argb = bit.bor(argb, bit.lshift(g, 8))  -- g
	argb = bit.bor(argb, bit.lshift(r, 16)) -- r
	argb = bit.bor(argb, bit.lshift(a, 24)) -- a
	return argb
end

function explode_argb(argb)
	local a = bit.band(bit.rshift(argb, 24), 0xFF)
	local r = bit.band(bit.rshift(argb, 16), 0xFF)
	local g = bit.band(bit.rshift(argb, 8), 0xFF)
	local b = bit.band(argb, 0xFF)
	return a, r, g, b
end

function argb_to_rgb(argb)
	return bit.band(argb, 0xFFFFFF)
end

function wallHackSet(en)
	local pStSet = sampGetServerSettingsPtr()
	if en == true then		
		NTdist = memory.getfloat(pStSet + 39)
		NTwalls = memory.getint8(pStSet + 47)
		NTshow = memory.getint8(pStSet + 56)
		memory.setfloat(pStSet + 39, 1488.0)
		memory.setint8(pStSet + 47, 0)
		memory.setint8(pStSet + 56, 1)
	else
		memory.setfloat(pStSet + 39, NTdist)
		memory.setint8(pStSet + 47, NTwalls)
		memory.setint8(pStSet + 56, NTshow)	
	end	
end

function renderSkelets()
	if wallHack then
		for k, ped in pairs(getAllChars()) do
			if isCharOnScreen(ped) and ped ~= PLAYER_PED then
				local result, i = sampGetPlayerIdByCharHandle(ped)
				if result then
					local color = sampGetPlayerColor(i)
					local aa, rr, gg, bb = explode_argb(color)
					color = join_argb(255, rr, gg, bb)
					local pos1X, pos1Y, pos1Z, pos2X, pos2Y, pos2Z, pos1, pos2, pos3, pos4
					local t = {3, 4, 5, 51, 52, 41, 42, 31, 32, 33, 21, 22, 23, 2}
					for v = 1, #t do
						pos1X, pos1Y, pos1Z = getBodyPartCoordinates(t[v], ped)
						pos2X, pos2Y, pos2Z = getBodyPartCoordinates(t[v] + 1, ped)
						pos1, pos2 = convert3DCoordsToScreen(pos1X, pos1Y, pos1Z)
						pos3, pos4 = convert3DCoordsToScreen(pos2X, pos2Y, pos2Z)	
						renderDrawLine(pos1, pos2, pos3, pos4, 1, color)
					end
					for v = 4, 5 do
						pos2X, pos2Y, pos2Z = getBodyPartCoordinates(v * 10 + 1, ped)
						pos3, pos4 = convert3DCoordsToScreen(pos2X, pos2Y, pos2Z)
						renderDrawLine(pos1, pos2, pos3, pos4, 1, color)
					end			
				end		
			end
		end
	end	
end

function getBodyPartCoordinates(id, handle)
	local pedptr = getCharPointer(handle)
	local vec = ffi.new("float[3]")
	getBonePosition(ffi.cast("void*", pedptr), vec, id, true)
	return vec[0], vec[1], vec[2]
end


function workInBackgroundSet()
	--workInBackground[0] = not workInBackground[0]
	if isWorkInBackground[0] then	
		memory.setuint8(7634870, 1)
        memory.setuint8(7635034, 1)
        memory.fill(7623723, 144, 8)
        memory.fill(5499528, 144, 6)
		memory.fill(0x00531155, 0x90, 5, true) -- Фиксим прыжок на shift при аафк.
		memory.write(7634870, 1, 1, true)
		memory.write(7635034, 1, 1, true)
		print("{FFD500}AAFK {00DF0F}[ON]")
	else 
        memory.setuint8(7634870, 0)
        memory.setuint8(7635034, 0)
        memory.hex2bin('5051FF1500838500', 7623723, 8)
        memory.hex2bin('0F847B010000', 5499528, 6)
		print("{FFD500}AAFK {FF0000}[OFF]")	
	end
end	


function drawClickableText(font, text, posX, posY, color, colorA)
   renderFontDrawText(font, text, posX, posY, color)
   local textLenght = renderGetFontDrawTextLength(font, text)
   local textHeight = renderGetFontDrawHeight(font)
   local curX, curY = getCursorPos()
   if curX >= posX and curX <= posX + textLenght and curY >= posY and curY <= posY + textHeight then
		renderFontDrawText(font, text, posX, posY, colorA)
		if isKeyJustPressed(VK_LBUTTON) then
			return true
		end
   end
end

function getDistanceToPlayer(playerId) -- дистанция до игрока
	if not sampIsPlayerConnected(playerId) then return end
	local result, ped = sampGetCharHandleBySampPlayerId(playerId)
	if result and doesCharExist(ped) then
		local myX, myY, myZ = getCharCoordinates(PLAYER_PED)
		local playerX, playerY, playerZ = getCharCoordinates(ped)
		return getDistanceBetweenCoords3d(myX, myY, myZ, playerX, playerY, playerZ)
	end
	return nil
end

function getMySquareName()
	if getActiveInterior() ~= 0 then return "Неизвестно" end
    local squares = {"А", "Б", "В", "Г", "Д", "Ж", "З", "И", "К", "Л", "М", "Н", "О", "П", "Р", "С", "Т", "У", "Ф", "Х", "Ц", "Ч", "Ш", "Я",
    }	
    local xCoord, yCoord = getCharCoordinates(PLAYER_PED)
    return squares[math.ceil((yCoord * - 1 + 3000) / 250)] .."-".. math.ceil((xCoord + 3000) / 250)
end

function getMyPassengers()
	local carHandle = getCarCharIsUsing(PLAYER_PED)
	local all_passengers = ""
	if carHandle ~= -1 then
		for i = -1, getMaximumNumberOfPassengers(carHandle) - 1 do
			local n = getPassengerByPlace(carHandle, i)
			if n ~= -1 and IsPlayerCop(n) and n ~= myID then
				local name, surname = string.match(sampGetPlayerNickname(n), "(%g+)_(%g+)")
				local exname = string.match(name, "(%g)")
		  		if all_passengers == "" then
		  			all_passengers = string.format("%s.%s", exname, surname)
				else
		  			all_passengers = string.format("%s, %s.%s", all_passengers, exname, surname)
				end
			end
		end
	end
  	return all_passengers
end

function getPassengerByPlace(car, placeid)
	if not isCarPassengerSeatFree(car, placeid) then
		local ped = getCharInCarPassengerSeat(car, placeid)
		local _, playerid = sampGetPlayerIdByCharHandle(ped)
		return playerid
	end
end

function centerTextOnScreen(font, text) 
	return (resX - renderGetFontDrawTextLength(font, text)) / 2 end

function getCrosshairPosition()
	local chOff1 = memory.getfloat(0xB6EC10)
	local chOff2 = memory.getfloat(0xB6EC14)
	return convertWindowScreenCoordsToGameScreenCoords(resX * chOff2, resY * chOff1)
end

function string.upper2(s)
    return s:gsub("([а-я])",function(str) return string.char(str:byte()-32) end):gsub("ё", "Ё"):upper()
end

function string.lower2(s)
    return s:gsub("([А-Я])",function(str) return string.char(str:byte()+32) end):gsub("Ё", "ё"):lower()
end

function apply_custom_style()
    local style = imgui.GetStyle()
    local colors = style.Colors
    local clr = imgui.Col
    local ImVec4 = imgui.ImVec4
    style.ButtonTextAlign = imgui.ImVec2(0.5, 0.5)
    style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
    style.FrameRounding = 0.5
    style.ItemSpacing = imgui.ImVec2(5.0, 4.0)
    style.ScrollbarSize = 13.0
    style.ScrollbarRounding = 0
    style.GrabMinSize = 8.0
    style.GrabRounding = 0.5
    style.Alpha = 1
    style.WindowPadding = imgui.ImVec2(4.0, 4.0)
    style.FramePadding = imgui.ImVec2(3.5, 3.5)
	style.WindowBorderSize = 0.0
	style.FrameBorderSize = 1.0

	colors[clr.Text] 				   = ImVec4(1.00, 1.00, 1.00, 1)
    colors[clr.TextDisabled]           = ImVec4(0.50, 0.50, 0.50, 1.00)
    colors[clr.WindowBg]               = ImVec4(0.06, 0.06, 0.06, 0.95) --ImVec4(0.06, 0.06, 0.06, 0.91)
    colors[clr.PopupBg]                = ImVec4(0.08, 0.08, 0.08, 0.94)
    colors[clr.Border]                 = ImVec4(0.43, 0.43, 0.50, 0.50) --0.43, 0.43, 0.50, 0.50
    colors[clr.BorderShadow]           = ImVec4(0.00, 0.00, 0.00, 0.00)
    colors[clr.FrameBg]                = ImVec4(0.12, 0.12, 0.12, 0.94)
    colors[clr.FrameBgHovered]         = ImVec4(0.45, 0.45, 0.45, 0.85)
    colors[clr.FrameBgActive]          = ImVec4(0.63, 0.63, 0.63, 0.63)
    colors[clr.TitleBg]                = ImVec4(0.13, 0.13, 0.13, 0.99)
    colors[clr.TitleBgActive]          = ImVec4(0.13, 0.13, 0.13, 0.99)
    colors[clr.TitleBgCollapsed]       = ImVec4(0.05, 0.05, 0.05, 0.79)
    colors[clr.MenuBarBg]              = ImVec4(0.14, 0.14, 0.14, 1.00)
    colors[clr.ScrollbarBg]            = ImVec4(0.02, 0.02, 0.02, 0.53)
    colors[clr.ScrollbarGrab]          = ImVec4(0.31, 0.31, 0.31, 1.00)
    colors[clr.ScrollbarGrabHovered]   = ImVec4(0.41, 0.41, 0.41, 1.00)
    colors[clr.ScrollbarGrabActive]    = ImVec4(0.51, 0.51, 0.51, 1.00)
    colors[clr.CheckMark]              = ImVec4(1.00, 1.00, 1.00, 1.00)
    colors[clr.SliderGrab]             = ImVec4(0.28, 0.28, 0.28, 1.00)
    colors[clr.SliderGrabActive]       = ImVec4(0.35, 0.35, 0.35, 1.00)
    colors[clr.Button]                 = ImVec4(0.12, 0.12, 0.12, 0.94)
    colors[clr.ButtonHovered]          = ImVec4(0.34, 0.34, 0.35, 0.89)
    colors[clr.ButtonActive]           = ImVec4(0.21, 0.21, 0.21, 0.81)
    colors[clr.Header]                 = ImVec4(0.12, 0.12, 0.12, 0.94)
    colors[clr.HeaderHovered]          = ImVec4(0.12, 0.12, 0.12, 0.94)
    colors[clr.HeaderActive]           = ImVec4(0.16, 0.16, 0.16, 0.90)
    colors[clr.Separator]              = colors[clr.Border]
    colors[clr.SeparatorHovered]       = ImVec4(0.26, 0.59, 0.98, 0.78)
    colors[clr.SeparatorActive]        = ImVec4(0.26, 0.59, 0.98, 1.00)
    colors[clr.ResizeGrip]             = ImVec4(0.26, 0.59, 0.98, 0.25)
    colors[clr.ResizeGripHovered]      = ImVec4(0.26, 0.59, 0.98, 0.67)
    colors[clr.ResizeGripActive]       = ImVec4(0.26, 0.59, 0.98, 0.95)
    colors[clr.PlotLines]              = ImVec4(0.61, 0.61, 0.61, 1.00)
    colors[clr.PlotLinesHovered]       = ImVec4(1.00, 0.43, 0.35, 1.00)
    colors[clr.PlotHistogram]          = ImVec4(0.90, 0.70, 0.00, 1.00)
    colors[clr.PlotHistogramHovered]   = ImVec4(1.00, 0.60, 0.00, 1.00)
    colors[clr.TextSelectedBg]         = ImVec4(0.26, 0.59, 0.98, 0.35)
end
 
imgui.OnInitialize(function()
	apply_custom_style() -- применим кастомный стиль
	local defGlyph = imgui.GetIO().Fonts.ConfigData.Data[0].GlyphRanges

	--imgui.GetIO().Fonts:Clear() -- очистим шрифты
	local font_config = imgui.ImFontConfig() -- у каждого шрифта есть свой конфиг
	font_config.SizePixels = 14.0;
	font_config.GlyphExtraSpacing.x = 0.05
	
   -- основной шрифт
	--local def = imgui.GetIO().Fonts:AddFontFromFileTTF(getFolderPath(0x14) .. '\\arialbd.ttf', font_config.SizePixels, font_config, defGlyph) -- основной шрифт
	
	font_config.MergeMode = true
	font_config.PixelSnapH = true
	font_config.FontDataOwnedByAtlas = false
	font_config.GlyphOffset.y = 1.0 -- смещение на 1 пиксеот вниз
	local fa_glyph_ranges = imgui.new.ImWchar[3]({ faicons.min_range, faicons.max_range, 0 })
	-- иконки
	local faicon = imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(faicons.get_font_data_base85(), font_config.SizePixels, font_config, fa_glyph_ranges)

	imgui.GetIO().ConfigWindowsMoveFromTitleBarOnly = true
	
end)

--[[imgui.Cond = {
    Always = 1, -- Всегда исполняетс
    Once = 2, -- Один раз
    FirstUseEver = 4, -- Единожды при вызове
    Appearing = 8, -- При открытии окна
}]]
local item_hovered = -1;
local menuOpen = true
local f
f = imgui.OnFrame(function () return true end,
function()	
	f.HideCursor = true
	local data = {}
	-- TARGET BAR
	local element = getTargetOnDistance(3.0)
	if element.exists then
		if element.eType == "Char" then
			local ped = element.value
			local result, id = sampGetPlayerIdByCharHandle(ped)
			if result and not sampIsPlayerNpc(id) then
				targetID = id
				data.id = id
				data.name = sampGetPlayerNickname(id)
				data.health = sampGetPlayerHealth(id)
				data.maxHealth = 100
				data.armor = sampGetPlayerArmor(id)
				data.maxArmor = 100
			end
		elseif element.eType == "Car" then
			local car = element.value
			local result, id = sampGetVehicleIdByCarHandle(car)
			if result then
			  local model = getCarModel(car)
			  data.id = id
				data.name = getNameOfVehicleModel(model)
			  data.health = getCarHealth(car)
			  data.maxHealth = 1000
			end
		end
	end
	if data.name then
		imgui.SetNextWindowBgAlpha(0.4)
		imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, 40), nil, imgui.ImVec2(0.5, 0.5))
		imgui.SetNextWindowSize(imgui.ImVec2(240, data.armor and 62 or 48))
		imgui.Begin("##overlay", nil, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoMove + imgui.WindowFlags.NoResize)
		local DrawList = imgui.GetWindowDrawList()
		local textSize = imgui.CalcTextSize(("%s[%d]"):format(data.name, data.id))
		imgui.SetCursorPos(imgui.ImVec2(120 - (textSize.x / 2), 3))
		imgui.Text(("%s[%d]"):format(data.name, data.id))
		local pos = imgui.GetCursorScreenPos()
		local textSize = imgui.CalcTextSize(tostring(data.health))
		local maxw = 240 - (imgui.GetStyle().WindowPadding.x * 2)
		local resX = (data.health / data.maxHealth) * maxw
		resX = resX > maxw and maxw or resX
		DrawList:AddRectFilled(pos, imgui.ImVec2(pos.x + maxw, pos.y + 11), 0x601D19B4, 2.0)
		if resX > 0 then
			DrawList:AddRectFilled(pos, imgui.ImVec2(pos.x + resX, pos.y + 11), 0xFF1D19B4, 2.0)
		end
		DrawList:AddText(imgui.ImVec2(pos.x + 119 - (textSize.x / 2), pos.y + 5 - (textSize.y / 2)), 0xFFFFFFFF, tostring(data.health))
		imgui.SetCursorScreenPos(imgui.ImVec2(pos.x, pos.y + 11 + imgui.GetStyle().ItemSpacing.y))
		if data.armor then
			local pos = imgui.GetCursorScreenPos()
			local textSize = imgui.CalcTextSize(tostring(data.armor))
			local maxw = 240 - (imgui.GetStyle().WindowPadding.x * 2)
			local resX = (data.armor / data.maxArmor) * maxw
			resX = resX > maxw and maxw or resX
			DrawList:AddRectFilled(pos, imgui.ImVec2(pos.x + maxw, pos.y + 11), 0x60E1E1E1, 2.0)
			if resX > 0 then
				DrawList:AddRectFilled(pos, imgui.ImVec2(pos.x + resX, pos.y + 11), 0xFFE1E1E1, 2.0)
			end
			DrawList:AddText(imgui.ImVec2(pos.x + 119 - (textSize.x / 2), pos.y + 5 - (textSize.y / 2)), 0xFFFFFFFF, tostring(data.armor))
			imgui.SetCursorScreenPos(imgui.ImVec2(pos.x, pos.y + 11 + imgui.GetStyle().ItemSpacing.y))
		end
		local pos = imgui.GetCursorScreenPos()
		local textSize = imgui.CalcTextSize("Press Z")
		DrawList:AddText(imgui.ImVec2(pos.x + 119 - (textSize.x / 2), pos.y - 4), 0xFFE1E1E1, "Press Z")
		imgui.End()
	end
	
	if element.exists and imgui.IsKeyDown(vkeys.VK_Z) and not sampIsChatInputActive() and ShowImgui() and imguiHelperWindow[0] == false then
		f.HideCursor = false
		imgui.SetNextWindowBgAlpha(0.0)
		imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), nil, imgui.ImVec2(0.5, 0.5))
		imgui.SetNextWindowSize(imgui.ImVec2(400, 400))
		imgui.Begin("##menu", nil, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoMove + imgui.WindowFlags.NoResize)
		local style = imgui.GetStyle()
		local RADIUS_MIN = 60.0;
		local RADIUS_MAX = 200.0;
		local RADIUS_INTERACT_MIN = 20.0;
		local DrawList = imgui.GetWindowDrawList()
		local IM_PI = 3.14159265358979323846
		local center = imgui.ImVec2(resX / 2, resY / 2)
		local drag_delta = imgui.ImVec2(imgui.GetIO().MousePos.x - center.x, imgui.GetIO().MousePos.y - center.y)
		local drag_dist2 = drag_delta.x*drag_delta.x + drag_delta.y*drag_delta.y;
		local items_count = #items[element.eType]
	  
	  DrawList:PushClipRectFullScreen();
	  DrawList:PathArcTo(center, (RADIUS_MIN + RADIUS_MAX)*0.5, 0.0, IM_PI*2.0*0.98, 64);   -- FIXME: 0.99f look like full arc with closed thick stroke has a bug now
	  DrawList:PathStroke(0x4c010101, true, RADIUS_MAX - RADIUS_MIN);

	  local item_arc_span = 2*IM_PI / items_count;
	  local drag_angle = math.atan2(drag_delta.y, drag_delta.x);

	  for item_n = 1, items_count do
		local item_label = items[element.eType][item_n].title;
		local inner_spacing = style.ItemInnerSpacing.x / RADIUS_MIN / 2;
		local item_inner_ang_min = item_arc_span * (item_n - 0.5 + inner_spacing);
		local item_inner_ang_max = item_arc_span * (item_n + 0.5 - inner_spacing);
		local item_outer_ang_min = item_arc_span * (item_n - 0.5 + inner_spacing * (RADIUS_MIN / RADIUS_MAX));
		local item_outer_ang_max = item_arc_span * (item_n + 0.5 - inner_spacing * (RADIUS_MIN / RADIUS_MAX));

		local hovered = false;
		while( ( drag_angle - item_inner_ang_min ) < 0.0 ) do
			drag_angle = drag_angle + 2.0 * IM_PI;
		end
		while( ( drag_angle - item_inner_ang_min ) > 2.0 * IM_PI ) do
		  drag_angle = drag_angle - 2.0 * IM_PI;
		end
		if (drag_dist2 >= RADIUS_INTERACT_MIN*RADIUS_INTERACT_MIN) then
		  if (drag_angle >= item_inner_ang_min and drag_angle < item_inner_ang_max) then
			  hovered = true;
		  end
		end
		
		local arc_segments = (64 * item_arc_span / (2*IM_PI)) + 1;
		DrawList:PathArcTo(center, RADIUS_MAX - style.ItemInnerSpacing.x, item_outer_ang_min, item_outer_ang_max, arc_segments);
		DrawList:PathArcTo(center, RADIUS_MIN + style.ItemInnerSpacing.x, item_inner_ang_max, item_inner_ang_min, arc_segments);
		DrawList:PathFillConvex(hovered and 0xFc1D19B4 or 0xFc232323)

		local text_size = imgui.CalcTextSize(item_label);
		local text_pos = imgui.ImVec2(
			center.x + math.cos((item_inner_ang_min + item_inner_ang_max) * 0.5) * (RADIUS_MIN + RADIUS_MAX) * 0.5 - text_size.x * 0.5 + 1,
			center.y + math.sin((item_inner_ang_min + item_inner_ang_max) * 0.5) * (RADIUS_MIN + RADIUS_MAX) * 0.5 - text_size.y * 0.5 + 1);
		DrawList:AddText(text_pos, 0xFFFFFFFF, item_label);

		if hovered == true then
			item_hovered = item_n;
		else 
			if item_hovered == item_n then
				item_hovered = -1 
			end
		end
	  end
	  DrawList:PopClipRect();
	  imgui.End()
	end
	--print(items[element.eType][1], -1)
	if element.exists and imgui.IsKeyReleased(vkeys.VK_Z) and items[element.eType][item_hovered] and ShowImgui() and imguiHelperWindow[0] == false and not sampIsChatInputActive() then
		items[element.eType][item_hovered].func()
		item_hovered = -1
	end
	-- END MENU
  
	-- END TARGET BAR
end)
f.HideCursor = true


imgui.OnFrame(function () return ShowImgui() end,
function()	
	--imgui.SetCursorPos(imgui.ImVec2(resX/2, resY/2))
	
	imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0.06, 0.06, 0.06, 0.75))
	local x, y = convertGameScreenCoordsToWindowScreenCoords(60, 290) -- Позиция X , позиция Y
	local w, h = convertGameScreenCoordsToWindowScreenCoords(125, 45) -- Длина, Высота 
	
	imgui.SetNextWindowPos(imgui.ImVec2(resX / 7, resY / 1.45),_,imgui.ImVec2(0.5, 0.5))
	imgui.SetNextWindowSize(imgui.ImVec2(w-x, h), imgui.Cond.FirstUseEver)			
	imgui.Begin(u8"##radarBar", _, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove + imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoSavedSettings)
	
	imgui.SetWindowFontScale(1.0)
	local _, hb = convertGameScreenCoordsToWindowScreenCoords(_, 38)
	imgui.BeginChild("##radar", imgui.ImVec2(w-x-2, hb))
		
	local color = sampGetPlayerColor(myID)	
	local r, g, b = bitex.bextract(color, 16, 8), bitex.bextract(color, 8, 8), bitex.bextract(color, 0, 8)
	local imgui_RGBA = imgui.ImVec4(r / 255.0, g / 255.0, b / 255.0, 1)	
	
	imgui.Text(faicons.ICON_USER) imgui.SameLine() imgui.TextColored(imgui_RGBA, ("%s[%d]"):format(myName, myID))

	imgui.Text(faicons.ICON_CLOCK_O) imgui.SameLine() imgui.Text(("%s %s"):format(currentDate, currentTime))
	
	local spinnerColor = imgui.GetColorU32Vec4(imgui.GetStyle().Colors[imgui.Col.Text])
	
	
	imgui.Text(faicons.ICON_LOCATION_ARROW) 
	imgui.SameLine() 
	if myZone == "Неизвестно" then mimgui_addons.Spinner("##spinner", 4, 2, spinnerColor) else imgui.Text(u8(("%s"):format(mySquare))) end
	
	imgui.Text(faicons.ICON_MAP_SIGNS)
	imgui.SameLine()
	if myZone == "Неизвестно" then mimgui_addons.Spinner("##spinner", 4, 2, spinnerColor) else imgui.Text(u8(("%s"):format(myZone))) end
	
	imgui.Text(faicons.ICON_COMPASS) imgui.SameLine() imgui.Text(u8(("%s"):format(myCompas)))
	
	imgui.EndChild()
	imgui.End()
	imgui.PopStyleColor()
		
end).HideCursor = true

imgui.OnFrame(function () return imguiHelperWindow[0] and ShowImgui() end,
function()	
	imgui.SetNextWindowPos(imgui.ImVec2(resX - 950, resY - 500),_,imgui.ImVec2(0.5, 0.5))
	imgui.SetNextWindowSize(imgui.ImVec2(740,500))
		imgui.Begin(u8(string.upper(thisScript().name)), main_window, imgui.WindowFlags.NoMove + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse + imgui.WindowFlags.NoSavedSettings)
	
		imgui.BeginChild('left', imgui.ImVec2(155, 470), true) --Навигация по главному меню слева
			if not selected then selected = 1 end 
			if imgui.Button(u8'Полиция '..faicons.ICON_ASTERISK, selectable_size) then selected = 1 end --Полиция
			imgui.Separator()
			if imgui.Button(u8'Информация '..faicons.ICON_INFO_CIRCLE,selectable_size) then selected = 3 end
		imgui.EndChild() --конец навигации
		
		imgui.SameLine()
		imgui.BeginChild('right', imgui.ImVec2(570, 470), true) --Навигация по меню справа
			if selected == 1 then --// Полиция //
				imgui.BeginChild('up', imgui.ImVec2(560, 48), true)
				if not selectedd then 
					selectedd = 1 
				end 
				
				if imgui.Button(u8'Розыск', btnlives_size) then selectedd = 1 end -- Розыск
				imgui.SameLine()
				if imgui.Button(u8'Помощь', btnlives_size) then selectedd = 2 end -- Помощь
				imgui.SameLine()
				if imgui.Button(u8'Биндеры', btnlives_size) then selectedd = 3 end -- Бинды
				imgui.SameLine()
				if imgui.Button(u8'Настройки', btnlives_size) then selectedd = 4 end -- Настройки
				imgui.EndChild()
				
				imgui.BeginChild('down', imgui.ImVec2(560, 410), true) --действия эфиров
					if selectedd == 1 then
						for i = 0, sampGetMaxPlayerId(false) do
							list_ids[i] = ("[%i]  %s"):format(i, sampIsPlayerConnected(i) == true and sampGetPlayerNickname(i) or "")
						end
						listArr = imgui.new['const char*'][#list_ids + 1](list_ids)
						
						imgui.PushItemWidth(45)
						imgui.InputInt("##Combo2", SuspectPlayerID, 0)

						imgui.PopItemWidth()
						imgui.SameLine()
						imgui.PushItemWidth(200)

						imgui.Combo("##Combo1", SuspectPlayerID, listArr, #list_ids + 1)

						imgui.SameLine()

						imgui.InputTextWithHint("##InputText1", u8"Поиск статьи", searchBuf, ffi.sizeof(searchBuf))
						imgui.SameLine()
						
						imgui.Text(u8"Статей: "..tostring(suspectElementCount))
					
						imgui.PopItemWidth()
						imgui.Separator()

						imgui.BeginChild('table suspect', imgui.ImVec2(550, 370), false)
							imgui.Columns(3, _, true)
							imgui.SetColumnWidth(-1, 52); imgui.Text(u8"Кодекс"); imgui.NextColumn()
							imgui.SetColumnWidth(-1, 420); imgui.Text(u8"Статья"); imgui.NextColumn()
							imgui.SetColumnWidth(-1, 52); imgui.Text(u8"Звезды"); imgui.NextColumn()
							imgui.Separator()

							suspectElementCount = 0
							for i = 1, #Ukodeks do
								if(ffi.sizeof(searchBuf) > 0) then
									if(string.find(string.upper2(Ukodeks[i][1]), string.upper2(u8:decode((ffi.string(searchBuf)))))) then	
										showSuspectElements(i)
									end
								else
									showSuspectElements(i)
								end
							end	
						imgui.EndChild()
					end
					if selectedd == 2 then
						--imgui.PushFont(defSmall)
						imgui.Text(tenCodes_1)
						imgui.Text(tenCodes_2)
						--imgui.PopFont()
					end
					if selectedd == 3 then
						for i = 1, #clickBinds do
							if imgui.TreeNodeStr(u8(clickBinds[i][1])) then		
								for d = 1, #clickBinds[i][2] do
									if d > 1 and d % 6 ~= 0 then imgui.SameLine() end
									if imgui.Button(u8(clickBinds[i][2][d][1]), btnlives_size) then
										lua_thread.create(function()
											for n = 1, #clickBinds[i][2][d][2] do
												sampSendChat(clickBinds[i][2][d][2][n])
												wait(1800)
											end	
										end)
									end
								end
							   imgui.TreePop()
							end
							imgui.Separator()
						end		
						if imgui.TreeNodeStr(u8"УКАЗАТЕЛИ") then
						
							imgui.Columns(3, "mycolumns")
							imgui.Separator()
							imgui.Text(u8"Описание") imgui.NextColumn()
							imgui.Text(u8"Значение") imgui.NextColumn()
							imgui.Text(u8"Указатель") imgui.NextColumn()
							imgui.Separator()
		
							for i = 1, #args do
								imgui.Text(u8(tags(args[i][2]))) imgui.NextColumn()
								imgui.Text(u8(tags(tostring(args[i][3])))) imgui.NextColumn()
								imgui.Text(args[i][1]) imgui.NextColumn()
							end
							imgui.Columns(1);
							imgui.TreePop()
						end
						imgui.Separator();

						--[[if imgui.Button(u8'Начало',btnlives_size) then
						end
						 imgui.SameLine()
						if imgui.Button(u8'След.страна',btnlives_size) then
							sampSetChatInputText('/news [Столицы] Следующая страна: ')
							sampSetChatInputEnabled(true)
						end
						if imgui.Button(u8'Конец',btnlives_size) then
					
						end]]
					end
					if selectedd == 4 then
						imgui.Text("Anti-AFK")
						imgui.SameLine(150)
						if mimgui_addons.ToggleButton("Anti-AFK", isWorkInBackground) then
							workInBackgroundSet()
						end
						imgui.Text(u8(("В сети:  %s"):format(FormatTime(os.clock()))))

					end
				end	
			if selected == 2 then
				--imgui.Text(u8"Тут инфа")
			end
		imgui.EndChild()
	imgui.End()  
end)



function showSuspectElements(i)
	suspectElementCount = suspectElementCount + 1
	imgui.Text(u8(Ukodeks[i][2])) imgui.NextColumn()
	
	if imgui.Selectable(u8(Ukodeks[i][1]), i == focusSuspectReason, imgui.SelectableFlags.SpanAllColumns + imgui.SelectableFlags.AllowDoubleClick) then	
		if imgui.IsMouseDoubleClicked(0) then
			sampSendChat(("/su %i %i %s"):format(SuspectPlayerID[0], Ukodeks[focusSuspectReason][3], Ukodeks[focusSuspectReason][1]))
		else
			focusSuspectReason = i
		end
	end 

	imgui.NextColumn() imgui.Text(u8(Ukodeks[i][3])) imgui.NextColumn()	
end

function GetPlayerFacingDirection(ped, facing_angle) 
	local side_of_the_world = 20.0
	local coord_indent = 0.1
	
	local north_coord_min = 360.0-side_of_the_world
	local north_coord_max = 0.0+side_of_the_world
	local west_coord_min = 90.0-side_of_the_world
	local west_coord_max = 90.0+side_of_the_world
	local south_coord_min = 180.0-side_of_the_world
	local south_coord_max = 180.0+side_of_the_world
	local east_coord_min = 270.0-side_of_the_world
	local east_coord_max = 270.0+side_of_the_world
	
	if facing_angle == -1.0 then
        facing_angle = getCharHeading(ped)
    elseif facing_angle < 0.0 then
        facing_angle = 0.0
    elseif facing_angle > 360.0 then
        facing_angle = 360.0
	end	

	if( (north_coord_min <= facing_angle and facing_angle <= 360.0) or (0.0 <= facing_angle and facing_angle <= north_coord_max) ) then

        return 1 -- NORTH
	elseif(north_coord_max+coord_indent <= facing_angle and facing_angle <= west_coord_min-coord_indent) then

		return 2 -- NORTH WEST

	elseif(west_coord_min <= facing_angle and facing_angle <= west_coord_max) then
		return 3 -- WEST
	elseif(west_coord_max+coord_indent <= facing_angle and facing_angle <= south_coord_min-coord_indent) then
		return 4 -- SOUTH_WEST

	elseif(south_coord_min <= facing_angle and facing_angle <= south_coord_max) then
		return 5-- SOUTH	
	elseif(south_coord_max+coord_indent <= facing_angle and facing_angle <= east_coord_min-coord_indent) then
		return 6-- SOUTH_EAST

	elseif(east_coord_min <= facing_angle and facing_angle <= east_coord_max) then
		return 7-- EAST
		
	elseif(east_coord_max+coord_indent <= facing_angle and facing_angle <= north_coord_min-coord_indent) then
		return 8-- NORTH_EAST
	end
end


function tags(text) -- функция с тэгами скрипта	
	for i = 1, #args do
		text = text:gsub(args[i][1], tostring(args[i][3]))
	end
	
	return text
end

function calculateZone(x, y, z)
    local streets = {{"Avispa Country Club", -2667.810, -302.135, -28.831, -2646.400, -262.320, 71.169},
    {"Easter Bay Airport", -1315.420, -405.388, 15.406, -1264.400, -209.543, 25.406},
    {"Avispa Country Club", -2550.040, -355.493, 0.000, -2470.040, -318.493, 39.700},
    {"Easter Bay Airport", -1490.330, -209.543, 15.406, -1264.400, -148.388, 25.406},
    {"Garcia", -2395.140, -222.589, -5.3, -2354.090, -204.792, 200.000},
    {"Shady Cabin", -1632.830, -2263.440, -3.0, -1601.330, -2231.790, 200.000},
    {"East Los Santos", 2381.680, -1494.030, -89.084, 2421.030, -1454.350, 110.916},
    {"LVA Freight Depot", 1236.630, 1163.410, -89.084, 1277.050, 1203.280, 110.916},
    {"Blackfield Intersection", 1277.050, 1044.690, -89.084, 1315.350, 1087.630, 110.916},
    {"Avispa Country Club", -2470.040, -355.493, 0.000, -2270.040, -318.493, 46.100},
    {"Temple", 1252.330, -926.999, -89.084, 1357.000, -910.170, 110.916},
    {"Unity Station", 1692.620, -1971.800, -20.492, 1812.620, -1932.800, 79.508},
    {"LVA Freight Depot", 1315.350, 1044.690, -89.084, 1375.600, 1087.630, 110.916},
    {"Los Flores", 2581.730, -1454.350, -89.084, 2632.830, -1393.420, 110.916},
    {"Starfish Casino", 2437.390, 1858.100, -39.084, 2495.090, 1970.850, 60.916},
    {"Easter Bay Chemicals", -1132.820, -787.391, 0.000, -956.476, -768.027, 200.000},
    {"Downtown Los Santos", 1370.850, -1170.870, -89.084, 1463.900, -1130.850, 110.916},
    {"Esplanade East", -1620.300, 1176.520, -4.5, -1580.010, 1274.260, 200.000},
    {"Market Station", 787.461, -1410.930, -34.126, 866.009, -1310.210, 65.874},
    {"Linden Station", 2811.250, 1229.590, -39.594, 2861.250, 1407.590, 60.406},
    {"Montgomery Intersection", 1582.440, 347.457, 0.000, 1664.620, 401.750, 200.000},
    {"Frederick Bridge", 2759.250, 296.501, 0.000, 2774.250, 594.757, 200.000},
    {"Yellow Bell Station", 1377.480, 2600.430, -21.926, 1492.450, 2687.360, 78.074},
    {"Downtown Los Santos", 1507.510, -1385.210, 110.916, 1582.550, -1325.310, 335.916},
    {"Jefferson", 2185.330, -1210.740, -89.084, 2281.450, -1154.590, 110.916},
    {"Mulholland", 1318.130, -910.170, -89.084, 1357.000, -768.027, 110.916},
    {"Avispa Country Club", -2361.510, -417.199, 0.000, -2270.040, -355.493, 200.000},
    {"Jefferson", 1996.910, -1449.670, -89.084, 2056.860, -1350.720, 110.916},
    {"Julius Thruway West", 1236.630, 2142.860, -89.084, 1297.470, 2243.230, 110.916},
    {"Jefferson", 2124.660, -1494.030, -89.084, 2266.210, -1449.670, 110.916},
    {"Julius Thruway North", 1848.400, 2478.490, -89.084, 1938.800, 2553.490, 110.916},
    {"Rodeo", 422.680, -1570.200, -89.084, 466.223, -1406.050, 110.916},
    {"Cranberry Station", -2007.830, 56.306, 0.000, -1922.000, 224.782, 100.000},
    {"Downtown Los Santos", 1391.050, -1026.330, -89.084, 1463.900, -926.999, 110.916},
    {"Redsands West", 1704.590, 2243.230, -89.084, 1777.390, 2342.830, 110.916},
    {"Little Mexico", 1758.900, -1722.260, -89.084, 1812.620, -1577.590, 110.916},
    {"Blackfield Intersection", 1375.600, 823.228, -89.084, 1457.390, 919.447, 110.916},
    {"Los Santos International", 1974.630, -2394.330, -39.084, 2089.000, -2256.590, 60.916},
    {"Beacon Hill", -399.633, -1075.520, -1.489, -319.033, -977.516, 198.511},
    {"Rodeo", 334.503, -1501.950, -89.084, 422.680, -1406.050, 110.916},
    {"Richman", 225.165, -1369.620, -89.084, 334.503, -1292.070, 110.916},
    {"Downtown Los Santos", 1724.760, -1250.900, -89.084, 1812.620, -1150.870, 110.916},
    {"The Strip", 2027.400, 1703.230, -89.084, 2137.400, 1783.230, 110.916},
    {"Downtown Los Santos", 1378.330, -1130.850, -89.084, 1463.900, -1026.330, 110.916},
    {"Blackfield Intersection", 1197.390, 1044.690, -89.084, 1277.050, 1163.390, 110.916},
    {"Conference Center", 1073.220, -1842.270, -89.084, 1323.900, -1804.210, 110.916},
    {"Montgomery", 1451.400, 347.457, -6.1, 1582.440, 420.802, 200.000},
    {"Foster Valley", -2270.040, -430.276, -1.2, -2178.690, -324.114, 200.000},
    {"Blackfield Chapel", 1325.600, 596.349, -89.084, 1375.600, 795.010, 110.916},
    {"Los Santos International", 2051.630, -2597.260, -39.084, 2152.450, -2394.330, 60.916},
    {"Mulholland", 1096.470, -910.170, -89.084, 1169.130, -768.027, 110.916},
    {"Yellow Bell Gol Course", 1457.460, 2723.230, -89.084, 1534.560, 2863.230, 110.916},
    {"The Strip", 2027.400, 1783.230, -89.084, 2162.390, 1863.230, 110.916},
    {"Jefferson", 2056.860, -1210.740, -89.084, 2185.330, -1126.320, 110.916},
    {"Mulholland", 952.604, -937.184, -89.084, 1096.470, -860.619, 110.916},
    {"Aldea Malvada", -1372.140, 2498.520, 0.000, -1277.590, 2615.350, 200.000},
    {"Las Colinas", 2126.860, -1126.320, -89.084, 2185.330, -934.489, 110.916},
    {"Las Colinas", 1994.330, -1100.820, -89.084, 2056.860, -920.815, 110.916},
    {"Richman", 647.557, -954.662, -89.084, 768.694, -860.619, 110.916},
    {"LVA Freight Depot", 1277.050, 1087.630, -89.084, 1375.600, 1203.280, 110.916},
    {"Julius Thruway North", 1377.390, 2433.230, -89.084, 1534.560, 2507.230, 110.916},
    {"Willowfield", 2201.820, -2095.000, -89.084, 2324.000, -1989.900, 110.916},
    {"Julius Thruway North", 1704.590, 2342.830, -89.084, 1848.400, 2433.230, 110.916},
    {"Temple", 1252.330, -1130.850, -89.084, 1378.330, -1026.330, 110.916},
    {"Little Mexico", 1701.900, -1842.270, -89.084, 1812.620, -1722.260, 110.916},
    {"Queens", -2411.220, 373.539, 0.000, -2253.540, 458.411, 200.000},
    {"Las Venturas Airport", 1515.810, 1586.400, -12.500, 1729.950, 1714.560, 87.500},
    {"Richman", 225.165, -1292.070, -89.084, 466.223, -1235.070, 110.916},
    {"Temple", 1252.330, -1026.330, -89.084, 1391.050, -926.999, 110.916},
    {"East Los Santos", 2266.260, -1494.030, -89.084, 2381.680, -1372.040, 110.916},
    {"Julius Thruway East", 2623.180, 943.235, -89.084, 2749.900, 1055.960, 110.916},
    {"Willowfield", 2541.700, -1941.400, -89.084, 2703.580, -1852.870, 110.916},
    {"Las Colinas", 2056.860, -1126.320, -89.084, 2126.860, -920.815, 110.916},
    {"Julius Thruway East", 2625.160, 2202.760, -89.084, 2685.160, 2442.550, 110.916},
    {"Rodeo", 225.165, -1501.950, -89.084, 334.503, -1369.620, 110.916},
    {"Las Brujas", -365.167, 2123.010, -3.0, -208.570, 2217.680, 200.000},
    {"Julius Thruway East", 2536.430, 2442.550, -89.084, 2685.160, 2542.550, 110.916},
    {"Rodeo", 334.503, -1406.050, -89.084, 466.223, -1292.070, 110.916},
    {"Vinewood", 647.557, -1227.280, -89.084, 787.461, -1118.280, 110.916},
    {"Rodeo", 422.680, -1684.650, -89.084, 558.099, -1570.200, 110.916},
    {"Julius Thruway North", 2498.210, 2542.550, -89.084, 2685.160, 2626.550, 110.916},
    {"Downtown Los Santos", 1724.760, -1430.870, -89.084, 1812.620, -1250.900, 110.916},
    {"Rodeo", 225.165, -1684.650, -89.084, 312.803, -1501.950, 110.916},
    {"Jefferson", 2056.860, -1449.670, -89.084, 2266.210, -1372.040, 110.916},
    {"Hampton Barns", 603.035, 264.312, 0.000, 761.994, 366.572, 200.000},
    {"Temple", 1096.470, -1130.840, -89.084, 1252.330, -1026.330, 110.916},
    {"Kincaid Bridge", -1087.930, 855.370, -89.084, -961.950, 986.281, 110.916},
    {"Verona Beach", 1046.150, -1722.260, -89.084, 1161.520, -1577.590, 110.916},
    {"Commerce", 1323.900, -1722.260, -89.084, 1440.900, -1577.590, 110.916},
    {"Mulholland", 1357.000, -926.999, -89.084, 1463.900, -768.027, 110.916},
    {"Rodeo", 466.223, -1570.200, -89.084, 558.099, -1385.070, 110.916},
    {"Mulholland", 911.802, -860.619, -89.084, 1096.470, -768.027, 110.916},
    {"Mulholland", 768.694, -954.662, -89.084, 952.604, -860.619, 110.916},
    {"Julius Thruway South", 2377.390, 788.894, -89.084, 2537.390, 897.901, 110.916},
    {"Idlewood", 1812.620, -1852.870, -89.084, 1971.660, -1742.310, 110.916},
    {"Ocean Docks", 2089.000, -2394.330, -89.084, 2201.820, -2235.840, 110.916},
    {"Commerce", 1370.850, -1577.590, -89.084, 1463.900, -1384.950, 110.916},
    {"Julius Thruway North", 2121.400, 2508.230, -89.084, 2237.400, 2663.170, 110.916},
    {"Temple", 1096.470, -1026.330, -89.084, 1252.330, -910.170, 110.916},
    {"Glen Park", 1812.620, -1449.670, -89.084, 1996.910, -1350.720, 110.916},
    {"Easter Bay Airport", -1242.980, -50.096, 0.000, -1213.910, 578.396, 200.000},
    {"Martin Bridge", -222.179, 293.324, 0.000, -122.126, 476.465, 200.000},
    {"The Strip", 2106.700, 1863.230, -89.084, 2162.390, 2202.760, 110.916},
    {"Willowfield", 2541.700, -2059.230, -89.084, 2703.580, -1941.400, 110.916},
    {"Marina", 807.922, -1577.590, -89.084, 926.922, -1416.250, 110.916},
    {"Las Venturas Airport", 1457.370, 1143.210, -89.084, 1777.400, 1203.280, 110.916},
    {"Idlewood", 1812.620, -1742.310, -89.084, 1951.660, -1602.310, 110.916},
    {"Esplanade East", -1580.010, 1025.980, -6.1, -1499.890, 1274.260, 200.000},
    {"Downtown Los Santos", 1370.850, -1384.950, -89.084, 1463.900, -1170.870, 110.916},
    {"The Mako Span", 1664.620, 401.750, 0.000, 1785.140, 567.203, 200.000},
    {"Rodeo", 312.803, -1684.650, -89.084, 422.680, -1501.950, 110.916},
    {"Pershing Square", 1440.900, -1722.260, -89.084, 1583.500, -1577.590, 110.916},
    {"Mulholland", 687.802, -860.619, -89.084, 911.802, -768.027, 110.916},
    {"Gant Bridge", -2741.070, 1490.470, -6.1, -2616.400, 1659.680, 200.000},
    {"Las Colinas", 2185.330, -1154.590, -89.084, 2281.450, -934.489, 110.916},
    {"Mulholland", 1169.130, -910.170, -89.084, 1318.130, -768.027, 110.916},
    {"Julius Thruway North", 1938.800, 2508.230, -89.084, 2121.400, 2624.230, 110.916},
    {"Commerce", 1667.960, -1577.590, -89.084, 1812.620, -1430.870, 110.916},
    {"Rodeo", 72.648, -1544.170, -89.084, 225.165, -1404.970, 110.916},
    {"Roca Escalante", 2536.430, 2202.760, -89.084, 2625.160, 2442.550, 110.916},
    {"Rodeo", 72.648, -1684.650, -89.084, 225.165, -1544.170, 110.916},
    {"Market", 952.663, -1310.210, -89.084, 1072.660, -1130.850, 110.916},
    {"Las Colinas", 2632.740, -1135.040, -89.084, 2747.740, -945.035, 110.916},
    {"Mulholland", 861.085, -674.885, -89.084, 1156.550, -600.896, 110.916},
    {"King's", -2253.540, 373.539, -9.1, -1993.280, 458.411, 200.000},
    {"Redsands East", 1848.400, 2342.830, -89.084, 2011.940, 2478.490, 110.916},
    {"Downtown", -1580.010, 744.267, -6.1, -1499.890, 1025.980, 200.000},
    {"Conference Center", 1046.150, -1804.210, -89.084, 1323.900, -1722.260, 110.916},
    {"Richman", 647.557, -1118.280, -89.084, 787.461, -954.662, 110.916},
    {"Ocean Flats", -2994.490, 277.411, -9.1, -2867.850, 458.411, 200.000},
    {"Greenglass College", 964.391, 930.890, -89.084, 1166.530, 1044.690, 110.916},
    {"Glen Park", 1812.620, -1100.820, -89.084, 1994.330, -973.380, 110.916},
    {"LVA Freight Depot", 1375.600, 919.447, -89.084, 1457.370, 1203.280, 110.916},
    {"Regular Tom", -405.770, 1712.860, -3.0, -276.719, 1892.750, 200.000},
    {"Verona Beach", 1161.520, -1722.260, -89.084, 1323.900, -1577.590, 110.916},
    {"East Los Santos", 2281.450, -1372.040, -89.084, 2381.680, -1135.040, 110.916},
    {"Caligula's Palace", 2137.400, 1703.230, -89.084, 2437.390, 1783.230, 110.916},
    {"Idlewood", 1951.660, -1742.310, -89.084, 2124.660, -1602.310, 110.916},
    {"Pilgrim", 2624.400, 1383.230, -89.084, 2685.160, 1783.230, 110.916},
    {"Idlewood", 2124.660, -1742.310, -89.084, 2222.560, -1494.030, 110.916},
    {"Queens", -2533.040, 458.411, 0.000, -2329.310, 578.396, 200.000},
    {"Downtown", -1871.720, 1176.420, -4.5, -1620.300, 1274.260, 200.000},
    {"Commerce", 1583.500, -1722.260, -89.084, 1758.900, -1577.590, 110.916},
    {"East Los Santos", 2381.680, -1454.350, -89.084, 2462.130, -1135.040, 110.916},
    {"Marina", 647.712, -1577.590, -89.084, 807.922, -1416.250, 110.916},
    {"Richman", 72.648, -1404.970, -89.084, 225.165, -1235.070, 110.916},
    {"Vinewood", 647.712, -1416.250, -89.084, 787.461, -1227.280, 110.916},
    {"East Los Santos", 2222.560, -1628.530, -89.084, 2421.030, -1494.030, 110.916},
    {"Rodeo", 558.099, -1684.650, -89.084, 647.522, -1384.930, 110.916},
    {"Easter Tunnel", -1709.710, -833.034, -1.5, -1446.010, -730.118, 200.000},
    {"Rodeo", 466.223, -1385.070, -89.084, 647.522, -1235.070, 110.916},
    {"Redsands East", 1817.390, 2202.760, -89.084, 2011.940, 2342.830, 110.916},
    {"The Clown's Pocket", 2162.390, 1783.230, -89.084, 2437.390, 1883.230, 110.916},
    {"Idlewood", 1971.660, -1852.870, -89.084, 2222.560, -1742.310, 110.916},
    {"Montgomery Intersection", 1546.650, 208.164, 0.000, 1745.830, 347.457, 200.000},
    {"Willowfield", 2089.000, -2235.840, -89.084, 2201.820, -1989.900, 110.916},
    {"Temple", 952.663, -1130.840, -89.084, 1096.470, -937.184, 110.916},
    {"Prickle Pine", 1848.400, 2553.490, -89.084, 1938.800, 2863.230, 110.916},
    {"Los Santos International", 1400.970, -2669.260, -39.084, 2189.820, -2597.260, 60.916},
    {"Garver Bridge", -1213.910, 950.022, -89.084, -1087.930, 1178.930, 110.916},
    {"Garver Bridge", -1339.890, 828.129, -89.084, -1213.910, 1057.040, 110.916},
    {"Kincaid Bridge", -1339.890, 599.218, -89.084, -1213.910, 828.129, 110.916},
    {"Kincaid Bridge", -1213.910, 721.111, -89.084, -1087.930, 950.022, 110.916},
    {"Verona Beach", 930.221, -2006.780, -89.084, 1073.220, -1804.210, 110.916},
    {"Verdant Bluffs", 1073.220, -2006.780, -89.084, 1249.620, -1842.270, 110.916},
    {"Vinewood", 787.461, -1130.840, -89.084, 952.604, -954.662, 110.916},
    {"Vinewood", 787.461, -1310.210, -89.084, 952.663, -1130.840, 110.916},
    {"Commerce", 1463.900, -1577.590, -89.084, 1667.960, -1430.870, 110.916},
    {"Market", 787.461, -1416.250, -89.084, 1072.660, -1310.210, 110.916},
    {"Rockshore West", 2377.390, 596.349, -89.084, 2537.390, 788.894, 110.916},
    {"Julius Thruway North", 2237.400, 2542.550, -89.084, 2498.210, 2663.170, 110.916},
    {"East Beach", 2632.830, -1668.130, -89.084, 2747.740, -1393.420, 110.916},
    {"Fallow Bridge", 434.341, 366.572, 0.000, 603.035, 555.680, 200.000},
    {"Willowfield", 2089.000, -1989.900, -89.084, 2324.000, -1852.870, 110.916},
    {"Chinatown", -2274.170, 578.396, -7.6, -2078.670, 744.170, 200.000},
    {"El Castillo del Diablo", -208.570, 2337.180, 0.000, 8.430, 2487.180, 200.000},
    {"Ocean Docks", 2324.000, -2145.100, -89.084, 2703.580, -2059.230, 110.916},
    {"Easter Bay Chemicals", -1132.820, -768.027, 0.000, -956.476, -578.118, 200.000},
    {"The Visage", 1817.390, 1703.230, -89.084, 2027.400, 1863.230, 110.916},
    {"Ocean Flats", -2994.490, -430.276, -1.2, -2831.890, -222.589, 200.000},
    {"Richman", 321.356, -860.619, -89.084, 687.802, -768.027, 110.916},
    {"Green Palms", 176.581, 1305.450, -3.0, 338.658, 1520.720, 200.000},
    {"Richman", 321.356, -768.027, -89.084, 700.794, -674.885, 110.916},
    {"Starfish Casino", 2162.390, 1883.230, -89.084, 2437.390, 2012.180, 110.916},
    {"East Beach", 2747.740, -1668.130, -89.084, 2959.350, -1498.620, 110.916},
    {"Jefferson", 2056.860, -1372.040, -89.084, 2281.450, -1210.740, 110.916},
    {"Downtown Los Santos", 1463.900, -1290.870, -89.084, 1724.760, -1150.870, 110.916},
    {"Downtown Los Santos", 1463.900, -1430.870, -89.084, 1724.760, -1290.870, 110.916},
    {"Garver Bridge", -1499.890, 696.442, -179.615, -1339.890, 925.353, 20.385},
    {"Julius Thruway South", 1457.390, 823.228, -89.084, 2377.390, 863.229, 110.916},
    {"East Los Santos", 2421.030, -1628.530, -89.084, 2632.830, -1454.350, 110.916},
    {"Greenglass College", 964.391, 1044.690, -89.084, 1197.390, 1203.220, 110.916},
    {"Las Colinas", 2747.740, -1120.040, -89.084, 2959.350, -945.035, 110.916},
    {"Mulholland", 737.573, -768.027, -89.084, 1142.290, -674.885, 110.916},
    {"Ocean Docks", 2201.820, -2730.880, -89.084, 2324.000, -2418.330, 110.916},
    {"East Los Santos", 2462.130, -1454.350, -89.084, 2581.730, -1135.040, 110.916},
    {"Ganton", 2222.560, -1722.330, -89.084, 2632.830, -1628.530, 110.916},
    {"Avispa Country Club", -2831.890, -430.276, -6.1, -2646.400, -222.589, 200.000},
    {"Willowfield", 1970.620, -2179.250, -89.084, 2089.000, -1852.870, 110.916},
    {"Esplanade North", -1982.320, 1274.260, -4.5, -1524.240, 1358.900, 200.000},
    {"The High Roller", 1817.390, 1283.230, -89.084, 2027.390, 1469.230, 110.916},
    {"Ocean Docks", 2201.820, -2418.330, -89.084, 2324.000, -2095.000, 110.916},
    {"Last Dime Motel", 1823.080, 596.349, -89.084, 1997.220, 823.228, 110.916},
    {"Bayside Marina", -2353.170, 2275.790, 0.000, -2153.170, 2475.790, 200.000},
    {"King's", -2329.310, 458.411, -7.6, -1993.280, 578.396, 200.000},
    {"El Corona", 1692.620, -2179.250, -89.084, 1812.620, -1842.270, 110.916},
    {"Blackfield Chapel", 1375.600, 596.349, -89.084, 1558.090, 823.228, 110.916},
    {"The Pink Swan", 1817.390, 1083.230, -89.084, 2027.390, 1283.230, 110.916},
    {"Julius Thruway West", 1197.390, 1163.390, -89.084, 1236.630, 2243.230, 110.916},
    {"Los Flores", 2581.730, -1393.420, -89.084, 2747.740, -1135.040, 110.916},
    {"The Visage", 1817.390, 1863.230, -89.084, 2106.700, 2011.830, 110.916},
    {"Prickle Pine", 1938.800, 2624.230, -89.084, 2121.400, 2861.550, 110.916},
    {"Verona Beach", 851.449, -1804.210, -89.084, 1046.150, -1577.590, 110.916},
    {"Robada Intersection", -1119.010, 1178.930, -89.084, -862.025, 1351.450, 110.916},
    {"Linden Side", 2749.900, 943.235, -89.084, 2923.390, 1198.990, 110.916},
    {"Ocean Docks", 2703.580, -2302.330, -89.084, 2959.350, -2126.900, 110.916},
    {"Willowfield", 2324.000, -2059.230, -89.084, 2541.700, -1852.870, 110.916},
    {"King's", -2411.220, 265.243, -9.1, -1993.280, 373.539, 200.000},
    {"Commerce", 1323.900, -1842.270, -89.084, 1701.900, -1722.260, 110.916},
    {"Mulholland", 1269.130, -768.027, -89.084, 1414.070, -452.425, 110.916},
    {"Marina", 647.712, -1804.210, -89.084, 851.449, -1577.590, 110.916},
    {"Battery Point", -2741.070, 1268.410, -4.5, -2533.040, 1490.470, 200.000},
    {"The Four Dragons Casino", 1817.390, 863.232, -89.084, 2027.390, 1083.230, 110.916},
    {"Blackfield", 964.391, 1203.220, -89.084, 1197.390, 1403.220, 110.916},
    {"Julius Thruway North", 1534.560, 2433.230, -89.084, 1848.400, 2583.230, 110.916},
    {"Yellow Bell Gol Course", 1117.400, 2723.230, -89.084, 1457.460, 2863.230, 110.916},
    {"Idlewood", 1812.620, -1602.310, -89.084, 2124.660, -1449.670, 110.916},
    {"Redsands West", 1297.470, 2142.860, -89.084, 1777.390, 2243.230, 110.916},
    {"Doherty", -2270.040, -324.114, -1.2, -1794.920, -222.589, 200.000},
    {"Hilltop Farm", 967.383, -450.390, -3.0, 1176.780, -217.900, 200.000},
    {"Las Barrancas", -926.130, 1398.730, -3.0, -719.234, 1634.690, 200.000},
    {"Pirates in Men's Pants", 1817.390, 1469.230, -89.084, 2027.400, 1703.230, 110.916},
    {"City Hall", -2867.850, 277.411, -9.1, -2593.440, 458.411, 200.000},
    {"Avispa Country Club", -2646.400, -355.493, 0.000, -2270.040, -222.589, 200.000},
    {"The Strip", 2027.400, 863.229, -89.084, 2087.390, 1703.230, 110.916},
    {"Hashbury", -2593.440, -222.589, -1.0, -2411.220, 54.722, 200.000},
    {"Los Santos International", 1852.000, -2394.330, -89.084, 2089.000, -2179.250, 110.916},
    {"Whitewood Estates", 1098.310, 1726.220, -89.084, 1197.390, 2243.230, 110.916},
    {"Sherman Reservoir", -789.737, 1659.680, -89.084, -599.505, 1929.410, 110.916},
    {"El Corona", 1812.620, -2179.250, -89.084, 1970.620, -1852.870, 110.916},
    {"Downtown", -1700.010, 744.267, -6.1, -1580.010, 1176.520, 200.000},
    {"Foster Valley", -2178.690, -1250.970, 0.000, -1794.920, -1115.580, 200.000},
    {"Las Payasadas", -354.332, 2580.360, 2.0, -133.625, 2816.820, 200.000},
    {"Valle Ocultado", -936.668, 2611.440, 2.0, -715.961, 2847.900, 200.000},
    {"Blackfield Intersection", 1166.530, 795.010, -89.084, 1375.600, 1044.690, 110.916},
    {"Ganton", 2222.560, -1852.870, -89.084, 2632.830, -1722.330, 110.916},
    {"Easter Bay Airport", -1213.910, -730.118, 0.000, -1132.820, -50.096, 200.000},
    {"Redsands East", 1817.390, 2011.830, -89.084, 2106.700, 2202.760, 110.916},
    {"Esplanade East", -1499.890, 578.396, -79.615, -1339.890, 1274.260, 20.385},
    {"Caligula's Palace", 2087.390, 1543.230, -89.084, 2437.390, 1703.230, 110.916},
    {"Royal Casino", 2087.390, 1383.230, -89.084, 2437.390, 1543.230, 110.916},
    {"Richman", 72.648, -1235.070, -89.084, 321.356, -1008.150, 110.916},
    {"Starfish Casino", 2437.390, 1783.230, -89.084, 2685.160, 2012.180, 110.916},
    {"Mulholland", 1281.130, -452.425, -89.084, 1641.130, -290.913, 110.916},
    {"Downtown", -1982.320, 744.170, -6.1, -1871.720, 1274.260, 200.000},
    {"Hankypanky Point", 2576.920, 62.158, 0.000, 2759.250, 385.503, 200.000},
    {"K.A.C.C. Military Fuels", 2498.210, 2626.550, -89.084, 2749.900, 2861.550, 110.916},
    {"Harry Gold Parkway", 1777.390, 863.232, -89.084, 1817.390, 2342.830, 110.916},
    {"Bayside Tunnel", -2290.190, 2548.290, -89.084, -1950.190, 2723.290, 110.916},
    {"Ocean Docks", 2324.000, -2302.330, -89.084, 2703.580, -2145.100, 110.916},
    {"Richman", 321.356, -1044.070, -89.084, 647.557, -860.619, 110.916},
    {"Randolph Industrial Estate", 1558.090, 596.349, -89.084, 1823.080, 823.235, 110.916},
    {"East Beach", 2632.830, -1852.870, -89.084, 2959.350, -1668.130, 110.916},
    {"Flint Water", -314.426, -753.874, -89.084, -106.339, -463.073, 110.916},
    {"Blueberry", 19.607, -404.136, 3.8, 349.607, -220.137, 200.000},
    {"Linden Station", 2749.900, 1198.990, -89.084, 2923.390, 1548.990, 110.916},
    {"Glen Park", 1812.620, -1350.720, -89.084, 2056.860, -1100.820, 110.916},
    {"Downtown", -1993.280, 265.243, -9.1, -1794.920, 578.396, 200.000},
    {"Redsands West", 1377.390, 2243.230, -89.084, 1704.590, 2433.230, 110.916},
    {"Richman", 321.356, -1235.070, -89.084, 647.522, -1044.070, 110.916},
    {"Gant Bridge", -2741.450, 1659.680, -6.1, -2616.400, 2175.150, 200.000},
    {"Lil' Probe Inn", -90.218, 1286.850, -3.0, 153.859, 1554.120, 200.000},
    {"Flint Intersection", -187.700, -1596.760, -89.084, 17.063, -1276.600, 110.916},
    {"Las Colinas", 2281.450, -1135.040, -89.084, 2632.740, -945.035, 110.916},
    {"Sobell Rail Yards", 2749.900, 1548.990, -89.084, 2923.390, 1937.250, 110.916},
    {"The Emerald Isle", 2011.940, 2202.760, -89.084, 2237.400, 2508.230, 110.916},
    {"El Castillo del Diablo", -208.570, 2123.010, -7.6, 114.033, 2337.180, 200.000},
    {"Santa Flora", -2741.070, 458.411, -7.6, -2533.040, 793.411, 200.000},
    {"Playa del Seville", 2703.580, -2126.900, -89.084, 2959.350, -1852.870, 110.916},
    {"Market", 926.922, -1577.590, -89.084, 1370.850, -1416.250, 110.916},
    {"Queens", -2593.440, 54.722, 0.000, -2411.220, 458.411, 200.000},
    {"Pilson Intersection", 1098.390, 2243.230, -89.084, 1377.390, 2507.230, 110.916},
    {"Spinybed", 2121.400, 2663.170, -89.084, 2498.210, 2861.550, 110.916},
    {"Pilgrim", 2437.390, 1383.230, -89.084, 2624.400, 1783.230, 110.916},
    {"Blackfield", 964.391, 1403.220, -89.084, 1197.390, 1726.220, 110.916},
    {"'The Big Ear'", -410.020, 1403.340, -3.0, -137.969, 1681.230, 200.000},
    {"Dillimore", 580.794, -674.885, -9.5, 861.085, -404.790, 200.000},
    {"El Quebrados", -1645.230, 2498.520, 0.000, -1372.140, 2777.850, 200.000},
    {"Esplanade North", -2533.040, 1358.900, -4.5, -1996.660, 1501.210, 200.000},
    {"Easter Bay Airport", -1499.890, -50.096, -1.0, -1242.980, 249.904, 200.000},
    {"Fisher's Lagoon", 1916.990, -233.323, -100.000, 2131.720, 13.800, 200.000},
    {"Mulholland", 1414.070, -768.027, -89.084, 1667.610, -452.425, 110.916},
    {"East Beach", 2747.740, -1498.620, -89.084, 2959.350, -1120.040, 110.916},
    {"San Andreas Sound", 2450.390, 385.503, -100.000, 2759.250, 562.349, 200.000},
    {"Shady Creeks", -2030.120, -2174.890, -6.1, -1820.640, -1771.660, 200.000},
    {"Market", 1072.660, -1416.250, -89.084, 1370.850, -1130.850, 110.916},
    {"Rockshore West", 1997.220, 596.349, -89.084, 2377.390, 823.228, 110.916},
    {"Prickle Pine", 1534.560, 2583.230, -89.084, 1848.400, 2863.230, 110.916},
    {"Easter Basin", -1794.920, -50.096, -1.04, -1499.890, 249.904, 200.000},
    {"Leafy Hollow", -1166.970, -1856.030, 0.000, -815.624, -1602.070, 200.000},
    {"LVA Freight Depot", 1457.390, 863.229, -89.084, 1777.400, 1143.210, 110.916},
    {"Prickle Pine", 1117.400, 2507.230, -89.084, 1534.560, 2723.230, 110.916},
    {"Blueberry", 104.534, -220.137, 2.3, 349.607, 152.236, 200.000},
    {"El Castillo del Diablo", -464.515, 2217.680, 0.000, -208.570, 2580.360, 200.000},
    {"Downtown", -2078.670, 578.396, -7.6, -1499.890, 744.267, 200.000},
    {"Rockshore East", 2537.390, 676.549, -89.084, 2902.350, 943.235, 110.916},
    {"San Fierro Bay", -2616.400, 1501.210, -3.0, -1996.660, 1659.680, 200.000},
    {"Paradiso", -2741.070, 793.411, -6.1, -2533.040, 1268.410, 200.000},
    {"The Camel's Toe", 2087.390, 1203.230, -89.084, 2640.400, 1383.230, 110.916},
    {"Old Venturas Strip", 2162.390, 2012.180, -89.084, 2685.160, 2202.760, 110.916},
    {"Juniper Hill", -2533.040, 578.396, -7.6, -2274.170, 968.369, 200.000},
    {"Juniper Hollow", -2533.040, 968.369, -6.1, -2274.170, 1358.900, 200.000},
    {"Roca Escalante", 2237.400, 2202.760, -89.084, 2536.430, 2542.550, 110.916},
    {"Julius Thruway East", 2685.160, 1055.960, -89.084, 2749.900, 2626.550, 110.916},
    {"Verona Beach", 647.712, -2173.290, -89.084, 930.221, -1804.210, 110.916},
    {"Foster Valley", -2178.690, -599.884, -1.2, -1794.920, -324.114, 200.000},
    {"Arco del Oeste", -901.129, 2221.860, 0.000, -592.090, 2571.970, 200.000},
    {"Fallen Tree", -792.254, -698.555, -5.3, -452.404, -380.043, 200.000},
    {"The Farm", -1209.670, -1317.100, 114.981, -908.161, -787.391, 251.981},
    {"The Sherman Dam", -968.772, 1929.410, -3.0, -481.126, 2155.260, 200.000},
    {"Esplanade North", -1996.660, 1358.900, -4.5, -1524.240, 1592.510, 200.000},
    {"Financial", -1871.720, 744.170, -6.1, -1701.300, 1176.420, 300.000},
    {"Garcia", -2411.220, -222.589, -1.14, -2173.040, 265.243, 200.000},
    {"Montgomery", 1119.510, 119.526, -3.0, 1451.400, 493.323, 200.000},
    {"Creek", 2749.900, 1937.250, -89.084, 2921.620, 2669.790, 110.916},
    {"Los Santos International", 1249.620, -2394.330, -89.084, 1852.000, -2179.250, 110.916},
    {"Santa Maria Beach", 72.648, -2173.290, -89.084, 342.648, -1684.650, 110.916},
    {"Mulholland Intersection", 1463.900, -1150.870, -89.084, 1812.620, -768.027, 110.916},
    {"Angel Pine", -2324.940, -2584.290, -6.1, -1964.220, -2212.110, 200.000},
    {"Verdant Meadows", 37.032, 2337.180, -3.0, 435.988, 2677.900, 200.000},
    {"Octane Springs", 338.658, 1228.510, 0.000, 664.308, 1655.050, 200.000},
    {"Come-A-Lot", 2087.390, 943.235, -89.084, 2623.180, 1203.230, 110.916},
    {"Redsands West", 1236.630, 1883.110, -89.084, 1777.390, 2142.860, 110.916},
    {"Santa Maria Beach", 342.648, -2173.290, -89.084, 647.712, -1684.650, 110.916},
    {"Verdant Bluffs", 1249.620, -2179.250, -89.084, 1692.620, -1842.270, 110.916},
    {"Las Venturas Airport", 1236.630, 1203.280, -89.084, 1457.370, 1883.110, 110.916},
    {"Flint Range", -594.191, -1648.550, 0.000, -187.700, -1276.600, 200.000},
    {"Verdant Bluffs", 930.221, -2488.420, -89.084, 1249.620, -2006.780, 110.916},
    {"Palomino Creek", 2160.220, -149.004, 0.000, 2576.920, 228.322, 200.000},
    {"Ocean Docks", 2373.770, -2697.090, -89.084, 2809.220, -2330.460, 110.916},
    {"Easter Bay Airport", -1213.910, -50.096, -4.5, -947.980, 578.396, 200.000},
    {"Whitewood Estates", 883.308, 1726.220, -89.084, 1098.310, 2507.230, 110.916},
    {"Calton Heights", -2274.170, 744.170, -6.1, -1982.320, 1358.900, 200.000},
    {"Easter Basin", -1794.920, 249.904, -9.1, -1242.980, 578.396, 200.000},
    {"Los Santos Inlet", -321.744, -2224.430, -89.084, 44.615, -1724.430, 110.916},
    {"Doherty", -2173.040, -222.589, -1.0, -1794.920, 265.243, 200.000},
    {"Mount Chiliad", -2178.690, -2189.910, -47.917, -2030.120, -1771.660, 576.083},
    {"Fort Carson", -376.233, 826.326, -3.0, 123.717, 1220.440, 200.000},
    {"Foster Valley", -2178.690, -1115.580, 0.000, -1794.920, -599.884, 200.000},
    {"Ocean Flats", -2994.490, -222.589, -1.0, -2593.440, 277.411, 200.000},
    {"Fern Ridge", 508.189, -139.259, 0.000, 1306.660, 119.526, 200.000},
    {"Bayside", -2741.070, 2175.150, 0.000, -2353.170, 2722.790, 200.000},
    {"Las Venturas Airport", 1457.370, 1203.280, -89.084, 1777.390, 1883.110, 110.916},
    {"Blueberry Acres", -319.676, -220.137, 0.000, 104.534, 293.324, 200.000},
    {"Palisades", -2994.490, 458.411, -6.1, -2741.070, 1339.610, 200.000},
    {"North Rock", 2285.370, -768.027, 0.000, 2770.590, -269.740, 200.000},
    {"Hunter Quarry", 337.244, 710.840, -115.239, 860.554, 1031.710, 203.761},
    {"Los Santos International", 1382.730, -2730.880, -89.084, 2201.820, -2394.330, 110.916},
    {"Missionary Hill", -2994.490, -811.276, 0.000, -2178.690, -430.276, 200.000},
    {"San Fierro Bay", -2616.400, 1659.680, -3.0, -1996.660, 2175.150, 200.000},
    {"Restricted Area", -91.586, 1655.050, -50.000, 421.234, 2123.010, 250.000},
    {"Mount Chiliad", -2997.470, -1115.580, -47.917, -2178.690, -971.913, 576.083},
    {"Mount Chiliad", -2178.690, -1771.660, -47.917, -1936.120, -1250.970, 576.083},
    {"Easter Bay Airport", -1794.920, -730.118, -3.0, -1213.910, -50.096, 200.000},
    {"The Panopticon", -947.980, -304.320, -1.1, -319.676, 327.071, 200.000},
    {"Shady Creeks", -1820.640, -2643.680, -8.0, -1226.780, -1771.660, 200.000},
    {"Back o Beyond", -1166.970, -2641.190, 0.000, -321.744, -1856.030, 200.000},
    {"Mount Chiliad", -2994.490, -2189.910, -47.917, -2178.690, -1115.580, 576.083},
    {"Tierra Robada", -1213.910, 596.349, -242.990, -480.539, 1659.680, 900.000},
    {"Flint County", -1213.910, -2892.970, -242.990, 44.615, -768.027, 900.000},
    {"Whetstone", -2997.470, -2892.970, -242.990, -1213.910, -1115.580, 900.000},
    {"Bone County", -480.539, 596.349, -242.990, 869.461, 2993.870, 900.000},
    {"Tierra Robada", -2997.470, 1659.680, -242.990, -480.539, 2993.870, 900.000},
    {"San Fierro", -2997.470, -1115.580, -242.990, -1213.910, 1659.680, 900.000},
    {"Las Venturas", 869.461, 596.349, -242.990, 2997.060, 2993.870, 900.000},
    {"Red County", -1213.910, -768.027, -242.990, 2997.060, 596.349, 900.000},
    {"Los Santos", 44.615, -2892.970, -242.990, 2997.060, -768.027, 900.000}}
    for i, v in ipairs(streets) do
        if (x >= v[2]) and (y >= v[3]) and (z >= v[4]) and (x <= v[5]) and (y <= v[6]) and (z <= v[7]) then
            return v[1]
        end
    end
    return "Неизвестно"
end


function FormatTime(time)
    local timezone_offset = 86400 - os.date('%H', 0) * 3600
    local time = time + timezone_offset
    return  os.date((os.date("%H",time) == "00" and '%M:%S' or '%H:%M:%S'), time)
end

function EmulateKey(key, isDown)
    if not isDown then
        ffi.C.keybd_event(key, 0, 2, 0)
    else
        ffi.C.keybd_event(key, 0, 0, 0)
    end
end

function ShowImgui()
	return not isPauseMenuActive() and sampIsChatVisible() and not sampIsScoreboardOpen() and sampIsLocalPlayerSpawned() and not isSampfuncsConsoleActive()
end

function getTargetOnDistance(distance)
	local distance = distance or 0.0
	local allElement = {}
	local chars = table.map(getAllChars(), function (v)
		return {
			eType = "Char",
			value = v,
		}
	end)
	local vehs = table.map(getAllVehicles(), function (v)
		return {
			eType = "Car",
			value = v,
		}
	end)
	local allElement = table.merge(vehs, chars)
	local ox, oy, oz = getCharCoordinates(PLAYER_PED)
	local angle = getCharHeading(PLAYER_PED)
	local x, y, z = getOffsetFromCharInWorldCoords(PLAYER_PED, 0.0, 0.5, 0.0)
	local result = {
		exists = false,
		eType = nil,
		value = nil,
		dist = 1488.0
	}
	for k, v in ipairs(allElement) do
		if (v.eType == "Char" and v.value ~= PLAYER_PED) or v.eType == "Car" then
			local xt, yt, zt = _G["get" .. v.eType .. "Coordinates"](v.value)
			local distance_ = getDistanceBetweenCoords3d(x, y, z, xt, yt, zt)
			if distance_ < result.dist and distance_ <= distance then
				result = {
					exists = true,
					eType = v.eType,
					value = v.value,
					dist = distance_
				}
			end
		end
	end
	return result
end

function autoupdate(json_url, prefix, url)
  local dlstatus = require('moonloader').download_status
  local json = getWorkingDirectory() .. '\\'..thisScript().name..'-version.json'
  if doesFileExist(json) then os.remove(json) end
  downloadUrlToFile(json_url, json,
    function(id, status, p1, p2)
      if status == dlstatus.STATUSEX_ENDDOWNLOAD then
        if doesFileExist(json) then
          local f = io.open(json, 'r')
          if f then
            local info = decodeJson(f:read('*a'))
            updatelink = info.updateurl
            updateversion = info.latest
            f:close()
            os.remove(json)
            if updateversion ~= thisScript().version then
              lua_thread.create(function(prefix)
                local dlstatus = require('moonloader').download_status
                local color = -1
                sampAddChatMessage((prefix..'Обнаружено обновление. Пытаюсь обновиться c '..thisScript().version..' на '..updateversion), color)
                wait(250)
                downloadUrlToFile(updatelink, thisScript().path,
                  function(id3, status1, p13, p23)
                    if status1 == dlstatus.STATUS_DOWNLOADINGDATA then
                      print(string.format('Загружено %d из %d.', p13, p23))
                    elseif status1 == dlstatus.STATUS_ENDDOWNLOADDATA then
                      print('Загрузка обновления завершена.')
                      sampAddChatMessage((prefix..'Обновление завершено!'), color)
                      goupdatestatus = true
                      lua_thread.create(function() wait(500) thisScript():reload() end)
                    end
                    if status1 == dlstatus.STATUSEX_ENDDOWNLOAD then
                      if goupdatestatus == nil then
                        sampAddChatMessage((prefix..'Обновление прошло неудачно. Запускаю устаревшую версию..'), color)
                        update = false
                      end
                    end
                  end
                )
                end, prefix
              )
            else
              update = false
              print('v'..thisScript().version..': Обновление не требуется.')
            end
          end
        else
          print('v'..thisScript().version..': Не могу проверить обновление. Смиритесь или проверьте самостоятельно на '..url)
          update = false
        end
      end
    end
  )
  while update ~= false do wait(100) end
end