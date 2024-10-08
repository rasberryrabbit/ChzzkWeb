unit ChzzkWeb_Main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, XMLConf, Forms, Controls, Graphics, Dialogs, StdCtrls,
  uCEFWindowParent, uCEFChromium, uCEFApplication, uCEFConstants,
  uCEFInterfaces, uCEFChromiumEvents, uCEFTypes, uCEFChromiumCore, LMessages,
  ExtCtrls, ActnList, Menus, uCEFWinControl, UniqueInstance, JvXPButtons,
  RxVersInfo;


const
  MSGVISITDOM = LM_USER+$102;
  SVISITDOM   = 'V_RENDERER';
  SLOGCHAT = 'V_LOGCHAT';
  SLOGSYS = 'V_LOGSYS';
  strhidden = 'hidden';

type

  { TFormChzzkWeb }

  TFormChzzkWeb = class(TForm)
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
    MenuItem8: TMenuItem;
    MenuItem9: TMenuItem;
    RxVersionInfo1: TRxVersionInfo;
    Timer1: TTimer;
    Timer2: TTimer;
    UniqueInstance1: TUniqueInstance;
    XMLConfig1: TXMLConfig;
    procedure ActionChatTimeExecute(Sender: TObject);
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
    procedure Chromium1BeforePopup(Sender: TObject; const browser: ICefBrowser;
      const frame: ICefFrame; const targetUrl, targetFrameName: ustring;
      targetDisposition: TCefWindowOpenDisposition; userGesture: Boolean;
      const popupFeatures: TCefPopupFeatures; var windowInfo: TCefWindowInfo;
      var client: ICefClient; var settings: TCefBrowserSettings;
      var extra_info: ICefDictionaryValue; var noJavascriptAccess: Boolean;
      var Result: Boolean);
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
    procedure VISITDOM(var Msg:TLMessage); message MSGVISITDOM;

    // CEF
    procedure CEFCreated(var Msg:TLMessage); message CEF_AFTERCREATED;
    procedure CEFDestroy(var Msg:TLMessage); message CEF_DESTROY;
  public
    procedure SetFormCaption;

  end;

var
  FormChzzkWeb: TFormChzzkWeb;

procedure CreateGlobalCEFApp;

implementation

uses
  uCEFMiscFunctions, uCEFProcessMessage, uCEFDomVisitor, uCEFStringMap,
  Windows, uWebsockSimple, uChecksumList, ShellApi, DateUtils, StrUtils;


{$R *.lfm}

const
  MaxLength = 2048;

var
  WSPortChat: string = '65002';
  WSPortSys: string = '65003';
  WSPortUnique: Boolean = False;
  SockServerChat: TSimpleWebsocketServer;
  SockServerSys: TSimpleWebsocketServer;
  ProcessSysChat: Boolean = False;
  CheckHidden: TDigest;
  CEFDebugLog: Boolean = False;
  iCountVisit: Integer = 0;
  IncludeChatTime: Boolean = False;
  chatlog_full: string = 'doc\webchatlog_list.html';
  chatlog_donation: string = '\doc\도네_구독_메시지.html';
  chatlog_chatonly: string = 'doc\채팅.html';


function GetChatMarkup(Node: ICefDomNode):ustring;
const
  taguser = '<span class="name_text__';
var
  utxt: ustring;
  ix: Integer;
begin
  Result:='';
  if Assigned(Node) then
    begin
      utxt:=Node.AsMarkup;
      ix:=Pos(taguser,utxt);
      if ix>0 then
        Result:=Copy(utxt,ix);
    end;
  if Result='' then
    Result:=strhidden;
end;

function GetNonChatMarkup(Node: ICefDomNode):ustring;
var
  temp: ICefDomNode;
begin
  Result:='subscribe';
  if Assigned(Node) then
    begin
      temp:=Node.FirstChild;
      if Assigned(temp) then
        begin
          temp:=temp.FirstChild;
          if Assigned(temp) then
            Result:=temp.AsMarkup;
        end;
    end;
end;

