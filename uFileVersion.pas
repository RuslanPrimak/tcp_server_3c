unit uFileVersion;

interface

function ReadVersion: String;

implementation

uses Forms, Windows, SysUtils;

function ReadVersion: String;
var
  S: string;
  n, Len: longword;
  Buf: PChar;
  Value: PChar;
  CalcLangCharSet: String;
  Temp: Integer;
begin
  S := Application.ExeName;
  n := GetFileVersionInfoSize(PChar(S), n);
  Result := '';

  if n > 0 then
  begin
    Buf := AllocMem(n);
    GetFileVersionInfo(PChar(S), 0, n, Buf);
    VerQueryValue(Buf, '\VarFileInfo\Translation', pointer(Value), Len);
    if Len >= 4 then
    begin
      Temp := 0;
      StrLCopy(@Temp, Value, 2);
      CalcLangCharSet := IntToHex(Temp, 4);
      StrLCopy(@Temp, Value + 2, 2);
      CalcLangCharSet := CalcLangCharSet + IntToHex(Temp, 4);
    end;
    //if VerQueryValue(Buf, PChar('\StringFileInfo\040904E4\FileVersion'), Pointer(Value), Len) then
    if VerQueryValue(Buf, PChar('\StringFileInfo\' + CalcLangCharSet + '\' + 'FileVersion'), Pointer(Value), Len) then
      Result := Value;
    FreeMem(Buf, n);
  end;
end;

end.
