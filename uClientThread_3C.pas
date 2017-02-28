unit uClientThread_3C;

interface

uses
  Windows, SimpleClientThread, uVehicles3C, WinSock, SysUtils, uDBSetProvider;

type
	TTestThreadEvent = procedure (Sender: TObject) of object;

  {
    Класс потока обработки подключения клиента 3C}
	TClientThread_3C = class(TSimpleClientThread)
	private
    FAuth: Boolean; // Признак авторизации клиента
    FPID: Byte;
    FSendCnt: Integer;
    VId: TVehIdent;
    FRecBuffNeedMore: Boolean;
    FRecBuff: String;
    FLastEOS: Byte;
    dbProvider: TDBSetProvider;
    FTestEvent: TTestThreadEvent;
    procedure SetTestEvent(const Value: TTestThreadEvent);
	protected
    function ProcessIncomingData(Data: PByte; Len: Integer): Boolean; override;
    procedure SendACK;
    procedure SendNAK;
    procedure ExecuteEx; override;
    procedure PreExecute(var ExecuteEnable: Boolean); override;
    procedure SendTestCommand;
    function IncPID: Byte;
    function CheckDBSerial(var v: TVehIdent): Boolean;
	public
    constructor Create(ClientSocket: TSocket; addr: TSockAddr); override;
    constructor CreateEmul;
    destructor Destroy; override;
    function ProcessPack(Pack: PByte; Len: Integer): Boolean;
    property TestEvent: TTestThreadEvent read FTestEvent write SetTestEvent;
	end;

implementation

uses uAuthClient_3C, uCommProtocol_3C, u_SQLs, LogFileUnit,
  StrConvUnit, SyncObjs, ElAES, uConnectParamsProvider, uDBSetProviderPool;

{ TClientThread_3C }

function TClientThread_3C.CheckDBSerial(var v: TVehIdent): Boolean;
begin
	if not dbProvider.ibSQL.Transaction.InTransaction then
  	dbProvider.ibSQL.Transaction.StartTransaction;
    
	dbProvider.ibSQL.Close;
	try
		dbProvider.ibSQL.SQL.Text := SQL_SERIAL_CHECK;
    dbProvider.ibSQL.ParamByName('sn').AsInteger := v.SN;
    dbProvider.ibSQL.ExecQuery;
    Result := dbProvider.ibSQL.FieldByName('ID_VEHICLE').AsInteger > 0;
    if Result then
    begin
      v.ID := dbProvider.ibSQL.FieldByName('ID_VEHICLE').AsInteger;
      v.Phone := dbProvider.ibSQL.FieldByName('PHONE_NUMBER').AsString;
    end;
    dbProvider.ibSQL.Close;
    if (dbProvider.ibSQL.Transaction.InTransaction) then
			dbProvider.ibSQL.Transaction.Commit;
  finally
		if (dbProvider.ibSQL.Transaction.InTransaction) then
			dbProvider.ibSQL.Transaction.Rollback;
  end;
end;

constructor TClientThread_3C.Create(ClientSocket: TSocket;
  addr: TSockAddr);
begin
  inherited;
  FRecBuff := '';
  FPID := 1;
  FLastEOS := EOS_SINGLE;
  FSendCnt := 0;
end;

constructor TClientThread_3C.CreateEmul;
begin
  FRecBuff := '';
  FPID := 1;
  FLastEOS := EOS_SINGLE;
  FSendCnt := 0;
end;

destructor TClientThread_3C.Destroy;
begin
	inherited;
	if Assigned(dbProvider) then
		//ProviderPool.PutDataBaseToPool(dbProvider);
    dbProvider.Free;
end;

procedure TClientThread_3C.ExecuteEx;
begin
  inherited;
end;

function TClientThread_3C.IncPID: Byte;
begin
  Result := FPID;
  if FPID = 255 then FPID := 0
  else Inc(FPID);
end;

procedure TClientThread_3C.PreExecute(var ExecuteEnable: Boolean);
var
	params: TDBConnectParams;
begin
	inherited;

	ExecuteEnable := False;

  params := TConParamsProvider.GetDBParams;
  try
  	//dbProvider := ProviderPool.GetDataBaseFromPool(params);
    dbProvider := TDBSetProvider.Create;
		dbProvider.Connect(params);
  finally
		params.Free;
  end;

  //ExecuteEnable := Assigned(dbProvider);
  ExecuteEnable := dbProvider.Active;

  if not (ExecuteEnable) then
		LogSelf('ERROR: connection to database failed!');
end;

