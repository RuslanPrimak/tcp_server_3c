unit u_IBJournDataWriter;

interface

uses
	u_IB_DBWriter, IBDatabase, IBSQL, SysUtils, uJournalSpec, uStateRec,
  uVehicles3C, uCommProtocol_3C;

type
	TIBJournDataWriter = class(TIB_DBWriter)
  private
    PrevJrnType: Byte; // Идентификатор типа журнала
    PrevSesID: Word; // Идентификатор сессии
    PrevPackID: Byte;
    SessionData: TJrnSession;
    CurrentPacket: PJrnPacket;
    qrJournal: TIBSQL;
    qrSens: TIBSQL;
    qrWrStateNoGPS: TIBSQL;
    qrWrStateFull: TIBSQL;
    qrWrStateGPS: TIBSQL;
    sr: TStateRec;
    function ParseBuffer: Boolean;
    procedure WriteGPSRec(RecData: PByte);
    procedure WriteStateRec(RecData: PByte);
    procedure WriteEventRec(RecData: PByte);
    procedure WriteExtSensRec(RecData: PByte);
    procedure WriteSensRec(RecData: PByte);
    procedure UpdateState;
    procedure FillRecHeader;
  public
    function WriteData(AData: PByte; AVid: TVehIdent): Boolean;
    constructor Create(DB: TIBDatabase);
    destructor Destroy; override;
    procedure ResetState;
  end;

implementation

uses
	u_SQLs, u_ByteOrders, Variants, StrConvUnit, u3SSensors;

{ TIBJournDataWriter }

constructor TIBJournDataWriter.Create(DB: TIBDatabase);
begin
  inherited;
  ResetState;
  SessionData := TJrnSession.Create;

  qrJournal := TIBSQL.Create(nil);
  qrJournal.Database := DB;
  qrJournal.Transaction := trWrite;
  qrJournal.SQL.Text := SQL_JOURNAL_INSERT;

  qrSens := TIBSQL.Create(nil);
  qrSens.Database := DB;
  qrSens.Transaction := trWrite;
  qrSens.SQL.Text := SQL_SENSORS_INSERT;

  qrWrStateNoGPS := TIBSQL.Create(nil);
  qrWrStateNoGPS.Database := DB;
  qrWrStateNoGPS.Transaction := trWrite;
  qrWrStateNoGPS.SQL.Text := SQL_STATE_NOGPS_INSERTUPDATE;

  qrWrStateFull := TIBSQL.Create(nil);
  qrWrStateFull.Database := DB;
  qrWrStateFull.Transaction := trWrite;
  qrWrStateFull.SQL.Text := SQL_STATE_INSERTUPDATE;

  qrWrStateGPS := TIBSQL.Create(nil);
  qrWrStateGPS.Database := DB;
  qrWrStateGPS.Transaction := trWrite;
  qrWrStateGPS.SQL.Text := SQL_STATE_ONLYGPS_INSERTUPDATE;
end;

destructor TIBJournDataWriter.Destroy;
begin
	qrJournal.Free;
  qrSens.Free;
  qrWrStateNoGPS.Free;
  qrWrStateFull.Free;
  qrWrStateGPS.Free;
  SessionData.Free;
  inherited;
end;

procedure TIBJournDataWriter.FillRecHeader;
begin
  qrJournal.ParamByName('id_veh_journ').AsInteger := 1; // Значение не имеет значения, т.к. триггер задаст значение из генератора
  qrJournal.ParamByName('id_vehicle').AsInteger := FVID.ID;
  qrJournal.ParamByName('phone_number').AsString := FVID.Phone;
end;

function TIBJournDataWriter.ParseBuffer: Boolean;
var
  iPack, iRec: Integer;
  UndefRec: PByte;
