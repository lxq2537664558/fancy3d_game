--[[
跨服聊天 view
2015年12月10日10:47:07
haohu
]]

_G.UIInterServiceChat = BaseUI:new("UIInterServiceChat")

UIInterServiceChat.channels = {};--所有显示的频道
UIInterServiceChat.currChannel = 0;--当前频道

UIInterServiceChat.isAutoHide = false;--是否是自动隐藏状态
UIInterServiceChat.outTime = 0;--鼠标离开UI的时间

UIInterServiceChat.lastSendTime = 0;--上次发送时间
UIInterServiceChat.lastSendText = nil;--上次发送的内容

UIInterServiceChat.currLink = "";--当前链接
UIInterServiceChat.quickSend = nil;--存储快捷发送

UIInterServiceChat.RefreshTime = 500;--聊天刷新时间(ms)
UIInterServiceChat.lastRefreshTime = 0;--聊天上次刷新时间
UIInterServiceChat.refreshState = 0;--刷新状态:0正常,1等待刷新

function UIInterServiceChat:Create()
	self:AddSWF("chatCross.swf", true, "interserver")
end

function UIInterServiceChat:OnLoaded(objSwf)
	ChatUtil:InitFilter();
	objSwf.btnHide.click = function() self:OnBtnHideClick();end
	objSwf.top.chatText.linkOver = function(e) self:OnLinkOver(e); end
	objSwf.top.chatText.linkOut = function() self:OnLinkOut(); end
	objSwf.top.chatText.linkClick = function() self:OnLinkClick(); end
	objSwf.bottom.btnFace.click = function() TipsManager:Hide();self:OnBtnFaceClick();end
	objSwf.bottom.btnEnter.click = function() self:OnBtnEnterClick();end
	objSwf.bottom.channelBar.itemClick = function(e) self:OnChannelItemClick(e);end
	objSwf.bottom.input.restrict = ChatConsts.Restrict;
	objSwf.bottom.input.textChange = function() self:OnInputChange(); end
	objSwf.bottom.input.pressKeyUp = function() self:OnInputKeyUp(); end
	objSwf.btnHide.rollOver = function()
		TipsManager:ShowBtnTips( objSwf.btnHide.selected and StrConfig['chat104'] or StrConfig['chat103'] )
	end
	objSwf.btnHide.rollOut = function() TipsManager:Hide(); end
	objSwf.bottom.btnFace.rollOver = function() TipsManager:ShowBtnTips(StrConfig["chat111"]); end
	objSwf.bottom.btnFace.rollOut = function() TipsManager:Hide(); end
end

function UIInterServiceChat:OnShow()
	self:ShowChannels()
	self:ShowChat()
	if self.autoHideTimerKey then
		TimerManager:UnRegisterTimer(self.autoHideTimerKey);
		self.autoHideTimerKey = nil;
	end
	self.autoHideTimerKey = TimerManager:RegisterTimer(function()
		self:AutoHideCheck();
	end,500,0);
end

function UIInterServiceChat:OnHide()
	if self.autoHideTimerKey then
		TimerManager:UnRegisterTimer(self.autoHideTimerKey);
		self.autoHideTimerKey = nil;
	end
end

function UIInterServiceChat:Update(e)
	if self.refreshState == 1 then
		if GetCurTime()-self.lastRefreshTime > UIInterServiceChat.RefreshTime then
			self:ShowChat();
			self.lastRefreshTime = GetCurTime();
			self.refreshState = 0;
		end
	end
end

function UIInterServiceChat:HandleNotification(name,body)
	if name == NotifyConsts.ChatChannelRefresh then
		if body.channel == self.currChannel then
			if GetCurTime()-self.lastRefreshTime > UIInterServiceChat.RefreshTime then
				self:ShowChat();
				self.lastRefreshTime = GetCurTime();
				self.refreshState = 0;
			else
				self.refreshState = 1;
			end
		end
	elseif name == NotifyConsts.ChatChannelNewMsg then
		self:ShowChannelEffect(body.channel);
	elseif name == NotifyConsts.StageClick then
		local inputTarget = string.gsub(self.objSwf.bottom.input._target,"/",".");
		if string.find(body.target,inputTarget) then
			return;
		end
		self:SetFocus(false);
	elseif name == NotifyConsts.StageFocusOut then
		self:SetFocus(false);
	end
end

