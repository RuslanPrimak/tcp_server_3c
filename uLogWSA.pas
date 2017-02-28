unit uLogWSA;

interface

procedure LogWSAError;

implementation

uses
  WinSock, LogFileUnit, SysUtils;

procedure LogWSAError;
var
  ErrCode: Integer;
begin
  ErrCode := WSAGetLastError;
  LogError('WSA', IntToStr(ErrCode));
end;

end.
