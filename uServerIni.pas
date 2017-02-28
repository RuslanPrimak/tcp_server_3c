unit uServerIni;

interface

uses
  IniFiles, SysUtils;

var
  Ini: TIniFile;

function IniPort: Integer;
function IniDBPath: String;
function IniDBUser: String;
function IniDBPass: String;
function IniDBRole: String;
function IniSNUpdTO: Integer;
function IniLogOn: Boolean;
function IniLogRecv: Boolean;
function IniDTBin: Boolean;
function IniLogErrors: Boolean;

implementation

Const
  TCP_SEC = 'TCP';
  PORT_IDENT = 'PORT';

  DB_SEC = 'DATABASE';
  DBPATH_IDENT = 'PATH';
  DBUSER_IDENT = 'USER';
  DBPASS_IDENT = 'PASS';
  DBROLE_IDENT = 'ROLE';
  SNUPD_IDENT = 'SN_UPDATE_TIMEOUT';

  LOG_SEG = 'LOGFILE';
  LOG_ON_IDENT = 'LOG_ON';
  LOG_RECV_IDENT = 'LOG_RECV';
  LOG_DATE_BIN_IDENT = 'DATE_BIN';
  LOG_ONLY_ERRORS = 'ONLY_ERRORS';

function IniDTBin: Boolean;
begin
  Result := Ini.ReadBool(LOG_SEG, LOG_DATE_BIN_IDENT, False);
end;

function IniLogOn: Boolean;
begin
  Result := Ini.ReadBool(LOG_SEG, LOG_ON_IDENT, True);
end;

function IniLogRecv: Boolean;
begin
  Result := Ini.ReadBool(LOG_SEG, LOG_RECV_IDENT, True);
end;

function IniLogErrors: Boolean;
begin
  Result := Ini.ReadBool(LOG_SEG, LOG_ONLY_ERRORS, True);
end;

function IniPort: Integer;
begin
  Result := Ini.ReadInteger(TCP_SEC, PORT_IDENT, 8228);
end;

function IniDBPath: String;
begin
  Result := Ini.ReadString(DB_SEC, DBPATH_IDENT, 'localhost:c:\Program Files\3C\3C.fdb');
end;

function IniDBUser: String;
begin
  Result := Ini.ReadString(DB_SEC, DBUSER_IDENT, 'sysdba');
end;

function IniDBPass: String;
begin
  Result := Ini.ReadString(DB_SEC, DBPASS_IDENT, 'masterkey');
end;

function IniDBRole: String;
begin
  Result := Ini.ReadString(DB_SEC, DBROLE_IDENT, '');
end;

{
  Вычитать интервал обновления списка серийных номеров в секундах
  0 - вычитывать при каждой авторизации
  По умолчанию 600 - 1 раз в 10 минут}
function IniSNUpdTO: Integer;
begin
  Result := Ini.ReadInteger(DB_SEC, SNUPD_IDENT, 600);
end;

initialization
  Ini := TIniFile.Create(ExtractFilePath(ParamStr(0)) + 'TCPServer3C.ini');

finalization
  Ini.Free;

end.