{function GetElementAttr(const Node: ICefDomNode):ustring;
var
  attr: ICefStringMap;
begin
  attr:=TCefStringMapOwn.Create;
  try
    Node.GetElementAttributes(attr);
    Result:=attr.Find('class');
  finally
    attr:=nil;
  end;
end;}

function CheckElementAttr(const str: ustring; const Node: ICefDomNode):Boolean;
var
  markup: ustring;
  ia, ib, ic, id: Integer;
begin
  {Result:=False;
  markup:=Node.AsMarkup;
  ia:=Pos('class',markup);
  if ia>0 then
    begin
      ib:=PosEx('"',markup,ia);
      if ib>0 then
        begin
          ic:=PosEx('"',markup,ib+1);
          if ic>0 then
            begin
              id:=PosEx(str,markup,ib);
              Result:=(id>0) and (id<ic);
            end;
        end;
    end;}
  Result:=Pos(str,Node.GetElementAttribute('class'))>0;
end;

function ExtractChat(const ANode: ICefDomNode; var Res:ICefDomNode; const aFrame: ICefFrame):Boolean;
const
  nonchatclass = ' live_chatting_list_';
  hiddenchatclass = '_message_is_hidden';
  chatclass = 'live_chatting_list_item';
  chatcontainer = 'live_chatting_list_wrapper';
  chatguide = '_list_guide_';
  chatdonation = '_list_donation_';
  chatsubscription = '_list_subscription_';
var
  TempChild, ChatNode, ChatBottom, ChatFirst, ChatComp, ChatCon: ICefDomNode;
  nodeattr: ustring;

  CheckItem, CheckItemLast: TDigest;
  pBuild, pPrev: pChecksumData;
  DupCount, PrevCount: Integer;
  s: UnicodeString;
  bMake, bCompare, bDup, bHidden: Boolean;

  Msg: ICefProcessMessage;
