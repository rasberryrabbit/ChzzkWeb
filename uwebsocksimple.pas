unit uWebsockSimple;

{$mode objfpc}{$H+}

interface


uses
  Classes, SysUtils,
  { mormot2 }
  mormot.net.ws.core, mormot.net.ws.server, mormot.net.server;

type

  { TSimpleWebsocketServer }

  TSimpleWebsocketServer=class
    private
      fServer:TWebSocketServer;
    protected
    public
      constructor Create(const Port:string);
      destructor Destroy; override;

      procedure BroadcastMsg(const msg: RawByteString);
  end;

  { TWebSocketProtocolEcho }

  TWebSocketProtocolEcho = class(TWebSocketProtocolChat)
    public
      Server: TSimpleWebsocketServer;

      procedure onExIncomeFrame(Sender: TWebSocketProcess; const Frame: TWebSocketFrame);
  end;


implementation


{ TWebSocketProtocolEcho }

procedure TWebSocketProtocolEcho.onExIncomeFrame(Sender: TWebSocketProcess;
  const Frame: TWebSocketFrame);
var
  respf:TWebSocketFrame;
begin
  case Frame.opcode of
  focBinary, focText :
      if Assigned(Server) then begin
        Server.BroadcastMsg(Frame.payload);
      end;
  end;
end;

{ TSimpleWebsocketServer }

constructor TSimpleWebsocketServer.Create(const Port: string);
var
  protocol:TWebSocketProtocolEcho;
begin
  fServer:=TWebSocketServer.Create(Port,nil,nil,'Chzzkchat');
  protocol:=TWebSocketProtocolEcho.Create('chat','');
  protocol.Server:=Self;
  protocol.OnIncomingFrame:=@protocol.onExIncomeFrame;
  fServer.WebSocketProtocols.Add(protocol);
end;

destructor TSimpleWebsocketServer.Destroy;
begin
  fServer.Free;
  Sleep(100);
  inherited Destroy;
end;

procedure TSimpleWebsocketServer.BroadcastMsg(const msg:RawByteString);
var
  outmsg:TWebSocketFrame;
begin
  outmsg.opcode:=focText;
  outmsg.payload:=msg;
  fServer.WebSocketBroadcast(outmsg);
end;


end.
