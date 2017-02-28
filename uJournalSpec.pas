unit uJournalSpec;

interface

uses
  Classes;

Const
  //Типы записей журнала
	ABS_TIME_FIX_JOURN = 'NDA';
	GPS_POSITION_JOURN = 'NDA';
	STATE_JOURN = 'NDA';
	EVENT_JOURN = 'NDA';
	GPS_POSITION_JOURN_INVALID = 'NDA';
  EXTERNAL_SENS_DATA_JOURN = 'NDA';
  SENSORS_DATA_JOURN = 'NDA';

  JRN_REC_SIZE = 'NDA';

  SN_RECTYPE_CHANGE = 'NDA';

type
  PJrnPacket = ^TJrnPacket;
  TJrnPacket = record
    'NDA'
  end;

  PGPSJrn = ^TGPSJrn;
  TGPSJrn = record
    'NDA'
  end;

  PStateJrn = ^TStateJrn;
  TStateJrn = record
    'NDA'
  end;

  PEventJrn = ^TEventJrn;
  TEventJrn = record
    'NDA'
  end;

  PSensJrn = ^TSensJrn;
  TSensJrn = record
    'NDA'
  end;

  PExtSensJrn = ^TExtSensJrn;
  TExtSensJrn = record
    'NDA'
  end;

  TExtGPSJrn = record
    'NDA'
  end;

  PSessionData = ^TSessionData;
  TSessionData = record
    'NDA'
  end;

  TJrnSession = class(TList)
  private
    FSessionType: Integer;
    procedure SetSessionType(const Value: Integer);
  protected
		function Get(Index: Integer): PSessionData;
		procedure Put(Index: Integer; const Value: PSessionData);
		procedure Notify(Ptr: Pointer; Action: TListNotification); override;
	public
		property Items[Index: Integer]: PSessionData read Get write Put; default;
		function Add(SrcPtr: Pointer; Records: Integer): Integer; overload;
    property SessionType: Integer read FSessionType write SetSessionType;
	end;

  function GetRecordFromData(Data: Pointer; Idx: Integer): PByte;
  function IDUndefRec(UndefRec: PByte): Byte;
  function Lg_GPSJrn(Rec: PGPSJrn): Longword;
  function Lt_GPSJrn(Rec: PGPSJrn): Longword;
  function Alt_GPSJrn(Rec: PGPSJrn): Longword;
  function Speed_GPSJrn(Rec: PGPSJrn): Word;
  function Course_GPSJrn(Rec: PGPSJrn): Word;

implementation

uses
  u_ByteOrders;

function Speed_GPSJrn(Rec: PGPSJrn): Word;
begin
  Result := 'NDA';
end;

function Course_GPSJrn(Rec: PGPSJrn): Word;
begin
  Result := 'NDA';
end;

function Lg_GPSJrn(Rec: PGPSJrn): Longword;
begin
  Result := 'NDA';
end;

function Lt_GPSJrn(Rec: PGPSJrn): Longword;
begin
  Result := 'NDA';
end;

function Alt_GPSJrn(Rec: PGPSJrn): Longword;
begin
  Result := 'NDA';
end;

function IDUndefRec(UndefRec: PByte): Byte;
begin
  Result := 'NDA';
end;

function GetRecordFromData(Data: Pointer; Idx: Integer): PByte;
begin
  Result := 'NDA';
end;

{ TJrnSession }

function TJrnSession.Add(SrcPtr: Pointer; Records: Integer): Integer;
var
  ptr: PSessionData;
  DataSize: Integer;
begin
  New(ptr);
  ptr.Records := Records;
  DataSize := ptr.Records*JRN_REC_SIZE;
  GetMem(ptr.Data, DataSize);
  System.Move(SrcPtr^, ptr.Data^, DataSize);
	Result := inherited Add(ptr);
end;

function TJrnSession.Get(Index: Integer): PSessionData;
begin
  Result := PSessionData(inherited Get(Index));
end;

procedure TJrnSession.Notify(Ptr: Pointer; Action: TListNotification);
begin
  inherited;
  if Action = lnDeleted then
	begin
    FreeMem(PSessionData(Ptr).Data);
		Dispose(Ptr);
	end;
end;

procedure TJrnSession.Put(Index: Integer; const Value: PSessionData);
begin
  inherited Put(Index, Value);
end;

procedure TJrnSession.SetSessionType(const Value: Integer);
begin
  FSessionType := Value;
end;

end.
