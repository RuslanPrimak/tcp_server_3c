unit SimpleClientThread;

interface

uses
	Classes, Windows, WinSock, SyncObjs;

Const
	fd_read_bit                     = 0;
  fd_write_bit                    = 1;
  fd_oob_bit                      = 2;
  fd_accept_bit                   = 3;
  fd_connect_bit                  = 4;
	fd_close_bit                    = 5;
  fd_qos_bit                      = 6;
  fd_group_qos_bit                = 7;
  fd_routing_interface_change_bit = 8;
	fd_address_list_change_bit      = 9;

	fd_max_events    = 10;

type
  TRecvBuff = array of Char;

	{
		TSimpleClientThread - поток клиентского сокета}
	TSimpleClientThread = class(TThread)
	private
		FWSAEvents: THandle;
		FRemoteHost: String;
		FRemotePort: Integer;
		FStrThreadID: String;
		FStrHostPort: String;
	protected
    FSocket: TSocket;
		procedure Execute; override;
		procedure SyncNothing;
    function ProcessIncomingData(Data: PByte; Len: Integer): Boolean; virtual;
    function SendBuf(var Buf; ALen: Integer): Boolean;
    procedure ExecuteEx; virtual;
    procedure LogSelf(s: String);
    procedure PreExecute(var ExecuteEnable: Boolean); virtual;
    function GetSelfID: String;
	public
		constructor Create(ClientSocket: TSocket; addr: TSockAddr); dynamic;
		destructor Destroy; override;
	end;

	{
		Объявления WinAPI типов и структур WinSock2}
	TTCP_KeepAlive = record
		onoff: ULONG;
		keepalivetime: ULONG;
		keepaliveinterval: ULONG;
	end;

	wsaevent = THandle;
	Pwsaevent = ^wsaevent;
	wsaoverlapped   = TOverlapped;
	TWSAOverlapped  = WSAOverlapped;
	PWSAOverlapped  = ^WSAOverlapped;
	LPwsaoverlapped = PWSAOverlapped;

	LPwsaoverlapped_COMPLETION_ROUTINE =
		procedure (const dwError, cbTransferred: DWORD; const lpOverlapped: LPwsaoverlapped;
			const dwFlags: DWORD); stdcall;

	TWSANetworkEvents = record
    lNetworkEvents: LongInt;
		iErrorCode: Array[0..fd_max_eventS-1] of Integer;
  end;
  PWSANetworkEvents = ^TWSANetworkEvents;
  LPWSANetworkEvents = PWSANetworkEvents;

	{
		Экспортируемые функции}
var
	hWinSock2: THandle;
	WSACreateEvent: function: THandle stdcall;
	WSAResetEvent: function (hEvent: THandle): Boolean stdcall;
	WSACloseEvent: function (hEvent: THandle): Boolean stdcall;
	WSAEventSelect: function (s: TSocket; hEventObject: THandle; lNetworkEvents: Integer): Integer stdcall;
	WSAIoctl: function (const s: TSocket; dwIoControlCode: DWORD; lpvInBuffer: Pointer;
		cbInBuffer: DWORD; lpvOutBuffer: Pointer; cbOutBuffer: DWORD;
		lpcbBytesReturned: LPDWORD; lpOverlapped: LPwsaoverlapped;
		lpCompletionRoutine: LPwsaoverlapped_COMPLETION_ROUTINE): Integer; stdcall;
	WSAWaitForMultipleEvents: function (cEvents: DWORD; lphEvents: Pwsaevent;
		fWaitAll: LongBool; dwTimeout: DWORD; fAlertable: LongBool): DWORD; stdcall;
	WSAEnumNetworkEvents: function (const s: TSocket; const hEventObject: wsaevent;
		lpNetworkEvents: LPWSANETWORKEVENTS): Integer; stdcall;

	function LoadWinSock2: Boolean;

Const
	SIO_KEEPALIVE_VALS = $80000000 or $18000000 or 4;

	wsa_wait_event_0        = wait_object_0;
	wsa_invalid_handle      = error_invalid_handle;
  wsa_invalid_parameter   = error_invalid_parameter;
	wsa_not_enough_memory   = error_not_enough_memory;
	wsa_wait_io_completion  = wait_io_completion;
  wsa_wait_timeout        = wait_timeout;

implementation

