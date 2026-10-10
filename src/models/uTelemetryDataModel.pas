unit uTelemetryDataModel;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, uDigitalSignalProcessing, uKeplerPhysics;

type
  { Deklarasi tipe eksplisit untuk array dinamis }
  TTimeStepArray = array of Double;
  TWavelengthArray = array of Double;

  { TPlanetParam
    Menyimpan parameter spesifik untuk setiap planet dalam suatu sistem multi-planet }
  TPlanetParam = record
    PeriodOffset: Integer;
    TransitWidth: Integer;
    TransitDepth: Double;
    OrbitSpeed: Double;
    OrbitRadius: Double;

    PlanetRadiusEarth: Double;
    PlanetType: string;
  end;

  TPlanetArray = array of TPlanetParam;

  { TTelemetryDataModel }
  TTelemetryDataModel = class
  private
    FRawFlux: TSignalArray;
    FFilteredFlux: TSignalArray;
    FTimeSteps: TTimeStepArray;
    FSectorName: string;
    FDataCount: Integer;
    FHasAnomaly: Boolean;
    FPlanets: TPlanetArray;

    FStar: TStarProperties;

    FHasBiosignature: Boolean;
    FHasMegastructure: Boolean;

    FSpectralFlux: TSignalArray;
    FWavelengths: TWavelengthArray;
    FSpectrumCount: Integer;

    { FITUR BARU: MINIGAME DEKRIPSI SINYAL ALIEN }
    FIsDecrypting: Boolean;
    FIsDecrypted: Boolean;
    FTargetFreq: Double;
    FTargetPhase: Double;
    FCurrentFreq: Double;
    FCurrentPhase: Double;
    FDecryptionAlienWave: TSignalArray;
    FDecryptionPlayerWave: TSignalArray;

    procedure InjectTransitAnomaly(var ASignal: TSignalArray; ACenterIdx, AWidth: Integer; ADepth: Double);
  public
    constructor Create;
    destructor Destroy; override;

    procedure Clear;

    procedure GenerateSectorData(const ASectorName: string; APointCount: Integer;
      ABaseFlux, ANoiseStdDev: Double; AIncludePlanet: Boolean; AStarClass: TStarClass);

    procedure GenerateSpectrumData(ABandwidth: Double);

    procedure ApplyFilterGaussian(ASigma: Double);
    procedure ApplyFilterMovingAverage(AWindowSize: Integer);

    { FITUR BARU: Metode Minigame }
    procedure StartDecryption;
    procedure GenerateDecryptionWaves;
    function AttemptDecode(AFreq, APhase: Double): Boolean;

    property SectorName: string read FSectorName;
    property DataCount: Integer read FDataCount;
    property HasAnomaly: Boolean read FHasAnomaly;

    property HasBiosignature: Boolean read FHasBiosignature;
    property HasMegastructure: Boolean read FHasMegastructure;

    property Planets: TPlanetArray read FPlanets;
    property Star: TStarProperties read FStar;
    function GetPlanetCount: Integer;

    property RawFlux: TSignalArray read FRawFlux;
    property FilteredFlux: TSignalArray read FFilteredFlux;
    property TimeSteps: TTimeStepArray read FTimeSteps;

    property SpectrumFlux: TSignalArray read FSpectralFlux;
    property Wavelengths: TWavelengthArray read FWavelengths;
    property SpectrumCount: Integer read FSpectrumCount;

    { FITUR BARU: Properti Minigame }
    property IsDecrypting: Boolean read FIsDecrypting;
    property IsDecrypted: Boolean read FIsDecrypted;
    property TargetFreq: Double read FTargetFreq;
    property TargetPhase: Double read FTargetPhase;
    property CurrentFreq: Double read FCurrentFreq;
    property CurrentPhase: Double read FCurrentPhase;
    property DecryptionAlienWave: TSignalArray read FDecryptionAlienWave;
    property DecryptionPlayerWave: TSignalArray read FDecryptionPlayerWave;
  end;

implementation

{ TTelemetryDataModel }

constructor TTelemetryDataModel.Create;
begin
  inherited Create;
  FDataCount := 0;
  FSpectrumCount := 0;
  SetLength(FPlanets, 0);
  FIsDecrypting := False;
  FIsDecrypted := False;
end;

destructor TTelemetryDataModel.Destroy;
begin
  Clear;
  inherited Destroy;
end;

