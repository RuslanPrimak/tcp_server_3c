unit u_IBConfDataWriter;

interface

uses
	u_IB_DBWriter, IBDatabase, IBSQL, SysUtils, uCommProtocol_3C;

type
  TIBConfDataWriter = class(TIB_DBWriter)
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

implementation

uses
	u_SQLs, LogFileUnit, u_ByteOrders;

{ TIBConfDataWriter }

procedure TIBConfDataWriter.ReadDBConf;
begin
  try
    qrWrite.Close;
    qrWrite.SQL.Text := SQL_READ_CONF;
    qrWrite.ParamByName('idv').AsInteger := FVID.ID;
    qrWrite.ExecQuery;

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

function TIBConfDataWriter.WriteAllConf: Boolean;
begin
  try
    qrWrite.Close;
    qrWrite.SQL.Text := SQL_CONF_WRITE;

    qrWrite.ParamByName('ID_VEH_CONF').AsInteger := Gen_Id('ID_VEH_CONF_GEN', 1);

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

function TIBConfDataWriter.WriteData(AData: PByte): Boolean;
var
  ConfType: Byte;
begin
	StartWork;
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

function TIBConfDataWriter.WriteGenConf: Boolean;
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

function TIBConfDataWriter.WriteGPRSConf: Boolean;
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

function TIBConfDataWriter.WriteGPSConf: Boolean;
begin
	Result := True;
end;

end.