uses
	SysUtils, LogFileUnit, StrConvUnit, uClientControl, uServerIni,
  uMultiThreadVars;

procedure FreeWinSock2;
begin
	if hWinSock2 > 0 then
	begin
		WSACreateEvent := nil;
		WSAResetEvent := nil;
		WSACloseEvent := nil;
		WSAEventSelect := nil;
		WSAIoctl := nil;
		WSAWaitForMultipleEvents := nil;
		WSAEnumNetworkEvents := nil;
		FreeLibrary(hWinSock2);
	end;
	hWinSock2 := 0;
end;

function LoadWinSock2: Boolean;
const
  DLLName = 'ws2_32.dll';
begin
  Result := hWinSock2 > 0;
  if Result then Exit;
	hWinSock2 := LoadLibrary(PChar(DLLName));
  Result := hWinSock2 > 0;
  if Result then
  begin
    WSACreateEvent := GetProcAddress(hWinSock2, 'WSACreateEvent');
		WSAResetEvent := GetProcAddress(hWinSock2, 'WSAResetEvent');
		WSACloseEvent := GetProcAddress(hWinSock2, 'WSACloseEvent');
		WSAEventSelect := GetProcAddress(hWinSock2, 'WSAEventSelect');
		WSAIoctl := GetProcAddress(hWinSock2, 'WSAIoctl');
		WSAWaitForMultipleEvents := GetProcAddress(hWinSock2, 'WSAWaitForMultipleEvents');
		WSAEnumNetworkEvents := GetProcAddress(hWinSock2, 'WSAEnumNetworkEvents');
  end;
end;

procedure InitClientParams;
begin

end;

procedure DeinitClientParams;
begin
	FreeWinSock2;
end;

{ TSimpleClientThread }

constructor TSimpleClientThread.Create(ClientSocket: TSocket; addr: TSockAddr);
var
  intTrue: Byte;
  alive: TTCP_KeepAlive;
  dwRet, dwSize: Dword;
begin
  Inc(ClientCounter);
	{
		Запоминаем хендл сокета}
	FSocket := ClientSocket;
	FRemoteHost := inet_ntoa(addr.sin_addr);
	FRemotePort := ntohs(addr.sin_port);
	FStrHostPort := FRemoteHost + ':' + IntToStr(FRemotePort);

	FWSAEvents := 0;
	inherited Create(True);
	FreeOnTerminate := True;

	FStrThreadID := IntToStr(ThreadID);

	//WriteLog('ThreadID: ' + FStrThreadID + '-' + FStrHostPort);

	{
		Событие для получения сведений о разрыве подключения}
	if not LoadWinSock2 then
	begin
		LogSelf('LoadWinSock2 failed');
		Terminate;
	end
	else
	begin
		FWSAEvents := WSACreateEvent;

		WSAEventSelect(FSocket, FWSAEvents, FD_READ or FD_CLOSE);
		{
			Для сокета устанавливаем параметр TimeAlive}
		{
			Этот код (TimeAlive) необходимо дополнительно тестировать,
			что-бы удостовериться в его работоспособности на 100%.
			Его применение возможно только в комбинации с отслеживанием события FD_CLOSE}
		intTrue := 1;
		if setsockopt(FSocket, SOL_SOCKET, SO_KEEPALIVE, PChar(@intTrue),
			SizeOf(intTrue)) <> NO_ERROR then
		begin
      LogSelf('keepalive error');
			Terminate;
		end
		else
		begin
			alive.onoff := 1;
			alive.keepalivetime := 600000;
			alive.keepaliveinterval := 10000;
			dwRet := WSAIoctl(FSocket, SIO_KEEPALIVE_VALS, @alive, sizeof(alive),
				nil, 0, @dwSize, nil, nil);
			if dwRet <> 0 then
			begin
        LogSelf('keepalive time error');
				Terminate;
			end;
		end;
	end;

  Resume;
end;

destructor TSimpleClientThread.Destroy;
begin
  Dec(ClientCounter);
	{
		Закрываем сокет при уничтожении потока, т.к. сокет уже существует на момент
		создания потока, поток сервера не заботится о закрытии клиентских сокетов,-
		только потоков. А до Execute может дело и не дойти}
	closesocket(FSocket);
  LogSelf('Destroyed');

	if FWSAEvents <> 0 then
		WSACloseEvent(FWSAEvents);
	FWSAEvents := 0;

	inherited;
end;