begin
  Result:=False;
  TempChild:=ANode;
  try
  if TempChild<>nil then
    begin
      // search chat list
      while TempChild<>nil do
        begin
          if (TempChild.Name='DIV') and CheckElementAttr(chatcontainer,TempChild) then
            begin
              Res:=TempChild;
              Result:=True;
              break;
            end;
          if TempChild.HasChildren then
            begin
              if ExtractChat(TempChild.FirstChild,Res,aFrame) then
                break;
            end;
          TempChild:=TempChild.NextSibling;
        end;
      // process chat list
      if Res<>nil then
        begin
          TempChild:=Res;
          Res:=nil;
          // search chat DOM
          if (TempChild.Name='DIV') and CheckElementAttr(chatcontainer, TempChild) then
            begin
              //Res:=TempChild;
              ChatNode:=TempChild.LastChild;

              CheckBuild.Clear;
              ChatBottom:=ChatNode;
              ChatFirst:=nil;
              bCompare:=True;
              bMake:=True;
              bDup:=False;
              MakeCheck('',CheckItemLast);
              DupCount:=0;
              // chat log
              while ChatNode<>nil do
                begin
                  nodeattr:=ChatNode.AsMarkup;
                  // chat only
                  if (POS(chatclass,nodeattr)<>0) then
                       begin
                         bHidden:=False;
                         // chat
                         if ChatBottom=nil then
                           ChatBottom:=ChatNode;

                         // build checksum list
                         if bMake then
                           begin
                             // non-chat class
                             if Pos(nonchatclass,nodeattr)<>0 then
                               begin
                                 s:=GetNonChatMarkup(ChatNode);
                                 MakeCheck(copy(s,1,MaxLength),CheckItem);
                                 bHidden:=True;
                                 //CefLog('ChzzkWeb', 1, CEF_LOG_SEVERITY_ERROR, '<38> ' + s);
                               end;
                             if not bHidden then
                               begin
                                 // make checksum
                                 s:=GetChatMarkup(ChatNode);
                                 MakeCheck(copy(s,1,MaxLength),CheckItem);
                                 //CefLog('ChzzkWeb', 1, CEF_LOG_SEVERITY_ERROR, '<30> ' + s);
                               end;

                             bDup:=CompareCheck(CheckItem,CheckItemLast);
                             if bDup then
                               Inc(DupCount)
                               else
                                 DupCount:=0;
                             CheckItemLast:=CheckItem;
                             if bDup then
                               begin
                                 pBuild^.dup:=DupCount;
                               end else
                                 begin
                                   if CheckBuild.Count<MaxChecksumList then
                                     begin
                                       pBuild:=CheckBuild.AddCheck;
                                       pBuild^.Checksum:=CheckItem;
                                     end
                                   else
                                     bMake:=False;
                                 end;
                           end;
                         // compare checksum
                         if bCompare then
                           begin
                             ChatComp:=ChatNode;
                             pPrev:=CheckPrev.FirstCheck;
                             if pPrev<>nil then
                               PrevCount:=pPrev^.dup;
                             while ChatComp<>nil do
                               begin
                                 bHidden:=False;
                                 // compare chat only
                                 nodeattr:=ChatComp.AsMarkup;
                                 if (POS(chatclass,nodeattr)<>0) then
                                   begin
                                     // non-chat class
                                     if Pos(nonchatclass,nodeattr)<>0 then
                                       begin
                                         s:=GetNonChatMarkup(ChatComp);
                                         MakeCheck(copy(s,1,MaxLength),CheckItem);
                                         bHidden:=True;
                                         //CefLog('ChzzkWeb', 1, CEF_LOG_SEVERITY_ERROR, '<38> ' + s);
                                       end;
                                     // check hidden message
                                     if not bHidden then
                                       begin
                                         ChatCon:=ChatComp.GetFirstChild;
                                         if Assigned(ChatCon) then
                                           begin
                                             nodeattr:=ChatCon.AsMarkup;
                                             if CheckElementAttr(hiddenchatclass,ChatCon) then
                                               begin
                                                 if pPrev<>nil then
                                                   CheckItem:=pPrev^.Checksum;
                                                 bHidden:=True;
                                                 //CefLog('ChzzkWeb', 1, CEF_LOG_SEVERITY_ERROR, '<30> ');
                                               end;
                                           end;
                                       end;
                                     if not bHidden then
                                       begin
                                         // make checksum
                                         s:=GetChatMarkup(ChatComp);
                                         MakeCheck(copy(s,1,MaxLength),CheckItem);
                                         //CefLog('ChzzkWeb', 1, CEF_LOG_SEVERITY_ERROR, '<30> '+ s);
                                       end;

                                     // compare
                                     if CheckPrev.Count>0 then
                                       begin
                                         // equal item checksum
                                         if CompareCheck(CheckItem,pPrev^.Checksum) then
                                           begin
                                             if PrevCount>0 then
                                               Dec(PrevCount)
                                               else
                                                 begin
                                                   pPrev:=CheckPrev.NextCheck;
                                                   if pPrev=nil then
                                                     begin
                                                       bCompare:=False;
                                                       break;
                                                     end else
                                                       PrevCount:=pPrev^.dup;
                                                 end;
                                           end
                                           else
                                           begin
                                             ChatFirst:=ChatNode;
                                             break;
                                           end;
                                       end
                                       else
                                       begin
                                         ChatFirst:=ChatNode;
                                         break;
                                       end;
                                   end;
                                 ChatComp:=ChatComp.PreviousSibling;
                               end;
                           end;
                       end;
                  ChatNode:=ChatNode.PreviousSibling;
                end;
                //
                CheckPrev.CopyData(CheckBuild);
                // process new chat
                ChatNode:=ChatFirst;
                while ChatNode<>nil do
                  begin
                    nodeattr:=ChatNode.AsMarkup;
                    if (POS(chatclass,nodeattr)<>0) then
                    begin
                      if (Pos(chatdonation,nodeattr)<>0) or
                         (Pos(chatsubscription,nodeattr)<>0) then
                        begin
                          // subscription, donation
                          Msg:=TCefProcessMessageRef.New(SLOGSYS);
                          try
                            Msg.ArgumentList.SetString(0,nodeattr);
                            if (aFrame<>nil) and aFrame.IsValid then
                              aFrame.SendProcessMessage(PID_BROWSER,Msg);
                          finally
                            Msg:=nil;
                          end;
                          if CEFDebugLog then
                            CefLog('ChzzkWeb', 1, CEF_LOG_SEVERITY_ERROR, '<5> ' + ChatNode.ElementInnerText);
                        end else
                        if (Pos(chatguide,nodeattr)=0) then
                        begin
                          // chatting
                          Msg:=TCefProcessMessageRef.New(SLOGCHAT);
                          try
                            Msg.ArgumentList.SetString(0,nodeattr);
                            if (aFrame<>nil) and aFrame.IsValid then
                              aFrame.SendProcessMessage(PID_BROWSER,Msg);
                          finally
                            Msg:=nil;
                          end;
                          if CEFDebugLog then
                            CefLog('ChzzkWeb', 1, CEF_LOG_SEVERITY_ERROR, '<4> ' + ChatNode.ElementInnerText);
                        end;
                    end;
                    if ChatNode=ChatBottom then
                      break;
                    ChatNode:=ChatNode.NextSibling;
                  end;
            end;
        end;
    end;
  except
    on e: exception do
      if CustomExceptionHandler('',e) then
        CefLog('ChzzkWeb', 1, CEF_LOG_SEVERITY_ERROR, '<30> ' + e.Message);
  end;