function UIInterServiceChat:ListNotificationInterests()
	return {NotifyConsts.ChatChannelRefresh,
			NotifyConsts.ChatChannelNewMsg,
			NotifyConsts.StageClick,
			NotifyConsts.StageFocusOut};
end

--聊天获取焦点
function UIInterServiceChat:SetFocus(focuse)
	if not self.bShowState then return; end
	local objSwf = self.objSwf;
	if not objSwf then return; end
	objSwf.bottom.input.focused = focuse;
	if focuse then
		self:DoAutoHide(false);
	end
end

--显示频道
function UIInterServiceChat:ShowChannels()
	local objSwf = self.objSwf;
	if not objSwf then return; end
	local bar = objSwf.bottom.channelBar;
	self.channels = ChatUtil:GetCrossSeverChannels();
	local listStr = "";
	for i,channelListVO in ipairs(self.channels) do
		local uiDataStr = UIData.encode(channelListVO);
		listStr = listStr .. uiDataStr;
		if i < #self.channels then
			listStr = listStr .. ",";
		end
	end
	bar:setList(listStr);
	--
	for i,vo in ipairs(self.channels) do
		if self.currChannel == vo.channel then
			bar.selectedIndex = i-1;
			return;
		end
	end
	bar.selectedIndex = 0;
	self.currChannel = self.channels[1].channel
end

--显示聊天
function UIInterServiceChat:ShowChat()
	local objSwf = self.objSwf;
	if not objSwf then return; end
	local channel = ChatModel:GetChannel(self.currChannel);
	if not channel then return; end
	local text = "";
	for i,chatVO in ipairs(channel.chatList) do
		text = text .. chatVO:GetText();
		if i < #channel.chatList then
			text = text .. "<br/>";
		end
	end
	objSwf.top.chatText.htmlText = text;
	objSwf.top.chatText.position = objSwf.top.chatText.maxscroll;
end

--点击选择频道
function UIInterServiceChat:OnChannelItemClick(e)
	local objSwf = self.objSwf;
	if not objSwf then return; end
	if not self.channels[e.index+1] then return; end
	local channelListVO = self.channels[e.index+1];
	if self.currChannel == channelListVO.channel then
		return;
	end
	self.currChannel = channelListVO.channel
	self:ShowChat()
	--取消特效
	local button = objSwf.bottom.channelBar:getButtonAtIndex(e.index);
	if button then
		button.eff:stopEffect();
	end
end

--显示频道新消息特效
function UIInterServiceChat:ShowChannelEffect(channel)
	if channel == self.currChannel then return; end
	local objSwf = self.objSwf;
	if not objSwf then return; end
	for i,vo in ipairs(self.channels) do
		if vo.channel == channel then
			local button = objSwf.bottom.channelBar:getButtonAtIndex(i-1);
			if button then
				button.eff:playEffect(0);
				return;
			end
		end
	end
end

--点击收缩聊天
function UIInterServiceChat:OnBtnHideClick()
	TipsManager:Hide();
	local objSwf = self.objSwf;
	if not objSwf then return; end
	local show = not objSwf.btnHide.selected;
	objSwf.bottom._visible = show;
	objSwf.bottom.hitTestDisable = not show;
	objSwf.top.visible = show;
end

--点击表情
function UIInterServiceChat:OnBtnFaceClick()
	local objSwf = self.objSwf;
	if not objSwf then return; end
	UIChatFace:Open(function(text)
		objSwf.bottom.input:appendText(text);
		objSwf.bottom.input.focused = true;
	end,objSwf.bottom.btnFace);
end

--点击回车
function UIInterServiceChat:OnBtnEnterClick()
	local objSwf = self.objSwf;
	if not objSwf then return; end
	local text = objSwf.bottom.input.text;
	if text == "" then return; end
	if GetServerTime()-self.lastSendTime < ChatConsts.InputInterval then
		ChatController:AddSysNotice(self.currChannel,2001201,"",true);
		objSwf.bottom.input.text = "";
		self.lastSendText = text;
		return;
	end
	self:SendChat(text);
	objSwf.bottom.input.text = "";
	self.lastSendTime = GetServerTime();
	self.lastSendText = text;
end

