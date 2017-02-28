unit uAuthClient_3C;

interface

uses
  uCommProtocol_3C, uVehicles3C;

function AuthClient3C(Pack: PByte; Len: Integer; var v: TVehIdent): Boolean;

implementation

uses
  ElAES, Classes;

var
  AESKey: TAESKey128 = ('NDA');

function AuthClient3C(Pack: PByte; Len: Integer; var v: TVehIdent): Boolean;
var
  Data: PByte;
  DataLen: Integer;

  ProtVer: Byte;
  InBuf: PAESBuffer;
  AESExpKey: TAESExpandedKey128;
  OutBuf: TAESBuffer;
  SN: Word;
  StrIMEI: TIMEI_STR;
begin
  Result := False;

  if ExtractDataFromPack(Pack, Len, Data, DataLen) = 0 then
  begin
    ProtVer := Data^; //Версия протокола

    // Расшифровка данных
    InBuf := PAESBuffer(Integer(Data) + 1);
    ExpandAESKeyForDecryption(AESKey, AESExpKey);
    DecryptAES(InBuf^, AESExpKey, OutBuf);

    // Получаем IMEI для авторизации по IMEI
    StrIMEI := ExractIMEI(@OutBuf[0]);

    // Получаем SN для авторизации по SN
    SN := ExtractSN(ProtVer, @OutBuf[0]);

    v.SN := SN;

    Result := SN > 0;
  end;
end;

end.
