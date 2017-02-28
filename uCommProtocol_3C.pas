unit uCommProtocol_3C;

interface

uses
  SysUtils, DateUtils, uInfoData;

Const
  SOH = 'NDA';
  ACK = 'NDA';
  NAK = 'NDA';
  CAN = 'NDA';
  ID_INFO_DATA          = 'NDA';
  ID_GEN_CONF_DATA      = 'NDA';
  ID_GPS_CONF_DATA      = 'NDA';
  ID_GPRS_CONF_DATA     = 'NDA';
  ID_NEW_JOURN_DATA     = 'NDA';
  ID_PERIOD_JOURN_DATA  = 'NDA';
  ID_ALARM_JOURN_DATA   = 'NDA';
  EOS_SINGLE  = 'NDA';
  EOS_FIRST   = 'NDA';
  EOS_MIDDLE  = 'NDA';
  EOS_LAST    = 'NDA';
  EOS_TERM    = 'NDA';
  START_TIME_POINT = 'NDA';

  GPS_FAKE = 'NDA';

type
  TIMEI_STR = String[15];

  PPackHeader = ^TPackHeader;
  TPackHeader = record
    'NDA'
  end;

  TPackData = record
    'NDA'
  end;

  PIMEIHeader = ^TIMEIHeader;
  TIMEIHeader = record
    'NDA'
  end;

  PGenConfData = ^TGenConfData;
  TGenConfData = record
    'NDA'
  end;

  PGPSConfData = ^TGPSConfData;
  TGPSConfData = record
    'NDA'
  end;

  TpGPRSConfData = record
    'NDA'
  end;

  TGPRSConfData = record
    'NDA'
  end;

  TAllConfData = record
    'NDA'
  end;

function CRC_Comm3C(APtr: Pointer; ALen: Integer): Word;
function CRC7(APtr: Pointer; ALen: Integer): Byte;
function ExtractSN(ADataID: Byte; AData: PByte): Word;
function ExractIMEI(AData: PByte): TIMEI_STR;
function ExtractDataFromPack(Pack: PByte; PackLen: Integer;
  var Data: PByte; var DataLen: Integer): Integer;
function DecodeInfoDateTime(IDT: TInfoDateTime): TDateTime;
function DecodeJournDateTime(UTC: Longword): TDateTime;
function DecodeLongitude(Lg: LongWord): Double;
function DecodeLatitude(Lt: LongWord): Double;
function DecodeAltitude(Alt: LongWord): Double;
function DecodeSpeed(Spd: Word): Double;
function DecodeCourse(Crs: Word): Double;
function DecodeIP(IP: LongWord): String;
function EOS_OfPack(AData: PByte): Byte;

implementation

function ExractIMEI(AData: PByte): TIMEI_STR;
var
  HLWord, LLWord: LongWord;
begin
  'NDA'
end;

function ExtractSN(ADataID: Byte; AData: PByte): Word;
begin
  'NDA'
end;

function CRC_Comm3C(APtr: Pointer; ALen: Integer): Word;
var
  i, j: Integer;
begin
  'NDA'
end;

function CRC7(APtr: Pointer; ALen: Integer): Byte;
var
  tCRC: Byte;
  i: Integer;
begin
  'NDA'
end;

function ExtractDataFromPack(Pack: PByte; PackLen: Integer;
  var Data: PByte; var DataLen: Integer): Integer;
var
  Header: PPackHeader;
  DataCRC: PWord;
  TempCRC: Word;
begin
  'NDA'
end;

function DecodeInfoDateTime(IDT: TInfoDateTime): TDateTime;
var
  FullYear: Word;
begin
  'NDA'
end;

function DecodeJournDateTime(UTC: Longword): TDateTime;
begin
  'NDA'
end;

function DecodeLongitude(Lg: LongWord): Double;
begin
  'NDA'
end;

function DecodeLatitude(Lt: LongWord): Double;
begin
  'NDA'
end;

function DecodeAltitude(Alt: LongWord): Double;
begin
  'NDA'
end;

function DecodeSpeed(Spd: Word): Double;
begin
  'NDA'
end;

function DecodeCourse(Crs: Word): Double;
begin
  'NDA'
end;

function DecodeIP(IP: LongWord): String;
var
  p: PByte;
  tmpStr: String;
begin
  'NDA'
end;

function EOS_OfPack(AData: PByte): Byte;
begin
  'NDA'
end;


end.