end;

procedure SimpleDOMIteration(const aDocument: ICefDomDocument; const aFrame: ICefFrame);
var
  TempBody, Res : ICefDomNode;
begin
  Res:=nil;
  if (aDocument <> nil) then
    begin
      // body
      TempBody := aDocument.Body;
      if TempBody <> nil then
        begin
          ExtractChat(TempBody.FirstChild,Res, aFrame);
        end;
    end;
end;


procedure DOMVisitor_OnDocAvailable(const browser: ICefBrowser; const frame: ICefFrame; const document: ICefDomDocument);
const
  ChzzkURL ='chzzk.naver.com/live/';
begin
  // This function is called from a different process.
  // document is only valid inside this function.
  if Assigned(browser) and Assigned(frame) then
    begin
      if POS(ChzzkURL,frame.Url)=0 then
        exit;
      if CEFDebugLog then
        CefLog('ChzzkWeb', 1, CEF_LOG_SEVERITY_ERROR, 'document.Title : ' + document.Title);

      // Simple DOM iteration example
      SimpleDOMIteration(document, frame);
    end;
end;

procedure GlobalCEFApp_OnProcessMessageReceived(const browser       : ICefBrowser;
                                                const frame         : ICefFrame;
                                                      sourceProcess : TCefProcessId;
                                                const message       : ICefProcessMessage;
                                                var   aHandled      : boolean);
var
  TempVisitor : TCefFastDomVisitor2;
begin
  // browser renderer message
  aHandled := False;

  if (browser <> nil) then
    begin
      if (message.name = SVISITDOM) then
        begin
          if (frame <> nil) and frame.IsValid then
            begin
              TempVisitor := TCefFastDomVisitor2.Create(browser, frame, @DOMVisitor_OnDocAvailable);
              frame.VisitDom(TempVisitor);
            end;
          aHandled := True;
        end;
    end;
end;


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
      SockServerChat.Free;
      SockServerChat:=TSimpleWebsocketServer.Create(WSPortChat);
      SockServerSys.Free;
      i:=StrToIntDef(WSPortChat,65002);
      Inc(i);
      WSPortSys:=IntToStr(i);
      SockServerSys:=TSimpleWebsocketServer.Create(WSPortSys);
      XMLConfig1.SetValue('WS/PORT',WSPortChat);
      XMLConfig1.SetValue('WS/PORTSYS',WSPortSys);
      SetFormCaption;
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
  CEFDebugLog:=ActionDebugLog.Checked;
end;

procedure TFormChzzkWeb.ActionChatTimeExecute(Sender: TObject);
begin
  ActionChatTime.Checked:=not ActionChatTime.Checked;
  IncludeChatTime:=ActionChatTime.Checked;
  XMLConfig1.SetValue('IncludeTime',IncludeChatTime);
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

