object srvTCP_3C: TsrvTCP_3C
  OldCreateOrder = False
  OnCreate = ServiceCreate
  OnDestroy = ServiceDestroy
  Dependencies = <
    item
      Name = 'FirebirdServerDefaultInstance'
      IsGroup = False
    end>
  DisplayName = '3C TCP Server'
  Interactive = True
  OnContinue = ServiceContinue
  OnPause = ServicePause
  OnShutdown = ServiceShutdown
  OnStart = ServiceStart
  OnStop = ServiceStop
  Left = 329
  Top = 214
  Height = 219
  Width = 380
end
