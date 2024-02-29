unit ChzzkWeb_Main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, XMLConf, Forms, Controls, Graphics, Dialogs, StdCtrls,
  uCEFWindowParent, uCEFChromium, uCEFApplication, uCEFConstants,
  uCEFInterfaces, uCEFChromiumEvents, uCEFTypes, uCEFChromiumCore, LMessages,
  ExtCtrls, ActnList, Menus, uCEFWinControl, UniqueInstance;


const
  MSGVISITDOM = LM_USER+$102;
  SVISITDOM   = 'V_RENDERER';
  SLOGCHAT = 'V_LOGCHAT';
  SLOGSYS = 'V_LOGSYS';

type

  { TFormChzzkWeb }

  TFormChzzkWeb = class(TForm)
    ActionWSPort: TAction;
    ActionList1: TActionList;
    Button1: TButton;
    Button2: TButton;
    CEFWindowParent1: TCEFWindowParent;
    Chromium1: TChromium;
    MainMenu1: TMainMenu;
    MenuItem1: TMenuItem;
    MenuItem2: TMenuItem;
    Timer1: TTimer;
    Timer2: TTimer;
    UniqueInstance1: TUniqueInstance;
    XMLConfig1: TXMLConfig;
    procedure ActionWSPortExecute(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    // CEF
    procedure Chromium1AfterCreated(Sender: TObject; const browser: ICefBrowser
      );
    procedure Chromium1BeforeClose(Sender: TObject; const browser: ICefBrowser);
    procedure Chromium1Close(Sender: TObject; const browser: ICefBrowser;
      var aAction: TCefCloseBrowserAction);
    procedure Chromium1ProcessMessageReceived(Sender: TObject;
      const browser: ICefBrowser; const frame: ICefFrame;
      sourceProcess: TCefProcessId; const message: ICefProcessMessage; out
      Result: Boolean);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure Timer2Timer(Sender: TObject);
  private
    procedure VISITDOM(var Msg:TLMessage); message MSGVISITDOM;

    // CEF
    procedure CEFCreated(var Msg:TLMessage); message CEF_AFTERCREATED;
    procedure CEFDestroy(var Msg:TLMessage); message CEF_DESTROY;
  public

  end;

var
  FormChzzkWeb: TFormChzzkWeb;

procedure CreateGlobalCEFApp;

implementation

uses
  uCEFMiscFunctions, uCEFProcessMessage, uCEFDomVisitor,
  Windows, uWebsockSimple, uChecksumList;


{$R *.lfm}

const
  MaxLength = 2048;

var
  WSPortChat: string = '65002';
  WSPortSys: string = '65003';
  SockServerChat: TSimpleWebsocketServer;
  SockServerSys: TSimpleWebsocketServer;
  ProcessSysChat: Boolean = False;
  CheckHidden: TDigest;
  CEFDebugLog: Boolean = False;


procedure ExtractChat(const ANode: ICefDomNode; var Res:ICefDomNode; const aFrame: ICefFrame);
const
  nonchatclass = ' live_';
  hiddenchatclass = '_message_is_hidden';
  chatclass = 'live_chatting_list_item';
  chatcontainer = 'live_chatting_list_wrapper';
  chatguide = '_list_guide_';
  chatdonation = '_list_donation_';
  chatsubscription = '_list_subscription_';
var
  TempChild, ChatNode, ChatBottom, ChatFirst, ChatComp: ICefDomNode;
  nodeattr: ustring;

  CheckItem, CheckItemLast, CheckItemComp: TDigest;
  pBuild, pPrev: pChecksumData;
  DupCount, DupCountComp: Integer;
  s : ansistring;
  bMake, bCompare, bDup: Boolean;

  Msg: ICefProcessMessage;

begin
  TempChild:=ANode;
  if TempChild<>nil then
    begin
      while TempChild<> nil do
        begin
          // search chat DOM
          if (TempChild.Name='DIV') and (POS(chatcontainer,TempChild.GetElementAttribute('CLASS'))<>0) then
            begin
              Res:=TempChild;
              ChatNode:=TempChild.LastChild;

              CheckBuild.Clear;
              ChatBottom:=nil;
              ChatFirst:=nil;
              bCompare:=True;
              bMake:=True;
              bDup:=False;
              MakeCheck('',CheckItemLast);
              DupCount:=0;
              // log
              while ChatNode<>nil do
                begin
                  nodeattr:=ChatNode.GetElementAttribute('CLASS');
                  // chat only
                  if (POS(chatclass,nodeattr)<>0) then
                       begin
                         // chat
                         if ChatBottom=nil then
                           ChatBottom:=ChatNode;

                         if (POS(hiddenchatclass,nodeattr)<>0) then
                           begin
                             // stop at hidden chat
                             bMake:=False;
                           end;
                         // build checksum list
                         if bMake then
                           begin
                             // make checksum
                             s:=UTF8Encode(ChatNode.AsMarkup);
                             MakeCheck(copy(s,1,MaxLength),CheckItem);
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
                                   if CheckBuild.DataIndex<MaxChecksumList-1 then
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
                             DupCountComp:=0;
                             pPrev:=CheckPrev.FirstCheck;
                             MakeCheck('',CheckItemComp);
                             while ChatComp<>nil do
                               begin
                                 // compare chat only
                                 nodeattr:=ChatComp.GetElementAttribute('CLASS');
                                 if (POS(chatclass,nodeattr)<>0) then
                                   begin
                                     if (POS(hiddenchatclass,nodeattr)<>0) then
                                       begin
                                         // hidden chat
                                         break;
                                       end;
                                     // make checksum
                                     s:=UTF8Encode(ChatComp.AsMarkup);
                                     MakeCheck(copy(s,1,MaxLength),CheckItem);
                                     bDup:=CompareCheck(CheckItem,CheckItemComp);
                                     if bDup then
                                       Inc(DupCountComp)
                                       else
                                         DupCountComp:=0;
                                     CheckItemComp:=CheckItem;

                                     // compare
                                     if CheckPrev.Count>0 then
                                       begin
                                         if CompareCheck(CheckItem,pPrev^.Checksum) then
                                           begin
                                             if DupCountComp=pPrev^.dup then
                                               begin
                                                 pPrev:=CheckPrev.NextCheck;
                                                 if pPrev=nil then
                                                   begin
                                                     bCompare:=False;
                                                     break;
                                                   end;
                                               end else
                                               if DupCountComp>pPrev^.dup then
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
                    nodeattr:=ChatNode.GetElementAttribute('CLASS');
                    if (POS(chatclass,nodeattr)<>0) then
                    begin
                      if (Pos(chatdonation,nodeattr)<>0) or
                         (Pos(chatsubscription,nodeattr)<>0) then
                        begin
                          // subscription, donation
                          Msg:=TCefProcessMessageRef.New(SLOGSYS);
                          try
                            Msg.ArgumentList.SetString(0,ChatNode.AsMarkup);
                            if (aFrame<>nil) and aFrame.IsValid then
                              aFrame.SendProcessMessage(PID_BROWSER,Msg);
                          finally
                            Msg:=nil;
                          end;
                          if CEFDebugLog then
                            CefLog('ChzzkWeb', 1, CEF_LOG_SEVERITY_ERROR, '<5> ' + ChatNode.ElementInnerText);
                        end else
                        if (Pos(hiddenchatclass,nodeattr)=0) and (Pos(chatguide,nodeattr)=0) then
                        begin
                          // chatting
                          Msg:=TCefProcessMessageRef.New(SLOGCHAT);
                          try
                            Msg.ArgumentList.SetString(0,ChatNode.AsMarkup);
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
          if (Res=nil) and TempChild.HasChildren then
            ExtractChat(TempChild.FirstChild,Res,aFrame);
          if Res<>nil then
            break;
          TempChild:=TempChild.NextSibling;
        end;
    end;
end;

procedure SimpleDOMIteration(const aDocument: ICefDomDocument; const aFrame: ICefFrame);
var
  TempBody, Res : ICefDomNode;
begin
  Res:=nil;
  try
    if (aDocument <> nil) then
      begin
        // body
        TempBody := aDocument.Body;
        if TempBody <> nil then
          begin
            ExtractChat(TempBody.FirstChild,Res, aFrame);
          end;
      end;
    if CEFDebugLog then
      begin
        if Res=nil then
          CefLog('ChzzkWeb', 1, CEF_LOG_SEVERITY_ERROR, '===== Cannot Find Chat Node =====')
          else
            CefLog('ChzzkWeb', 1, CEF_LOG_SEVERITY_ERROR, '===== End of Chat Node =====');
      end;
  except
    on e : exception do
      if CustomExceptionHandler('SimpleDOMIteration', e) then raise;
  end;
end;


procedure DOMVisitor_OnDocAvailable(const browser: ICefBrowser; const frame: ICefFrame; const document: ICefDomDocument);
const
  ChzzkURL ='chzzk.naver.com/live/';
begin
  // This function is called from a different process.
  // document is only valid inside this function.
  // As an example, this function only writes the document title to the 'debug.log' file.
  if POS(ChzzkURL,frame.Url)=0 then
    exit;
  if CEFDebugLog then
    CefLog('ChzzkWeb', 1, CEF_LOG_SEVERITY_ERROR, 'document.Title : ' + document.Title);

  // Simple DOM iteration example
  SimpleDOMIteration(document, frame);

end;

procedure GlobalCEFApp_OnProcessMessageReceived(const browser       : ICefBrowser;
                                                const frame         : ICefFrame;
                                                      sourceProcess : TCefProcessId;
                                                const message       : ICefProcessMessage;
                                                var   aHandled      : boolean);
var
  TempVisitor : TCefFastDomVisitor2;
begin
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

procedure TFormChzzkWeb.Button1Click(Sender: TObject);
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
    end;
end;

procedure TFormChzzkWeb.Button2Click(Sender: TObject);
begin
  Timer2.Enabled:=not Timer2.Enabled;
  if Timer2.Enabled then
    Button2.Caption:='사용 중'
    else
      Button2.Caption:='대기 중';
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

procedure TFormChzzkWeb.Chromium1Close(Sender: TObject; const browser: ICefBrowser;
  var aAction: TCefCloseBrowserAction);
begin
  PostMessage(Handle, CEF_DESTROY, 0, 0);
  aAction := cbaDelay;
end;

procedure TFormChzzkWeb.Chromium1ProcessMessageReceived(Sender: TObject;
  const browser: ICefBrowser; const frame: ICefFrame;
  sourceProcess: TCefProcessId; const message: ICefProcessMessage; out
  Result: Boolean);
var
  s: ustring;
begin
  Result := False;
  if message=nil then
    exit;

  if message.Name=SLOGCHAT then
    begin
      s:=message.ArgumentList.GetString(0);
      SockServerChat.BroadcastMsg(UTF8Encode(s));
      Result:=True;
    end else
    if message.Name=SLOGSYS then
      begin
        s:=message.ArgumentList.GetString(0);
        SockServerSys.BroadcastMsg(UTF8Encode(s));
        Result:=True;
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
  if XMLConfig1.Modified then
    XMLConfig1.SaveToFile('config.xml');
end;

procedure TFormChzzkWeb.FormShow(Sender: TObject);
begin
  MakeCheck('hidden',CheckHidden);
  if FileExists('config.xml') then
    XMLConfig1.LoadFromFile('config.xml');
  WSPortChat:=XMLConfig1.GetValue('WS/PORT','65002');
  WSPortSys:=XMLConfig1.GetValue('WS/PORTSYS','65003');

  SockServerChat:=TSimpleWebsocketServer.Create(WSPortChat);
  SockServerSys:=TSimpleWebsocketServer.Create(WSPortSys);

  if not(Chromium1.CreateBrowser(CEFWindowParent1, '')) then Timer1.Enabled := True;
end;

procedure TFormChzzkWeb.Timer1Timer(Sender: TObject);
begin
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
  TempMsg := TCefProcessMessageRef.New(SVISITDOM);
  Chromium1.SendProcessMessage(PID_RENDERER, TempMsg);
end;

procedure TFormChzzkWeb.CEFCreated(var Msg: TLMessage);
begin
  CEFWindowParent1.UpdateSize;
  Button1.Click;
end;

procedure TFormChzzkWeb.CEFDestroy(var Msg: TLMessage);
begin
  CEFWindowParent1.Free;
end;


// initialize CEF

procedure CreateGlobalCEFApp;
begin
  GlobalCEFApp                     := TCefApplication.Create;
  GlobalCEFApp.OnProcessMessageReceived := @GlobalCEFApp_OnProcessMessageReceived;
  GlobalCEFApp.cache               := 'cache';
  GlobalCEFApp.LogFile             := 'debug.log';
  GlobalCEFApp.LogSeverity         := LOGSEVERITY_INFO;
  GlobalCEFApp.EnablePrintPreview  := True;
  GlobalCEFApp.EnableGPU           := True;
  GlobalCEFApp.SetCurrentDir       := True;
  //GlobalCEFApp.SingleProcess       := True;
end;

initialization


finalization


end.

