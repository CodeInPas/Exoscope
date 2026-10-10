unit uGalaxyMapModel;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, uKeplerPhysics;

type
  { Status eksplorasi dari sebuah sektor bintang }
  TSectorStatus = (ssUnexplored, ssScannedEmpty, ssScannedPlanets);

  { Data spasial dan status untuk satu sektor / sistem tata surya }
  TStarSector = record
    Name: string;
    X: Double;
    Y: Double;
    Status: TSectorStatus;
    StarClass: TStarClass;
    IsBlackHole: Boolean; // DATA BARU: Penanda anomali Black Hole / Event Horizon
  end;

  TStarSectorArray = array of TStarSector;

  { TGalaxyMapModel }
  TGalaxyMapModel = class
  private
    FSectors: TStarSectorArray;
    FMapWidth: Double;
    FMapHeight: Double;

    procedure GenerateGalaxy;
    function GenerateSectorName: string;
    function IsNameExists(const AName: string): Boolean;
  public
    constructor Create(ASectorCount: Integer; AWidth, AHeight: Double);
    destructor Destroy; override;

    function FindSectorIndex(const ASectorName: string): Integer;
    procedure UpdateSectorStatus(const ASectorName: string; AHasPlanets: Boolean);
    procedure ResetExploration;

    property Sectors: TStarSectorArray read FSectors;
    property MapWidth: Double read FMapWidth;
    property MapHeight: Double read FMapHeight;
    function GetSectorCount: Integer;
  end;

implementation

{ TGalaxyMapModel }

constructor TGalaxyMapModel.Create(ASectorCount: Integer; AWidth, AHeight: Double);
begin
  inherited Create;
  FMapWidth := AWidth;
  FMapHeight := AHeight;
  SetLength(FSectors, ASectorCount);
  GenerateGalaxy;
end;

destructor TGalaxyMapModel.Destroy;
begin
  SetLength(FSectors, 0);
  inherited Destroy;
end;

function TGalaxyMapModel.GetSectorCount: Integer;
begin
  Result := Length(FSectors);
end;

function TGalaxyMapModel.IsNameExists(const AName: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(FSectors) do
  begin
    if SameText(FSectors[I].Name, AName) then
      Exit(True);
  end;
end;

function TGalaxyMapModel.GenerateSectorName: string;
const
  PREFIXES: array[0..5] of string = ('KEPLER', 'TRAPPIST', 'GLIESE', 'HD', 'K2', 'EXO');
var
  Prefix: string;
  Number: Integer;
  Candidate: string;
begin
  repeat
    Prefix := PREFIXES[Random(Length(PREFIXES))];
    Number := 1 + Random(9999);
    Candidate := Format('%s-%d', [Prefix, Number]);
  until not IsNameExists(Candidate);
  Result := Candidate;
end;

procedure TGalaxyMapModel.GenerateGalaxy;
var
  I, BHCount, TargetIdx: Integer;
  StarProps: TStarProperties;
begin
  Randomize;
  for I := 0 to High(FSectors) do
  begin
    FSectors[I].Name := GenerateSectorName;
    FSectors[I].X := Random * FMapWidth;
    FSectors[I].Y := Random * FMapHeight;
    FSectors[I].Status := ssUnexplored;
    FSectors[I].IsBlackHole := False;

    StarProps := TKeplerPhysics.GenerateRandomStar;
    FSectors[I].StarClass := StarProps.StarClass;
  end;

  // FITUR BARU: Injeksi 2 Black Hole mematikan secara acak ke dalam peta galaksi
  BHCount := 0;
  while BHCount < 2 do
  begin
    TargetIdx := Random(Length(FSectors));
    if not FSectors[TargetIdx].IsBlackHole then
    begin
      FSectors[TargetIdx].IsBlackHole := True;
      // Menyamarkan namanya menjadi kode anomali
      FSectors[TargetIdx].Name := 'VOID-' + IntToStr(1000 + Random(9000));
      Inc(BHCount);
    end;
  end;
end;

procedure TGalaxyMapModel.ResetExploration;
var
  I: Integer;
begin
  for I := 0 to High(FSectors) do
    FSectors[I].Status := ssUnexplored;
end;

function TGalaxyMapModel.FindSectorIndex(const ASectorName: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(FSectors) do
  begin
    if SameText(FSectors[I].Name, ASectorName) then
      Exit(I);
  end;
end;

procedure TGalaxyMapModel.UpdateSectorStatus(const ASectorName: string; AHasPlanets: Boolean);
var
  Idx: Integer;
begin
  Idx := FindSectorIndex(ASectorName);
  if Idx >= 0 then
  begin
    if AHasPlanets then
      FSectors[Idx].Status := ssScannedPlanets
    else
      FSectors[Idx].Status := ssScannedEmpty;
  end;
end;

end.