procedure TFormChzzkWeb.Chromium1BeforePopup(Sender: TObject;
  const browser: ICefBrowser; const frame: ICefFrame; const targetUrl,
  targetFrameName: ustring; targetDisposition: TCefWindowOpenDisposition;
  userGesture: Boolean; const popupFeatures: TCefPopupFeatures;
  var windowInfo: TCefWindowInfo; var client: ICefClient;
  var settings: TCefBrowserSettings; var extra_info: ICefDictionaryValue;
  var noJavascriptAccess: Boolean; var Result: Boolean);
begin
  Result:=True;
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
  // wait browser loading
  if progress<1.0 then
    iCountVisit:=0
    else
      iCountVisit:=1;
end;

procedure TFormChzzkWeb.Chromium1LoadingStateChange(Sender: TObject;
  const browser: ICefBrowser; isLoading, canGoBack, canGoForward: Boolean);
begin
  // wait browser loading
  if isLoading then
    iCountVisit:=0
    else
      iCountVisit:=1;
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
  s: ustring;
begin
  // browser message
  Result := False;
  if message=nil then
    exit;

  if message.Name=SLOGCHAT then
    begin
      s:=message.ArgumentList.GetString(0);
      if IncludeChatTime then
        InsertTime(s);
      SockServerChat.BroadcastMsg(UTF8Encode(s));
      Result:=True;
    end else
    if message.Name=SLOGSYS then
      begin
        s:=message.ArgumentList.GetString(0);
        if IncludeChatTime then
          InsertTime(s);
        SockServerSys.BroadcastMsg(UTF8Encode(s));
        if WSPortUnique then
          SockServerChat.BroadcastMsg(UTF8Encode(s));
        Result:=True;
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
  MakeCheck(strhidden,CheckHidden);

  if FileExists('config.xml') then
    XMLConfig1.LoadFromFile('config.xml');

  IncludeChatTime:=XMLConfig1.GetValue('IncludeTime',False);
  WSPortChat:=XMLConfig1.GetValue('WS/PORT','65002');
  WSPortSys:=XMLConfig1.GetValue('WS/PORTSYS','65003');
  WSPortUnique:=XMLConfig1.GetValue('WS/UNIQUE',False);
  ActionChatTime.Checked:=IncludeChatTime;
  ActionWSockUnique.Checked:=WSPortUnique;

  chatlog_full:=UTF8Encode(XMLConfig1.GetValue('CHAT/FULL',UTF8Decode(chatlog_full)));
  chatlog_chatonly:=UTF8Encode(XMLConfig1.GetValue('CHAT/CHAT',UTF8Decode(chatlog_chatonly)));
  chatlog_donation:=UTF8Encode(XMLConfig1.GetValue('CHAT/DONATION',UTF8Decode(chatlog_donation)));

  // start websocket server
  SockServerChat:=TSimpleWebsocketServer.Create(WSPortChat);
  SockServerSys:=TSimpleWebsocketServer.Create(WSPortSys);

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
  PostMessage(Handle, MSGVISITDOM, 0, 0);
end;

procedure TFormChzzkWeb.VISITDOM(var Msg: TLMessage);
var
  TempMsg : ICefProcessMessage;
begin
  // Send Message to Renderer for parsing
  if iCountVisit=0 then
    exit;
  TempMsg := TCefProcessMessageRef.New(SVISITDOM);
  Chromium1.SendProcessMessage(PID_RENDERER, TempMsg);
end;

procedure TFormChzzkWeb.CEFCreated(var Msg: TLMessage);
begin
  CEFWindowParent1.UpdateSize;
  // loading chzzk live
  ButtonHome.Click;
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


// initialize CEF

procedure CreateGlobalCEFApp;
begin
  GlobalCEFApp                     := TCefApplication.Create;
  GlobalCEFApp.OnProcessMessageReceived := @GlobalCEFApp_OnProcessMessageReceived;
  GlobalCEFApp.cache               := 'cache';
  GlobalCEFApp.LogFile             := 'debug.log';
  GlobalCEFApp.LogSeverity         := LOGSEVERITY_ERROR;
  GlobalCEFApp.EnablePrintPreview  := False;
  GlobalCEFApp.EnableGPU           := True;
  GlobalCEFApp.SetCurrentDir       := True;
  //GlobalCEFApp.SingleProcess       := True;
end;

initialization

finalization


end.

