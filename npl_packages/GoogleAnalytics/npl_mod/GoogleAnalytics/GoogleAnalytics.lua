--[[
	title: google analytics client
	author: chenqh
	date: 2018/10/25
	desc: a simple google analytics client for npl, support both website and mobile app.
	only support event type for now.

	===========================================================================================
	useage:
	===========================================================================================

	-------------------------------------------------------------------------------------------
	-- Load and init
	-------------------------------------------------------------------------------------------

	-- load mod
	GoogleAnalytics = NPL.load("GoogleAnalytics")

	-- define parameters

	-- ua number from google
	-- this is the only one that's mandatory
	UA = 'UA-127983943-1'
	-- a account that represent a user, such as keepwork username or etc
	-- default: 'anonymous'
	user_id = 'dreamanddead'
	-- an id that marks a client, such as an uuid of a machine with paracraft installed
	-- default: a rand number
	client_id = '215150-24a97f-23'
	-- which app that is running. paracraft, haqi, haqi2 or etc
	-- default: 'npl analytics'
	app_name = 'paracraft'
	-- which version of current app. 0.7.14, 0.7.0, or etc
	-- default: '0.0'
	app_version = '0.7.14'
	-- how many api requests per second you limit
	-- default: 2
	api_rate = 4

	-- init ga client
	gaClient = GoogleAnalytics:new():init(UA, user_id, client_id, app_name, app_version, api_rate)

	-------------------------------------------------------------------------------------------
	-- Send Event
	-------------------------------------------------------------------------------------------

	-- category key and action key are mandatory
	-- ATTENTION options.value should be number type. it'll be converted to number if it's not.
	-- you'd better follow the 'number type' rule because the parameter converted is possibly not what you want.
	options = {
	  category = 'block',
	  action = 'create',
	  label = 'paracraft',
	  value = 62, -- a block id
	}

	gaClient:SendEvent(options)

	-------------------------------------------------------------------------------------------
	-- Session control
	-------------------------------------------------------------------------------------------

	-- force starting a new session
	gaClient:StartSession()
	-- force ending the current session
	gaClient:EndSession()
]]


local GoogleAnalytics = commonlib.inherit(nil, NPL.export())

local table_concat = table.concat
local rand = math.random
local http_post = System.os.GetUrl

local GA_URL = 'https://www.google-analytics.com/collect'
-- debug api address
-- local GA_URL = 'https://www.google-analytics.com/debug/collect'


function GoogleAnalytics:ctor()
end

function GoogleAnalytics:init(ua, user_id, client_id, app_name, app_version, api_rate)
	if not ua then
		LOG.std(nil, "error", "GoogleAnalytics->Init", "ua parameter is a must");
	end

	self.ua = ua
	self.user_id = user_id or 'anonymous'
	self.client_id = client_id or (rand(1000000000, 9999999999) .. '.' .. rand(1000000000, 9999999999))
	self.app_name = app_name or 'npl analytics'
	self.app_version = app_version or '0.0'
	self.data_source = 'app'

	-- limit request number per second
	self.avg_rate = api_rate or 2
	self.peak_rate = self.avg_rate * 4

	NPL.load("(gl)script/ide/Network/StreamRateController.lua");
	local StreamRateController = commonlib.gettable("commonlib.Network.StreamRateController");
	self.rate_limiter = StreamRateController:new({name="analytics-rate-limiter", history_length = self.peak_rate, max_msg_rate=self.avg_rate})

	return self
end

