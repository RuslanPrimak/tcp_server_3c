unit SimpleServerThread;

interface

uses
	Classes, Windows, WinSock;

var
	WSAData: TWSAData;

type
	TSimpleServerThread = class(TThread)
	private
  	FWSAError: Boolean;
		FServerSocket: TSocket;
    FOnExecute: TNotifyEvent;
    FOnDestroy: TNotifyEvent;
    procedure SetOnExecute(const Value: TNotifyEvent);
    procedure SetOnDestroy(const Value: TNotifyEvent);
	protected
		procedure Execute; override;
    procedure NewClientThread(ASocket: TSocket; AAddr: TSockAddr); dynamic;
	public
		constructor Create(Port: Integer);
		destructor Destroy; override;
    property OnExecute: TNotifyEvent read FOnExecute write SetOnExecute;
    property OnDestroy: TNotifyEvent read FOnDestroy write SetOnDestroy;
    property WSAError: Boolean read FWSAError;
	end;

implementation

uses
	SimpleClientThread, LogFileUnit, SysUtils, uClientControl, uLogWSA,
  uFileVersion, uMultiThreadVars;

procedure InitWSA;
var
	WSARes: Integer;
begin
	//WSARes := WSAStartup(MAKEWORD(2,2), WSAData);
  WSARes := WSAStartup($0101, WSAData);
	if WSARes <> NO_ERROR then
    LogError('WSA', 'WSA Startup Error!');
end;

procedure EndWSA;
begin
	WSACleanup;
end;

{ TSimpleServerThread }

constructor TSimpleServerThread.Create(Port: Integer);
var
	intTrue: Integer;
  intFalse: Integer;
  //OptVal: DWORD;
	addr: TSockAddr;
begin
	FWSAError := False;
  ClientCounter := 0;
	inherited Create(True);

	//FreeOnTerminate := True;
	intTrue := 1;
  intFalse := 0;
	LogInfo('ServerThread', '//******************************');

	{
		Create server socket}
	FServerSocket := socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
	if FServerSocket = INVALID_SOCKET then
	begin
  	FWSAError := True;
		LogWSAError;
    Terminate;
		exit;
	end;

	// Ќельз€ использовать адрес, который уже зан€т
  {
		Disable reuse address}
	if setsockopt(FServerSocket, SOL_SOCKET, SO_REUSEADDR, PChar(@intFalse),
		SizeOf(intFalse)) <> NO_ERROR then
  (*OptVal := 1;
  if setsockopt(FServerSocket, SOL_SOCKET, SO_REUSEADDR, PAnsiChar(@OptVal),
  	SizeOf(OptVal)) <> NO_ERROR then*)
	begin
  	FWSAError := True;
		LogWSAError;//
    Terminate;
		exit;
	end;

	{
		Set in nonblocking mode}
	if ioctlsocket(FServerSocket, FIONBIO, intTrue) <> NO_ERROR then
	begin
  	FWSAError := True;
		LogWSAError;//WriteLog('Server socket nonblocking error!');
    Terminate;
		exit;
	end;

	{
		Bind socket to interface}
	addr.sin_family := AF_INET;
	addr.sin_addr.s_addr := htonl(INADDR_ANY);
	addr.sin_port := htons(Port);
	if bind(FServerSocket, addr, sizeof(addr)) = SOCKET_ERROR then
	begin
  	FWSAError := True;
		LogWSAError;//WriteLog('Server socket binding error!');
    Terminate;
		exit;
	end;

	{
		Start listener}
	//if listen(FServerSocket, 1) = SOCKET_ERROR then
  if listen(FServerSocket, SOMAXCONN) = SOCKET_ERROR then
	begin
  	FWSAError := True;
		LogWSAError;//WriteLog('Server socket listen error!');
    Terminate;
    exit;
	end;
end;

destructor TSimpleServerThread.Destroy;
begin
  evStopAllTCPThrds.SetEvent;
  while ClientCounter > 0 do ;

  closesocket(FServerSocket);
  if Assigned(FOnDestroy) then FOnDestroy(Self);
	inherited;
end;

procedure TSimpleServerThread.Execute;
var
	ClientSocket: TSocket;
	addr: TSockAddr;
	len: Integer;
	WSAErr: Integer;
begin
	if not FWSAError then
  begin
  	if Assigned(FOnExecute) then FOnExecute(Self);
    len := sizeof(addr);
    Fillchar(addr, sizeof(addr), 0);
    while not Terminated do
    begin
      ClientSocket := accept(FServerSocket, @addr, @len);
      if ClientSocket = INVALID_SOCKET then
      begin
        WSAErr := WSAGetLastError;
        if WSAErr <> WSAEWOULDBLOCK then
        begin
          if WSAErr = WSAEINTR then
            LogError('WSA', 'Interrupted function call')
          else
            LogError('WSA', 'Client socket accept WSA error: ' + IntToStr(WSAErr));
        end;
        Sleep(1);
      end
      else
      begin
        LogInfo('NEW', inet_ntoa(addr.sin_addr) + ':' + IntToStr(ntohs(addr.sin_port)));
        NewClientThread(ClientSocket, addr);
      end;
    end;
  end;
  LogInfo('Server finished', '******************************//');
end;

procedure TSimpleServerThread.SetOnExecute(const Value: TNotifyEvent);
begin
  FOnExecute := Value;
end;

procedure TSimpleServerThread.SetOnDestroy(const Value: TNotifyEvent);
begin
  FOnDestroy := Value;
end;

procedure TSimpleServerThread.NewClientThread(ASocket: TSocket;
	AAddr: TSockAddr);
begin
  TSimpleClientThread.Create(ASocket, AAddr);
end;

initialization
	InitWSA;

finalization
	EndWSA;

end.