function TClientThread_3C.ProcessIncomingData(Data: PByte; Len: Integer): Boolean;
begin
  Result := False;
  inherited;
  if FAuth then
  begin
    if (Data^ = SOH) or FRecBuffNeedMore then
    begin
      // Обработка данных от клиента
      Result := ProcessPack(Data, Len);
      if not Result then
      begin
        LogSelf('ERROR ProcessPack: "' + BufToHexStr(Data^, Len) + '"');
        Terminate;
      end;
    end
    else
    if Data^ = ACK then
    begin
      if FSendCnt > 0 then
      begin
        Dec(FSendCnt);
        IncPID;
      end;
      LogSelf('ACK');
      Result := True;
    end
    else
    begin
      LogSelf('ERROR 1B: "' + BufToHexStr(Data^, Len) + '"');
      Terminate;
    end;
  end
  else
  begin
    // Выполнение процедуры авторизации
    FAuth := AuthClient3C(Data, Len, VId);
    if FAuth then
    begin
      LogSelf('Check: ' + IntToStr(VId.SN));
      FAuth := CheckDBSerial(VId);
      //FAuth := CheckSN(VId);
    end;

    if FAuth then
    begin
      FLastEOS := EOS_OfPack(Data);
      SendACK;
      LogSelf('Auth: ' + IntToStr(VId.SN));
      Result := True;
    end
    else
    begin
      LogSelf('Auth: ' + IntToStr(VId.SN) + ' ERROR: "' + BufToHexStr(Data^, Len) + '"');
      Terminate;
    end;
  end;
end;

function TClientThread_3C.ProcessPack(Pack: PByte; Len: Integer): Boolean;
var
  Data: PByte;
  DataLen: Integer;
  DataID: Byte;
  s: String;
  res: Integer;
begin
  Result := False;

  SetString(s, PChar(Pack), Len);

  if FRecBuffNeedMore then
  begin
    FRecBuffNeedMore := False;
    FRecBuff := FRecBuff + s;
  end
  else
    FRecBuff := s;

  res := ExtractDataFromPack(@FRecBuff[1], Length(FRecBuff), Data, DataLen);

  if res = 0 then
  begin
    DataID := Data^;

    case DataID of
      ID_INFO_DATA:
        begin
          Result := dbProvider.WriteInfoData(Data, vid);
          if not Result then
          	LogError(GetSelfID + ': WriteInfoData', BufToHexStr(Data^, DataLen));
        end;
      ID_GEN_CONF_DATA, ID_GPS_CONF_DATA, ID_GPRS_CONF_DATA:
        begin
          Result := dbProvider.WriteConfData(Data, vid);
          if not Result then
          	LogError(GetSelfID + ': WriteConfData', BufToHexStr(Data^, DataLen));
        end;
      ID_NEW_JOURN_DATA, ID_PERIOD_JOURN_DATA, ID_ALARM_JOURN_DATA:
      begin
        Result := dbProvider.WriteJournData(Data, vid);
        if not Result then
        	LogError(GetSelfID + ': WriteJournData', BufToHexStr(Data^, DataLen));
      end;
    else
      Result := False;
      LogError(GetSelfID + ': DataID', BufToHexStr(Data^, DataLen));
    end;

    if Result then
    begin
      SendACK;
      FLastEOS := EOS_OfPack(@FRecBuff[1]);
    end
    else
      LogError(GetSelfID + ': DB ERROR');
  end
  else
  if res = 1 then
  begin
    FRecBuffNeedMore := True;
    Result := True;
  end
  else
    LogError(GetSelfID + ': ResExtract', IntToStr(res) + ' "' +
    	BufToHexStr(Data^, DataLen) + '"');
end;

procedure TClientThread_3C.SendACK;
var
  b: byte;
begin
  b := ACK;
  SendBuf(b, 1);
end;

procedure TClientThread_3C.SendNAK;
var
  b: byte;
begin
  b := NAK;
  SendBuf(b, 1);
end;

procedure TClientThread_3C.SendTestCommand;
var
  at_cmd: PChar;
  Res: Integer;
begin
  try
    // at_cmd := 'AT'#13;
    // Res := send(FSocket, at_cmd^, SizeOf(at_cmd), 0);
    at_cmd := Chr($FF) + Chr($30) + Chr($47) + Chr($67) + Chr($4D) + Chr($74) +
              Chr($5F) + Chr($31) + Chr($32) + Chr($30) + Chr($00) +

              (*Chr($61) + Chr($74) + Chr($2B) + Chr($63) + Chr($66) + Chr($75) + Chr($6E) +
              Chr($3D) + Chr($31) +*)

              Chr($61) + Chr($74) +
              Chr($00);
    Res := send(FSocket, at_cmd^, 14, 0);
    if Res > 0 then
      Inc(FSendCnt);
  finally
  end;
end;

procedure TClientThread_3C.SetTestEvent(const Value: TTestThreadEvent);
begin
  FTestEvent := Value;
end;

end.