procedure TTelemetryDataModel.Clear;
begin
  SetLength(FRawFlux, 0);
  SetLength(FFilteredFlux, 0);
  SetLength(FTimeSteps, 0);
  SetLength(FSpectralFlux, 0);
  SetLength(FWavelengths, 0);
  SetLength(FPlanets, 0);
  SetLength(FDecryptionAlienWave, 0);
  SetLength(FDecryptionPlayerWave, 0);

  FDataCount := 0;
  FSpectrumCount := 0;
  FSectorName := '';
  FHasBiosignature := False;
  FHasMegastructure := False;
  FIsDecrypting := False;
  FIsDecrypted := False;
end;

function TTelemetryDataModel.GetPlanetCount: Integer;
begin
  Result := Length(FPlanets);
end;

procedure TTelemetryDataModel.InjectTransitAnomaly(var ASignal: TSignalArray; ACenterIdx, AWidth: Integer; ADepth: Double);
var
  I, StartIdx, EndIdx: Integer;
  Phase, InjectedDepth: Double;
begin
  StartIdx := Max(0, ACenterIdx - (AWidth div 2));
  EndIdx := Min(FDataCount - 1, ACenterIdx + (AWidth div 2));

  for I := StartIdx to EndIdx do
  begin
    Phase := (I - ACenterIdx) / (AWidth / 2);
    InjectedDepth := ADepth * Cos(Phase * (Pi / 2));

    if InjectedDepth > 0 then
      ASignal[I] := ASignal[I] - InjectedDepth;
  end;
end;

procedure TTelemetryDataModel.GenerateSectorData(const ASectorName: string; APointCount: Integer;
  ABaseFlux, ANoiseStdDev: Double; AIncludePlanet: Boolean; AStarClass: TStarClass);
var
  I, NumPlanets, PIdx, Transits, TIdx, CenterTime: Integer;
  TimeStepInterval: Double;
  OrbPeriod, SemiMajorAxis: Double;
  HZ: THabitableZone;
  SystemIsHabitable: Boolean;
begin
  Clear;
  FSectorName := ASectorName;
  FDataCount := APointCount;
  FHasAnomaly := AIncludePlanet;

  FStar := TKeplerPhysics.GetStarProperties(AStarClass);

  if FDataCount <= 0 then Exit;

  SetLength(FRawFlux, FDataCount);
  SetLength(FFilteredFlux, FDataCount);
  SetLength(FTimeSteps, FDataCount);

  TimeStepInterval := 100.0 / FDataCount;

  for I := 0 to FDataCount - 1 do
  begin
    FRawFlux[I] := ABaseFlux;
    FTimeSteps[I] := I * TimeStepInterval;
  end;

  SystemIsHabitable := False;

  if FHasAnomaly then
  begin
    NumPlanets := 1 + Random(4);
    SetLength(FPlanets, NumPlanets);
    HZ := TKeplerPhysics.CalculateHabitableZone(FStar.Luminosity);

    for PIdx := 0 to NumPlanets - 1 do
    begin
      FPlanets[PIdx].PeriodOffset := (FDataCount div 5) + Random(FDataCount div 2);
      FPlanets[PIdx].TransitWidth := (FDataCount div 20) + Random(FDataCount div 10);

      FPlanets[PIdx].TransitDepth := ABaseFlux * (0.005 + (Random * 0.05)) / Sqr(FStar.Radius);
      if FPlanets[PIdx].TransitDepth > (ABaseFlux * 0.99) then
        FPlanets[PIdx].TransitDepth := ABaseFlux * 0.99;

      FPlanets[PIdx].PlanetRadiusEarth := TKeplerPhysics.CalculatePlanetRadius(FPlanets[PIdx].TransitDepth, FStar.Radius);
      OrbPeriod := FPlanets[PIdx].PeriodOffset * 0.5;
      SemiMajorAxis := TKeplerPhysics.CalculateSemiMajorAxis(OrbPeriod, FStar.Mass);

      FPlanets[PIdx].PlanetType := TKeplerPhysics.GetPlanetaryTypology(
        FPlanets[PIdx].PlanetRadiusEarth, SemiMajorAxis, HZ);

      if TKeplerPhysics.IsHabitable(SemiMajorAxis, HZ) then
        SystemIsHabitable := True;

      FPlanets[PIdx].OrbitSpeed := 0.5 + (Random * 1.5);
      FPlanets[PIdx].OrbitRadius := 1.5 + (PIdx * 0.8);

      Transits := FDataCount div FPlanets[PIdx].PeriodOffset;
      for TIdx := 1 to Transits do
      begin
        CenterTime := TIdx * FPlanets[PIdx].PeriodOffset;
        InjectTransitAnomaly(FRawFlux, CenterTime, FPlanets[PIdx].TransitWidth, FPlanets[PIdx].TransitDepth);
      end;
    end;

    if Random(100) < 5 then
      FHasMegastructure := True
    else if SystemIsHabitable and (Random(100) < 35) then
      FHasBiosignature := True;
  end;

  TSignalProcessor.AddGaussianNoise(FRawFlux, 0, ANoiseStdDev);
  FFilteredFlux := Copy(FRawFlux);
