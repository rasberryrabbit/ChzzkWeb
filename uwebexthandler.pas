unit uWebExtHandler;

{$mode ObjFPC}{$H+}

interface

uses
  LCLIntf, LCLType, LMessages,
  uCEFRenderProcessHandler, uCEFBrowserProcessHandler, uCEFInterfaces, uCEFProcessMessage,
  uCEFv8Context, uCEFTypes, uCEFv8Handler;

type
  TWebExtensionHandler = class(TCefv8HandlerOwn)
    protected
      function Execute(const name: ustring; const obj: ICefv8Value; const arguments: TCefv8ValueArray; var retval: ICefv8Value; var exception: ustring): Boolean; override;
  end;

implementation

uses
  uCEFMiscFunctions, uCEFConstants;

function TWebExtensionHandler.Execute(const name      : ustring;
                                       const obj       : ICefv8Value;
                                       const arguments : TCefv8ValueArray;
                                       var   retval    : ICefv8Value;
                                       var   exception : ustring): Boolean;
var
  TempMessage : ICefProcessMessage;
  TempFrame   : ICefFrame;
begin
  Result := False;

  try
    if (name = 'postMessage') then
      begin
        if (length(arguments) > 0) and arguments[0].IsString then
          begin
            TempMessage := TCefProcessMessageRef.New(name);
            TempMessage.ArgumentList.SetString(0, arguments[0].GetStringValue);

            TempFrame := TCefv8ContextRef.Current.Browser.MainFrame;

            if (TempFrame <> nil) and TempFrame.IsValid then
              TempFrame.SendProcessMessage(PID_BROWSER, TempMessage);
          end;
        Result := True;
      end;
  finally
    TempMessage := nil;
  end;
end;

end.

