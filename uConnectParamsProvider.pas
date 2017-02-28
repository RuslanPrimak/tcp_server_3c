unit uConnectParamsProvider;

interface

uses
	uDBSetProvider;

type
	TConParamsProvider = class(TObject)
  public
		class function GetDBParams: TDBConnectParams;
  end;

implementation

uses uServerIni;



{ TConParamsProvider }

class function TConParamsProvider.GetDBParams: TDBConnectParams;
begin
	Result := TDBConnectParams.Create;
  Result.DBPath := IniDBPath;
  Result.login := IniDBUser;
  Result.pass := IniDBPass;
  Result.role := IniDBRole;
end;

end.