begin
  try
  	if not trWrite.InTransaction then
    	trWrite.StartTransaction;

    for iPack := 0 to SessionData.Count-1 do
    begin
      for iRec := 0 to SessionData[iPack].Records-1 do
      begin
        UndefRec := GetRecordFromData(SessionData[iPack].Data, iRec);
        case IDUndefRec(UndefRec) of
          GPS_POSITION_JOURN, GPS_POSITION_JOURN_INVALID: WriteGPSRec(UndefRec);
          STATE_JOURN: WriteStateRec(UndefRec);
          EVENT_JOURN: WriteEventRec(UndefRec);
          EXTERNAL_SENS_DATA_JOURN: WriteExtSensRec(UndefRec);
          SENSORS_DATA_JOURN: WriteSensRec(UndefRec);
        else ;//ABS_TIME_FIX_JOURN: ;
        end;
      end;
    end;
    // Обновление состояния автомобиля
    UpdateState;

    if trWrite.InTransaction then
    begin
      trWrite.Commit;
      Result := True;
      PrevPackID := 0;
    end
    else
    begin
      Result := False;
    end;
  finally
    SessionData.Clear;
    RollbackWork;
  end;
end;

procedure TIBJournDataWriter.ResetState;
begin
	PrevSesID := 0;
  PrevJrnType := $FF;
  PrevPackID := 0;
end;

procedure TIBJournDataWriter.UpdateState;
var
  f: Byte;
  IsGPSFake: Boolean;
  qrState: TIBSQL;
  i: Integer;
Const
  MAX_TRIES = 10;
begin
  f := 0;
  if sr.pos_exists then f := 1;
  if sr.state_exists then f := f or 2;

  if f > 0 then
  begin
    case f of
      1: qrState := qrWrStateGPS;
      2: qrState := qrWrStateNoGPS;
      else
        qrState := qrWrStateFull;
    end;

    qrState.ParamByName('id_vehicle').AsInteger := FVID.ID;
    qrState.ParamByName('time_state').AsDateTime := sr.time_state;

    IsGPSFake := (sr.latitude = GPS_FAKE) or (sr.longitude = GPS_FAKE);

    if (f and 1) = 1 then
    begin
      if not IsGPSFake then
      begin
        qrState.ParamByName('latitude').AsFloat := sr.latitude;
        qrState.ParamByName('longitude').AsFloat := sr.longitude;
        qrState.ParamByName('altitude').AsFloat := sr.altitude;
        qrState.ParamByName('speed').AsFloat := sr.speed;
        qrState.ParamByName('course').AsFloat := sr.course;
      end;
    end;

    if (f and 2) = 2 then
    begin
      qrState.ParamByName('din').AsShort := sr.din;
      qrState.ParamByName('dout').AsShort := sr.dout;
      qrState.ParamByName('adc1').AsShort := sr.adc1;
      qrState.ParamByName('adc2').AsShort := sr.adc2;
      qrState.ParamByName('dac').AsShort := sr.dac;
      qrState.ParamByName('charge_level').AsShort := sr.charge_level;
      qrState.ParamByName('gsm_signal_strength').AsShort := sr.gsm_signal_str;
      qrState.ParamByName('flags_state').AsShort := sr.flags_state;
      qrState.ParamByName('running_hours').AsFloat := sr.running_hours;
      qrState.ParamByName('journal_size').AsFloat := sr.journal_size;
      qrState.ParamByName('newjournal_size').AsFloat := sr.newjourn_size;
      qrState.ParamByName('exstatus').AsInteger := sr.exstatus;
    end;

    for i := 0 to MAX_TRIES do
    begin
      try
        qrState.ExecQuery;
        break;
      except
        on E: Exception do if Pos('Deadlock', E.Message) = 0 then raise;
      end;
    end;
  end;
end;

function TIBJournDataWriter.WriteData(AData: PByte;
  AVid: TVehIdent): Boolean;
var
  CurrSesID: Word;
