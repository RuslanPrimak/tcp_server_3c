unit frmDebugUnit;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls
  //************************
  ,SimpleServerThread, DB, IBCustomDataSet, IBQuery, IBSQL
  //************************
  ;

type
  TfrmDebug = class(TForm)
    memPackedData: TMemo;
    Label1: TLabel;
    btnTestPacket: TButton;
    btnStartServer: TButton;
    btnStopServer: TButton;
    IBQuery1: TIBQuery;
    IBSQL1: TIBSQL;
    procedure btnTestPacketClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure ServiceStart(Sender: TObject; var Started: Boolean);
    procedure ServiceStop(Sender: TObject; var Stopped: Boolean);
    procedure ServiceContinue(Sender: TObject; var Continued: Boolean);
    procedure ServicePause(Sender: TObject; var Paused: Boolean);
    procedure ServiceShutdown(Sender: TObject);
    procedure btnStartServerClick(Sender: TObject);
    procedure btnStopServerClick(Sender: TObject);
  private
    { Private declarations }
    //FJournWriter: TJournDataWriter;
    FServer: TSimpleServerThread;
    function ProcessPack(Pack: PByte; Len: Integer): Boolean;
    procedure ServerExecuted(Sender: TObject);
    procedure ServerDestroyed(Sender: TObject);
  public
    { Public declarations }
  end;

var
  frmDebug: TfrmDebug;

implementation

uses uClientThread_3C, StrConvUnit, uCommProtocol_3C,
  uVehicles3C, LogFileUnit
  //************************
  ,uServerIni, uServerThread_3C
  //************************
  , uFileVersion, uConnectParamsProvider, uDBSetProvider,
  uDBSetProviderPool, strConst;

{$R *.dfm}

procedure TfrmDebug.btnTestPacketClick(Sender: TObject);
var
  buf: array of byte;
  str: String;
  //ref: String;
begin
  str := Copy(memPackedData.Lines.Text, 1, Length(memPackedData.Lines.Text)-2);
  SetLength(buf, Length(str) div 2);
  HexStrToBuf(str, Buf[0]);
  ProcessPack(PByte(@Buf[0]), Length(str) div 2);

  (*str := Copy(memPackedData.Lines.Text, 1, Length(memPackedData.Lines.Text)-2);
  SetLength(buf, Length(str) div 2);
  HexStrToBuf(str, Buf[0]);
  ref := BufToHexStr(Buf[0], Length(Buf));

  if (str = ref) then
    ShowMessage('TRUE')
  else
    ShowMessage('FALSE');*)
end;

function TfrmDebug.ProcessPack(Pack: PByte; Len: Integer): Boolean;
var
  Data: PByte;
  DataLen: Integer;
  DataID: Byte;
  s: String;
  res: Integer;
  FRecBuff: String;
  FRecBuffNeedMore: Boolean;
  vid: TVehIdent;
begin
  Result := False;

  vid.ID := 2;
  vid.SN := 8913;
  vid.Phone := '0503413538';

  SetString(s, PChar(Pack), Len);
  FRecBuffNeedMore := false;

  if FRecBuffNeedMore then
  begin
    //FRecBuffNeedMore := False;
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
          //Result := WriteInfoData(Data, vid);
          if not Result then LogError('WriteInfoData', BufToHexStr(Data^, DataLen));
        end;
      ID_GEN_CONF_DATA, ID_GPS_CONF_DATA, ID_GPRS_CONF_DATA:
        begin
          //Result := WriteConfData(Data, vid);
          if not Result then LogError('WriteConfData', BufToHexStr(Data^, DataLen));
        end;
      ID_NEW_JOURN_DATA, ID_PERIOD_JOURN_DATA, ID_ALARM_JOURN_DATA:
      begin
        //Result := FJournWriter.WriteData(Data, vid);
        if not Result then LogError('FJournWriter', BufToHexStr(Data^, DataLen));
      end;
    else
      Result := False;
      LogError('DataID', BufToHexStr(Data^, DataLen));
    end;

    if Result then
    begin
      ;
    end
    else
      LogError('DB ERROR');
  end
  else
  if res = 1 then
  begin
    //FRecBuffNeedMore := True;
    Result := True;
  end
  else
    LogError('ResExtract', IntToStr(res) + ' "' + BufToHexStr(Data^, DataLen) + '"');