procedure TSimpleClientThread.Execute;
var
	EventsRes: DWORD;
	NetEvents: TWSANetworkEvents;
	RecBuf: PByte;
	RecCntr: Integer;
  bytes_in_buffer: integer;
  LogStr: String;
  check: Boolean;
begin
	check := False;
  PreExecute(check);
  if (check) then
  begin
  	while not Terminated do
    begin
      if evStopAllTCPThrds.WaitFor(0) = wrSignaled then
      begin
        LogSelf('SrvTerm');
        Terminate;
        exit;
      end;

      ExecuteEx;

      {
        Ожидание событий по приему и разрыву сокета}
      EventsRes := WSAWaitForMultipleEvents(1, @FWSAEvents, False, 10, False);

      case EventsRes of
        WSA_WAIT_EVENT_0:
          begin
            {
              При возникновении какого либо из событий - необходимо определить какое}
            EventsRes := WSAEnumNetworkEvents(FSocket, FWSAEvents, @NetEvents);
            if EventsRes = NO_ERROR then
            begin
              {
                Обеспечение приема данных}
              if (NetEvents.lNetworkEvents and FD_READ) = FD_READ then
              begin
                // Определение количества байт во входном буфере
                if (ioctlsocket(FSocket, FIONREAD, bytes_in_buffer) <> SOCKET_ERROR) and
                  (bytes_in_buffer > 0) then
                begin
                  GetMem(RecBuf, bytes_in_buffer);
                  try
                    RecCntr := recv(FSocket, RecBuf^, bytes_in_buffer, 0);
                    LogStr := 'recv ' + IntToStr(RecCntr) + ' B';
                    if IniLogRecv then
                      LogStr := LogStr + ' = "' + BufToHexStr(RecBuf^, RecCntr) + '"';
                    LogSelf(LogStr);
                    if not ProcessIncomingData(RecBuf, RecCntr) then
                    begin
                      LogSelf('Process Data Error');
                      Terminate;
                    end;
                  finally
                    FreeMem(RecBuf);
                  end;
                end;
              end;

              {
                 Обработка разрыва соединения}
              if (NetEvents.lNetworkEvents and FD_CLOSE) = FD_CLOSE then
              begin
                case NetEvents.iErrorCode[fd_close_bit] of
                  WSAENETDOWN: LogSelf('disconnected by "The network subsystem has failed"');
                  WSAECONNRESET: LogSelf('disconnected by "The connection was reset by the remote side"');
                  WSAECONNABORTED: LogSelf('disconnected by "The connection was terminated due to a time-out or other failure"');
                else
                  LogSelf('normal disconnection');
                end;
                Terminate;
              end;
            end
            else
            begin
              LogSelf('disconnected by "WSAEnumNetworkEvents error"');
              Terminate;
            end;
          end;
        WSANOTINITIALISED, WSAENETDOWN, WSA_INVALID_HANDLE, WSA_INVALID_PARAMETER,
        WSA_NOT_ENOUGH_MEMORY:
          begin
            LogSelf('disconnected by "WSAWaitForMultipleEvents error"');
            Terminate;
          end;
      end;
    end;
  end;
end;

procedure TSimpleClientThread.ExecuteEx;
begin
  ;
end;

function TSimpleClientThread.GetSelfID: String;
begin
	Result := FStrHostPort;
end;

procedure TSimpleClientThread.LogSelf(s: String);
begin
  //WriteLog(FStrHostPort + ': ' + s);
  LogInfo(FStrHostPort, s);
end;

procedure TSimpleClientThread.PreExecute(var ExecuteEnable: Boolean);
begin
  ExecuteEnable := True;
end;

function TSimpleClientThread.ProcessIncomingData(Data: PByte;
  Len: Integer): Boolean;
begin
	Result := True;
end;

function TSimpleClientThread.SendBuf(var Buf; ALen: Integer): Boolean;
var
  SendBytes: Integer;
begin
  SendBytes := send(FSocket, Buf, ALen, 0);
  Result := SendBytes <> SOCKET_ERROR;

  if not Result then
  begin
    LogSelf('Error' + IntToStr(WSAGetLastError) + ' while sending ' + BufToHexStr(Buf, ALen));
  end;
end;

procedure TSimpleClientThread.SyncNothing;
begin
	;
end;

initialization
	InitClientParams;

finalization
	DeinitClientParams;

end.
