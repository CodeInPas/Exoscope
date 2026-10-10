unit fMainDashboard;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  ComCtrls, Menus, SimLcdDisplay, TwLazUI.Button, TwLazUI.CheckBox, LCLIntf,
  TwLazUI.TrackBar, SynHighlighterGalaxy,
  uCoreSimulationEngine, uViewDashboardRenderer,
  fraTerminalPanel, fraLightCurveChart, fraSpectrumChart, fraVectorVisualizer,
  fraStarmap,UnitAbout;

type
  { TMainDashboard }
  TMainDashboard = class(TForm)
    btnReportDiscovery: TTwLazUIButton;
    FrameVectorVisualizer1: TFrameVectorVisualizer;
    lblAlerts: TLabel;
    lblFunding: TLabel;
    lblPoints: TLabel;
    MainMenu1: TMainMenu;
    MenuItem1: TMenuItem;
    MenuItem2: TMenuItem;
    mnTutorialID: TMenuItem;
    mnTutorialEN: TMenuItem;
    mnExit: TMenuItem;
    mnTutorial: TMenuItem;
    mnAbout: TMenuItem;
    pbVectorCanvas: TPaintBox;
    pnlBackground: TPanel;
    pnlCharts: TPanel;
    pnlControlDock: TPanel;
    pnlRight: TPanel;
    pnlRightTop: TPanel;
    pnlTerminal: TPanel;
    pnlTopBar: TPanel;

    lblCtrlTitle: TLabel;
    pnlVector: TPanel;
    shpCtrlDivider: TShape;
    pnlLeftCtrl: TPanel;
    pnlRightCtrl: TPanel;
    lblFilterMode: TLabel;
    cbFilterMode: TComboBox;
    lblBandwidth: TLabel;
    lblBandwidthVal: TLabel;
    SynGalaxySyn1: TSynGalaxySyn;
    lblNoiseGate: TLabel;
    lblNoiseGateVal: TLabel;
    lblThreshold: TLabel;
    lblThresholdVal: TLabel;

    FrameTerminal1: TFrameTerminal;
    FrameLightCurve1: TFrameLightCurve;
    FrameSpectrum1: TFrameSpectrum;
    FrameStarmap1: TFrameStarmap;
    tbNoiseGate: TTwLazUITrackBar;
    tbBandwidth: TTwLazUITrackBar;
    tmrAnimation: TTimer;
    tmrAnimation1: TTimer;
    tmrAnimation2: TTimer;
    btnApplyFilterClick: TTwLazUIButton;
    tbThreshold: TTwLazUITrackBar;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure cClick(Sender: TObject);
    procedure btnReportDiscoveryClick(Sender: TObject);
    procedure mnTutorialENClick(Sender: TObject);
    procedure mnTutorialIDClick(Sender: TObject);
    procedure mnAboutClick(Sender: TObject);
    procedure mnExitClick(Sender: TObject);
    procedure mnTutorialClick(Sender: TObject);
    procedure tbBandwidthChange(Sender: TObject);
    procedure tbNoiseGateChange(Sender: TObject);
    procedure tbThresholdChange(Sender: TObject);
    procedure tmrAnimationTimer(Sender: TObject);
  private
    FEngine: TCoreSimulationEngine;
    FRenderer: TViewDashboardRenderer;

    FTransitionTimer: TTimer;

    procedure EngineLogMessage(const AMessage: string; AIsError: Boolean);
    procedure EngineStateChanged(Sender: TObject);
    procedure EngineDataUpdated(Sender: TObject);
    procedure EngineViewChanged(const AView: string);
    procedure EngineMapRebuilt(Sender: TObject); // Event penyambung Load Game

    procedure TerminalClearLog;
    procedure TerminalCommandEntered(Sender: TObject; const ACommand: string);
    procedure RenderVectorTarget(ABitmap: TObject; APhase: Double; AHasAnomaly: Boolean);
    procedure StarmapSectorSelected(Sender: TObject; const ASectorName: string);

    procedure OnTransitionTick(Sender: TObject);
  public
  end;

var
  MainDashboard: TMainDashboard;

implementation

{$R *.lfm}

uses BGRABitmap;

{ TMainDashboard }

procedure TMainDashboard.FormCreate(Sender: TObject);
var
  DbPath, DbDir: string;