begin
  Vid := AVid;

  CurrentPacket := PJrnPacket(AData);
  CurrSesID := Swap(CurrentPacket.SessionID);
  // Если при смене номера сессии или смене типа журнала есть данные в буфере - разрываем соединение
  if ((PrevJrnType <> CurrentPacket.JrnType) or (PrevSesID <> CurrSesID))
  	and (SessionData.Count > 0) then
    Result := False
  else
  begin
    // Проверяем номер пакета
    if (PrevPackID + 1) = CurrentPacket.PacketID then
    begin
      SessionData.SessionType := CurrentPacket.JrnType;
      SessionData.Add(@CurrentPacket.JrnData, CurrentPacket.FramesNum);
      if SessionData.Count = CurrentPacket.PacksNum then
      begin
        Result := ParseBuffer;
      end
      else
      begin
        Result := True;
        PrevPackID := CurrentPacket.PacketID;
      end;
    end
    else Result := (PrevPackID = CurrentPacket.PacketID);
  end;

  if not Result then SessionData.Clear;

  PrevSesID := CurrSesID;
  PrevJrnType := CurrentPacket.JrnType;
end;

procedure TIBJournDataWriter.WriteEventRec(RecData: PByte);
var
  Struct: PEventJrn;
  s: String;
begin
  Struct := PEventJrn(RecData);

  // Запись в журнал
  FillRecHeader;

  qrJournal.ParamByName('recordtype_id').AsInteger := EVENT_JOURN;

  qrJournal.ParamByName('absolute_time').AsDateTime := DecodeJournDateTime(SwapLongword(Struct.UTC));
  qrJournal.ParamByName('latitude').AsVariant := null;
  qrJournal.ParamByName('longitude').AsVariant := null;
  qrJournal.ParamByName('altitude').AsVariant := null;
  qrJournal.ParamByName('din').AsVariant := null;
  qrJournal.ParamByName('dout').AsVariant := null;
  qrJournal.ParamByName('adc1').AsVariant := null;
  qrJournal.ParamByName('adc2').AsVariant := null;
  qrJournal.ParamByName('dac').AsVariant := null;
  qrJournal.ParamByName('charge_level').AsVariant := null;
  qrJournal.ParamByName('gsm_signal_strength').AsVariant := null;
  qrJournal.ParamByName('flags_state').AsVariant := null;

  qrJournal.ParamByName('event_id').AsInteger := Struct.EventID;
  SetString(s, PChar(@Struct.EventData[0]), Length(Struct.EventData));
  //s := BufToHexStr(Struct.EventData[0], Length(Struct.EventData));
  qrJournal.ParamByName('event_data').AsString := s;

  qrJournal.ParamByName('speed').AsVariant := null;
  qrJournal.ParamByName('course').AsVariant := null;
  qrJournal.ParamByName('exstatus').AsVariant := null;
  qrJournal.ExecQuery;
end;

procedure TIBJournDataWriter.WriteExtSensRec(RecData: PByte);
var
  Struct: PExtSensJrn;
  s: String;
  CC, CC1: Byte;
begin
  Struct := PExtSensJrn(RecData);

  // Проверка контрольной суммы
  CC := Struct.ID and $0F;
  SetString(s, PChar(@Struct.SensData[0]), Length(Struct.SensData));
  s := BufToHexStr(Struct.SensData[0], Length(Struct.SensData));
  CC1 := Struct.SensType xor CRC7(@Struct.SensData[0], Length(Struct.SensData));
  if ((CC = 0) or (CC = CC1)) and (s <> '') then
  begin
    // Запись в журнал
    FillRecHeader;
    qrJournal.ParamByName('recordtype_id').AsInteger := IDUndefRec(RecData);
    qrJournal.ParamByName('absolute_time').AsDateTime := DecodeJournDateTime(SwapLongword(Struct.UTC));

    qrJournal.ParamByName('latitude').AsVariant := null;
    qrJournal.ParamByName('longitude').AsVariant := null;
    qrJournal.ParamByName('altitude').AsVariant := null;
    qrJournal.ParamByName('din').AsVariant := null;
    qrJournal.ParamByName('dout').AsVariant := null;
    qrJournal.ParamByName('adc1').AsVariant := null;
    qrJournal.ParamByName('adc2').AsVariant := null;
    qrJournal.ParamByName('dac').AsVariant := null;
    qrJournal.ParamByName('charge_level').AsVariant := null;
    qrJournal.ParamByName('gsm_signal_strength').AsVariant := null;
    qrJournal.ParamByName('flags_state').AsVariant := null;

    qrJournal.ParamByName('event_id').AsInteger := Struct.SensType;
    qrJournal.ParamByName('event_data').AsString := s;

    qrJournal.ParamByName('speed').AsVariant := null;
    qrJournal.ParamByName('course').AsVariant := null;
    qrJournal.ParamByName('exstatus').AsVariant := null;
    qrJournal.ExecQuery;
  end;