--输入内容改变时
function UIInterServiceChat:OnInputChange()
	local objSwf = self.objSwf;
	if not objSwf then return; end
	local text = objSwf.bottom.input.text;
	if text=="" then return; end
	local hasEnter = false;
	text,hasEnter = ChatUtil:FilterInput(text);
	local len = 0;
	text,len = ChatUtil:CheckInputLength(text);
	if hasEnter or text:tail("\r") then
		if text:tail("\r") then
			local textLen = text:len();
			text = string.sub(text,1,textLen-1);
		end
		if text=="" then 
			objSwf.bottom.input.text = "";
			return;
		end
		if GetServerTime()-self.lastSendTime < ChatConsts.InputInterval then
			ChatController:AddSysNotice(self.currChannel,2001201,"",true);
			self.lastSendText = text;
			objSwf.bottom.input.text = "";
			return;
		end
		self:SendChat(text);
		objSwf.bottom.input.text = "";
		self.lastSendTime = GetServerTime();
		self.lastSendText = text;
	else
		objSwf.bottom.input.text = text;
	end
end

--发送聊天
function UIInterServiceChat:SendChat(text)
	if self.quickSend then
		text = string.gsub(text,"%[[^%[%]]+%]",
			function(pattern)
				local t = self.quickSend[pattern];
				if not t then return pattern; end
				if #t<=0 then return pattern; end
				return table.remove(t,1);
			end);
	end
	hack(text);
	ChatController:SendCrossChat(self.currChannel,text);
	self.quickSend = nil;
end

--按上翻页
function UIInterServiceChat:OnInputKeyUp()
	local objSwf = self.objSwf;
	if not objSwf then return; end
	if not self.lastSendText then return; end
	if objSwf.bottom.input.text ~= "" then return; end
	objSwf.bottom.input.text = self.lastSendText;
end

-----------自动隐藏处理-----------
local leftUpPoint = {x=0,y=0}
function UIInterServiceChat:AutoHideCheck()
	local objSwf = self.objSwf;
	if not objSwf then return; end
	if objSwf.bottom.input.focused then 
		self.outTime = 0;
		return; 
	end
	if objSwf.btnHide.selected then
		self.outTime = 0;
		return;
	end
	local mousePos = _sys:getRelativeMouse();
	UIManager:PosLtoG(objSwf,0,objSwf.bottom._y - objSwf.top._height,leftUpPoint);
	if mousePos.x > leftUpPoint.x and mousePos.y > leftUpPoint.y and mousePos.x <  leftUpPoint.x + objSwf.top._width then
		self:DoAutoHide(false);
		self.outTime = 0;
	else
		self.outTime = self.outTime + 500;
		if self.outTime > ChatConsts.PanelAutoHideTime then
			self:DoAutoHide(true);
		end
	end
end

function UIInterServiceChat:DoAutoHide(hide)
	if self.isAutoHide == hide then return; end
	self.isAutoHide = hide;
	local objSwf = self.objSwf;
	if not objSwf then return; end
	if hide then
		Tween:To(objSwf.bottom,0.5,{_alpha=0},{onComplete=function() objSwf.top.bg._visible = false; end});
		Tween:To(objSwf.btnHide,0.5,{_alpha=0},{onComplete=function() objSwf.btnHide._visible=false; end});
		Tween:To(objSwf.top.bg,0.5,{_alpha=0},{onComplete=function() 
											objSwf.top.bg._visible=false;
											end});
	else
		objSwf.bottom._visible = true;
		Tween:To(objSwf.bottom,0.5,{_alpha=100});
		objSwf.btnHide._visible = true;
		Tween:To(objSwf.btnHide,0.5,{_alpha=100});
		Tween:To(objSwf.top.bg,0.5,{_alpha=100});
		objSwf.top.bg._visible = true;
	end
end


-----------链接处理---------------
function UIInterServiceChat:OnLinkOver(e)
	if e.url==self.currLink then return; end
	self.currLink = e.url;
	local params = split(self.currLink,",");
	if #params<=0 then return; end
	local type = toint(params[1]);
	local parseClass = ChatConsts.ChatParamMap[type];
	if not parseClass then return; end
	local parser = parseClass:new();
	parser:DoLinkOver(self.currLink);
end
function UIInterServiceChat:OnLinkOut()
	self.currLink = "";
	TipsManager:Hide();
end
function UIInterServiceChat:OnLinkClick()
	if self.currLink=="" then return; end
	local params = split(self.currLink,",");
	if #params<=0 then return; end
	local type = toint(params[1]);
	local parseClass = ChatConsts.ChatParamMap[type];
	if not parseClass then return; end
	local parser = parseClass:new();
	parser:DoLink(self.currLink);
end
