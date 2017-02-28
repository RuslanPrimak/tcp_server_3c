unit u_DMDatabase;

interface

uses
  SysUtils, Classes, FIBDatabase, pFIBDatabase, DB, FIBDataSet, pFIBDataSet,
  FIBQuery, pFIBQuery, pFIBProps, uCommProtocol_3C, uVehicles3C, Variants,
  uInfoData, SyncObjs
  //,Windows
  ;

type
  TdmDatabase = class(TDataModule)
    db3C: TpFIBDatabase;
    trRead: TpFIBTransaction;
    trWrite: TpFIBTransaction;
    dsVehiclesRO: TpFIBDataSet;
  private
    { Private declarations }
  public
    { Public declarations }
  end;

  TDBWriter = class
    qrWrite: TpFIBQuery;
    trWrite: TpFIBTransaction;
    FVID: TVehIdent;
  private
    procedure SetVID(const Value: TVehIdent);
    { Private declarations }
  public
    constructor Create(DB: TpFIBDatabase); overload;
    destructor Destroy; override;
    procedure ExecQuery(strQuery: String; Commit: Boolean = True);
    procedure CommitWork;
    procedure RollbackWork;
    property VID: TVehIdent read FVID write SetVID;
  end;

  TStateRec = record
    id_vehicle    : Integer;
    time_state    : TDateTime;
    latitude_ex   : Cardinal;
    longitude_ex  : Cardinal;
    altitude_ex   : Cardinal;
    latitude      : Double;
    longitude     : Double;
    altitude      : Double;
    din           : Byte;
    dout          : Byte;
    adc1          : Word;
    adc2          : Word;
    dac           : Byte;
    charge_level  : Byte;
    gsm_signal_str: Byte;
    flags_state   : Byte;
    speed_ex      : Word;
    course_ex     : Word;
    speed         : Double;
    course        : Double;
    running_hours : Cardinal;
    journal_size  : Cardinal;
    newjourn_size : Cardinal;
    exstatus      : Word;
    pos_exists    : Boolean;
    state_exists  : Boolean;
  end;

  TInfoDataWriter = class(TDBWriter)
  private
    InfoData: PInfoData;
    sr: TStateRec;
    qrWrStateNoGPS: TpFIBQuery;
    qrWrStateFull: TpFIBQuery;
    function WriteState: Boolean;
    function WritePosJournal: Boolean;
    function WriteStateJournal: Boolean;
  public
    function WriteData(AData: PByte): Boolean;
    constructor Create(DB: TpFIBDatabase);
    destructor Destroy; override;
  end;

  TConfDataWriter = class(TDBWriter)
  private
    ConfData: PByte;
    AllConf: TAllConfData;
    function WriteGenConf: Boolean;
    function WriteGPSConf: Boolean;
    function WriteGPRSConf: Boolean;
    function WriteAllConf: Boolean;
    procedure ReadDBConf;
  public
    function WriteData(AData: PByte): Boolean;
  end;

var
  dmDatabase: TdmDatabase;

function DBConnected: Boolean;
function DBReconnect: Boolean;
function CheckSN(var vid: TVehIdent): Boolean;
function WriteInfoData(AData: PByte; vid: TVehIdent): Boolean;
function WriteConfData(AData: PByte; vid: TVehIdent): Boolean;

implementation

uses
  uServerIni, u_SQLs, u_ByteOrders, uJournalSpec, LogFileUnit;

var
  CheckSNTO, LastCheckSN: Double;
  csCheckSN: TCriticalSection;

{$R *.dfm}

function DBConnected: Boolean;
begin
  Result := dmDatabase.db3C.Connected;
end;

function DBReconnect: Boolean;
begin
  CheckSNTO := IniSNUpdTO / SecsPerDay;
  with dmDatabase.db3C do
  begin
    Close;
    DBName := IniDBPath;
    ConnectParams.UserName := IniDBUser;
    ConnectParams.Password := IniDBPass;
    ConnectParams.RoleName := IniDBRole;
    Open;
    dmDatabase.trRead.StartTransaction;
    Result := Connected;
    if Result then
      LogInfo('DB connected!', DBName)
    else
      LogWarning('DB NOT connected', DBName);
  end;