end;

procedure TIBJournDataWriter.WriteGPSRec(RecData: PByte);
var
  Struct: PGPSJrn;
begin
  Struct := PGPSJrn(RecData);

  // Запись в журнал
  FillRecHeader;
  
  if FVID.SN > SN_RECTYPE_CHANGE then
    qrJournal.ParamByName('recordtype_id').AsInteger := GPS_POSITION_JOURN
  else
    qrJournal.ParamByName('recordtype_id').AsInteger := IDUndefRec(RecData);

  qrJournal.ParamByName('absolute_time').AsDateTime := DecodeJournDateTime(SwapLongword(Struct.UTC));

  qrJournal.ParamByName('latitude').AsInteger := Lt_GPSJrn(Struct);
  qrJournal.ParamByName('longitude').AsInteger := Lg_GPSJrn(Struct);
  qrJournal.ParamByName('altitude').AsInteger := Alt_GPSJrn(Struct);

  qrJournal.ParamByName('din').AsVariant := null;
  qrJournal.ParamByName('dout').AsVariant := null;
  qrJournal.ParamByName('adc1').AsVariant := null;
  qrJournal.ParamByName('adc2').AsVariant := null;
  qrJournal.ParamByName('dac').AsVariant := null;
  qrJournal.ParamByName('charge_level').AsVariant := null;
  qrJournal.ParamByName('gsm_signal_strength').AsVariant := null;
  qrJournal.ParamByName('flags_state').AsVariant := null;
  qrJournal.ParamByName('event_id').AsVariant := null;
  qrJournal.ParamByName('event_data').AsVariant := null;
  qrJournal.ParamByName('speed').AsInteger := Speed_GPSJrn(Struct);
  qrJournal.ParamByName('course').AsInteger := Course_GPSJrn(Struct);
  qrJournal.ParamByName('exstatus').AsVariant := null;
  qrJournal.ExecQuery;

  // Обновление параметров состояния
  if SessionData.SessionType <> ID_PERIOD_JOURN_DATA then
  begin
    sr.pos_exists     := True;
    sr.time_state     := qrJournal.ParamByName('absolute_time').AsDateTime;
    sr.latitude_ex    := qrJournal.ParamByName('latitude').AsInteger;
    sr.longitude_ex   := qrJournal.ParamByName('longitude').AsInteger;
    sr.altitude_ex    := qrJournal.ParamByName('altitude').AsInteger;
    sr.latitude       := DecodeLatitude(sr.latitude_ex);
    sr.longitude      := DecodeLongitude(sr.longitude_ex);
    sr.altitude       := DecodeAltitude(sr.altitude_ex);
    sr.speed_ex       := qrJournal.ParamByName('speed').AsInteger;
    sr.course_ex      := qrJournal.ParamByName('course').AsInteger;
    sr.speed          := DecodeSpeed(sr.speed_ex);
    sr.course         := DecodeCourse(sr.course_ex);
  end;
end;

