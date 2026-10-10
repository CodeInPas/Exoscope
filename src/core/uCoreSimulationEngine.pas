unit uCoreSimulationEngine;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, IniFiles, // Menambahkan library IniFiles
  uTelemetryDataModel, uCatalogDatabaseManager, uCommandLexer,
  uBackgroundWorkerThread, uKeplerPhysics, uDigitalSignalProcessing,
  uGalaxyMapModel, uAudioSynthesizer, uSurfaceProbeRenderer, uReportExporter;

type
  TGameState = (gsIdle, gsAcquiring, gsAnalyzing, gsReported);

  TLogMessageEvent = procedure(const AMessage: string; AIsError: Boolean) of object;
  TClearTerminalEvent = procedure of object;
  TViewChangeEvent = procedure(const AView: string) of object;

  TCoreSimulationEngine = class
  private
    FState: TGameState;
    FDataModel: TTelemetryDataModel;
    FDatabase: TCatalogDatabaseManager;
    FGalaxyMap: TGalaxyMapModel;
    FAudioSynth: TAudioSynthesizer;

    FResearchFunding: Double;
    FDiscoveryPoints: Integer;
    FScanResultType: string;

    FDecryptionDeadline: TDateTime;

    { Variabel baru untuk sistem Save/Load & Ekonomi }
    FMapSeed: Integer;
    FExpendedFunding: Double;

    FOnLogMessage: TLogMessageEvent;
    FOnClearTerminal: TClearTerminalEvent;
    FOnStateChanged: TNotifyEvent;
    FOnDataUpdated: TNotifyEvent;
    FOnViewChanged: TViewChangeEvent;
    FOnMapRebuilt: TNotifyEvent; // Event untuk merestart Peta di UI saat Load

    procedure SetState(const ANewState: TGameState);
    procedure Log(const AMsg: string; AIsError: Boolean = False);
    procedure SyncDatabaseMetrics;

    procedure OnAcquisitionComplete(Sender: TObject);
    procedure OnFilterComplete(Sender: TObject);

    procedure CmdConnect(const ACmd: TCommandData);
    procedure CmdFilter(const ACmd: TCommandData);
    procedure CmdReport(const ACmd: TCommandData);
    procedure CmdView(const ACmd: TCommandData);
    procedure CmdUpgrade(const ACmd: TCommandData);
    procedure CmdScanBio(const ACmd: TCommandData);
    procedure CmdListen(const ACmd: TCommandData);
    procedure CmdLaunch(const ACmd: TCommandData);
    procedure CmdExport(const ACmd: TCommandData);
    procedure CmdDecode(const ACmd: TCommandData);

    procedure CmdSave; // Perintah Save
    procedure CmdLoad; // Perintah Load
    procedure CmdHelp;
  public
    constructor Create(const ADbPath: string);
    destructor Destroy; override;

    procedure ExecuteCommandString(const AInput: string);

    property State: TGameState read FState;
    property DataModel: TTelemetryDataModel read FDataModel;
    property Database: TCatalogDatabaseManager read FDatabase;
    property GalaxyMap: TGalaxyMapModel read FGalaxyMap;
    property ResearchFunding: Double read FResearchFunding;
    property DiscoveryPoints: Integer read FDiscoveryPoints;
    property Audio: TAudioSynthesizer read FAudioSynth;

    property OnLogMessage: TLogMessageEvent read FOnLogMessage write FOnLogMessage;
    property OnClearTerminal: TClearTerminalEvent read FOnClearTerminal write FOnClearTerminal;
    property OnStateChanged: TNotifyEvent read FOnStateChanged write FOnStateChanged;
    property OnDataUpdated: TNotifyEvent read FOnDataUpdated write FOnDataUpdated;
    property OnViewChanged: TViewChangeEvent read FOnViewChanged write FOnViewChanged;
    property OnMapRebuilt: TNotifyEvent read FOnMapRebuilt write FOnMapRebuilt;
  end;

implementation

uses DateUtils;

{ TCoreSimulationEngine }

constructor TCoreSimulationEngine.Create(const ADbPath: string);
begin
  inherited Create;
  FState := gsIdle;
  FScanResultType := '';
  FDataModel := TTelemetryDataModel.Create;
  FDatabase := TCatalogDatabaseManager.Create(ADbPath);

  // Inisialisasi variabel memori Save/Load
  FExpendedFunding := 0.0;
  FMapSeed := Random(MaxInt);
  RandSeed := FMapSeed; // Tanamkan Seed unik untuk sesi ini

  FGalaxyMap := TGalaxyMapModel.Create(300, 3000.0, 3000.0);
  FAudioSynth := TAudioSynthesizer.Create;

  if FDatabase.Connect then
    SyncDatabaseMetrics
  else
    FResearchFunding := 100000;