begin
  DbPath := ExtractFilePath(Application.ExeName) + '..\db\catalog.sqlite';
  DbDir := ExtractFilePath(DbPath);

  if not DirectoryExists(DbDir) then
    ForceDirectories(DbDir);

  FEngine := TCoreSimulationEngine.Create(DbPath);

  // Hubungkan event Map Rebuilt untuk fitur Load Game
  FEngine.OnMapRebuilt := @EngineMapRebuilt;

  if Assigned(FEngine.Audio) then
    FEngine.Audio.PlayAmbient;

  FEngine.OnLogMessage := @EngineLogMessage;
  FEngine.OnStateChanged := @EngineStateChanged;
  FEngine.OnDataUpdated := @EngineDataUpdated;
  FEngine.OnClearTerminal := @TerminalClearLog;
  FEngine.OnViewChanged := @EngineViewChanged;

  FRenderer := TViewDashboardRenderer.Create(FEngine.DataModel);
  FRenderer.BindLightCurveChart(FrameLightCurve1.chrtLightCurve, FrameLightCurve1.serRawFlux, FrameLightCurve1.serFlux);
  FRenderer.BindSpectrumChart(FrameSpectrum1.chrtSpectrum, FrameSpectrum1.serSpectrum);

  FrameTerminal1.OnCommandEntered := @TerminalCommandEntered;
  FrameTerminal1.AudioEngine := FEngine.Audio;
  FrameVectorVisualizer1.OnRenderFrame := TVectorRenderEvent(@RenderVectorTarget);

  FrameStarmap1.BindModel(FEngine.GalaxyMap);
  FrameStarmap1.RadarLevel := FEngine.Database.RadarLevel;
  FrameStarmap1.AudioEngine := FEngine.Audio;

  FrameStarmap1.OnSectorSelect := @StarmapSectorSelected;
  FrameStarmap1.Visible := False;
  FrameStarmap1.Align := alClient;

  FTransitionTimer := TTimer.Create(Self);
  FTransitionTimer.Interval := 30;
  FTransitionTimer.OnTimer := @OnTransitionTick;
  FTransitionTimer.Enabled := False;

  tbBandwidthChange(Self);
  tbNoiseGateChange(Self);
  tbThresholdChange(Self);

  EngineStateChanged(Self);
end;

procedure TMainDashboard.FormDestroy(Sender: TObject);
begin
  if Assigned(FEngine) and Assigned(FEngine.Audio) then
    FEngine.Audio.StopAmbient;

  FTransitionTimer.Free;
  FRenderer.Free;
  FEngine.Free;
end;

procedure TMainDashboard.EngineLogMessage(const AMessage: string; AIsError: Boolean);
begin
  FrameTerminal1.AddLog(AMessage, AIsError);
end;

procedure TMainDashboard.TerminalClearLog;
begin
  FrameTerminal1.memLog.Clear;
end;

procedure TMainDashboard.EngineMapRebuilt(Sender: TObject);
begin
  // Fungsi vital: Saat LOAD ditekan, hubungkan ulang Peta Galaksi yang baru
  FrameStarmap1.BindModel(FEngine.GalaxyMap);
end;

procedure TMainDashboard.EngineStateChanged(Sender: TObject);
var
  AlertText: string;
begin
  lblFunding.Caption := 'RESEARCH FUNDING: $' + FormatFloat('#,##0', FEngine.ResearchFunding);
  lblPoints.Caption := 'DISCOVERY POINTS: ' + IntToStr(FEngine.DiscoveryPoints);

  if FEngine.DataModel.IsDecrypting then
    AlertText := '!!! CRITICAL ALERT: DECRYPTION IN PROGRESS !!!'
  else if FEngine.State = gsIdle then
    AlertText := Format('SYSTEM ONLINE | SENSOR LV.%d | RADAR LV.%d',
      [FEngine.Database.SensorLevel, FEngine.Database.RadarLevel])
  else if FEngine.State = gsReported then
    AlertText := Format('SYSTEM CATALOGED | PLANETS REVEALED | SENSOR LV.%d',
      [FEngine.Database.SensorLevel])
  else
    AlertText := Format('DATA ACQUIRED | SENSOR LV.%d | RADAR LV.%d',
      [FEngine.Database.SensorLevel, FEngine.Database.RadarLevel]);

  lblAlerts.Caption := AlertText;

  if FrameStarmap1.RadarLevel <> FEngine.Database.RadarLevel then
    FrameStarmap1.RadarLevel := FEngine.Database.RadarLevel;

  if FEngine.State = gsAnalyzing then
  begin
    FrameVectorVisualizer1.StartAnimation(FEngine.DataModel.HasAnomaly);
    if not FEngine.DataModel.IsDecrypting then
      tbBandwidthChange(Self);
  end
  else if FEngine.State = gsReported then
  begin
    FrameVectorVisualizer1.StartAnimation(FEngine.DataModel.HasAnomaly);
  end
  else if FEngine.State = gsIdle then
  begin
    FrameVectorVisualizer1.StopAnimation;
    FRenderer.RefreshCharts;
  end;
end;

procedure TMainDashboard.EngineDataUpdated(Sender: TObject);
begin
  FRenderer.RefreshCharts;
  EngineStateChanged(Self);
end;