end;

procedure TTelemetryDataModel.GenerateSpectrumData(ABandwidth: Double);
var
  I: Integer;
  StartWL, EndWL, WL, Flux: Double;
begin
  FSpectrumCount := 1000;
  SetLength(FSpectralFlux, FSpectrumCount);
  SetLength(FWavelengths, FSpectrumCount);

  StartWL := 300.0;
  EndWL := StartWL + ABandwidth;

  for I := 0 to FSpectrumCount - 1 do
  begin
    WL := StartWL + (I / (FSpectrumCount - 1)) * (EndWL - StartWL);
    FWavelengths[I] := WL;

    Flux := 1.2 * Exp(-Power((WL - FStar.PeakWavelength) / 400.0, 2));
    Flux := Flux + (Random - 0.5) * 0.05;

    if FHasBiosignature then
    begin
      if Abs(WL - 760.0) < 15.0 then
        Flux := Flux - (0.15) * Exp(-Power(WL - 760.0, 2) / 5.0);
      if Abs(WL - 940.0) < 20.0 then
        Flux := Flux - (0.12) * Exp(-Power(WL - 940.0, 2) / 10.0);
    end;

    if FHasMegastructure then
    begin
      if Abs(WL - 500.0) < 10.0 then
        Flux := Flux - (0.35) * Exp(-Power(WL - 500.0, 2) / 2.0);
    end;

    if Flux < 0 then Flux := 0;
    FSpectralFlux[I] := Flux;
  end;
end;

procedure TTelemetryDataModel.ApplyFilterGaussian(ASigma: Double);
begin
  if FDataCount = 0 then Exit;
  FFilteredFlux := TSignalProcessor.GaussianSmooth(FRawFlux, ASigma);
end;

procedure TTelemetryDataModel.ApplyFilterMovingAverage(AWindowSize: Integer);
begin
  if FDataCount = 0 then Exit;
  FFilteredFlux := TSignalProcessor.MovingAverage(FRawFlux, AWindowSize);
end;

{ ========================================================================= }
{ FITUR BARU: LOGIKA MINIGAME DEKRIPSI SINYAL                               }
{ ========================================================================= }

procedure TTelemetryDataModel.StartDecryption;
begin
  if not (FHasBiosignature or FHasMegastructure) then Exit;

  FIsDecrypting := True;
  FIsDecrypted := False;

  // Tentukan kunci rahasia secara acak
  FTargetFreq := 1.0 + (Random(80) / 10.0); // Rentang: 1.0 - 9.0
  FTargetPhase := Random(100) / 10.0;       // Rentang: 0.0 - 9.9

  // Reset posisi pemain
  FCurrentFreq := 1.0;
  FCurrentPhase := 0.0;

  SetLength(FDecryptionAlienWave, 200);
  SetLength(FDecryptionPlayerWave, 200);

  GenerateDecryptionWaves;
end;

procedure TTelemetryDataModel.GenerateDecryptionWaves;
var
  I: Integer;
  X, TimeNoise: Double;
begin
  if Length(FDecryptionAlienWave) = 0 then Exit;

  TimeNoise := Random * 0.1; // Sedikit getaran agar terasa seperti gelombang radio asli

  for I := 0 to 199 do
  begin
    X := I / 20.0;

    // Gelombang kompleks milik alien (Target)
    FDecryptionAlienWave[I] :=
      Sin(X * FTargetFreq + FTargetPhase) +
      0.5 * Sin(X * FTargetFreq * 1.5) + TimeNoise;

    // Gelombang sinkronisasi dari satelit pemain
    FDecryptionPlayerWave[I] :=
      Sin(X * FCurrentFreq + FCurrentPhase) +
      0.5 * Sin(X * FCurrentFreq * 1.5);
  end;
end;

function TTelemetryDataModel.AttemptDecode(AFreq, APhase: Double): Boolean;
begin
  if not FIsDecrypting then Exit(False);

  FCurrentFreq := AFreq;
  FCurrentPhase := APhase;
  GenerateDecryptionWaves;

  // Cek apakah pemain berhasil menyamakan gelombang (dengan sedikit toleransi)
  if (Abs(FCurrentFreq - FTargetFreq) <= 0.2) and (Abs(FCurrentPhase - FTargetPhase) <= 0.5) then
  begin
    FIsDecrypted := True;
    FIsDecrypting := False; // Minigame selesai
    Result := True;
  end
  else
    Result := False;
end;

end.
