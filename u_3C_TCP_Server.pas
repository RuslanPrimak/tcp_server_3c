unit u_3C_TCP_Server;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, SvcMgr, Dialogs
  , SimpleServerThread, uServerThread_3C;

type
  TsrvTCP_3C = class(TService)
    procedure ServiceStart(Sender: TService; var Started: Boolean);
    procedure ServiceStop(Sender: TService; var Stopped: Boolean);
    procedure ServiceContinue(Sender: TService; var Continued: Boolean);
    procedure ServicePause(Sender: TService; var Paused: Boolean);
    procedure ServiceShutdown(Sender: TService);
    procedure ServiceCreate(Sender: TObject);
    procedure ServiceDestroy(Sender: TObject);
  private
    { Private declarations }
    FServer: TSimpleServerThread;
  public
    function GetServiceController: TServiceController; override;
    { Public declarations }
  end;

var
  srvTCP_3C: TsrvTCP_3C;

implementation

uses
  LogFileUnit, uServerIni, uDBSetProviderPool,
  uDBSetProvider, uConnectParamsProvider, uFileVersion, strConst,
  uMultiThreadVars;

{$R *.DFM}

var
  IsDebug: Boolean = False;

procedure ServiceController(CtrlCode: DWord); stdcall;
begin
  srvTCP_3C.Controller(CtrlCode);
end;

function TsrvTCP_3C.GetServiceController: TServiceController;
begin
  Result := ServiceController;
end;

procedure TsrvTCP_3C.ServiceStart(Sender: TService; var Started: Boolean);
var
  StopFlag: Boolean;
	params: TDBConnectParams;
  provider: TDBSetProvider;
begin
	LogInfo('The service version is ', ReadVersion);
  FullLog := IniLogOn;
  LogInfo('Attempt to start the service...');

  if not FServer.WSAError then
  begin
  	//FServer.FreeOnTerminate := True;
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
  end
  else
  begin
  	Started := False;
    ServiceStop(Self, StopFlag);
    //FServer.Free;
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

procedure TsrvTCP_3C.ServiceStop(Sender: TService; var Stopped: Boolean);
begin
  FServer.Terminate;
  Stopped := True;
  LogWarning('ServiceStop');
end;

procedure TsrvTCP_3C.ServiceContinue(Sender: TService;
  var Continued: Boolean);
begin
  LogWarning('ServiceContinue');
  FServer.Resume;
  Continued := True;
end;

procedure TsrvTCP_3C.ServicePause(Sender: TService; var Paused: Boolean);
begin
  LogWarning('ServicePause');
  FServer.Suspend;
  Paused := True;
end;

procedure TsrvTCP_3C.ServiceShutdown(Sender: TService);
var
  StopFlag: Boolean;
begin
  ServiceStop(Sender, StopFlag);
  LogWarning('ServiceShutdown');
end;

procedure TsrvTCP_3C.ServiceCreate(Sender: TObject);
begin
	FServer := TServerThread_3C.Create(IniPort);
end;

procedure TsrvTCP_3C.ServiceDestroy(Sender: TObject);
begin
  FServer.Free;
  LogWarning('ServiceDestroy (' + IntToStr(ClientCounter) + ' clients)');
end;

end.
