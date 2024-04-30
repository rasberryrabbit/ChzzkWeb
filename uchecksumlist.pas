unit uChecksumList;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils;

const
  MaxChecksumList = 5;

type
  TDigest = array[0..4] of DWord;

  TChecksumData = record
    checksum: TDigest;
    dup: Integer;
    //IsHidden: Boolean;
  end;

  pChecksumData=^TChecksumData;

  { TChecksumList }

  TChecksumList = class
    private
      FList: array[0..MaxChecksumList] of TChecksumData;
      function GetFirstCheck: pChecksumData;
      function GetLastCheck: pChecksumData;
      function GetNextCheck: pChecksumData;
    public
      DataIndex: Integer;
      Count: Integer;

      constructor Create;
      procedure Clear;
      destructor Destroy; override;

      function AddCheck:pChecksumData;

      procedure CopyData(from:TChecksumList);

      property FirstCheck:pChecksumData read GetFirstCheck;
      property LastCheck:pChecksumData read GetLastCheck;
      property NextCheck:pChecksumData read GetNextCheck;
  end;

  procedure MakeCheck(const s:UnicodeString ; var aDigest: TDigest);
  function CompareCheck(const a, b:TDigest):Boolean;
  function CheckString(const a:TDigest):string;

var
  CheckPrev, CheckBuild: TChecksumList;


implementation

uses
  DCPripemd160;


procedure MakeCheck(const s:UnicodeString; var aDigest: TDigest);
var
  HashCalc: TDCP_ripemd160;
begin
  HashCalc:=TDCP_ripemd160.Create(nil);
  try
    HashCalc.Burn;
    HashCalc.Init;
    if Length(s)>0 then
      begin
        HashCalc.Update(s[1],Length(s)*sizeof(WideChar));
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

{ TChecksumList }

function TChecksumList.GetFirstCheck: pChecksumData;
begin
  if Count>0 then
    begin
      Result:=@(FList[0]);
      DataIndex:=0;
    end else
    begin
      Result:=nil;
      DataIndex:=-1;
    end;
end;

function TChecksumList.GetLastCheck: pChecksumData;
begin
  if Count>0 then
    begin
      Result:=@(FList[Count-1]);
      DataIndex:=Count-1;
    end else
    begin
      Result:=nil;
      DataIndex:=-1;
    end;
end;

function TChecksumList.GetNextCheck: pChecksumData;
begin
  if DataIndex<Count-1 then
    begin
      Inc(DataIndex);
      Result:=@(FList[DataIndex]);
    end else
    begin
      Result:=nil;
      DataIndex:=-1;
    end;
end;

constructor TChecksumList.Create;
begin
  Clear;
end;

procedure TChecksumList.Clear;
begin
  FillChar(FList[0],sizeof(FList),0);
  Count:=0;
  DataIndex:=-1;
end;

destructor TChecksumList.Destroy;
begin
  inherited Destroy;
end;

function TChecksumList.AddCheck: pChecksumData;
var
  i: Integer;
begin
  if Count>=MaxChecksumList then
    begin
      Count:=MaxChecksumList;
      system.Move(FList[1],FList[0],sizeof(TChecksumData)*(MaxChecksumList-1));
      FillChar(FList[MaxChecksumList-1],sizeof(TChecksumData),0);
      Result:=@(FList[MaxChecksumList-1]);
      DataIndex:=MaxChecksumList-1;
    end else
    begin
      Result:=@(FList[Count]);
      DataIndex:=Count;
      Inc(Count);
    end;
    FillChar(Result^,sizeof(TChecksumData),0);
end;

procedure TChecksumList.CopyData(from: TChecksumList);
begin
  system.Move(from.FList[0],FList[0],sizeof(FList));
  Count:=from.Count;
end;



initialization
  CheckPrev:=TChecksumList.Create;
  CheckBuild:=TChecksumList.Create;

finalization
  CheckPrev.Free;
  CheckBuild.Free;

end.