end;

destructor TCoreSimulationEngine.Destroy;
begin
  FAudioSynth.Free;
  FGalaxyMap.Free;
  FDatabase.Free;
  FDataModel.Free;
  inherited Destroy;
end;

procedure TCoreSimulationEngine.SetState(const ANewState: TGameState);
begin
  if FState <> ANewState then
  begin
    FState := ANewState;
    if Assigned(FOnStateChanged) then FOnStateChanged(Self);
  end;
end;

procedure TCoreSimulationEngine.Log(const AMsg: string; AIsError: Boolean);
begin
  if Assigned(FOnLogMessage) then FOnLogMessage(AMsg, AIsError);
end;

procedure TCoreSimulationEngine.SyncDatabaseMetrics;
begin
  FDiscoveryPoints := FDatabase.GetTotalDiscoveries() * 50;
  FResearchFunding := 100000 + FDatabase.CalculateTotalFunding();

  if FDatabase.SensorLevel > 1 then FResearchFunding := FResearchFunding - 300000;
  if FDatabase.RadarLevel > 1 then FResearchFunding := FResearchFunding - 500000;

  // Terapkan semua denda & bonus dari memori Save/Load
  FResearchFunding := FResearchFunding - FExpendedFunding;

  if FResearchFunding < 0 then FResearchFunding := 0;

  if Assigned(FOnStateChanged) then FOnStateChanged(Self);
end;

procedure TCoreSimulationEngine.OnAcquisitionComplete(Sender: TObject);
begin
  FScanResultType := '';
  FAudioSynth.Stop;

  Log('ACQUISITION: ONLINE. Data loaded for ' + FDataModel.SectorName);
  Log('--- STELLAR INTEL ---');
  Log('CLASS: ' + FDataModel.Star.ClassName);
  Log(Format('MASS: %.2f M_sun | RADIUS: %.2f R_sun', [FDataModel.Star.Mass, FDataModel.Star.Radius]));
  Log(Format('TEMP: %.0f K | LUM: %.4f L_sun', [FDataModel.Star.Temperature, FDataModel.Star.Luminosity]));
  Log('---------------------');

  SetState(gsAnalyzing);
  if Assigned(FOnDataUpdated) then FOnDataUpdated(Self);
end;

procedure TCoreSimulationEngine.OnFilterComplete(Sender: TObject);
begin
  Log('FILTER: OPERATION SUCCESSFUL.');
  if Assigned(FOnDataUpdated) then FOnDataUpdated(Self);
end;

procedure TCoreSimulationEngine.ExecuteCommandString(const AInput: string);
var
  CmdData: TCommandData;