end;

procedure TfrmDebug.FormCreate(Sender: TObject);
begin
  //FJournWriter := TJournDataWriter.Create(dmDatabase.db3C);
  //DBReconnect;
end;

procedure TfrmDebug.FormDestroy(Sender: TObject);
begin
  //FJournWriter.Free;
end;

procedure TfrmDebug.ServiceContinue(Sender: TObject;
  var Continued: Boolean);
begin
  LogWarning('ServiceContinue');
  FServer.Resume;
  Continued := True;
end;

procedure TfrmDebug.ServicePause(Sender: TObject; var Paused: Boolean);
begin
  LogWarning('ServicePause');
  FServer.Suspend;
  Paused := True;
end;

procedure TfrmDebug.ServiceShutdown(Sender: TObject);
var
  StopFlag: Boolean;
begin
  ServiceStop(Sender, StopFlag);
  LogWarning('ServiceShutdown');
end;

procedure TfrmDebug.ServiceStart(Sender: TObject; var Started: Boolean);
var
  StopFlag: Boolean;
	params: TDBConnectParams;
  provider: TDBSetProvider;
begin
	LogInfo('The service version is ', ReadVersion);
  FullLog := IniLogOn;
  LogInfo('Starting the service...');
  FServer := TServerThread_3C.Create(IniPort);
  FServer.FreeOnTerminate := True;
  FServer.OnExecute := ServerExecuted;
  FServer.OnDestroy := ServerDestroyed;

  // There is no necessity to keep connection to the database
  // We only need to test the availability of database for further work

	params := TConParamsProvider.GetDBParams;
  try
		provider := ProviderPool.GetDataBaseFromPool(params);
    if Assigned(provider) and provider.Active then
    begin
    	ProviderPool.PutDataBaseToPool(provider);
      LogInfo('SUCCESS! ' + rcStrTestConnDB, params.DBPath);

      FServer.Resume;
    	Started := True;

    end
    else
    begin
      LogError('FAIL! ' + rcStrTestConnDB, params.DBPath);
    	if Assigned(provider) then
				ProviderPool.PutDataBaseToPool(provider);

			Started := False;
    	ServiceStop(Self, StopFlag);

    end;
  finally
		params.Free;
  end;

  (*try
    DBReconnect;
  except
    on E: Exception do
      LogError('DBReconnect', E.Message);
  end;

  if DBConnected then
  begin
    FServer.Resume;
    Started := True;
  end
  else
  begin
    Started := False;
    ServiceStop(Self, StopFlag);
  end;*)
end;

procedure TfrmDebug.ServiceStop(Sender: TObject; var Stopped: Boolean);
begin
  FServer.Terminate;
  Stopped := True;
  LogWarning('ServiceStop');
end;

procedure TfrmDebug.ServerDestroyed(Sender: TObject);
begin
  btnStartServer.Enabled := True;
  btnStopServer.Enabled := False;
end;

procedure TfrmDebug.ServerExecuted(Sender: TObject);
begin
  btnStartServer.Enabled := False;
  btnStopServer.Enabled := True;
end;

procedure TfrmDebug.btnStartServerClick(Sender: TObject);
var
  bVoid: Boolean;
begin
  ServiceStart(nil, bVoid);
end;

procedure TfrmDebug.btnStopServerClick(Sender: TObject);
var
  bVoid: Boolean;
begin
  ServiceStop(nil, bVoid);
end;

end.

