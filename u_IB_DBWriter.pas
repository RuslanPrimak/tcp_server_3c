unit u_IB_DBWriter;

interface

uses
  uVehicles3C, IBDatabase, IBSQL;

type
  TIB_DBWriter = class
    qrWrite: TIBSQL;
    trWrite: TIBTransaction;
    qrGen: TIBSQL;
    trGen: TIBTransaction;
    FVID: TVehIdent;
  private
    procedure SetVID(const Value: TVehIdent);
    { Private declarations }
  protected
  	function Gen_Id(const GeneratorName: string; Step: Int64): Int64;
  public
    constructor Create(DB: TIBDatabase); overload;
    destructor Destroy; override;
    procedure ExecQuery(strQuery: String; Commit: Boolean = True);
    procedure StartWork;
    procedure CommitWork;
    procedure RollbackWork;
    property VID: TVehIdent read FVID write SetVID;
  end;

implementation

{ TIB_DBWriter }

procedure TIB_DBWriter.CommitWork;
begin
  if trWrite.InTransaction
  	then trWrite.Commit;
end;

constructor TIB_DBWriter.Create(DB: TIBDatabase);
begin
  inherited Create;
  trWrite := TIBTransaction.Create(nil);
  trWrite.DefaultDatabase := DB;
  trWrite.Params.Add('write');
  trWrite.Params.Add('read_committed');
  trWrite.Params.Add('rec_version');
  trWrite.Params.Add('nowait');
  trWrite.AllowAutoStart := True;
  trWrite.DefaultAction := TACommit;

  qrWrite := TIBSQL.Create(nil);
  qrWrite.Database := DB;
  qrWrite.Transaction := trWrite;

  trGen := TIBTransaction.Create(nil);
  trGen.DefaultDatabase := DB;
  trGen.Params.Add('write');
  trGen.Params.Add('read_committed');
  trGen.Params.Add('rec_version');
  trGen.Params.Add('nowait');
  trGen.AllowAutoStart := True;
  trGen.DefaultAction := TACommit;

  qrGen := TIBSQL.Create(nil);
  qrGen.Database := DB;
  qrGen.Transaction := trGen;
  qrGen.SQL.Text := 'select gen_id(:GenName, :Step) from RDB$DATABASE';
end;

destructor TIB_DBWriter.Destroy;
begin
	qrGen.Free;
  if trGen.InTransaction then
  	trGen.Rollback;
  trGen.Free;

  qrWrite.Free;
  if trWrite.InTransaction then
  	trWrite.Rollback;
  trWrite.Free;
  inherited;
end;

procedure TIB_DBWriter.ExecQuery(strQuery: String; Commit: Boolean);
begin
	if not qrWrite.Transaction.InTransaction then
    qrWrite.Transaction.StartTransaction;

  qrWrite.Close;
  qrWrite.SQL.Text := strQuery;
  qrWrite.ExecQuery;

  if Commit then
    qrWrite.Transaction.Commit;
end;

function TIB_DBWriter.Gen_Id(const GeneratorName: string;
  Step: Int64): Int64;
begin
	if not trGen.InTransaction then
  	trGen.StartTransaction;

	qrGen.Close;
  qrGen.ParamByName('GenName').AsString := GeneratorName;
  qrGen.ParamByName('Step').AsInt64 := Step;

  try
  	qrGen.ExecQuery;
    Result := qrGen.Fields[0].AsInt64;
    if trGen.InTransaction then
    	trGen.Commit;
  finally
		if trGen.InTransaction then
    	trGen.Rollback;
  end;
end;

procedure TIB_DBWriter.RollbackWork;
begin
  if trWrite.InTransaction then
  	trWrite.Rollback;
end;

procedure TIB_DBWriter.SetVID(const Value: TVehIdent);
begin
  FVID.ID := Value.ID;
  FVID.SN := Value.SN;
  FVID.Phone := Value.Phone;
end;

procedure TIB_DBWriter.StartWork;
begin
	if not trWrite.InTransaction then
  	trWrite.StartTransaction;
end;

end.