begin
  if Trim(AInput) = '' then Exit;
  Log('usr@exoscope_ops > ' + AInput);
  CmdData := TCommandLexer.Parse(AInput);

  if not CmdData.IsValid then
  begin
    Log('ERROR: INVALID COMMAND SYNTAX', True);
    Exit;
  end;

  if CmdData.Command = 'CONNECT' then CmdConnect(CmdData)
  else if CmdData.Command = 'FILTER' then CmdFilter(CmdData)
  else if CmdData.Command = 'SCAN' then CmdScanBio(CmdData)
  else if CmdData.Command = 'LISTEN' then CmdListen(CmdData)
  else if CmdData.Command = 'LAUNCH' then CmdLaunch(CmdData)
  else if CmdData.Command = 'EXPORT' then CmdExport(CmdData)
  else if CmdData.Command = 'REPORT' then CmdReport(CmdData)
  else if CmdData.Command = 'VIEW' then CmdView(CmdData)
  else if CmdData.Command = 'UPGRADE' then CmdUpgrade(CmdData)
  else if CmdData.Command = 'DECODE' then CmdDecode(CmdData)
  else if CmdData.Command = 'SAVE' then CmdSave
  else if CmdData.Command = 'LOAD' then CmdLoad
  else if CmdData.Command = 'HELP' then CmdHelp
  else if CmdData.Command = 'CLEAR' then
  begin
    if Assigned(FOnClearTerminal) then FOnClearTerminal();
  end
  else Log('ERROR: UNKNOWN COMMAND ''' + CmdData.Command + '''', True);
end;

procedure TCoreSimulationEngine.CmdHelp;
begin
  Log('AVAILABLE COMMANDS:');
  Log('  CONNECT -SECTOR <Name>  : Connect to satellite and acquire sector data.');
  Log('  FILTER -MODE <Type>     : Apply noise filter (GAUSSIAN or MOVINGAVG).');
  Log('  SCAN -BIO               : Scan for life signs / artificial signatures.');
  Log('  LISTEN -FREQ <MHz>      : Tune SETI radio receiver to specific frequency.');
  Log('  LAUNCH -PROBE           : Launch surface probe ($1,000,000) for surface imaging.');
  Log('  EXPORT -PDF             : Export official discovery report document.');
  Log('  REPORT                  : Analyze filtered data and report discovery.');
  Log('  UPGRADE -<System>       : Upgrade equipment (-SENSOR or -RADAR).');
  Log('  VIEW -MAP               : Open Galaxy Navigation Map.');
  Log('  VIEW -CHARTS            : Return to Telemetry Charts.');
  Log('  DECODE -FREQ <v> -PHASE : Decrypt alien signal (Req. during Alert).');
  Log('  SAVE                    : Save current progress to terminal archive.');
  Log('  LOAD                    : Load previous progress from archive.');
  Log('  CLEAR                   : Clear terminal output.');
  Log('  HELP                    : Show this command list.');
end;

procedure TCoreSimulationEngine.CmdSave;
var
  Ini: TIniFile;
  SavePath: string;
  I, StatInt: Integer;
begin
  SavePath := ExtractFilePath(ParamStr(0)) + 'savegame.ini';
  Ini := TIniFile.Create(SavePath);
  try
    Ini.WriteInteger('Galaxy', 'Seed', FMapSeed);
    Ini.WriteFloat('Player', 'ExpendedFunding', FExpendedFunding);

    Ini.EraseSection('Sectors'); // Bersihkan sisa data sebelumnya

    // Simpan status bintang (Mana yang sudah dipindai)
    for I := 0 to FGalaxyMap.GetSectorCount - 1 do
    begin
      if FGalaxyMap.Sectors[I].Status <> ssUnexplored then
      begin
        if FGalaxyMap.Sectors[I].Status = ssScannedPlanets then StatInt := 2
        else StatInt := 1;

        Ini.WriteInteger('Sectors', FGalaxyMap.Sectors[I].Name, StatInt);
      end;
    end;

    Log('>>> PROGRESS SAVED TO TERMINAL ARCHIVE.');
    FAudioSynth.PlaySuccess;
  finally
    Ini.Free;
  end;
end;

procedure TCoreSimulationEngine.CmdLoad;
var
  Ini: TIniFile;
  SavePath, SecName: string;
  I, StatInt: Integer;
begin
  SavePath := ExtractFilePath(ParamStr(0)) + 'savegame.ini';
  if not FileExists(SavePath) then
  begin
    Log('ERROR: NO ARCHIVE FOUND.', True);
    FAudioSynth.PlayFail;
    Exit;
  end;

  Ini := TIniFile.Create(SavePath);
  try
    FMapSeed := Ini.ReadInteger('Galaxy', 'Seed', FMapSeed);
    FExpendedFunding := Ini.ReadFloat('Player', 'ExpendedFunding', 0.0);

    // Regenerasi Peta Galaksi yang sama persis
    RandSeed := FMapSeed;
    FGalaxyMap.Free;
    FGalaxyMap := TGalaxyMapModel.Create(300, 3000.0, 3000.0);

    // Kembalikan status bintang
    for I := 0 to FGalaxyMap.GetSectorCount - 1 do
    begin
      SecName := FGalaxyMap.Sectors[I].Name;
      StatInt := Ini.ReadInteger('Sectors', SecName, 0);

      if StatInt = 2 then
        FGalaxyMap.UpdateSectorStatus(SecName, True)
      else if StatInt = 1 then
        FGalaxyMap.UpdateSectorStatus(SecName, False);
    end;

    // Peringatkan UI bahwa pointer Peta telah diganti
    if Assigned(FOnMapRebuilt) then FOnMapRebuilt(Self);

    SyncDatabaseMetrics;

    Log('>>> ARCHIVE LOADED. GALAXY MAP AND FUNDS RESTORED.');
    FAudioSynth.PlaySuccess;

    if Assigned(FOnDataUpdated) then FOnDataUpdated(Self);
  finally
    Ini.Free;
  end;
end;

procedure TCoreSimulationEngine.CmdView(const ACmd: TCommandData);
begin
  if ACmd.HasFlag('MAP') then
  begin
    Log('SWITCHING VISUALIZER TO GALAXY MAP...');
    FAudioSynth.Stop;
    if Assigned(FOnViewChanged) then FOnViewChanged('MAP');
  end
  else if ACmd.HasFlag('CHARTS') then
  begin
    Log('SWITCHING VISUALIZER TO TELEMETRY CHARTS...');
    if Assigned(FOnViewChanged) then FOnViewChanged('CHARTS');
  end
  else
    Log('ERROR: SPECIFY VIEW TARGET (-MAP OR -CHARTS)', True);
end;

procedure TCoreSimulationEngine.CmdConnect(const ACmd: TCommandData);
var
  SectorStr: string;
  Idx: Integer;
  TargetClass: TStarClass;
  NoiseLevel: Double;
begin
  if FDataModel.IsDecrypting then
  begin
    Log('ERROR: CANNOT CONNECT WHILE DECRYPTING SIGNAL.', True);
    Exit;
  end;

  if FState = gsAcquiring then
  begin
    Log('ERROR: ACQUISITION IN PROGRESS', True);
    Exit;
  end;

  SectorStr := ACmd.GetFlagValue('SECTOR', 'UNKNOWN');
  Log('CONNECTING SECTOR ' + SectorStr + '...');
  SetState(gsAcquiring);

  Idx := FGalaxyMap.FindSectorIndex(SectorStr);

  if (Idx >= 0) and FGalaxyMap.Sectors[Idx].IsBlackHole then
  begin
    Log('!!! CRITICAL WARNING: EVENT HORIZON DETECTED !!!', True);
    Log('!!! MASSIVE GRAVITATIONAL PULL DETECTED !!!', True);
    Log('SATELLITE TELEMETRY LOST. CONNECTION TERMINATED.', True);

    FExpendedFunding := FExpendedFunding + 200000; // Penalti Denda

    FAudioSynth.PlaySignal(stMegastructure);
    FAudioSynth.PlayFail;

    SetState(gsIdle);
    SyncDatabaseMetrics;
    Exit;
  end;

  if (Idx >= 0) and (FDatabase.RadarLevel > 1) then
    TargetClass := FGalaxyMap.Sectors[Idx].StarClass
  else
  begin
    TargetClass := TKeplerPhysics.GenerateRandomStar.StarClass;
    if Idx >= 0 then FGalaxyMap.Sectors[Idx].StarClass := TargetClass;
  end;

  if FDatabase.SensorLevel > 1 then
    NoiseLevel := 0.03
  else
    NoiseLevel := 0.1;

  TBackgroundWorkerThread.CreateGenerateData(
    FDataModel, SectorStr, 1000, 1.0, NoiseLevel, Random(2) = 0, TargetClass, @OnAcquisitionComplete);
end;

procedure TCoreSimulationEngine.CmdListen(const ACmd: TCommandData);
var
  FreqStr: string;
  FreqVal: Double;
begin
  if not (FState in [gsAnalyzing, gsReported]) then
  begin
    Log('ERROR: RADIO RECEIVER OFFLINE. NO ACTIVE SECTOR.', True);
    Exit;
  end;

  if not ACmd.HasFlag('FREQ') then
  begin
    Log('STOPPING RADIO RECEIVER...');
    FAudioSynth.Stop;
    Exit;
  end;

  FreqStr := ACmd.GetFlagValue('FREQ', '0');
  FreqVal := StrToFloatDef(FreqStr, 0.0);

  Log(Format('TUNING RECEIVER TO %.1f MHz...', [FreqVal]));

  if (Abs(FreqVal - 1420.0) < 5.0) and FDataModel.HasBiosignature then
  begin
    if not FDataModel.IsDecrypted then
    begin
      if not FDataModel.IsDecrypting then
      begin
        Log('!!! CRITICAL WARNING !!!', True);
        Log('UNKNOWN ENCRYPTED TRANSMISSION DETECTED ON HYDROGEN LINE.', True);
        Log('SIGNAL DECAY IN 60 SECONDS. INITIATE DECRYPTION IMMEDIATELY!', True);
        Log('USE: DECODE -FREQ <1.0-9.0> -PHASE <0.0-9.9>', True);
        FDataModel.StartDecryption;
        FDecryptionDeadline := IncSecond(Now, 60);
        FAudioSynth.PlaySignal(stNoise);
        if Assigned(FOnDataUpdated) then FOnDataUpdated(Self);
      end
      else
        Log('ERROR: DECRYPTION ALREADY IN PROGRESS. USE DECODE COMMAND.', True);
      Exit;
    end;

    Log('>>> ANOMALY DETECTED: ORGANIC PATTERN ENCRYPTED IN HYDROGEN LINE.');
    FAudioSynth.PlaySignal(stBiosignature);
  end
  else if (Abs(FreqVal - 1618.0) < 5.0) and FDataModel.HasMegastructure then
  begin
    if not FDataModel.IsDecrypted then
    begin
      if not FDataModel.IsDecrypting then
      begin
        Log('!!! CRITICAL WARNING !!!', True);
        Log('UNKNOWN ENCRYPTED TRANSMISSION DETECTED ON SYNTHETIC BAND.', True);
        Log('SIGNAL DECAY IN 60 SECONDS. INITIATE DECRYPTION IMMEDIATELY!', True);
        Log('USE: DECODE -FREQ <1.0-9.0> -PHASE <0.0-9.9>', True);
        FDataModel.StartDecryption;
        FDecryptionDeadline := IncSecond(Now, 60);
        FAudioSynth.PlaySignal(stNoise);
        if Assigned(FOnDataUpdated) then FOnDataUpdated(Self);
      end
      else
        Log('ERROR: DECRYPTION ALREADY IN PROGRESS. USE DECODE COMMAND.', True);
      Exit;
    end;

    Log('!!! CRITICAL ALERT: HIGH ENERGY SYNTHETIC DRONE DETECTED.');
    FAudioSynth.PlaySignal(stMegastructure);
  end
  else
  begin
    Log('MONITORING BACKGROUND NOISE... (EMPTY)');
    FAudioSynth.PlaySignal(stNoise);
  end;
end;

procedure TCoreSimulationEngine.CmdUpgrade(const ACmd: TCommandData);
begin
  if ACmd.HasFlag('SENSOR') then
  begin
    if FDatabase.SensorLevel > 1 then
    begin
      Log('ERROR: ADVANCED SENSOR IS ALREADY INSTALLED.', True);
      Exit;
    end;

    if FResearchFunding < 300000 then
    begin
      Log('INSUFFICIENT FUNDS. $300,000 REQUIRED FOR SENSOR UPGRADE.', True);
      FAudioSynth.PlayFail;
      Exit;
    end;

    FDatabase.SaveUpgrade(2, FDatabase.RadarLevel);
    Log('SUCCESS! SENSOR UPGRADED TO LV.2 (NOISE REDUCED)');
    FAudioSynth.PlaySuccess;
    SyncDatabaseMetrics;
  end
  else if ACmd.HasFlag('RADAR') then
  begin
    if FDatabase.RadarLevel > 1 then
    begin
      Log('ERROR: DEEP SPACE RADAR IS ALREADY INSTALLED.', True);
      Exit;
    end;

    if FResearchFunding < 500000 then
    begin
      Log('INSUFFICIENT FUNDS. $500,000 REQUIRED FOR RADAR UPGRADE.', True);
      FAudioSynth.PlayFail;
      Exit;
    end;

    FDatabase.SaveUpgrade(FDatabase.SensorLevel, 2);
    Log('SUCCESS! DEEP SPACE RADAR UPGRADED TO LV.2 (STAR CLASSIFICATION UNLOCKED)');
    FAudioSynth.PlaySuccess;

    if Assigned(FOnDataUpdated) then FOnDataUpdated(Self);
    SyncDatabaseMetrics;
  end
  else
    Log('ERROR: SPECIFY UPGRADE TYPE (-SENSOR OR -RADAR)', True);
end;

procedure TCoreSimulationEngine.CmdFilter(const ACmd: TCommandData);
var
  ModeStr: string;
  SigmaStr: string;
begin
  if FDataModel.IsDecrypting then
  begin
    Log('ERROR: FILTER OFFLINE DURING DECRYPTION EMERGENCY.', True);
    Exit;
  end;

  if FState <> gsAnalyzing then
  begin
    Log('ERROR: NO UNPROCESSED DATA LOADED FOR ANALYSIS', True);
    Exit;
  end;

  ModeStr := ACmd.GetFlagValue('MODE', 'GAUSSIAN');
  Log('FILTERING NOISE... ' + ModeStr);

  if ModeStr = 'GAUSSIAN' then
  begin
    SigmaStr := ACmd.GetFlagValue('SIGMA', '5.0');
    TBackgroundWorkerThread.CreateFilterGaussian(FDataModel, StrToFloatDef(SigmaStr, 5.0), @OnFilterComplete);
  end
  else if ModeStr = 'MOVINGAVG' then
    TBackgroundWorkerThread.CreateFilterMA(FDataModel, 15, @OnFilterComplete)
  else
    Log('ERROR: UNSUPPORTED FILTER MODE', True);
end;

procedure TCoreSimulationEngine.CmdScanBio(const ACmd: TCommandData);
begin
  if FState <> gsAnalyzing then
  begin
    Log('ERROR: NO ACTIVE SECTOR', True);
    Exit;
  end;

  if not ACmd.HasFlag('BIO') then
  begin
    Log('ERROR: SPECIFY SCAN TYPE (EG: -BIO)', True);
    Exit;
  end;

  Log('INITIATING BIOSIGNATURE & ANOMALY SCAN...');

  if (FDataModel.HasMegastructure or FDataModel.HasBiosignature) and not FDataModel.IsDecrypted then
  begin
    if not FDataModel.IsDecrypting then
    begin
      Log('!!! CRITICAL WARNING !!!', True);
      Log('UNKNOWN ENCRYPTED TRANSMISSION DETECTED.', True);
      Log('SIGNAL DECAY IN 60 SECONDS. INITIATE DECRYPTION IMMEDIATELY!', True);
      Log('USE: DECODE -FREQ <1.0-9.0> -PHASE <0.0-9.9>', True);

      FDataModel.StartDecryption;
      FDecryptionDeadline := IncSecond(Now, 60);
      FAudioSynth.PlaySignal(stNoise);

      if Assigned(FOnDataUpdated) then FOnDataUpdated(Self);
    end
    else
    begin
      Log('ERROR: DECRYPTION ALREADY IN PROGRESS. USE DECODE COMMAND.', True);
      Log(Format('TIME REMAINING: %d SECONDS', [SecondsBetween(Now, FDecryptionDeadline)]), True);
    end;
    Exit;
  end;

  if FDataModel.HasMegastructure then
  begin
    Log('!!! WARNING !!! ARTIFICIAL SIGNATURE DETECTED!', True);
    Log('!!! WARNING !!! SPECTRUM INDICATES SYNTHETIC ALLOY (TITANIUM/IRON).', True);
    FScanResultType := 'MEGASTRUCTURE';
  end
  else if FDataModel.HasBiosignature then
  begin
    Log('>>> CONFIRMED: HIGH CONCENTRATION OF O2 AND H2O DETECTED.');
    Log('>>> ORGANIC BIOSIGNATURE LIKELY.');
    FScanResultType := 'BIO-CONFIRMED';
  end
  else
  begin
    Log('SCAN COMPLETE: NO ANOMALIES FOUND. DEAD WORLD.');
    FScanResultType := '';
  end;
end;

procedure TCoreSimulationEngine.CmdDecode(const ACmd: TCommandData);
var
  Freq, Phase: Double;
  ScanCmd: TCommandData;
begin
  if not FDataModel.IsDecrypting then
  begin
    Log('ERROR: NO ACTIVE ENCRYPTED SIGNAL TO DECODE.', True);
    Exit;
  end;

  if Now > FDecryptionDeadline then
  begin
    Log('!!! CRITICAL FAILURE: SIGNAL LOST !!!', True);
    Log('TRANSMISSION DECAYED BEFORE DECRYPTION COULD BE COMPLETED.', True);
    Log('SECTOR DATA CORRUPTED. DISCONNECTING...', True);

    FAudioSynth.PlayFail;
    FAudioSynth.Stop;

    FDataModel.Clear;
    SetState(gsIdle);
    if Assigned(FOnDataUpdated) then FOnDataUpdated(Self);
    Exit;
  end;

  Freq := ACmd.GetFlagValueAsFloat('FREQ', 1.0);
  Phase := ACmd.GetFlagValueAsFloat('PHASE', 0.0);

  Log(Format('ATTEMPTING DECODE: FREQ %.1f | PHASE %.1f', [Freq, Phase]));

  if FDataModel.AttemptDecode(Freq, Phase) then
  begin
    Log('>>> DECRYPTION SUCCESSFUL! <<<', False);
    Log('SIGNAL LOCK ESTABLISHED. ALIEN TRANSMISSION INTERCEPTED.', False);

    FAudioSynth.Stop;
    FAudioSynth.PlaySuccess;

    FExpendedFunding := FExpendedFunding - 10000000; // Bonus Uang
    SyncDatabaseMetrics;
    Log('CRITICAL DISCOVERY BONUS: $10,000,000 GRANTED!', True);

    ScanCmd := TCommandLexer.Parse('SCAN -BIO');
    CmdScanBio(ScanCmd);

    if Assigned(FOnDataUpdated) then FOnDataUpdated(Self);
  end
  else
  begin
    Log('DECRYPTION FAILED. WAVEFORMS DO NOT MATCH.', True);
    Log(Format('TIME REMAINING: %d SECONDS', [SecondsBetween(Now, FDecryptionDeadline)]), True);
    if Assigned(FOnDataUpdated) then FOnDataUpdated(Self);
  end;
end;

procedure TCoreSimulationEngine.CmdLaunch(const ACmd: TCommandData);
var
  SaveLocation, PrimaryType: string;
begin
  if FDataModel.IsDecrypting then
  begin
    Log('ERROR: CANNOT LAUNCH PROBES DURING DECRYPTION EMERGENCY.', True);
    Exit;
  end;

  if not (FState in [gsAnalyzing, gsReported]) then
  begin
    Log('ERROR: NO ACTIVE SECTOR. CANNOT LAUNCH PROBE.', True);
    Exit;
  end;

  if not ACmd.HasFlag('PROBE') then
  begin
    Log('ERROR: SPECIFY LAUNCH TYPE (EG: -PROBE)', True);
    Exit;
  end;

  if FDataModel.GetPlanetCount = 0 then
  begin
    Log('LAUNCH FAILED: NO PLANETARY TARGETS DETECTED IN THIS SECTOR.', True);
    FAudioSynth.PlayFail;
    Exit;
  end;

  if FResearchFunding < 1000000 then
  begin
    Log('INSUFFICIENT FUNDS. $1,000,000 REQUIRED FOR SURFACE PROBE LAUNCH.', True);
    FAudioSynth.PlayFail;
    Exit;
  end;

  FExpendedFunding := FExpendedFunding + 1000000; // Biaya Probe
  SyncDatabaseMetrics;
  FAudioSynth.PlaySuccess;

  Log('>>> INITIATING PROBE LAUNCH SEQUENCE...');
  Log('>>> TRAJECTORY CALCULATED. IMPACT IN T-MINUS 3 SECONDS.');

  if FScanResultType <> '' then
    PrimaryType := FScanResultType
  else
    PrimaryType := FDataModel.Planets[0].PlanetType;

  SaveLocation := TSurfaceProbeRenderer.LaunchProbe(FDataModel.SectorName, PrimaryType);

  Log('>>> TOUCHDOWN CONFIRMED. SURFACE IMAGING SUCCESSFUL.');
  Log('IMAGE SAVED TO: ' + SaveLocation);
end;

procedure TCoreSimulationEngine.CmdExport(const ACmd: TCommandData);
var
  SaveLocation, PrimaryType: string;
  PlanetCount: Integer;
  IsHabitable: Boolean;
  EstimatedValue: Double;
begin
  if FDataModel.IsDecrypting then
  begin
    Log('ERROR: EXPORT OFFLINE DURING DECRYPTION EMERGENCY.', True);
    Exit;
  end;

  if not (FState in [gsAnalyzing, gsReported]) then
  begin
    Log('ERROR: NO ACTIVE SECTOR DATA TO EXPORT.', True);
    Exit;
  end;

  if not ACmd.HasFlag('PDF') then
  begin
    Log('ERROR: SPECIFY EXPORT FORMAT (EG: -PDF)', True);
    Exit;
  end;

  Log('>>> COMPILING DISCOVERY DATA...');

  PlanetCount := FDataModel.GetPlanetCount;

  if PlanetCount = 0 then
  begin
    Log('EXPORT FAILED: NO PLANETARY DATA TO DOCUMENT.', True);
    FAudioSynth.PlayFail;
    Exit;
  end;

  FAudioSynth.PlaySuccess;

  if FScanResultType <> '' then
    PrimaryType := FScanResultType
  else
    PrimaryType := FDataModel.Planets[0].PlanetType;

  IsHabitable := FDataModel.HasBiosignature or
    TKeplerPhysics.IsHabitable(
      TKeplerPhysics.CalculateSemiMajorAxis(FDataModel.Planets[0].PeriodOffset * 0.5, FDataModel.Star.Mass),
      TKeplerPhysics.CalculateHabitableZone(FDataModel.Star.Luminosity));

  EstimatedValue := 100000;
  if IsHabitable then EstimatedValue := EstimatedValue + 500000;
  if PrimaryType = 'MEGASTRUCTURE' then EstimatedValue := EstimatedValue + 5000000
  else if PrimaryType = 'BIO-CONFIRMED' then EstimatedValue := EstimatedValue + 2000000;

  SaveLocation := TReportExporter.GeneratePDF(
    FDataModel.SectorName, FDataModel.Star.ClassName, PrimaryType,
    PlanetCount, IsHabitable, EstimatedValue
  );

  Log('>>> EXPORT COMPLETE. CLASSIFIED DOCUMENT SAVED TO:');
  Log(SaveLocation);
end;

procedure TCoreSimulationEngine.CmdReport(const ACmd: TCommandData);
var
  DiscoveryData: TExoplanetDiscovery;
  DipsFound, PlanetCount, HabitableCount, PIdx: Integer;
  HZ: THabitableZone;
  SemiMajorAxis: Double;
begin
  if FDataModel.IsDecrypting then
  begin
    Log('ERROR: CANNOT REPORT WHILE SIGNAL IS DECAYING! MUST DECODE FIRST.', True);
    Exit;
  end;

  if FState = gsReported then
  begin
    Log('ERROR: SECTOR HAS ALREADY BEEN CATALOGED.', True);
    Exit;
  end;

  if FState <> gsAnalyzing then
  begin
    Log('ERROR: NO ACTIVE SECTOR TO REPORT', True);
    Exit;
  end;

  DipsFound := TSignalProcessor.DetectTransitDips(FDataModel.FilteredFlux, 0.98, 10);

  if (DipsFound = 0) or (not FDataModel.HasAnomaly) then
  begin
    Log('REPORT FAILED: NO TRANSIT SIGNATURE DETECTED. PENALTY APPLIED.', True);
    FAudioSynth.PlayFail;

    FExpendedFunding := FExpendedFunding + 10000; // Penalti Salah Lapor
    FDatabase.SaveDiscovery(Default(TExoplanetDiscovery));
    SyncDatabaseMetrics;
    FGalaxyMap.UpdateSectorStatus(FDataModel.SectorName, False);
    SetState(gsIdle);
    Exit;
  end;

  FAudioSynth.PlaySuccess;
  FGalaxyMap.UpdateSectorStatus(FDataModel.SectorName, True);

  PlanetCount := FDataModel.GetPlanetCount;
  Log(Format('MULTI-PLANETARY SYSTEM DETECTED: %d PLANET(S) FOUND', [PlanetCount]));
  HabitableCount := 0;

  HZ := TKeplerPhysics.CalculateHabitableZone(FDataModel.Star.Luminosity);

  for PIdx := 0 to PlanetCount - 1 do
  begin
    DiscoveryData.SectorName := FDataModel.SectorName + '-' + Chr(Ord('b') + PIdx);

    if FScanResultType <> '' then
      DiscoveryData.PlanetType := FScanResultType
    else
      DiscoveryData.PlanetType := FDataModel.Planets[PIdx].PlanetType;

    DiscoveryData.PlanetRadius := FDataModel.Planets[PIdx].PlanetRadiusEarth;
    DiscoveryData.OrbitalPeriod := FDataModel.Planets[PIdx].PeriodOffset * 0.5;
    DiscoveryData.BiosignatureConfidence := Random * 100;

    SemiMajorAxis := TKeplerPhysics.CalculateSemiMajorAxis(DiscoveryData.OrbitalPeriod, FDataModel.Star.Mass);
    DiscoveryData.IsHabitable := TKeplerPhysics.IsHabitable(SemiMajorAxis, HZ);

    if FDatabase.SaveDiscovery(DiscoveryData) then
    begin
      Log(Format('  -> %s [%s] CATALOGED SUCCESSFULLY.', [DiscoveryData.SectorName, DiscoveryData.PlanetType]));
      if DiscoveryData.IsHabitable then Inc(HabitableCount);
    end
    else
      Log(Format('ERROR: DATABASE WRITE FAILED FOR %s', [DiscoveryData.SectorName]), True);
  end;

  Log('ALL DISCOVERIES REPORTED! FUNDING GRANTED.');
  if HabitableCount > 0 then
    Log(Format('[ALERT] %d PLANET(S) CONFIRMED IN HABITABLE ZONE!', [HabitableCount]));

  if FScanResultType = 'MEGASTRUCTURE' then
    Log('!!! MEGASTRUCTURE BONUS FUNDING ACQUIRED !!!', True);

  SyncDatabaseMetrics;
  SetState(gsReported);
end;

end.