end;

function CheckSN(var vid: TVehIdent): Boolean;
begin
  csCheckSN.Acquire;
  try
    // Проверка Таймаута;
    if (not dmDatabase.dsVehiclesRO.Active) or
      ((Now-LastCheckSN) > CheckSNTO) then
    begin
      dmDatabase.dsVehiclesRO.Close;
      dmDatabase.dsVehiclesRO.Open;
      LastCheckSN := Now;
    end;

    Result := dmDatabase.dsVehiclesRO.Locate('SERIAL_NUM', vid.SN, []);
    if Result then
    begin
      vid.ID := dmDatabase.dsVehiclesRO.FieldByName('ID_VEHICLE').AsInteger;
      vid.Phone := dmDatabase.dsVehiclesRO.FieldByName('PHONE_NUMBER').AsString;
    end;
  finally
    csCheckSN.Release;
  end;
end;

function WriteInfoData(AData: PByte; vid: TVehIdent): Boolean;
var
  InfoWriter: TInfoDataWriter;
begin
  InfoWriter := TInfoDataWriter.Create(dmDatabase.db3C);
  try
    InfoWriter.VID := vid;
    Result := InfoWriter.WriteData(AData);
  finally
    InfoWriter.Free;
  end;
end;

function WriteConfData(AData: PByte; vid: TVehIdent): Boolean;
var
  ConfWriter: TConfDataWriter;
begin
  ConfWriter := TConfDataWriter.Create(dmDatabase.db3C);
  try
    ConfWriter.VID := vid;
    Result := ConfWriter.WriteData(AData);
  finally
    ConfWriter.Free;
  end;
end;

{ TDBWriter }

procedure TDBWriter.CommitWork;
begin
  if trWrite.InTransaction then trWrite.Commit;
end;

constructor TDBWriter.Create(DB: TpFIBDatabase);
begin
  inherited Create;
  trWrite := TpFIBTransaction.Create(nil);
  trWrite.DefaultDatabase := DB;
  trWrite.TPBMode := tpbDefault;
  trWrite.TRParams.Text :=
    'write' + #13#10 +
    'read_committed' + #13#10 +
    'rec_version' + #13#10 +
    'nowait';

  qrWrite := TpFIBQuery.Create(nil);
  qrWrite.Database := DB;
  qrWrite.Transaction := trWrite;
end;

destructor TDBWriter.Destroy;
begin
  qrWrite.Free;
  if trWrite.InTransaction then trWrite.Rollback;
  trWrite.Free;
  inherited;
end;

procedure TDBWriter.ExecQuery(strQuery: String; Commit: Boolean);
begin
  qrWrite.Close;
  if Commit then
    qrWrite.Options := [qoStartTransaction, qoAutoCommit]
  else
    qrWrite.Options := [qoStartTransaction];

  qrWrite.SQL.Text := strQuery;
  qrWrite.ExecQuery;
end;

procedure TDBWriter.RollbackWork;
begin
  if trWrite.InTransaction then trWrite.Rollback;
end;

procedure TDBWriter.SetVID(const Value: TVehIdent);
begin
  FVID.ID := Value.ID;
  FVID.SN := Value.SN;
  FVID.Phone := Value.Phone;
end;

{ TInfoDataWriter }

constructor TInfoDataWriter.Create(DB: TpFIBDatabase);
begin
  inherited;
  qrWrStateNoGPS := TpFIBQuery.Create(nil);
  qrWrStateNoGPS.Database := DB;
  qrWrStateNoGPS.Transaction := trWrite;
  qrWrStateNoGPS.SQL.Text := SQL_STATE_NOGPS_INSERTUPDATE;

  qrWrStateFull := TpFIBQuery.Create(nil);
  qrWrStateFull.Database := DB;
  qrWrStateFull.Transaction := trWrite;
  qrWrStateFull.SQL.Text := SQL_STATE_INSERTUPDATE;
