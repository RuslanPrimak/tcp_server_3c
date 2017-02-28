unit uDBSetProviderPool;

interface

uses
	uDBSetProvider, Contnrs, SyncObjs;

type
	TDBSetProviderPool = class(TObject)
  private
  	FListProviders: TObjectList;
  public
  	constructor Create;
    destructor Destroy; override;
    function GetDataBaseFromPool(param: TDBConnectParams): TDBSetProvider;
    procedure PutDataBaseToPool(provider: TDBSetProvider);
	end;

var
	ProviderPool: TDBSetProviderPool;

implementation

var
	csPool: TCriticalSection;

{ TDBSetProviderPool }

constructor TDBSetProviderPool.Create;
begin
	FListProviders := TObjectList.Create(true);
end;

destructor TDBSetProviderPool.Destroy;
begin
	FListProviders.Free;
  inherited;
end;

function TDBSetProviderPool.GetDataBaseFromPool(param: TDBConnectParams): TDBSetProvider;
var
	i: Integer;
  newProvider: TDBSetProvider;
begin
	csPool.Acquire;
	try
  	newProvider := nil;
    for i := 0 to FListProviders.Count-1 do
      if not TDBSetProvider(FListProviders[i]).Active then
      begin
				newProvider := TDBSetProvider(FListProviders[i]);
        break;
      end;

    if not Assigned(newProvider) then
    begin
			newProvider := TDBSetProvider.Create;
    	FListProviders.Add(newProvider);
  	end;

    newProvider.Connect(param);
    if newProvider.Active then
    	result := newProvider
    else
    	result := nil;
  finally
		csPool.Release;
  end;
end;

procedure TDBSetProviderPool.PutDataBaseToPool(provider: TDBSetProvider);
begin
	csPool.Acquire;
	try
		provider.Disconnect;
  finally
		csPool.Release;
  end;
end;

initialization
	csPool := TCriticalSection.Create;
  ProviderPool := TDBSetProviderPool.Create;

finalization
	ProviderPool.Free;
	csPool.Free;

end.
