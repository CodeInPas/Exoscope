program ExoScopeOps;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF HASAMIGA}
  athreads,
  {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, tachartlazaruspkg, fraControlDock, fraLightCurveChart,
  fraSpectrumChart, fraTerminalPanel, fraVectorVisualizer, uGlassmorphismCache,
  uViewDashboardRenderer, uDigitalSignalProcessing, uKeplerPhysics,
  uCatalogDatabaseManager, uTelemetryDataModel, uBackgroundWorkerThread,
  uCommandLexer, uCoreSimulationEngine, BASS, fraStarmap, fMainDashboard,
  UnitAbout;

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Title:='ExoScope';
  Application.Scaled:=True;
  Application.Initialize;
  Application.CreateForm(TMainDashboard, MainDashboard);
  Application.Run;
end.