end;

destructor TInfoDataWriter.Destroy;
begin
  qrWrStateNoGPS.Free;
  qrWrStateFull.Free;
  inherited;
end;

function TInfoDataWriter.WriteData(AData: PByte): Boolean;
begin
  InfoData := PInfoData(AData);
  Result := WriteState;
  if Result then Result := WriteStateJournal;
  if Result and (sr.latitude <> -1) and (sr.longitude <> -1) then
    Result := WritePosJournal;

  if Result then CommitWork else RollbackWork;
end;

function TInfoDataWriter.WritePosJournal: Boolean;
begin
  try
    qrWrite.Close;
    qrWrite.SQL.Text := SQL_JOURNAL_INSERT;
    qrWrite.Options := [qoStartTransaction];
    qrWrite.ParamByName('id_vehicle').AsInteger := sr.id_vehicle;
    qrWrite.ParamByName('phone_number').AsString := FVID.Phone;
    qrWrite.ParamByName('recordtype_id').AsInteger := GPS_POSITION_JOURN;
    qrWrite.ParamByName('absolute_time').AsDateTime := sr.time_state;
    qrWrite.ParamByName('latitude').AsFloat := sr.latitude_ex;
    qrWrite.ParamByName('longitude').AsFloat := sr.longitude_ex;
    qrWrite.ParamByName('altitude').AsFloat := sr.altitude_ex;

    qrWrite.ParamByName('din').AsVariant := null;
    qrWrite.ParamByName('dout').AsVariant := null;
    qrWrite.ParamByName('adc1').AsVariant := null;
    qrWrite.ParamByName('adc2').AsVariant := null;
    qrWrite.ParamByName('dac').AsVariant := null;
    qrWrite.ParamByName('charge_level').AsVariant := null;
    qrWrite.ParamByName('gsm_signal_strength').AsVariant := null;
    qrWrite.ParamByName('flags_state').AsVariant := null;

    qrWrite.ParamByName('speed').AsFloat := sr.speed_ex;
    qrWrite.ParamByName('course').AsFloat := sr.course_ex;

    qrWrite.ParamByName('exstatus').AsVariant := null;

    qrWrite.ExecQuery;
    Result := True;
  except
    on E: Exception do begin
      LogError('WritePosJournal', E.Message);
      Result := False;
    end;
  end;
end;

function TInfoDataWriter.WriteState: Boolean;
var
  qr: TFIBQuery;
  IsGPSFake: Boolean;
