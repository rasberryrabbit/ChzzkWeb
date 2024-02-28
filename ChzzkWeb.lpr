program ChzzkWeb;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF HASAMIGA}
  athreads,
  {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, Windows,
  uCEFApplication,
  ChzzkWeb_Main, uChecksumList
  { you can add units after this };

{$R *.res}

{$SetPEFlags IMAGE_FILE_LARGE_ADDRESS_AWARE}

begin
  CreateGlobalCEFApp;

  RequireDerivedFormResource:=True;
  Application.Scaled:=True;
  if GlobalCEFApp.StartMainProcess then begin
    Application.Initialize;
    Application.CreateForm(TForm1, Form1);
    Application.Run;
  end;

  DestroyGlobalCEFApp;
end.

