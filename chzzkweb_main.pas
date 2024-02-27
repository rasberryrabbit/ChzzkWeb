unit ChzzkWeb_Main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  uCEFWindowParent, uCEFChromium, uCEFApplication, uCEFConstants,
  uCEFInterfaces, uCEFChromiumEvents, uCEFTypes, uCEFChromiumCore, LMessages,
  ExtCtrls, DCPripemd160, uCEFWinControl;


const
  MSG_PROCESS = LM_USER+$101;
  MSGVISITDOM = LM_USER+$102;
  SVISITDOM   = 'VISITDOM';
  SVERBOSEDOM = 'VERBOSEDOM';

type

  { TForm1 }

  TForm1 = class(TForm)
    Button1: TButton;
    Button2: TButton;
    CEFWindowParent1: TCEFWindowParent;
    Chromium1: TChromium;
    DCP_ripemd160_1: TDCP_ripemd160;
    Memo1: TMemo;
    Timer1: TTimer;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Chromium1AfterCreated(Sender: TObject; const browser: ICefBrowser
      );
    procedure Chromium1BeforeClose(Sender: TObject; const browser: ICefBrowser);
    procedure Chromium1Close(Sender: TObject; const browser: ICefBrowser;
      var aAction: TCefCloseBrowserAction);
    procedure Chromium1ProcessMessageReceived(Sender: TObject;
      const browser: ICefBrowser; const frame: ICefFrame;
      sourceProcess: TCefProcessId; const message: ICefProcessMessage; out
      Result: Boolean);
    procedure FormShow(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
  private
    procedure MSGProcess(var Msg:TLMessage); message MSG_PROCESS;
    procedure VISITDOM(var Msg:TLMessage); message MSGVISITDOM;

    // CEF
    procedure CEFCreated(var Msg:TLMessage); message CEF_AFTERCREATED;
    procedure CEFDestroy(var Msg:TLMessage); message CEF_DESTROY;
  public

  end;

var
  Form1: TForm1;

procedure CreateGlobalCEFApp;

implementation

uses
  uCEFMiscFunctions, uCEFProcessMessage, uCEFDomVisitor,
  Windows, uWebsockSimple;


{$R *.lfm}

type
  TDigest = array[0..4] of DWord;

const
  MaxChecksum = 10;
  MaxLength = 1024;

var
  SockServer: TSimpleWebsocketServer;

  CountPrev : Integer = 0;
  CheckPrev : array[0..MaxChecksum] of TDigest;
  DupPrev   : array[0..MaxChecksum] of Integer;
  ProcessSysChat : Boolean = True;

  CheckHidden : TDigest;

  CEFDebugLog : Boolean = True;
  debugout : string;


procedure MakeCheck(const s:rawbytestring; var aDigest: TDigest);
var
  HashCalc: TDCP_ripemd160;
begin
  HashCalc:=TDCP_ripemd160.Create(nil);
  try
    HashCalc.Burn;
    HashCalc.Init;
    if Length(s)>0 then
      begin
        HashCalc.Update(s[1],Length(s));
        HashCalc.Final(aDigest);
      end;
  finally
    HashCalc.Free;
  end;
end;

function CompareCheck(const a, b:TDigest):Boolean;
begin
  Result:=CompareMem(@(a[0]),@(b[0]),sizeof(TDigest));
end;

function CheckString(const a:TDigest):string;
var
  i:Integer;
begin
  Result:='';
  for i:=0 to 4 do
    Result:=Result+IntToHex(a[i]);
end;

procedure ExtractChat(const ANode: ICefDomNode; var Res:ICefDomNode);
const
  // live_chatting_donation_message
  // live_chatting_list_subscription
  // live_chatting_message_is_hidden
  nonchatclass = ' live_';
  hiddenchatclass = '_message_is_hidden';
  chatclass = 'live_chatting_list_item';
  chatcontainer = 'live_chatting_list_wrapper';
var
  TempChild, ChatNode, ChatBottom, ChatFirst: ICefDomNode;
  nodeattr: ustring;

  CheckItem, CheckItemLast: TDigest;
  CheckCurr: array[0..MaxChecksum] of TDigest;
  DupCurr: array[0..MaxChecksum] of Integer;
  CountCurr: Integer;
  ItemIdx, PrevIdx: Integer;
  s : ansistring;
  DoInc, Matched: Boolean;

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

              CountCurr:=0;
              ItemIdx:=-1;
              PrevIdx:=0;
              FillChar(DupCurr,sizeof(DupCurr),0);
              FillChar(CheckCurr,sizeof(CheckCurr),0);
              ChatBottom:=nil;
              ChatFirst:=nil;
              Matched:=False;
              MakeCheck('',CheckItemLast);
              // log
              while ChatNode<>nil do
                begin
                  nodeattr:=ChatNode.GetElementAttribute('CLASS');
                  // chat only
                  if (POS(chatclass,nodeattr)<>0) then
                       begin
                         DoInc:=False;
                         if ProcessSysChat and (POS(nonchatclass,nodeattr)<>0) then
                           begin
                             // system
                           end else
                           begin
                             // chat
                             if ChatBottom=nil then
                               ChatBottom:=ChatNode;

                             if (POS(hiddenchatclass,nodeattr)<>0) then
                               begin
                                 // hidden chat
                                 break;
                               end;
                             s:=UTF8Encode(ChatNode.AsMarkup);
                             MakeCheck(copy(s,1,MaxLength),CheckItem);
                             //CefLog('ChzzkWeb', 1, CEF_LOG_SEVERITY_ERROR, CheckString(CheckItem));
                             // generate new checksum
                             DoInc:=CompareCheck(CheckItem,CheckItemLast);
                             if DoInc then
                                 Inc(DupCurr[ItemIdx])
                                 else
                                   begin
                                     if ItemIdx<MaxChecksum then
                                       begin
                                         Inc(ItemIdx);
                                         CheckCurr[ItemIdx]:=CheckItem;
                                       end
                                       else
                                         // matched partial
                                         if PrevIdx>0 then
                                           Matched:=True;
                                   end;
                             // compare checksum
                             if (not Matched) then
                               begin
                                 if (CountPrev>0) and
                                    (PrevIdx<CountPrev) and
                                    CompareCheck(CheckCurr[ItemIdx],CheckPrev[PrevIdx]) then
                                   begin
                                     if DupCurr[ItemIdx]>DupPrev[PrevIdx] then
                                       begin
                                         PrevIdx:=0;
                                         ChatFirst:=ChatNode;
                                       end else
                                       begin
                                         if DupCurr[ItemIdx]=DupPrev[PrevIdx] then
                                           begin
                                             if PrevIdx<CountPrev then
                                               Inc(PrevIdx);
                                             // matched full
                                             if PrevIdx=CountPrev then
                                               Matched:=True;
                                           end;
                                       end;
                                   end else
                                   begin
                                     PrevIdx:=0;
                                     ChatFirst:=ChatNode;
                                   end;
                               end;

                             CheckItemLast:=CheckItem;
                           end;
                           //CefLog('ChzzkWeb', 1, CEF_LOG_SEVERITY_ERROR, '<2> ' + ChatNode.AsMarkup);
                       end;
                  ChatNode:=ChatNode.PreviousSibling;
                end;
                //
                CheckPrev:=CheckCurr;
                DupPrev:=DupCurr;
                CountPrev:=ItemIdx+1;
                // process new chat
                ChatNode:=ChatFirst;
                while ChatNode<>nil do
                  begin
                    nodeattr:=ChatNode.GetElementAttribute('CLASS');
                    if ( (POS(nonchatclass,nodeattr)=0) or
                         (POS(hiddenchatclass,nodeattr)<>0) ) and
                       (POS(chatclass,nodeattr)<>0) then
                    begin
                      if POS(nonchatclass,nodeattr)<>0 then
                      begin
                        //
                      end else
                      begin
                        SockServer.BroadcastMsg(UTF8Encode(ChatNode.AsMarkup));
                        CefLog('ChzzkWeb', 1, CEF_LOG_SEVERITY_ERROR, '<4> ' + ChatNode.ElementInnerText);
                      end;
                    end;
                    if ChatNode=ChatBottom then
                      break;
                    ChatNode:=ChatNode.NextSibling;
                  end;
            end;
          if (Res=nil) and TempChild.HasChildren then
            ExtractChat(TempChild.FirstChild,Res);
          if Res<>nil then
            break;
          TempChild:=TempChild.NextSibling;
        end;
    end;
end;

procedure SimpleDOMIteration(const aDocument: ICefDomDocument);
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
            ExtractChat(TempBody.FirstChild,Res);
          end;
      end;
    if Res=nil then
      CefLog('ChzzkWeb', 1, CEF_LOG_SEVERITY_ERROR, '===== Cannot Find Chat Node =====')
      else
        CefLog('ChzzkWeb', 1, CEF_LOG_SEVERITY_ERROR, '===== End of Chat Node =====');
  except
    on e : exception do
      if CustomExceptionHandler('SimpleDOMIteration', e) then raise;
  end;
end;


procedure DOMVisitor_OnDocAvailable(const browser: ICefBrowser; const frame: ICefFrame; const document: ICefDomDocument);
var
  TempMessage : ICefProcessMessage;
begin
  // This function is called from a different process.
  // document is only valid inside this function.
  // As an example, this function only writes the document title to the 'debug.log' file.
  CefLog('ChzzkWeb', 1, CEF_LOG_SEVERITY_ERROR, 'document.Title : ' + document.Title);

  // Simple DOM iteration example
  SimpleDOMIteration(document);

  // Sending back some custom results to the browser process
  try
    TempMessage := TCefProcessMessageRef.New(SVERBOSEDOM);
    TempMessage.ArgumentList.SetString(0, 'document.Title : ' + document.Title);

    if (frame <> nil) and frame.IsValid then
      frame.SendProcessMessage(PID_BROWSER, TempMessage);
  finally
    TempMessage := nil;
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


{ TForm1 }

procedure TForm1.Button1Click(Sender: TObject);
begin
  Chromium1.LoadURL('https://chzzk.naver.com');
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  PostMessage(Handle, MSGVISITDOM, 0, 0);
end;

procedure TForm1.Chromium1AfterCreated(Sender: TObject;
  const browser: ICefBrowser);
begin
  PostMessage(Handle, CEF_AFTERCREATED, 0,0);
end;

procedure TForm1.Chromium1BeforeClose(Sender: TObject;
  const browser: ICefBrowser);
begin
  PostMessage(Handle, WM_CLOSE, 0,0);
end;

procedure TForm1.Chromium1Close(Sender: TObject; const browser: ICefBrowser;
  var aAction: TCefCloseBrowserAction);
begin
  PostMessage(Handle, CEF_DESTROY, 0, 0);
  aAction := cbaDelay;
end;

procedure TForm1.Chromium1ProcessMessageReceived(Sender: TObject;
  const browser: ICefBrowser; const frame: ICefFrame;
  sourceProcess: TCefProcessId; const message: ICefProcessMessage; out
  Result: Boolean);
begin
  Result := False;
  if message=nil then
    exit;

  // receive MSG from RENDERER
  if message.Name=SVERBOSEDOM then
    begin
      Result:=True;
    end;
end;

procedure TForm1.FormShow(Sender: TObject);
begin
  if not(Chromium1.CreateBrowser(CEFWindowParent1, '')) then Timer1.Enabled := True;
end;

procedure TForm1.Timer1Timer(Sender: TObject);
begin
  Timer1.Enabled := False;
  if not(Chromium1.CreateBrowser(CEFWindowParent1, '')) and not(Chromium1.Initialized) then
    Timer1.Enabled := True;
end;

procedure TForm1.MSGProcess(var Msg: TLMessage);
begin
  Memo1.Lines.Add(IntToStr(Msg.lParam));
end;

procedure TForm1.VISITDOM(var Msg: TLMessage);
var
  TempMsg : ICefProcessMessage;
begin
  TempMsg := TCefProcessMessageRef.New(SVISITDOM);
  Chromium1.SendProcessMessage(PID_RENDERER, TempMsg);
end;

procedure TForm1.CEFCreated(var Msg: TLMessage);
begin
  CEFWindowParent1.UpdateSize;
  Button1.Click;
end;

procedure TForm1.CEFDestroy(var Msg: TLMessage);
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
  if CEFDebugLog then
    GlobalCEFApp.LogSeverity         := LOGSEVERITY_INFO
      else
        GlobalCEFApp.LogSeverity         := LOGSEVERITY_FATAL;
  GlobalCEFApp.EnablePrintPreview  := True;
  GlobalCEFApp.EnableGPU           := True;
  GlobalCEFApp.SetCurrentDir       := True;
  //GlobalCEFApp.SingleProcess       := True;
end;

initialization
  MakeCheck('hidden',CheckHidden);
  SockServer:=TSimpleWebsocketServer.Create('65020');

finalization
  SockServer.Free;


end.