begin
  sr.id_vehicle := FVID.ID;
  sr.time_state := DecodeInfoDateTime(InfoData.UTC);
  sr.latitude_ex   := SwapLongWord(InfoData.Latitude);
  sr.longitude_ex  := SwapLongWord(InfoData.Longitude);
  sr.altitude_ex   := SwapLongWord(InfoData.Altitude);
  sr.latitude   := DecodeLatitude(sr.latitude_ex);
  sr.longitude  := DecodeLongitude(sr.longitude_ex);
  sr.altitude   := DecodeAltitude(sr.altitude_ex);
  sr.din        := InfoData.DIn;
  sr.dout       := InfoData.DOut;
  sr.adc1       := InfoData.ADC1;
  sr.adc2       := InfoData.ADC2;
  sr.dac        := InfoData.DAC;
  sr.charge_level   := InfoData.CL;
  sr.gsm_signal_str := InfoData.SS;
  sr.flags_state    := InfoData.Status;
  sr.speed_ex       := Swap(InfoData.Speed);
  sr.course_ex      := Swap(InfoData.Course);
  sr.speed          := DecodeSpeed(sr.speed_ex);
  sr.course         := DecodeCourse(sr.course_ex);
  sr.running_hours  := SwapLongWord(InfoData.RunningHours);
  sr.journal_size   := SwapLongWord(InfoData.JournalSize);
  sr.newjourn_size  := SwapLongWord(InfoData.NewJournalSize);
  //sr.exstatus       := Swap(InfoData.exstatus);
  sr.exstatus       := 0;

  if not trWrite.Active then trWrite.StartTransaction;

  IsGPSFake := (sr.latitude = GPS_FAKE) or (sr.longitude = GPS_FAKE);
  if IsGPSFake then
    qr := qrWrStateNoGPS
  else
    qr := qrWrStateFull;

  qr.ParamByName('id_vehicle').AsInteger := sr.id_vehicle;
  qr.ParamByName('time_state').AsDateTime := sr.time_state;
  if not IsGPSFake then
  begin
    qr.ParamByName('latitude').AsFloat := sr.latitude;
    qr.ParamByName('longitude').AsFloat := sr.longitude;
    qr.ParamByName('altitude').AsFloat := sr.altitude;
  end;

  qr.ParamByName('din').AsShort := sr.din;
  qr.ParamByName('dout').AsShort := sr.dout;
  qr.ParamByName('adc1').AsShort := sr.adc1;
  qr.ParamByName('adc2').AsShort := sr.adc2;
  qr.ParamByName('dac').AsShort := sr.dac;
  qr.ParamByName('charge_level').AsShort := sr.charge_level;
  qr.ParamByName('gsm_signal_strength').AsShort := sr.gsm_signal_str;
  qr.ParamByName('flags_state').AsShort := sr.flags_state;
  if not IsGPSFake then
  begin
    qr.ParamByName('speed').AsFloat := sr.speed;
    qr.ParamByName('course').AsFloat := sr.course;
  end;
  qr.ParamByName('running_hours').AsFloat := sr.running_hours;
  qr.ParamByName('journal_size').AsFloat := sr.journal_size;
  qr.ParamByName('newjournal_size').AsFloat := sr.newjourn_size;
  qr.ParamByName('exstatus').AsInteger := sr.exstatus;
  //OutputDebugString(PChar(IntToStr(sr.exstatus)));
  qr.ExecQuery;
  Result := True;
end;

function TInfoDataWriter.WriteStateJournal: Boolean;
begin
  try
    qrWrite.Close;
    qrWrite.SQL.Text := SQL_JOURNAL_INSERT;
    qrWrite.Options := [qoStartTransaction];
    qrWrite.ParamByName('id_vehicle').AsInteger := sr.id_vehicle;
    qrWrite.ParamByName('phone_number').AsString := FVID.Phone;
    qrWrite.ParamByName('recordtype_id').AsInteger := STATE_JOURN;
    qrWrite.ParamByName('absolute_time').AsDateTime := sr.time_state;

    qrWrite.ParamByName('latitude').AsVariant := null;
    qrWrite.ParamByName('longitude').AsVariant := null;
    qrWrite.ParamByName('altitude').AsVariant := null;

    qrWrite.ParamByName('din').AsShort := sr.din;
    qrWrite.ParamByName('dout').AsShort := sr.dout;
    qrWrite.ParamByName('adc1').AsShort := sr.adc1;
    qrWrite.ParamByName('adc2').AsShort := sr.adc2;
    qrWrite.ParamByName('dac').AsShort := sr.dac;
    qrWrite.ParamByName('charge_level').AsShort := sr.charge_level;
    qrWrite.ParamByName('gsm_signal_strength').AsShort := sr.gsm_signal_str;
    qrWrite.ParamByName('flags_state').AsShort := sr.flags_state;

    qrWrite.ParamByName('speed').AsVariant := null;
    qrWrite.ParamByName('course').AsVariant := null;

    qrWrite.ParamByName('exstatus').AsInteger := sr.exstatus;
    qrWrite.ExecQuery;
    Result := True;
  except
    on E: Exception do
    begin
      LogError('WriteStateJournal', E.Message);
      Result := False;
    end;
  end;
end;

{ TConfDataWriter }

