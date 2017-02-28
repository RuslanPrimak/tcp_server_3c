program TCPServer3C;

uses
  Forms,
{$ifndef DEBUG}
  SvcMgr,
{$endif}
  u_3C_TCP_Server in 'u_3C_TCP_Server.pas' {srvTCP_3C: TService},
  uCommProtocol_3C in 'uCommProtocol_3C.pas',
  uInfoData in 'uInfoData.pas',
  uVehicles3C in 'uVehicles3C.pas',
  u_SQLs in 'u_SQLs.pas',
  uJournalSpec in 'uJournalSpec.pas',
  SimpleServerThread in 'SimpleServerThread.pas',
  SimpleClientThread in 'SimpleClientThread.pas',
  StrConvUnit in '..\3C\StrConvUnit.pas',
  uClientControl in 'uClientControl.pas',
  uLogWSA in 'uLogWSA.pas',
  uFileVersion in 'uFileVersion.pas',
  uServerThread_3C in 'uServerThread_3C.pas',
  uClientThread_3C in 'uClientThread_3C.pas',
  u3SSensors in '..\3C\u3SSensors.pas',
  uAuthClient_3C in 'uAuthClient_3C.pas',
  ElAES in '..\3C\ElAES.pas',
  uServerIni in 'uServerIni.pas',
  LogFileUnit in '..\LogFiles\LogFileUnit.pas',
  frmDebugUnit in 'frmDebugUnit.pas' {frmDebug},
  u_ByteOrders in '..\Units\u_ByteOrders.pas',
  uDBSetProvider in 'uDBSetProvider.pas',
  u_IB_DBWriter in 'u_IB_DBWriter.pas',
  uDBSetProviderPool in 'uDBSetProviderPool.pas',
  uConnectParamsProvider in 'uConnectParamsProvider.pas',
  strConst in 'strConst.pas',
  u_IBInfoDataWriter in 'u_IBInfoDataWriter.pas',
  uStateRec in 'uStateRec.pas',
  u_IBConfDataWriter in 'u_IBConfDataWriter.pas',
  u_IBJournDataWriter in 'u_IBJournDataWriter.pas',
  u_ThreadEnvelope in 'u_ThreadEnvelope.pas',
  uMultiThreadVars in 'uMultiThreadVars.pas';

{$R *.RES}

begin
  Application.Initialize;
{$ifndef DEBUG}
  Application.CreateForm(TsrvTCP_3C, srvTCP_3C);
  {$else}
  Application.CreateForm(TfrmDebug, frmDebug);
{$endif}
  Application.Run;
end.
