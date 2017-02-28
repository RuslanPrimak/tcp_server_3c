unit uServerThread_3C;

interface

uses
  WinSock, SimpleServerThread;

type
	TServerThread_3C = class(TSimpleServerThread)
	private
	protected
    procedure NewClientThread(ASocket: TSocket; AAddr: TSockAddr); override;
	public
	end;

implementation

uses
	uClientThread_3C, u_ThreadEnvelope;

{ TServerThread_3C }

procedure TServerThread_3C.NewClientThread(ASocket: TSocket;
  AAddr: TSockAddr);
var
	ct: TClientThread_3C;
begin
  ct := TClientThread_3C.Create(ASocket, AAddr);
  ct.TestEvent := TThreadEnvelope.EnvelopeTest1;
end;

end.