procedure TConfDataWriter.ReadDBConf;
begin
  try
    qrWrite.Close;
    qrWrite.SQL.Text := SQL_READ_CONF;
    qrWrite.Options := [qoStartTransaction];
    qrWrite.ExecWP([FVID.ID]);

    AllConf.GenConf.DataID := ID_GEN_CONF_DATA;
    AllConf.GenConf.cfgSerialNum := qrWrite.FieldByName('serial_num').AsInteger;
    AllConf.GenConf.cfgSoftVer := qrWrite.FieldByName('soft_ver').AsInteger;
    AllConf.GenConf.cfgHardVer := qrWrite.FieldByName('hard_ver').AsInteger;
    AllConf.GenConf.cfgFlashSize := qrWrite.FieldByName('flash_size').AsInteger;
    AllConf.GenConf.cfgBatteryType := qrWrite.FieldByName('battery_type').AsInteger;
    AllConf.GenConf.cfgCapacity := qrWrite.FieldByName('capacity').AsInteger;
    AllConf.GenConf.cfgPinCode := qrWrite.FieldByName('pin').AsInteger;
    AllConf.GenConf.cfgGPSscan := qrWrite.FieldByName('gps_scan_period').AsInteger;
    AllConf.GenConf.cfgStateScan := qrWrite.FieldByName('di_ai_scan_period').AsInteger;
    AllConf.GenConf.cfgDIMask := qrWrite.FieldByName('di_mask').AsInteger;
    AllConf.GenConf.cfgGPSDistance := qrWrite.FieldByName('gps_distance').AsInteger;
    AllConf.GenConf.cfgZoneLatitude := qrWrite.FieldByName('zone_latitude').AsInteger;
    AllConf.GenConf.cfgZoneLongitude := qrWrite.FieldByName('zone_longitude').AsInteger;
    AllConf.GenConf.cfgZoneRadius := qrWrite.FieldByName('zone_radius').AsInteger;
    AllConf.GenConf.cfgDataSendPeriod := qrWrite.FieldByName('data_send_period').AsInteger;
    AllConf.GenConf.cfgConfDataCC := qrWrite.FieldByName('conf_data_cc').AsInteger;
    AllConf.GenConf.cfgJrnSendPeriod := qrWrite.FieldByName('journal_send_period').AsInteger;
    AllConf.GenConf.cfgConfJrnCC := qrWrite.FieldByName('conf_journal_cc').AsInteger;
    AllConf.GenConf.DOut := qrWrite.FieldByName('dout').AsInteger;
    AllConf.GenConf.DAC := qrWrite.FieldByName('aout').AsInteger;
    AllConf.GenConf.cfgMovementAlgorithm := Trunc(qrWrite.FieldByName('movement_algorithm').AsFloat);
    AllConf.GenConf.cfgDistanceAlgorithm := Trunc(qrWrite.FieldByName('distance_algorithm').AsFloat);

    AllConf.GPRSConf.DataID := ID_GPRS_CONF_DATA;
    AllConf.GPRSConf.cfgServerIP := qrWrite.FieldByName('gprs_ip').AsString;
    AllConf.GPRSConf.cfgServerPort := qrWrite.FieldByName('gprs_port').AsInteger;
    AllConf.GPRSConf.cfgAPN := qrWrite.FieldByName('gprs_apn').AsString;
    AllConf.GPRSConf.cfgUserName := qrWrite.FieldByName('gprs_user').AsString;
    AllConf.GPRSConf.cfgPassword := qrWrite.FieldByName('gprs_pswd').AsString;

    AllConf.CipherKey := qrWrite.FieldByName('cipher_key').AsString;
    AllConf.DO_Mask := qrWrite.FieldByName('do_mask').AsInteger;
  except
    on E: Exception do
      LogError('ReadDBConf', E.Message);
  end;
end;

