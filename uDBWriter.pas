unit uDBWriter;

interface

uses
  pFIBQuery, pFIBDatabase, uVehicles3C, pFIBProps;

type
  TDBWriter = class
    qrWrite: TpFIBQuery;
    trWrite: TpFIBTransaction;
    FVID: TVehIdent;
  private
    procedure SetVID(const Value: TVehIdent);
    { Private declarations }
  public
    constructor Create(DB: TpFIBDatabase); overload;
    destructor Destroy; override;
    procedure ExecQuery(strQuery: String; Commit: Boolean = True);
    procedure CommitWork;
    procedure RollbackWork;
    property VID: TVehIdent read FVID write SetVID;
  end;

implementation

{ TDBWriter }

procedure TDBWriter.CommitWork;
begin
  if trWrite.InTransaction then trWrite.Commit;
end;

constructor TDBWriter.Create(DB: TpFIBDatabase);
begin
  inherited Create;
  trWrite := TpFIBTransaction.Create(nil);
  trWrite.DefaultDatabase := DB;
  trWrite.TPBMode := tpbDefault;
  trWrite.TRParams.Text :=
    'write' + #13#10 +
    'read_committed' + #13#10 +
    'rec_version' + #13#10 +
    'nowait';

  qrWrite := TpFIBQuery.Create(nil);
  qrWrite.Database := DB;
  qrWrite.Transaction := trWrite;
end;

destructor TDBWriter.Destroy;
begin
  qrWrite.Free;
  if trWrite.InTransaction then trWrite.Rollback;
  trWrite.Free;
  inherited;
end;

procedure TDBWriter.ExecQuery(strQuery: String; Commit: Boolean);
begin
  qrWrite.Close;
  if Commit then
    qrWrite.Options := [qoStartTransaction, qoAutoCommit]
  else
    qrWrite.Options := [qoStartTransaction];

  qrWrite.SQL.Text := strQuery;
  qrWrite.ExecQuery;
end;

procedure TDBWriter.RollbackWork;
begin
  if trWrite.InTransaction then trWrite.Rollback;
end;

procedure TDBWriter.SetVID(const Value: TVehIdent);
begin
  FVID.ID := Value.ID;
  FVID.SN := Value.SN;
  FVID.Phone := Value.Phone;
end;

end.