procedure TMainDashboard.EngineViewChanged(const AView: string);
begin
  if AView = 'MAP' then
  begin
    FrameLightCurve1.Visible := False;
    FrameSpectrum1.Visible := False;

    FrameStarmap1.Visible := True;
    FrameStarmap1.BringToFront;
    FrameStarmap1.StartFadeIn;
  end
  else if AView = 'CHARTS' then
  begin
    if FrameStarmap1.Visible then
    begin
      FrameStarmap1.StartFadeOut;
      FTransitionTimer.Enabled := True;
    end
    else
    begin
      FrameLightCurve1.Visible := True;
      FrameSpectrum1.Visible := True;
    end;
  end;
end;

procedure TMainDashboard.OnTransitionTick(Sender: TObject);
begin
  if FrameStarmap1.FadeComplete then
  begin
    FTransitionTimer.Enabled := False;

    FrameStarmap1.Visible := False;
    FrameLightCurve1.Visible := True;
    FrameSpectrum1.Visible := True;
  end;
end;

procedure TMainDashboard.StarmapSectorSelected(Sender: TObject; const ASectorName: string);
begin
  FrameStarmap1.SetSelectedSector(ASectorName);
  FEngine.ExecuteCommandString('CONNECT -SECTOR ' + ASectorName);

  if FEngine.State <> gsIdle then
    EngineViewChanged('CHARTS');
end;

procedure TMainDashboard.TerminalCommandEntered(Sender: TObject; const ACommand: string);
begin
  FEngine.ExecuteCommandString(ACommand);
end;

procedure TMainDashboard.cClick(Sender: TObject);
var
  FilterMode: string;
  SigmaVal: Double;
begin
  FilterMode := 'GAUSSIAN';
  if cbFilterMode.ItemIndex = 1 then
    FilterMode := 'MOVINGAVG';

  SigmaVal := (tbThreshold.Position / 100.0) * 10.0;
  if SigmaVal <= 0 then SigmaVal := 1.0;

  FEngine.ExecuteCommandString('FILTER -MODE ' + FilterMode + ' -SIGMA ' + FloatToStr(SigmaVal));
end;

procedure TMainDashboard.btnReportDiscoveryClick(Sender: TObject);
begin
  FEngine.ExecuteCommandString('REPORT');
end;

procedure TMainDashboard.mnTutorialENClick(Sender: TObject);
begin
  OpenDocument(ExtractFilePath(Application.ExeName) + 'help/tutorial_exoscope_en.pdf');
end;

procedure TMainDashboard.mnTutorialIDClick(Sender: TObject);
begin
  OpenDocument(ExtractFilePath(Application.ExeName) + 'help/tutorial_exoscope_id.pdf');
end;

procedure TMainDashboard.mnAboutClick(Sender: TObject);
var
  F : TFormAbout;
begin

  try
    F := TFormAbout.Create(self);
    F.ShowModal;
  finally
    F.Free;
  end;

end;

procedure TMainDashboard.mnExitClick(Sender: TObject);
begin
  Application.Terminate;
end;

procedure TMainDashboard.mnTutorialClick(Sender: TObject);
begin
  OpenDocument(ExtractFilePath(Application.ExeName) + 'tutorial_exoscope.pdf');
end;

procedure TMainDashboard.tbBandwidthChange(Sender: TObject);
begin
  lblBandwidthVal.Caption := IntToStr(tbBandwidth.Position) + ' nm';

  if Assigned(FEngine) and Assigned(FEngine.Audio) then
    FEngine.Audio.PlaySlider;

  if (Assigned(FEngine)) and (FEngine.State = gsAnalyzing) then
  begin
    FEngine.DataModel.GenerateSpectrumData(tbBandwidth.Position);
    if Assigned(FRenderer) then FRenderer.RefreshCharts;
  end;
end;

procedure TMainDashboard.tbNoiseGateChange(Sender: TObject);
begin
  lblNoiseGateVal.Caption := IntToStr(tbNoiseGate.Position) + ' %';

  if Assigned(FEngine) and Assigned(FEngine.Audio) then
    FEngine.Audio.PlaySlider;
end;

procedure TMainDashboard.tbThresholdChange(Sender: TObject);
begin
  lblThresholdVal.Caption := FloatToStrF(tbThreshold.Position / 100, ffFixed, 4, 2);

  if Assigned(FEngine) and Assigned(FEngine.Audio) then
    FEngine.Audio.PlaySlider;
end;

procedure TMainDashboard.tmrAnimationTimer(Sender: TObject);
begin

end;

procedure TMainDashboard.RenderVectorTarget(ABitmap: TObject; APhase: Double; AHasAnomaly: Boolean);
var
  RevealPlanets: Boolean;
begin
  RevealPlanets := (FEngine.State = gsReported) and AHasAnomaly;

  if ABitmap is TBGRABitmap then
    FRenderer.RenderVectorTarget(TBGRABitmap(ABitmap), APhase, RevealPlanets);
end;

end.