function TConfDataWriter.WriteAllConf: Boolean;
begin
  try
    qrWrite.Close;
    qrWrite.SQL.Text := SQL_CONF_WRITE;
    qrWrite.Options := [qoStartTransaction];

    qrWrite.ParamByName('ID_VEH_CONF').AsInteger :=
      dmDatabase.db3C.Gen_Id('ID_VEH_CONF_GEN', 1);

    qrWrite.ParamByName('id_vehicle').AsInteger := FVID.ID;    
    qrWrite.ParamByName('serial_num').AsInteger := AllConf.GenConf.cfgSerialNum;
    qrWrite.ParamByName('soft_ver').AsInteger := AllConf.GenConf.cfgSoftVer;
    qrWrite.ParamByName('hard_ver').AsInteger := AllConf.GenConf.cfgHardVer;
    qrWrite.ParamByName('flash_size').AsInteger := AllConf.GenConf.cfgFlashSize;
    qrWrite.ParamByName('battery_type').AsInteger := AllConf.GenConf.cfgBatteryType;
    qrWrite.ParamByName('capacity').AsInteger := AllConf.GenConf.cfgCapacity;
    qrWrite.ParamByName('pin').AsInteger := AllConf.GenConf.cfgPinCode;
    qrWrite.ParamByName('gps_scan_period').AsInteger := AllConf.GenConf.cfgGPSscan;
    qrWrite.ParamByName('di_ai_scan_period').AsInteger := AllConf.GenConf.cfgStateScan;
    qrWrite.ParamByName('di_mask').AsInteger := AllConf.GenConf.cfgDIMask;
    qrWrite.ParamByName('gps_distance').AsInteger := AllConf.GenConf.cfgGPSDistance;
    qrWrite.ParamByName('zone_latitude').AsFloat := AllConf.GenConf.cfgZoneLatitude;
    qrWrite.ParamByName('zone_longitude').AsFloat := AllConf.GenConf.cfgZoneLongitude;
    qrWrite.ParamByName('zone_radius').AsFloat := AllConf.GenConf.cfgZoneRadius;
    qrWrite.ParamByName('data_send_period').AsInteger := AllConf.GenConf.cfgDataSendPeriod;
    qrWrite.ParamByName('conf_data_cc').AsInteger := AllConf.GenConf.cfgConfDataCC;
    qrWrite.ParamByName('journal_send_period').AsInteger := AllConf.GenConf.cfgJrnSendPeriod;
    qrWrite.ParamByName('conf_journal_cc').AsInteger := AllConf.GenConf.cfgConfJrnCC;
    qrWrite.ParamByName('dout').AsInteger := AllConf.GenConf.DOut;
    qrWrite.ParamByName('aout').AsInteger := AllConf.GenConf.DAC;
    qrWrite.ParamByName('movement_algorithm').AsFloat := AllConf.GenConf.cfgMovementAlgorithm;
    qrWrite.ParamByName('distance_algorithm').AsFloat := AllConf.GenConf.cfgDistanceAlgorithm;
    qrWrite.ParamByName('gprs_ip').AsString := AllConf.GPRSConf.cfgServerIP;
    qrWrite.ParamByName('gprs_port').AsInteger := AllConf.GPRSConf.cfgServerPort;
    qrWrite.ParamByName('gprs_apn').AsString := AllConf.GPRSConf.cfgAPN;
    qrWrite.ParamByName('gprs_user').AsString := AllConf.GPRSConf.cfgUserName;
    qrWrite.ParamByName('gprs_pswd').AsString := AllConf.GPRSConf.cfgPassword;
    qrWrite.ParamByName('cipher_key').AsString := AllConf.CipherKey;
    qrWrite.ParamByName('do_mask').AsInteger := AllConf.DO_Mask;
    qrWrite.ParamByName('PROBABLY').AsString := 'N';
    qrWrite.ExecQuery;
    Result := True;
  except
    on E: Exception do begin
      LogError('WriteAllConf', E.Message);
      Result := False;
    end;
  end;
end;

function TConfDataWriter.WriteData(AData: PByte): Boolean;
var
  ConfType: Byte;
begin
  ConfData := AData;
  ReadDBConf;
  ConfType := ConfData^;
  case ConfType of
    ID_GEN_CONF_DATA: Result := WriteGenConf;
    ID_GPS_CONF_DATA: Result := WriteGPSConf;
    ID_GPRS_CONF_DATA: Result := WriteGPRSConf;
  else
    Result := False;
  end;

  if Result then CommitWork else RollbackWork;
end;

