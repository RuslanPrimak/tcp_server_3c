unit u_IBInfoDataWriter;

interface

uses
	u_IB_DBWriter, IBDatabase, IBSQL, uInfoData, uStateRec, SysUtils;

type
  TIBInfoDataWriter = class(TIB_DBWriter)
  private
    InfoData: PInfoData;
    sr: TStateRec;
    qrWrStateNoGPS: TIBSQL;
    qrWrStateFull: TIBSQL;
    function WriteState: Boolean;
    function WritePosJournal: Boolean;
    function WriteStateJournal: Boolean;
  public
    function WriteData(AData: PByte): Boolean;
    constructor Create(DB: TIBDatabase);
    destructor Destroy; override;
  end;

implementation

uses
	u_SQLs, uJournalSpec, Variants, LogFileUnit, uCommProtocol_3C, u_ByteOrders;

{ TIBInfoDataWriter }

constructor TIBInfoDataWriter.Create(DB: TIBDatabase);
begin
  inherited;
  qrWrStateNoGPS := TIBSQL.Create(nil);
  qrWrStateNoGPS.Database := DB;
  qrWrStateNoGPS.Transaction := trWrite;
  qrWrStateNoGPS.SQL.Text := SQL_STATE_NOGPS_INSERTUPDATE;

  qrWrStateFull := TIBSQL.Create(nil);
  qrWrStateFull.Database := DB;
  qrWrStateFull.Transaction := trWrite;
  qrWrStateFull.SQL.Text := SQL_STATE_INSERTUPDATE;
end;

destructor TIBInfoDataWriter.Destroy;
begin
	qrWrStateNoGPS.Free;
  qrWrStateFull.Free;
  inherited;
end;

function TIBInfoDataWriter.WriteData(AData: PByte): Boolean;
begin
	StartWork;
  InfoData := PInfoData(AData);
  Result := WriteState;
  if Result then Result := WriteStateJournal;
  if Result and (sr.latitude <> -1) and (sr.longitude <> -1) then
    Result := WritePosJournal;

  if Result then
  	CommitWork
  else
  	RollbackWork;
end;

function TIBInfoDataWriter.WritePosJournal: Boolean;
begin
  try
    qrWrite.Close;
    qrWrite.SQL.Text := SQL_JOURNAL_INSERT;
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

function TIBInfoDataWriter.WriteState: Boolean;
var
  qr: TIBSQL;
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

function TIBInfoDataWriter.WriteStateJournal: Boolean;
begin
  try
    qrWrite.Close;
    qrWrite.SQL.Text := SQL_JOURNAL_INSERT;
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

end.