procedure TIBJournDataWriter.WriteSensRec(RecData: PByte);
var
  Struct: PSensJrn;
  CC: Byte;
  TotalNibbles, iNibble: Integer;
  StartByte: Integer;
  SensID: Byte;
  OddStart, OddEnd: Byte;
  SensDataLen: Byte;
  SensDataStr: String;
  SensData: Int64;
  UTC: TDateTime;
  wMixData: Word;
  StateV1Exist: Boolean;
  ADCCount: Integer;
  tempSR: TStateRec;

  function GetHexStr: String;
  var
    s: String;
    hs: String;
    sl: Integer;
    i: Integer;
  begin
    sl := (SensDataLen + OddStart + OddEnd) div 2;
    SetString(s, PChar(@Struct.SensData[StartByte]), sl);
    hs := '';
    for i := 1 to sl do
      hs := hs + IntToHex(Ord(s[i]), 2);

    Result := Copy(hs, 1 + OddStart, SensDataLen);
  end;
begin
  StateV1Exist := False;
  ADCCount := 0;
  Struct := PSensJrn(RecData);
  UTC := DecodeJournDateTime(SwapLongword(Struct.UTC));

  // Проверка контрольной суммы
  CC := Struct.ID and $0F;
  if CC = CRC7(@Struct.SensData[0], Length(Struct.SensData)) then
  begin
    // Разборка данных датчиков
    TotalNibbles := Length(Struct.SensData)*2-1;
    iNibble := 0;
    while iNibble < TotalNibbles do
    begin
      StartByte := iNibble div 2;
      OddStart := iNibble mod 2;
      if OddStart = 1 then
        SensID := Byte(Swap(PWord(@Struct.SensData[StartByte])^) shr 4)
      else
        SensID := PByte(@Struct.SensData[StartByte])^;

      SensDataLen := Byte(SensID shr 5); // Значение в полубайтах

      if (SensID = 0) and (SensDataLen = 0) then break;

      if SensDataLen = 5 then SensDataLen := 8;
      if SensDataLen = 6 then SensDataLen := 9;

      OddEnd := (SensDataLen mod 2) xor OddStart;
      iNibble := iNibble + 2;
      StartByte := StartByte + 1; // Смещаем указатель на данные, следующие за SensID

      SensDataStr := GetHexStr;
      SensData := StrToInt64('$' + SensDataStr);
      // Запись значения датчика в таблицу датчиков
      qrSens.ParamByName('UTC_TIME').AsDateTime := UTC;
      qrSens.ParamByName('VEHICLE').AsInteger := FVID.ID;
      qrSens.ParamByName('SENS_ID').AsInteger := SensID;
      qrSens.ParamByName('SENS_DATA').AsInt64 := SensData;
      qrSens.ExecQuery;

      if SensID = SENS_ID_STATE_V1 then
      begin
        StateV1Exist := True;

        tempSR.state_exists := True;
        tempSR.time_state := UTC;

        wMixData := StrToInt('$' + Copy(SensDataStr, 8, 2));

        tempSR.din := StrToInt('$' + Copy(SensDataStr, 3, 2));
        tempSR.dout := StrToInt('$' + Copy(SensDataStr, 5, 1));
        tempSR.dac := StrToInt('$' + Copy(SensDataStr, 6, 2));
        tempSR.charge_level := (wMixData and $E0) shr 5;
        tempSR.gsm_signal_str := wMixData and $1F;
        tempSR.flags_state := StrToInt('$' + Copy(SensDataStr, 1, 2));
      end
      else if ((SensID and $F8) = SENS_ID_ADC_PORT1) then // по маске обрабатываем только ADC
      begin
        if ADCCount = 0 then
          tempSR.adc1 := Word(SensData)
        else if ADCCount = 1 then
          tempSR.adc2 := Word(SensData);
          
        Inc(ADCCount);
      end;
      // Смещаем указатель на длинну данных датчика
      iNibble := iNibble + SensDataLen;
    end;

    // Запись в журнал
    if StateV1Exist then
    begin
      FillRecHeader;
      //qrJournal.ParamByName('recordtype_id').AsInteger := IDUndefRec(RecData);
      qrJournal.ParamByName('recordtype_id').AsInteger := STATE_JOURN;
      qrJournal.ParamByName('absolute_time').AsDateTime := UTC;

      qrJournal.ParamByName('latitude').AsVariant := null;
      qrJournal.ParamByName('longitude').AsVariant := null;
      qrJournal.ParamByName('altitude').AsVariant := null;

      qrJournal.ParamByName('din').AsShort := tempSR.din;
      qrJournal.ParamByName('dout').AsShort := tempSR.dout;
      qrJournal.ParamByName('adc1').AsShort := tempSR.ADC1;
      qrJournal.ParamByName('adc2').AsShort := tempSR.ADC2;
      qrJournal.ParamByName('dac').AsShort := tempSR.DAC;
      qrJournal.ParamByName('charge_level').AsShort := tempSR.charge_level;
      qrJournal.ParamByName('gsm_signal_strength').AsShort := tempSR.gsm_signal_str;
      qrJournal.ParamByName('flags_state').AsShort := tempSR.flags_state;

      qrJournal.ParamByName('event_id').AsVariant := null;
      qrJournal.ParamByName('event_data').AsVariant := null;
      qrJournal.ParamByName('speed').AsVariant := null;
      qrJournal.ParamByName('course').AsVariant := null;
      qrJournal.ParamByName('exstatus').AsVariant := null;
      qrJournal.ExecQuery;

      // Обновление параметров состояния
      if SessionData.SessionType <> ID_PERIOD_JOURN_DATA then
      begin
        sr.state_exists   := True;
        sr.time_state     := tempSR.time_state;

        sr.din := tempSR.DIn;
        sr.dout := tempSR.DOut;
        sr.adc1 := tempSR.ADC1;
        sr.adc2 := tempSR.ADC2;
        sr.dac := tempSR.DAC;
        sr.charge_level := tempSR.charge_level;
        sr.gsm_signal_str := tempSR.gsm_signal_str;
        sr.flags_state := tempSR.flags_state;
      end;
    end;
  end;