function TConfDataWriter.WriteGenConf: Boolean;
var
  GenConfData: PGenConfData;
begin
  GenConfData := PGenConfData(ConfData);

  AllConf.GenConf.cfgSerialNum := FVID.SN;
  AllConf.GenConf.cfgSoftVer := SwapLongWord(GenConfData.cfgSoftVer);
  AllConf.GenConf.cfgHardVer := SwapLongWord(GenConfData.cfgHardVer);
  AllConf.GenConf.cfgFlashSize := SwapLongWord(GenConfData.cfgFlashSize);
  AllConf.GenConf.cfgBatteryType := GenConfData.cfgBatteryType;
  AllConf.GenConf.cfgCapacity := Swap(GenConfData.cfgCapacity);
  AllConf.GenConf.cfgPinCode := SwapLongWord(GenConfData.cfgPinCode);
  AllConf.GenConf.cfgGPSscan := Swap(GenConfData.cfgGPSscan);
  AllConf.GenConf.cfgStateScan := Swap(GenConfData.cfgStateScan);
  AllConf.GenConf.cfgDIMask := GenConfData.cfgDIMask;
  AllConf.GenConf.cfgGPSDistance := Swap(GenConfData.cfgGPSDistance);
  AllConf.GenConf.cfgZoneLatitude := SwapLongWord(GenConfData.cfgZoneLatitude);
  AllConf.GenConf.cfgZoneLongitude := SwapLongWord(GenConfData.cfgZoneLongitude);
  AllConf.GenConf.cfgZoneRadius := Swap(GenConfData.cfgZoneRadius);
  AllConf.GenConf.cfgDataSendPeriod := Swap(GenConfData.cfgDataSendPeriod);
  AllConf.GenConf.cfgConfDataCC := GenConfData.cfgConfDataCC;
  AllConf.GenConf.cfgJrnSendPeriod := Swap(GenConfData.cfgJrnSendPeriod);
  AllConf.GenConf.cfgConfJrnCC := GenConfData.cfgConfJrnCC;
  AllConf.GenConf.DOut := GenConfData.DOut;
  AllConf.GenConf.DAC := GenConfData.DAC;
  AllConf.GenConf.cfgMovementAlgorithm := SwapLongWord(GenConfData.cfgMovementAlgorithm);
  AllConf.GenConf.cfgDistanceAlgorithm := SwapLongWord(GenConfData.cfgDistanceAlgorithm);

  Result := WriteAllConf;
end;

function TConfDataWriter.WriteGPRSConf: Boolean;
var
  pGPRSConf: TpGPRSConfData;
begin
  pGPRSConf.DataID := PByte(ConfData);
  pGPRSConf.cfgServerIP := PLongword(Integer(pGPRSConf.DataID) + 1);
  pGPRSConf.cfgServerPort := System.PWord(Integer(pGPRSConf.cfgServerIP) + 4);
  pGPRSConf.cfgAPN        :=  PChar(Integer(pGPRSConf.cfgServerPort) + 2);
  pGPRSConf.cfgUserName   :=  PChar(Integer(pGPRSConf.cfgAPN) + Length(pGPRSConf.cfgAPN)+1);
  pGPRSConf.cfgPassword   :=  PChar(Integer(pGPRSConf.cfgUserName) + Length(pGPRSConf.cfgUserName)+1);

  AllConf.GPRSConf.cfgServerIP := DecodeIP(pGPRSConf.cfgServerIP^);
  AllConf.GPRSConf.cfgServerPort := Swap(pGPRSConf.cfgServerPort^);
  AllConf.GPRSConf.cfgAPN := pGPRSConf.cfgAPN;
  AllConf.GPRSConf.cfgUserName := pGPRSConf.cfgUserName;
  AllConf.GPRSConf.cfgPassword := pGPRSConf.cfgPassword;

  Result := WriteAllConf;
end;

function TConfDataWriter.WriteGPSConf: Boolean;
begin
  Result := True;
end;


initialization
  csCheckSN := TCriticalSection.Create;

finalization
  csCheckSN.Free;

end.