function GoogleAnalytics:_MergeOptions(options)
	-- https://developers.google.com/analytics/devguides/collection/protocol/v1/parameters
	-- there're too many parameters to use. we will extend it later.
	return {
		v = options.version or 1, -- ga api version
		tid = self.ua, -- tracking id (your ua number)
		uid = self.user_id, -- User ID, e.g. a login user name
		cid = self.client_id, -- client id number, e.g. the device UUID number
		z = options.z or rand(1000000000, 2147483647), -- a random number to avoid http cache

		sc = options.session_control, -- session control, 'start' or 'end'

		-- the type of tracking.
		-- event, transaction, pageview, screenview,
		-- item, social, exception, timing
		t = options.type,
		ec = options.category, -- event category
		ea = options.action, --- event action
		el = options.label, -- event label
		ev = options.value and tonumber(options.value), -- event value, must be number type

		ds = options.data_source or self.data_source, -- data source, like 'web', 'app' or others
		an = options.app_name or self.app_name, -- Application Name
		av = options.app_version or self.app_version, -- Application Version
		aid = options.app_id, -- Application ID, e.g. com.company.app
		aiid = options.app_installer_id, -- Application Installer ID, e.g. com.platform.vending

		sr = options.screen_resolution, -- device screen resolution, e.g. 800x600
		vp = options.view_port, -- device view port size, e.g. 123x456
		de = options.document_encoding or 'UTF-8', -- document encoding
		sd = options.screen_depth, -- screen color depth, e.g. 24-bits
		ul = options.user_language or 'zh-cn', -- user language

		aip = options.anonymous_ip,  -- boolean, 0 or 1. don't track my ip
		uip = options.user_ip, -- user machine ip address, in case user behind a proxy
		ua = options.user_agent, -- browser user agent
		geoid = options.geo_id, -- geo id, e.g. US

		-- custom dimensions, at most 20
		cd1 = options.custom_dimension_1,
		cd2 = options.custom_dimension_2,
		cd3 = options.custom_dimension_3,
		cd4 = options.custom_dimension_4,
		cd5 = options.custom_dimension_5,
		-- ....

		-- custom metrics, at most 20
		cm1 = options.custom_metric_1,
		cm2 = options.custom_metric_2,
		cm3 = options.custom_metric_3,
		cm4 = options.custom_metric_4,
		cm5 = options.custom_metric_5,
		-- ....
	}
end

function GoogleAnalytics:_HttpPost(url, payload, headers)
	return self.rate_limiter:AddMessage(1, function()
		http_post(
			{
				url = url,
				headers = {
					['User-Agent'] = headers.user_agent or 'npl analytics/0.0',
					['Content-Type'] = 'application/x-www-form-urlencoded',
				},
				postfields = payload,
			},
			function (err, msg, data)
				if(err == 200) then
					LOG.std(nil, "debug", "GoogleAnalytics event sent", payload)
				else
					LOG.std(nil, "warn", "GoogleAnalytics", "failed with http code: %d", err)
					LOG.std(nil, "warn", "GoogleAnalytics", payload)
				end
			end
		)
	end)
end

function GoogleAnalytics:_Collect(options)
	local merged_options = self:_MergeOptions(options)
	local payload = self:_GetPayload(merged_options)
	local url = GA_URL

	return self:_HttpPost(url, payload, {user_agent=options.user_agent})
end

-- https://github.com/stuartpb/tvtropes-lua/blob/master/urlencode.lua
local function encode(str)
	--Ensure all newlines are in CRLF form
	str = string.gsub (str, "\r?\n", "\r\n")

	--Percent-encode all non-unreserved characters
	--as per RFC 3986, Section 2.3
	--(except for space, which gets plus-encoded)
	str = string.gsub (str, "([^%w%-%.%_%~ ])",
					   function (c) return string.format ("%%%02X", string.byte(c)) end)

	--Convert spaces to plus signs
	str = string.gsub (str, " ", "+")

	return str
end

local function urlencode(options)
	local arr = {}
	for k, v in pairs(options) do
		if v ~= nil then
			arr[#arr+1] = encode(tostring(k)) .. '=' .. encode(tostring(v))
		end
	end
	return table_concat(arr, '&')
end

function GoogleAnalytics:_GetPayload(options)
	-- transform options from dict to x-www-url-encode form
	return urlencode(options)
end


function GoogleAnalytics:_CheckEvent(event)
	if next(event) == nil then
		return false
	end
	if (not event.category or not event.action) then
		return false
	end
	return true
end

function GoogleAnalytics:SendEvent(event)
	if not self:_CheckEvent(event) then
		LOG.std(nil, "error", "GoogleAnalytics->SendEvent, event object is illegal: ", event)
		return
	end
	event.type = 'event'

	return self:_Collect(event)
end

function GoogleAnalytics:_SendSession(session)
	local url = GA_URL
	options = self._MergeOptions(session)
	payload = self._GetPayload(options)

	LOG.std(nil, "debug", "GoogleAnalytics->send session", payload)
	return self:_HttpPost(url, payload, {user_agent=options.user_agent})
end

-- force start a new session
function GoogleAnalytics:StartSession()
	self._SendSession({session_control='start'})
end
-- force end the current session
function GoogleAnalytics:EndSession()
	self._SendSession({session_control='end'})
end