end;

procedure TIBJournDataWriter.WriteStateRec(RecData: PByte);
var
  Struct: PStateJrn;
begin
  Struct := PStateJrn(RecData);

  // Запись в журнал
  FillRecHeader;
  qrJournal.ParamByName('recordtype_id').AsInteger := IDUndefRec(RecData);
  qrJournal.ParamByName('absolute_time').AsDateTime := DecodeJournDateTime(SwapLongword(Struct.UTC));

  qrJournal.ParamByName('latitude').AsVariant := null;
  qrJournal.ParamByName('longitude').AsVariant := null;
  qrJournal.ParamByName('altitude').AsVariant := null;

  qrJournal.ParamByName('din').AsShort := Struct.DIn;
  qrJournal.ParamByName('dout').AsShort := Struct.DOut;
  qrJournal.ParamByName('adc1').AsShort := Struct.ADC1;
  qrJournal.ParamByName('adc2').AsShort := Struct.ADC2;
  qrJournal.ParamByName('dac').AsShort := Struct.DAC;
  qrJournal.ParamByName('charge_level').AsShort := Struct.CL;
  qrJournal.ParamByName('gsm_signal_strength').AsShort := Struct.SS;
  qrJournal.ParamByName('flags_state').AsShort := Struct.Status;

  qrJournal.ParamByName('event_id').AsVariant := null;
  qrJournal.ParamByName('event_data').AsVariant := null;
  qrJournal.ParamByName('speed').AsVariant := null;
  qrJournal.ParamByName('course').AsVariant := null;

  qrJournal.ParamByName('exstatus').AsShort := Struct.ExStatus;
  qrJournal.ExecQuery;

  // Обновление параметров состояния
  if SessionData.SessionType <> ID_PERIOD_JOURN_DATA then
  begin
    sr.state_exists   := True;
    sr.time_state     := qrJournal.ParamByName('absolute_time').AsDateTime;

    sr.din := Struct.DIn;
    sr.dout := Struct.DOut;
    sr.adc1 := Struct.ADC1;
    sr.adc2 := Struct.ADC2;
    sr.dac := Struct.DAC;
    sr.charge_level := Struct.CL;
    sr.gsm_signal_str := Struct.SS;
    sr.flags_state := Struct.Status;
    sr.exstatus := Struct.ExStatus;
  end;
end;

end.
