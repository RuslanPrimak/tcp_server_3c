unit uDBSetProvider;

{
  Модуль содержит класс провайдера, который содержит набор компонентов для
  работы с базой банных клиенского потока.}

interface

uses
	IBDatabase, SysUtils, IBSQL, u_IBInfoDataWriter, uVehicles3C,
  u_IBConfDataWriter, u_IBJournDataWriter;

type
	TDBConnectParams = class(TObject)
  private
    FDBPath: String;
    Fpass: String;
    Flogin: String;
    Frole: String;
    procedure SetDBPath(const Value: String);
    procedure Setlogin(const Value: String);
    procedure Setpass(const Value: String);
    procedure Setrole(const Value: String);
  public
  	property DBPath: String read FDBPath write SetDBPath;
    property login: String read Flogin write Setlogin;
    property pass: String read Fpass write Setpass;
    property role: String read Frole write Setrole;
  end;

	TDBSetProvider = class(TObject)
  private
    FDatabase: TIBDatabase;
    FTransaction: TIBTransaction;
    FSQL: TIBSQL;
    FGenerator: TIBSQL;
    FInfoWriter: TIBInfoDataWriter;
    FConfWriter: TIBConfDataWriter;
		FJournWriter: TIBJournDataWriter;
    function GetActive: Boolean;
  public
  	constructor Create;
    destructor Destroy; override;
    property Active: Boolean read GetActive;
    function Connect(params: TDBConnectParams): Boolean;
    procedure Disconnect;
    property ibSQL: TIBSQL read FSQL;
    function WriteInfoData(AData: PByte; vid: TVehIdent): Boolean;
    function WriteConfData(AData: PByte; vid: TVehIdent): Boolean;
    function WriteJournData(AData: PByte; vid: TVehIdent): Boolean;
    function Gen_Id(const GeneratorName: string; Step: Int64): Int64;
	end;

implementation

uses LogFileUnit;

{ TDBSetProvider }

function TDBSetProvider.Connect(params: TDBConnectParams): Boolean;
begin
	FDatabase.DatabaseName := params.DBPath;
  FDatabase.Params.Clear;
  FDatabase.Params.Add('user_name=' + params.login);
  FDatabase.Params.Add('password=' + params.pass);
  if (params.role <> '') then
		FDatabase.Params.Add('sql_role_name=' + params.role);
  try
  	FDatabase.Connected := True;
  except
    on E: Exception do
    	LogError('Exception', E.Message);
  end;
  Result := FDatabase.Connected;
  FJournWriter.ResetState;
end;

constructor TDBSetProvider.Create;
begin
	FDatabase := TIBDatabase.Create(nil);
  FTransaction := TIBTransaction.Create(nil);
  FSQL := TIBSQL.Create(nil);
  FGenerator := TIBSQL.Create(nil);

  FDatabase.LoginPrompt := False;
  FDatabase.SQLDialect := 3;
  FDatabase.DefaultTransaction := FTransaction;

  FTransaction.DefaultDatabase := FDatabase;
  FTransaction.Params.Add('write');
  FTransaction.Params.Add('read_committed');
  FTransaction.Params.Add('rec_version');
  FTransaction.Params.Add('nowait');
  FTransaction.AllowAutoStart := True;
  FTransaction.DefaultAction := TACommit;

  FSQL.Database := FDatabase;
  FSQL.Transaction := FTransaction;

  FGenerator.Database := FDatabase;
  FGenerator.Transaction := FTransaction;
  FGenerator.SQL.Text := 'select gen_id(:GenName, :Step) from RDB$DATABASE';

  FInfoWriter := TIBInfoDataWriter.Create(FDatabase);
  FConfWriter := TIBConfDataWriter.Create(FDatabase);
  FJournWriter := TIBJournDataWriter.Create(FDatabase);
end;

destructor TDBSetProvider.Destroy;
begin
  FJournWriter.Free;
  FConfWriter.Free;
  FInfoWriter.Free;
  FGenerator.Free;
  FSQL.Free;
  Disconnect;
	FTransaction.Free;
  FDatabase.Free;
  inherited;
end;

procedure TDBSetProvider.Disconnect;
begin
	try
    if FTransaction.InTransaction then
    	FTransaction.Commit;
  finally
  	if FTransaction.InTransaction then
    	FTransaction.Rollback;
  end;
	FDatabase.Connected := False;
end;

function TDBSetProvider.Gen_Id(const GeneratorName: string; Step: Int64): Int64;
begin
	if not FTransaction.InTransaction then
  	FTransaction.StartTransaction;
    
	FGenerator.Close;
  FGenerator.ParamByName('GenName').AsString := GeneratorName;
  FGenerator.ParamByName('Step').AsInt64 := Step;

  try
  	FGenerator.ExecQuery;
    Result := FGenerator.Fields[0].AsInt64;
    if FTransaction.InTransaction then
    	FTransaction.Commit;
  finally
		if FTransaction.InTransaction then
    	FTransaction.Rollback;
  end;
end;

function TDBSetProvider.GetActive: Boolean;
begin
	Result := FDatabase.Connected;
end;

function TDBSetProvider.WriteConfData(AData: PByte;
  vid: TVehIdent): Boolean;
begin
  FConfWriter.VID := vid;
  Result := FConfWriter.WriteData(AData);
end;

function TDBSetProvider.WriteInfoData(AData: PByte;
  vid: TVehIdent): Boolean;
begin
  FInfoWriter.VID := vid;
  Result := FInfoWriter.WriteData(AData);
end;

function TDBSetProvider.WriteJournData(AData: PByte;
  vid: TVehIdent): Boolean;
begin
	Result := FJournWriter.WriteData(AData, vid);
end;

{ TDBConnectParams }

procedure TDBConnectParams.SetDBPath(const Value: String);
begin
  FDBPath := Value;
end;

procedure TDBConnectParams.Setlogin(const Value: String);
begin
  Flogin := Value;
end;

procedure TDBConnectParams.Setpass(const Value: String);
begin
  Fpass := Value;
end;

procedure TDBConnectParams.Setrole(const Value: String);
begin
  Frole := Value;
end;

end.
