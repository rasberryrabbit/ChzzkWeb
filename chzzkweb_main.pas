unit ChzzkWeb_Main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, XMLConf, Forms, Controls, Graphics, Dialogs, StdCtrls,
  uCEFWindowParent, uCEFChromium, uCEFApplication, uCEFConstants,
  uCEFInterfaces, uCEFChromiumEvents, uCEFTypes, uCEFChromiumCore, LMessages,
  ExtCtrls, ActnList, Menus, XMLPropStorage, uCEFWinControl, UniqueInstance,
  JvXPButtons, RxVersInfo, uWebExtHandler;


const
  LM_Execute_script = LM_USER+$102;

type

  { TFormChzzkWeb }

  TFormChzzkWeb = class(TForm)
    ActionChatuser: TAction;
    ActionWSockUnique: TAction;
    ActionOpenChatFull: TAction;
    ActionChatTime: TAction;
    ActionDebugLog: TAction;
    ActionOpenNotify: TAction;
    ActionOpenChat: TAction;
    ActionWSPort: TAction;
    ActionList1: TActionList;
    ButtonHome: TButton;
    ButtonGo: TButton;
    CEFWindowParent1: TCEFWindowParent;
    Chromium1: TChromium;
    Editurl: TEdit;
    JvXPButton1: TJvXPButton;
    Label1: TLabel;
    MainMenu1: TMainMenu;
    MenuItem1: TMenuItem;
    MenuItem10: TMenuItem;
    MenuItem2: TMenuItem;
    MenuItem3: TMenuItem;
    MenuItem4: TMenuItem;
    MenuItem5: TMenuItem;
    MenuItem6: TMenuItem;
    MenuItem7: TMenuItem;
    MenuItem9: TMenuItem;
    RxVersionInfo1: TRxVersionInfo;
    Timer1: TTimer;
    Timer2: TTimer;
    UniqueInstance1: TUniqueInstance;
    XMLConfig1: TXMLConfig;
    XMLPropStorage1: TXMLPropStorage;
    procedure ActionChatTimeExecute(Sender: TObject);
    procedure ActionChatuserExecute(Sender: TObject);
    procedure ActionDebugLogExecute(Sender: TObject);
    procedure ActionOpenChatExecute(Sender: TObject);
    procedure ActionOpenChatFullExecute(Sender: TObject);
    procedure ActionOpenNotifyExecute(Sender: TObject);
    procedure ActionWSockUniqueExecute(Sender: TObject);
    procedure ActionWSPortExecute(Sender: TObject);
    procedure ButtonHomeClick(Sender: TObject);
    procedure ButtonRunClick(Sender: TObject);
    procedure ButtonGoClick(Sender: TObject);
    procedure Chromium1AddressChange(Sender: TObject;
      const browser: ICefBrowser; const frame: ICefFrame; const url: ustring);
    // CEF
    procedure Chromium1AfterCreated(Sender: TObject; const browser: ICefBrowser
      );
    procedure Chromium1BeforeClose(Sender: TObject; const browser: ICefBrowser);
    procedure Chromium1BeforeDevToolsPopup(Sender: TObject;
      const browser: ICefBrowser; var windowInfo: TCefWindowInfo;
      var client: ICefClient; var settings: TCefBrowserSettings;
      var extra_info: ICefDictionaryValue; var use_default_window: boolean);
    procedure Chromium1BeforePopup(Sender: TObject; const browser: ICefBrowser;
      const frame: ICefFrame; const targetUrl, targetFrameName: ustring;
      targetDisposition: TCefWindowOpenDisposition; userGesture: Boolean;
      const popupFeatures: TCefPopupFeatures; var windowInfo: TCefWindowInfo;
      var client: ICefClient; var settings: TCefBrowserSettings;
      var extra_info: ICefDictionaryValue; var noJavascriptAccess: Boolean;
      var Result: Boolean);
    procedure Chromium1ChromeCommand(Sender: TObject;
      const browser: ICefBrowser; command_id: integer;
      disposition: TCefWindowOpenDisposition; var aResult: boolean);
    procedure Chromium1Close(Sender: TObject; const browser: ICefBrowser;
      var aAction: TCefCloseBrowserAction);
    procedure Chromium1LoadingProgressChange(Sender: TObject;
      const browser: ICefBrowser; const progress: double);
    procedure Chromium1LoadingStateChange(Sender: TObject;
      const browser: ICefBrowser; isLoading, canGoBack, canGoForward: Boolean);
    procedure Chromium1ProcessMessageReceived(Sender: TObject;
      const browser: ICefBrowser; const frame: ICefFrame;
      sourceProcess: TCefProcessId; const message: ICefProcessMessage; out
      Result: Boolean);
    procedure EditurlKeyPress(Sender: TObject; var Key: char);

    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure JvXPButton1Click(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure Timer2Timer(Sender: TObject);
  private
    procedure ExecuteScript(var Msg:TLMessage); message LM_Execute_script;

    // CEF
    procedure CEFCreated(var Msg:TLMessage); message CEF_AFTERCREATED;
    procedure CEFDestroy(var Msg:TLMessage); message CEF_DESTROY;
  public
    procedure SetFormCaption;

    procedure SetUpWebSocketPort;
    procedure ReplaceWSPortHTML(const fname, port1, port2: string);

  end;

var
  FormChzzkWeb: TFormChzzkWeb;

procedure CreateGlobalCEFApp;

implementation

uses
  uCEFMiscFunctions, uCEFProcessMessage, uCEFDomVisitor, uCEFStringMap,
  Windows, uWebsockSimple, ShellApi, DateUtils, StrUtils,
  regexpr;


{$R *.lfm}

const
  MaxLength = 2048;
  cqueryjs = 'var obser=document.querySelector("div.live_chatting_list_wrapper__a5XTV");'+
             'if(obser) {'+
             'browserExt.postMessage("!Observer Start!");'+
             'const observer = new MutationObserver((mutations) => {'+
             'mutations.forEach(mutat => {'+
             'mutat.addedNodes.forEach(node => {'+
             'browserExt.postMessage(node.outerHTML);'+
             '});'+
             '});'+
             '});'+
             'observer.observe(obser, {'+
             '    subtree: false,'+
             '    attributes: false,'+
             '    childList: true,'+
             '    characterData: false,'+
             '    });'+
             'observer.start();'+
             'window.addEventListener(''unload'', function() {'+
             '  observer.disconnect();'+
             '});'+
             '}';

  syschat_str = '0SGhw live_chatting_list';
  syschat_guide = 'live_chatting_guide_';


var
  WSPortChat: string = '65002';
  WSPortSys: string = '65003';
  WSPortUnique: Boolean = False;
  SockServerChat: TSimpleWebsocketServer;
  SockServerSys: TSimpleWebsocketServer;
  ProcessSysChat: Boolean = False;
  //CEFDebugLog: Boolean = False;
  IncludeChatTime: Boolean = False;
  chatlog_full: string = 'doc\webchatlog_list.html';
  chatlog_full_unique: string = 'doc\webchatlog_list_unique.html';
  chatlog_donation: string = 'doc\webchatlog_donation_sub.html';
  chatlog_chatonly: string = 'doc\webchatlog_chatbox.html';
  chatlog_userid: string = 'doc\webchatlog_user_unique.html';
  stripusertooltip: TRegExpr;
  PageLoaded: Boolean = False;
  observer_started: Boolean = False;
  FTemp: ustring;


{ TFormChzzkWeb }

procedure TFormChzzkWeb.ButtonHomeClick(Sender: TObject);
begin
  Chromium1.LoadURL('https://chzzk.naver.com');
end;

procedure TFormChzzkWeb.ActionWSPortExecute(Sender: TObject);
var
  ir, i: Integer;
  port: string;
begin
  ir:=InputCombo('웹소켓 포트','웹소켓 포트를 지정',['65002','65010','65020','65030','65040']);
  case ir of
  1: WSPortChat:='65002';
  2: WSPortChat:='65010';
  3: WSPortChat:='65020';
  4: WSPortChat:='65030';
  5: WSPortChat:='65040';
  end;
  if ir<>-1 then
    begin
      try
        SetUpWebSocketPort;
        ReplaceWSPortHTML(chatlog_chatonly,WSPortChat,'');
        ReplaceWSPortHTML(chatlog_donation,WSPortSys,'');
        ReplaceWSPortHTML(chatlog_userid,WSPortChat,'');
        ReplaceWSPortHTML(chatlog_full_unique,WSPortChat,'');
        ReplaceWSPortHTML(chatlog_full,WSPortChat,WSPortSys);
        XMLConfig1.SetValue('WS/PORT',WSPortChat);
        XMLConfig1.SetValue('WS/PORTSYS',WSPortSys);
        SetFormCaption;
      except
        on e:exception do
          ShowMessage(e.Message);
      end;
    end;
end;

procedure TFormChzzkWeb.ActionOpenChatExecute(Sender: TObject);
begin
  ShellExecuteW(0,'open',pwidechar(ExtractFilePath(Application.ExeName)+UTF8Decode(chatlog_chatonly)),nil,nil,SW_SHOWNORMAL);
end;

procedure TFormChzzkWeb.ActionOpenChatFullExecute(Sender: TObject);
begin
  ShellExecuteW(0,'open',pwidechar(ExtractFilePath(Application.ExeName)+UTF8Decode(chatlog_full)),nil,nil,SW_SHOWNORMAL);
end;

procedure TFormChzzkWeb.ActionDebugLogExecute(Sender: TObject);
begin
  ActionDebugLog.Checked:=not ActionDebugLog.Checked;
  //CEFDebugLog:=ActionDebugLog.Checked;
end;

procedure TFormChzzkWeb.ActionChatTimeExecute(Sender: TObject);
begin
  ActionChatTime.Checked:=not ActionChatTime.Checked;
  IncludeChatTime:=ActionChatTime.Checked;
  XMLConfig1.SetValue('IncludeTime',IncludeChatTime);
end;

procedure TFormChzzkWeb.ActionChatuserExecute(Sender: TObject);
begin
  ShellExecuteW(0,'open',pwidechar(ExtractFilePath(Application.ExeName)+UTF8Decode(chatlog_userid)),nil,nil,SW_SHOWNORMAL);
end;

procedure TFormChzzkWeb.ActionOpenNotifyExecute(Sender: TObject);
begin
  ShellExecuteW(0,'open',pwidechar(ExtractFilePath(Application.ExeName)+UTF8Decode(chatlog_donation)),nil,nil,SW_SHOWNORMAL);
end;

procedure TFormChzzkWeb.ActionWSockUniqueExecute(Sender: TObject);
begin
  ActionWSockUnique.Checked:=not ActionWSockUnique.Checked;
  WSPortUnique:=ActionWSockUnique.Checked;
  XMLConfig1.SetValue('WS/UNIQUE',WSPortUnique);
end;

procedure TFormChzzkWeb.ButtonRunClick(Sender: TObject);
begin

end;

procedure TFormChzzkWeb.ButtonGoClick(Sender: TObject);
begin
  Chromium1.LoadURL(Editurl.Text);
end;

procedure TFormChzzkWeb.Chromium1AddressChange(Sender: TObject;
  const browser: ICefBrowser; const frame: ICefFrame; const url: ustring);
begin
  Editurl.Text:=url;
  observer_started:=False;
  Timer2.Enabled:=True;
end;

procedure TFormChzzkWeb.Chromium1AfterCreated(Sender: TObject;
  const browser: ICefBrowser);
begin
  PostMessage(Handle, CEF_AFTERCREATED, 0,0);
end;

procedure TFormChzzkWeb.Chromium1BeforeClose(Sender: TObject;
  const browser: ICefBrowser);
begin
  PostMessage(Handle, WM_CLOSE, 0,0);
end;

procedure TFormChzzkWeb.Chromium1BeforeDevToolsPopup(Sender: TObject;
  const browser: ICefBrowser; var windowInfo: TCefWindowInfo;
  var client: ICefClient; var settings: TCefBrowserSettings;
  var extra_info: ICefDictionaryValue; var use_default_window: boolean);
begin

end;

procedure TFormChzzkWeb.Chromium1BeforePopup(Sender: TObject;
  const browser: ICefBrowser; const frame: ICefFrame; const targetUrl,
  targetFrameName: ustring; targetDisposition: TCefWindowOpenDisposition;
  userGesture: Boolean; const popupFeatures: TCefPopupFeatures;
  var windowInfo: TCefWindowInfo; var client: ICefClient;
  var settings: TCefBrowserSettings; var extra_info: ICefDictionaryValue;
  var noJavascriptAccess: Boolean; var Result: Boolean);
begin
  Result := (targetDisposition in [CEF_WOD_NEW_FOREGROUND_TAB, CEF_WOD_NEW_BACKGROUND_TAB, CEF_WOD_NEW_POPUP, CEF_WOD_NEW_WINDOW]);
end;

procedure TFormChzzkWeb.Chromium1ChromeCommand(Sender: TObject;
  const browser: ICefBrowser; command_id: integer;
  disposition: TCefWindowOpenDisposition; var aResult: boolean);
begin
    aResult:=True;
end;

procedure TFormChzzkWeb.Chromium1Close(Sender: TObject; const browser: ICefBrowser;
  var aAction: TCefCloseBrowserAction);
begin
  PostMessage(Handle, CEF_DESTROY, 0, 0);
  aAction := cbaDelay;
end;

procedure TFormChzzkWeb.Chromium1LoadingProgressChange(Sender: TObject;
  const browser: ICefBrowser; const progress: double);
begin
end;

procedure TFormChzzkWeb.Chromium1LoadingStateChange(Sender: TObject;
  const browser: ICefBrowser; isLoading, canGoBack, canGoForward: Boolean);
begin

end;

function InsertTime(var s:ustring):Boolean;
var
  tp, sp: Integer;
begin
  tp:=Pos('<',s);
  sp:=Pos(' ',s);
  if (tp+sp>1) and (sp>tp) then
    begin
      Inc(sp);
      Insert('Time="'+IntToStr(DateTimeToUnix(Now))+'" ', s, sp);
    end;
end;

procedure TFormChzzkWeb.Chromium1ProcessMessageReceived(Sender: TObject;
  const browser: ICefBrowser; const frame: ICefFrame;
  sourceProcess: TCefProcessId; const message: ICefProcessMessage; out
  Result: Boolean);
var
  buf: ustring;
begin
  // browser message
  Result := False;
  if message=nil then
    exit;
  if message.Name='postMessage' then
    begin
      buf:=message.ArgumentList.GetString(0);
      if buf='!Observer Start!' then begin
        observer_started:=True;
      end else
      begin
        if (Pos(UTF8Decode(syschat_str),buf)>0) and
           (Pos(UTF8Decode(syschat_guide),buf)=0) then
         begin
           SockServerSys.BroadcastMsg(UTF8Encode(buf));
           if WSPortUnique then
             SockServerChat.BroadcastMsg(UTF8Encode(buf));
         end
         else
           SockServerChat.BroadcastMsg(UTF8Encode(buf));

        //if IncludeChatTime then
        //  InsertTime(s);
        Result:=True;
      end;
    end;
end;

procedure TFormChzzkWeb.EditurlKeyPress(Sender: TObject; var Key: char);
begin
  if Key=#13 then
    begin
      Key:=#0;
      ButtonGo.Click;
    end;
end;

procedure TFormChzzkWeb.FormClose(Sender: TObject; var CloseAction: TCloseAction
  );
begin

end;

procedure TFormChzzkWeb.FormDestroy(Sender: TObject);
begin
  SockServerChat.Free;
  SockServerSys.Free;
  XMLConfig1.SetValue('CHAT/FULL',UTF8Decode(chatlog_full));
  XMLConfig1.SetValue('CHAT/CHAT',UTF8Decode(chatlog_chatonly));
  XMLConfig1.SetValue('CHAT/DONATION',UTF8Decode(chatlog_donation));
  if XMLConfig1.Modified then
    XMLConfig1.SaveToFile('config.xml');
end;

procedure TFormChzzkWeb.FormShow(Sender: TObject);
begin

  if FileExists('config.xml') then
    XMLConfig1.LoadFromFile('config.xml');

  IncludeChatTime:=XMLConfig1.GetValue('IncludeTime',False);
  WSPortChat:=XMLConfig1.GetValue('WS/PORT','65002');
  WSPortSys:=XMLConfig1.GetValue('WS/PORTSYS','65003');
  WSPortUnique:=XMLConfig1.GetValue('WS/UNIQUE',WSPortUnique);
  ActionChatTime.Checked:=IncludeChatTime;
  ActionWSockUnique.Checked:=WSPortUnique;

  chatlog_full:=UTF8Encode(XMLConfig1.GetValue('CHAT/FULL',UTF8Decode(chatlog_full)));
  chatlog_full_unique:=UTF8Encode(XMLConfig1.GetValue('CHAT/FULLUNIQUE',UTF8Decode(chatlog_full_unique)));
  chatlog_chatonly:=UTF8Encode(XMLConfig1.GetValue('CHAT/CHAT',UTF8Decode(chatlog_chatonly)));
  chatlog_donation:=UTF8Encode(XMLConfig1.GetValue('CHAT/DONATION',UTF8Decode(chatlog_donation)));
  chatlog_userid:=UTF8Encode(XMLConfig1.GetValue('CHAT/USERID',UTF8Decode(chatlog_userid)));

  SetUpWebSocketPort;
  SetFormCaption;

  if not(Chromium1.CreateBrowser(CEFWindowParent1, '')) then Timer1.Enabled := True;
end;

procedure TFormChzzkWeb.JvXPButton1Click(Sender: TObject);
begin
  Timer2.Enabled:=not Timer2.Enabled;
  if Timer2.Enabled then
    JvXPButton1.Caption:='실행 중'
    else
      JvXPButton1.Caption:='대기 중';
end;

procedure TFormChzzkWeb.Timer1Timer(Sender: TObject);
begin
  // prepare chromium
  Timer1.Enabled := False;
  if not(Chromium1.CreateBrowser(CEFWindowParent1, '')) and not(Chromium1.Initialized) then
    Timer1.Enabled := True;
end;

procedure TFormChzzkWeb.Timer2Timer(Sender: TObject);
begin
  PostMessage(Handle, LM_Execute_script, 0, 0);
end;

procedure TFormChzzkWeb.ExecuteScript(var Msg: TLMessage);
var
  TempMsg : ICefProcessMessage;
begin
  if observer_started then
    exit;
  // Send Message to Renderer for parsing
  if 0<Pos('chzzk.naver.com/live/',Chromium1.DocumentURL) then
    Chromium1.ExecuteJavaScript(cqueryjs,'');
end;

procedure TFormChzzkWeb.CEFCreated(var Msg: TLMessage);
begin
  CEFWindowParent1.UpdateSize;
  // loading chzzk live
  ButtonGo.Click;
end;

procedure TFormChzzkWeb.CEFDestroy(var Msg: TLMessage);
begin
  CEFWindowParent1.Free;
  if XMLConfig1.Modified then
    XMLConfig1.SaveToFile('config.xml');
end;

procedure TFormChzzkWeb.SetFormCaption;
var
  cefVer: Cardinal;
begin
  cefVer:=GetFileVersion('libcef');
  Caption:='ChzzkWeb '+RxVersionInfo1.FileVersion+' '+IntToHex(cefVer,8)+' @'+WSPortChat;
end;

procedure TFormChzzkWeb.SetUpWebSocketPort;
var
  i, j: Integer;
begin
  // start websocket server
  if Assigned(SockServerChat) then
    SockServerChat.Free;
  if Assigned(SockServerSys) then
    SockServerSys.Free;
  j:=0;
  if not TryStrToInt(WSPortChat,i) then
  begin
    WSPortChat:='65002';
    i:=65002;
  end;
  while j<8 do begin
    try
      SockServerChat:=TSimpleWebsocketServer.Create(WSPortChat);
      try
        WSPortSys:=IntToStr(i+1);
        SockServerSys:=TSimpleWebsocketServer.Create(WSPortSys);
        break;
      except
        SockServerChat.Free;
        raise;
      end;
    except
      Inc(j,2);
      Inc(i,j);
      WSPortChat:=IntToStr(i);
    end;
  end;
end;

procedure TFormChzzkWeb.ReplaceWSPortHTML(const fname, port1, port2: string);
const
  rport = '(?-s)(WebSocket\(\"ws\:.+)(\:\d+)(\",\"chat\"\);)';
var
  fs: TStringStream;
  regport: TRegExpr;
  res: string;
  i, j: Integer;
begin
  res:='';
  i:=1;
  fs := TStringStream.Create('');
  try
    fs.LoadFromFile(fname);
    regport:=TRegExpr.Create(rport);
    try
      // first item
      if (port1<>'') and regport.Exec(fs.DataString) then
      begin
        j:=regport.MatchPos[2];
        res:=res+Copy(fs.DataString,i,j-i+1)+port1;
        i:=regport.MatchPos[3];
      end;
      // second item
      if (port2<>'') and regport.ExecNext then
      begin
        j:=regport.MatchPos[2];
        res:=res+Copy(fs.DataString,i,j-i+1)+port2;
        i:=regport.MatchPos[3];
      end;
      res:=res+Copy(fs.DataString,i);
      // save to file
      fs.Clear;
      fs.WriteString(res);
      fs.SaveToFile(fname);
    finally
      regport.Free;
    end;
  finally
    fs.Free;
  end;
end;

procedure GlobalCEFApp_OnWebKitInitialized;
var
  TempExtensionCode : string;
  TempHandler       : ICefv8Handler;
begin

  TempExtensionCode := 'var browserExt;' +
                       'if (!browserExt)' +
                       '  browserExt = {};' +
                       '(function() {' +
                       '  browserExt.postMessage = function(b) {' +
                       '    native function postMessage();' +
                       '    postMessage(b);' +
                       '  };' +
                       '})();';

  try
    TempHandler := TWebExtensionHandler.Create;

    if CefRegisterExtension('browserExt', TempExtensionCode, TempHandler) then
      {CEFDebugLog('JavaScript extension registered successfully!')}
     else
      {CefDebugLog('There was an error registering the JavaScript extension!')};
  finally
    TempHandler := nil;
  end;
end;

// initialize CEF

procedure CreateGlobalCEFApp;
begin
  GlobalCEFApp                     := TCefApplication.Create;
  GlobalCEFApp.OnWebKitInitialized := @GlobalCEFApp_OnWebKitInitialized;
  GlobalCEFApp.cache               := 'cache';
  GlobalCEFApp.LogFile             := 'debug.log';
  GlobalCEFApp.LogSeverity         := LOGSEVERITY_ERROR;
  GlobalCEFApp.EnablePrintPreview  := False;
  //GlobalCEFApp.EnableGPU           := True;
  GlobalCEFApp.SetCurrentDir       := True;
  GlobalCEFApp.CheckCEFFiles       := False;
  //GlobalCEFApp.SingleProcess       := True;
end;

initialization

finalization


end.

