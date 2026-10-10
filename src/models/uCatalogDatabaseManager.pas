unit uCatalogDatabaseManager;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, sqldb, sqlite3conn;

type
  { Struktur data log penemuan eksoplanet. }
  TExoplanetDiscovery = record
    SectorName: string;
    PlanetType: string; // Bisa berisi tipe standar, 'BIO-CONFIRMED', atau 'MEGASTRUCTURE'
    PlanetRadius: Double;
    OrbitalPeriod: Double;
    BiosignatureConfidence: Double;
    IsHabitable: Boolean;
  end;

  { TCatalogDatabaseManager }
  TCatalogDatabaseManager = class
  private
    FConnection: TSQLite3Connection;
    FTransaction: TSQLTransaction;
    FDatabasePath: string;

    FSensorLevel: Integer;
    FRadarLevel: Integer;

    procedure InitializeSchema;
    procedure LoadTechTree;
  public
    constructor Create(const ADatabasePath: string);
    destructor Destroy; override;

    function Connect: Boolean;
    procedure Disconnect;

    function SaveDiscovery(const AData: TExoplanetDiscovery): Boolean;
    function GetTotalDiscoveries: Integer;
    function CalculateTotalFunding: Double;

    procedure SaveUpgrade(ASensorLv, ARadarLv: Integer);
    property SensorLevel: Integer read FSensorLevel;
    property RadarLevel: Integer read FRadarLevel;
  end;

implementation

{ TCatalogDatabaseManager }

constructor TCatalogDatabaseManager.Create(const ADatabasePath: string);
begin
  inherited Create;
  FDatabasePath := ADatabasePath;
  FSensorLevel := 1;
  FRadarLevel := 1;

  FConnection := TSQLite3Connection.Create(nil);
  FTransaction := TSQLTransaction.Create(nil);

  FConnection.DatabaseName := FDatabasePath;
  FConnection.Transaction := FTransaction;
  FTransaction.DataBase := FConnection;
end;

destructor TCatalogDatabaseManager.Destroy;
begin
  Disconnect;
  FTransaction.Free;
  FConnection.Free;
  inherited Destroy;
end;

function TCatalogDatabaseManager.Connect: Boolean;
begin
  Result := False;
  try
    if not FConnection.Connected then
    begin
      FConnection.Open;
      InitializeSchema;
      LoadTechTree;
    end;
    Result := True;
  except
    on E: Exception do
      Result := False;
  end;
end;

procedure TCatalogDatabaseManager.Disconnect;
begin
  if Assigned(FConnection) and FConnection.Connected then
  begin
    if FTransaction.Active then
      FTransaction.Commit;
    FConnection.Close;
  end;
end;

procedure TCatalogDatabaseManager.InitializeSchema;
var
  Query: TSQLQuery;
begin
  Query := TSQLQuery.Create(nil);
  try
    Query.DataBase := FConnection;
    Query.Transaction := FTransaction;

    Query.SQL.Text :=
      'CREATE TABLE IF NOT EXISTS ExoplanetCatalog (' +
      '  ID INTEGER PRIMARY KEY AUTOINCREMENT, ' +
      '  SectorName TEXT NOT NULL, ' +
      '  PlanetType TEXT, ' +
      '  PlanetRadius REAL, ' +
      '  OrbitalPeriod REAL, ' +
      '  BiosignatureConf REAL, ' +
      '  IsHabitable INTEGER, ' +
      '  DiscoveryDate DATETIME DEFAULT CURRENT_TIMESTAMP' +
      ');';
    Query.ExecSQL;

    Query.SQL.Text :=
      'CREATE TABLE IF NOT EXISTS PlayerTechTree (' +
      '  ID INTEGER PRIMARY KEY, ' +
      '  SensorLevel INTEGER DEFAULT 1, ' +
      '  RadarLevel INTEGER DEFAULT 1 ' +
      ');';
    Query.ExecSQL;

    Query.SQL.Text := 'INSERT OR IGNORE INTO PlayerTechTree (ID, SensorLevel, RadarLevel) VALUES (1, 1, 1);';
    Query.ExecSQL;

    FTransaction.CommitRetaining;
  finally
    Query.Free;
  end;
end;

procedure TCatalogDatabaseManager.LoadTechTree;
var
  Query: TSQLQuery;
begin
  if not FConnection.Connected then Exit;

  Query := TSQLQuery.Create(nil);
  try
    Query.DataBase := FConnection;
    Query.Transaction := FTransaction;
    Query.SQL.Text := 'SELECT SensorLevel, RadarLevel FROM PlayerTechTree WHERE ID = 1;';
    Query.Open;

    if not Query.EOF then
    begin
      FSensorLevel := Query.FieldByName('SensorLevel').AsInteger;
      FRadarLevel := Query.FieldByName('RadarLevel').AsInteger;
    end;
    Query.Close;
  finally
    Query.Free;
  end;
