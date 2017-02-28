unit uClientControl;

interface

uses
  SyncObjs;

var
  evStopAllTCPThrds: TEvent;

implementation

initialization
  evStopAllTCPThrds := TEvent.Create(nil, True, False, 'StopAllTCPThrds_3C');

finalization
  evStopAllTCPThrds.Free;

end.
