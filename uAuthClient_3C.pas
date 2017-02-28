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
    ProtVer := Data^; //������ ���������

    // ����������� ������
    InBuf := PAESBuffer(Integer(Data) + 1);
    ExpandAESKeyForDecryption(AESKey, AESExpKey);
    DecryptAES(InBuf^, AESExpKey, OutBuf);

    // �������� IMEI ��� ����������� �� IMEI
    StrIMEI := ExractIMEI(@OutBuf[0]);

    // �������� SN ��� ����������� �� SN
    SN := ExtractSN(ProtVer, @OutBuf[0]);

    v.SN := SN;

    Result := SN > 0;
  end;
end;

end.