end;

procedure TCatalogDatabaseManager.SaveUpgrade(ASensorLv, ARadarLv: Integer);
var
  Query: TSQLQuery;
begin
  if not FConnection.Connected then Exit;

  Query := TSQLQuery.Create(nil);
  try
    Query.DataBase := FConnection;
    Query.Transaction := FTransaction;

    Query.SQL.Text := 'UPDATE PlayerTechTree SET SensorLevel = :Sens, RadarLevel = :Rad WHERE ID = 1;';
    Query.Params.ParamByName('Sens').AsInteger := ASensorLv;
    Query.Params.ParamByName('Rad').AsInteger := ARadarLv;

    try
      Query.ExecSQL;
      FTransaction.CommitRetaining;

      FSensorLevel := ASensorLv;
      FRadarLevel := ARadarLv;
    except
      FTransaction.RollbackRetaining;
    end;
  finally
    Query.Free;
  end;
end;

function TCatalogDatabaseManager.SaveDiscovery(const AData: TExoplanetDiscovery): Boolean;
var
  Query: TSQLQuery;
begin
  Result := False;
  if not FConnection.Connected then Exit;

  Query := TSQLQuery.Create(nil);
  try
    Query.DataBase := FConnection;
    Query.Transaction := FTransaction;

    Query.SQL.Text :=
      'INSERT INTO ExoplanetCatalog ' +
      '(SectorName, PlanetType, PlanetRadius, OrbitalPeriod, BiosignatureConf, IsHabitable) ' +
      'VALUES (:Sector, :PType, :Radius, :Period, :BioConf, :Habitable);';

    Query.Params.ParamByName('Sector').AsString := AData.SectorName;
    Query.Params.ParamByName('PType').AsString := AData.PlanetType;
    Query.Params.ParamByName('Radius').AsFloat := AData.PlanetRadius;
    Query.Params.ParamByName('Period').AsFloat := AData.OrbitalPeriod;
    Query.Params.ParamByName('BioConf').AsFloat := AData.BiosignatureConfidence;
    Query.Params.ParamByName('Habitable').AsInteger := Ord(AData.IsHabitable);

    try
      Query.ExecSQL;
      FTransaction.CommitRetaining;
      Result := True;
    except
      FTransaction.RollbackRetaining;
    end;
  finally
    Query.Free;
  end;
end;

function TCatalogDatabaseManager.GetTotalDiscoveries: Integer;
var
  Query: TSQLQuery;
begin
  Result := 0;
  if not FConnection.Connected then Exit;

  Query := TSQLQuery.Create(nil);
  try
    Query.DataBase := FConnection;
    Query.Transaction := FTransaction;
    Query.SQL.Text := 'SELECT COUNT(ID) AS Total FROM ExoplanetCatalog;';
    Query.Open;

    if not Query.EOF then
      Result := Query.FieldByName('Total').AsInteger;

    Query.Close;
  finally
    Query.Free;
  end;
end;

function TCatalogDatabaseManager.CalculateTotalFunding: Double;
var
  Query: TSQLQuery;
begin
  Result := 0;
  if not FConnection.Connected then Exit;

  Query := TSQLQuery.Create(nil);
  try
    Query.DataBase := FConnection;
    Query.Transaction := FTransaction;

    Query.SQL.Text :=
      'SELECT SUM(' +
      '  100000 + ' +
      '  (IsHabitable * 500000) + ' +
      '  CASE ' +
      '    WHEN PlanetType LIKE ''%MEGASTRUCTURE%'' THEN 5000000 ' +
      '    WHEN PlanetType LIKE ''%BIO-CONFIRMED%'' THEN 2000000 ' +
      '    WHEN PlanetType = ''TERRESTRIAL'' THEN 500000 ' +
      '    WHEN PlanetType = ''SUPER-EARTH'' THEN 300000 ' +
      '    WHEN PlanetType = ''GAS GIANT'' THEN 50000 ' +
      '    ELSE 0 ' +
      '  END' +
      ') AS TotalFunding ' +
      'FROM ExoplanetCatalog;';
    Query.Open;

    if not Query.EOF and not Query.FieldByName('TotalFunding').IsNull then
      Result := Query.FieldByName('TotalFunding').AsFloat;

    Query.Close;
  finally
    Query.Free;
  end;
end;

end.
