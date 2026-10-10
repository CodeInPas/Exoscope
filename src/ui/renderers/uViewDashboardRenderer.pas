unit uViewDashboardRenderer;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, Math,
  TAGraph, TASources, TACustomSource, TACustomSeries, TASeries, TAChartUtils,
  BGRABitmap, BGRABitmapTypes,
  uTelemetryDataModel, uKeplerPhysics;

type
  { TViewDashboardRenderer }
  TViewDashboardRenderer = class
  private
    FDataModel: TTelemetryDataModel;

    { Referensi komponen UI untuk Grafik Light Curve }
    FLightCurveChart: TChart;
    FRawFluxSeries: TLineSeries;
    FLightCurveSeries: TLineSeries;
    FRawFluxSource: TUserDefinedChartSource;
    FLightCurveSource: TUserDefinedChartSource;

    { Referensi komponen UI untuk Grafik Spektrum }
    FSpectrumChart: TChart;
    FSpectrumSeries: TLineSeries;
    FSpectrumSource: TUserDefinedChartSource;

    { Event handler untuk TUserDefinedChartSource }
    procedure OnGetRawFluxItem(ASource: TUserDefinedChartSource; AIndex: Integer; var AItem: TChartDataItem);
    procedure OnGetLightCurveItem(ASource: TUserDefinedChartSource; AIndex: Integer; var AItem: TChartDataItem);
    procedure OnGetSpectrumItem(ASource: TUserDefinedChartSource; AIndex: Integer; var AItem: TChartDataItem);
  public
    constructor Create(ADataModel: TTelemetryDataModel);
    destructor Destroy; override;

    procedure BindLightCurveChart(AChart: TChart; ARawSeries, AFilteredSeries: TLineSeries);
    procedure BindSpectrumChart(AChart: TChart; ASeries: TLineSeries);

    procedure RefreshCharts;
    procedure RenderVectorTarget(ATargetBitmap: TBGRABitmap; APhase: Double; AHasAnomaly: Boolean);
  end;

implementation

{ TViewDashboardRenderer }

constructor TViewDashboardRenderer.Create(ADataModel: TTelemetryDataModel);
begin
  inherited Create;
  FDataModel := ADataModel;

  FRawFluxSource := TUserDefinedChartSource.Create(nil);
  FRawFluxSource.OnGetChartDataItem := @OnGetRawFluxItem;

  FLightCurveSource := TUserDefinedChartSource.Create(nil);
  FLightCurveSource.OnGetChartDataItem := @OnGetLightCurveItem;

  FSpectrumSource := TUserDefinedChartSource.Create(nil);
  FSpectrumSource.OnGetChartDataItem := @OnGetSpectrumItem;
end;

destructor TViewDashboardRenderer.Destroy;
begin
  FRawFluxSource.Free;
  FLightCurveSource.Free;
  FSpectrumSource.Free;
  inherited Destroy;
end;

procedure TViewDashboardRenderer.OnGetRawFluxItem(ASource: TUserDefinedChartSource; AIndex: Integer; var AItem: TChartDataItem);
begin
  if not Assigned(FDataModel) then Exit;

  if FDataModel.IsDecrypting then
  begin
    if (AIndex < 0) or (AIndex >= Length(FDataModel.DecryptionAlienWave)) then Exit;
    AItem.X := AIndex;
    AItem.Y := FDataModel.DecryptionAlienWave[AIndex];
    AItem.Color := clFuchsia;
    Exit;
  end;

  if (AIndex < 0) or (AIndex >= FDataModel.DataCount) then Exit;
  AItem.X := FDataModel.TimeSteps[AIndex];
  AItem.Y := FDataModel.RawFlux[AIndex];
  AItem.Color := clTAColor;
end;

procedure TViewDashboardRenderer.OnGetLightCurveItem(ASource: TUserDefinedChartSource; AIndex: Integer; var AItem: TChartDataItem);
begin
  if not Assigned(FDataModel) then Exit;

  if FDataModel.IsDecrypting then
  begin
    if (AIndex < 0) or (AIndex >= Length(FDataModel.DecryptionPlayerWave)) then Exit;
    AItem.X := AIndex;
    AItem.Y := FDataModel.DecryptionPlayerWave[AIndex];
    AItem.Color := clAqua;
    Exit;
  end;

  if (AIndex < 0) or (AIndex >= FDataModel.DataCount) then Exit;
  AItem.X := FDataModel.TimeSteps[AIndex];
  AItem.Y := FDataModel.FilteredFlux[AIndex];
  AItem.Color := clTAColor;
end;

procedure TViewDashboardRenderer.OnGetSpectrumItem(ASource: TUserDefinedChartSource; AIndex: Integer; var AItem: TChartDataItem);
begin
  if not Assigned(FDataModel) or (AIndex < 0) or (AIndex >= FDataModel.SpectrumCount) then Exit;
  AItem.X := FDataModel.Wavelengths[AIndex];
  AItem.Y := FDataModel.SpectrumFlux[AIndex];

  if (AItem.X >= 490) and (AItem.X <= 510) and FDataModel.HasMegastructure then
    AItem.Color := clFuchsia
  else if (AItem.X >= 750) and (AItem.X <= 770) and FDataModel.HasBiosignature then
    AItem.Color := clLime
  else if (AItem.X >= 930) and (AItem.X <= 950) and FDataModel.HasBiosignature then
    AItem.Color := clAqua
  else
    AItem.Color := clTAColor;
end;

procedure TViewDashboardRenderer.BindLightCurveChart(AChart: TChart; ARawSeries, AFilteredSeries: TLineSeries);
begin
  FLightCurveChart := AChart;
  FRawFluxSeries := ARawSeries;
  FLightCurveSeries := AFilteredSeries;

  if Assigned(FRawFluxSeries) then FRawFluxSeries.Source := FRawFluxSource;
  if Assigned(FLightCurveSeries) then FLightCurveSeries.Source := FLightCurveSource;
end;

procedure TViewDashboardRenderer.BindSpectrumChart(AChart: TChart; ASeries: TLineSeries);
begin
  FSpectrumChart := AChart;
  FSpectrumSeries := ASeries;

  if Assigned(FSpectrumSeries) then FSpectrumSeries.Source := FSpectrumSource;
end;

procedure TViewDashboardRenderer.RefreshCharts;
begin
  if Assigned(FDataModel) then
  begin
    if FDataModel.IsDecrypting then
    begin
      if Assigned(FRawFluxSource) then
      begin
        FRawFluxSource.PointsNumber := Length(FDataModel.DecryptionAlienWave);
        FRawFluxSource.Reset;
      end;
      if Assigned(FLightCurveSource) then
      begin
        FLightCurveSource.PointsNumber := Length(FDataModel.DecryptionPlayerWave);
        FLightCurveSource.Reset;
      end;
    end
    else
    begin
      if Assigned(FRawFluxSource) then
      begin
        FRawFluxSource.PointsNumber := FDataModel.DataCount;
        FRawFluxSource.Reset;
      end;
      if Assigned(FLightCurveSource) then
      begin
        FLightCurveSource.PointsNumber := FDataModel.DataCount;
        FLightCurveSource.Reset;
      end;
    end;

    if Assigned(FSpectrumSource) then
    begin
      FSpectrumSource.PointsNumber := FDataModel.SpectrumCount;
      FSpectrumSource.Reset;
    end;
  end;
end;

procedure TViewDashboardRenderer.RenderVectorTarget(ATargetBitmap: TBGRABitmap; APhase: Double; AHasAnomaly: Boolean);
var
  CX, CY, BaseRadius, StarRadius, SpecificOrbitRadius: Double;
  PlanetX, PlanetY, PlanetPhase: Double;
  PlanetDrawRadius: Double;
  I, PlanetCount: Integer;
  StarColor: TBGRAPixel;
  IsMegastructure: Boolean;

  OldRandSeed: LongInt;
  StarX, StarY: Integer;
  StarBright: Byte;

  // Variabel untuk Efek CRT
  px, py: Integer;
  p: PBGRAPixel;
  MaxDistCRT, DistCRT, Darken: Double;
begin
  if not Assigned(ATargetBitmap) then Exit;

  CX := ATargetBitmap.Width * 0.5;
  CY := ATargetBitmap.Height * 0.5;
  BaseRadius := Min(CX, CY) * 0.28;

  IsMegastructure := Assigned(FDataModel) and FDataModel.HasMegastructure;

  if Assigned(FDataModel) and (FDataModel.Star.Radius > 0) then
  begin
    StarRadius := BaseRadius * Power(FDataModel.Star.Radius, 0.5);

    case FDataModel.Star.StarClass of
      scO: StarColor := BGRA(100, 150, 255, 255);
      scB: StarColor := BGRA(150, 200, 255, 255);
      scA: StarColor := BGRA(240, 240, 255, 255);
      scF: StarColor := BGRA(255, 250, 200, 255);
      scG: StarColor := BGRA(255, 210, 80, 255);
      scK: StarColor := BGRA(255, 130, 30, 255);
      scM: StarColor := BGRA(255, 50, 30, 255);
      else StarColor := BGRA(255, 200, 100, 255);
    end;
  end
  else
  begin
    StarRadius := BaseRadius;
    StarColor := BGRA(255, 200, 100, 255);
  end;

  if Assigned(FDataModel) and FDataModel.IsDecrypting then
    ATargetBitmap.Fill(BGRA(Round(20 + 35 * Abs(Sin(APhase * 5))), 5, 10, 255))
  else
    ATargetBitmap.Fill(BGRA(8, 10, 15, 255));

  OldRandSeed := RandSeed;
  if Assigned(FDataModel) then
    RandSeed := 1024 + Length(FDataModel.SectorName) * 100
  else
    RandSeed := 1024;

  ATargetBitmap.FillEllipseAntialias(CX * 0.4, CY * 0.3, CX * 0.8, CY * 0.6, BGRA(40, 20, 70, 15));
  ATargetBitmap.FillEllipseAntialias(CX * 1.6, CY * 1.5, CX * 0.9, CY * 0.7, BGRA(20, 40, 80, 12));
  ATargetBitmap.FillEllipseAntialias(CX * 1.2, CY * 0.2, CX * 0.7, CY * 0.5, BGRA(80, 20, 50, 10));

  for I := 1 to 200 do
  begin
    StarX := Random(ATargetBitmap.Width);
    StarY := Random(ATargetBitmap.Height);
    StarBright := 20 + Random(120);

    if Random(10) > 8 then
      ATargetBitmap.SetPixel(StarX, StarY, BGRA(150, 200, 255, StarBright))
    else if Random(10) > 8 then
      ATargetBitmap.SetPixel(StarX, StarY, BGRA(255, 220, 150, StarBright))
    else
      ATargetBitmap.SetPixel(StarX, StarY, BGRA(255, 255, 255, StarBright));
  end;

  RandSeed := OldRandSeed;

  if IsMegastructure then
  begin
    ATargetBitmap.FillEllipseAntialias(CX, CY, StarRadius + 12, StarRadius + 12, BGRA(255, 0, 255, 15));
    ATargetBitmap.FillEllipseAntialias(CX, CY, StarRadius + 6, StarRadius + 6, BGRA(255, 0, 255, 40));
    ATargetBitmap.FillEllipseAntialias(CX, CY, StarRadius, StarRadius, BGRA(StarColor.red div 2, StarColor.green div 2, 255, 255));
  end
  else
  begin
    ATargetBitmap.FillEllipseAntialias(CX, CY, StarRadius + 12, StarRadius + 12, BGRA(StarColor.red, StarColor.green, StarColor.blue, 15));
    ATargetBitmap.FillEllipseAntialias(CX, CY, StarRadius + 6, StarRadius + 6, BGRA(StarColor.red, StarColor.green, StarColor.blue, 40));
    ATargetBitmap.FillEllipseAntialias(CX, CY, StarRadius, StarRadius, StarColor);
  end;

  if AHasAnomaly and Assigned(FDataModel) then
  begin
    PlanetCount := FDataModel.GetPlanetCount;

    for I := 0 to PlanetCount - 1 do
    begin
      SpecificOrbitRadius := StarRadius + (BaseRadius * 0.5) + (BaseRadius * FDataModel.Planets[I].OrbitRadius);

      if IsMegastructure then
        ATargetBitmap.EllipseAntialias(CX, CY, SpecificOrbitRadius, SpecificOrbitRadius * 0.3, BGRA(255, 0, 255, 90), 1.0)
      else
        ATargetBitmap.EllipseAntialias(CX, CY, SpecificOrbitRadius, SpecificOrbitRadius * 0.3, BGRA(0, 255, 255, 70), 1.0);

      PlanetPhase := APhase * FDataModel.Planets[I].OrbitSpeed;
      PlanetX := CX + SpecificOrbitRadius * Cos(PlanetPhase * 2 * Pi);
      PlanetY := CY + (SpecificOrbitRadius * 0.3) * Sin(PlanetPhase * 2 * Pi);

      PlanetDrawRadius := (BaseRadius * 0.20) * Power(FDataModel.Planets[I].PlanetRadiusEarth, 0.4);
      if PlanetDrawRadius < 3.0 then PlanetDrawRadius := 3.0;
      if PlanetDrawRadius > (BaseRadius * 0.8) then PlanetDrawRadius := BaseRadius * 0.8;

      if IsMegastructure then
      begin
        if Sin(PlanetPhase * 2 * Pi) > 0 then
        begin
          ATargetBitmap.DrawPolygonAntialias([
            PointF(PlanetX, PlanetY - PlanetDrawRadius), PointF(PlanetX + PlanetDrawRadius, PlanetY),
            PointF(PlanetX, PlanetY + PlanetDrawRadius), PointF(PlanetX - PlanetDrawRadius, PlanetY)
          ], BGRA(255, 0, 255, 255), 1.5);
          ATargetBitmap.FillPolyAntialias([
            PointF(PlanetX, PlanetY - PlanetDrawRadius), PointF(PlanetX + PlanetDrawRadius, PlanetY),
            PointF(PlanetX, PlanetY + PlanetDrawRadius), PointF(PlanetX - PlanetDrawRadius, PlanetY)
          ], BGRA(10, 10, 10, 255));
        end
        else
        begin
          ATargetBitmap.FillPolyAntialias([
            PointF(PlanetX, PlanetY - PlanetDrawRadius), PointF(PlanetX + PlanetDrawRadius, PlanetY),
            PointF(PlanetX, PlanetY + PlanetDrawRadius), PointF(PlanetX - PlanetDrawRadius, PlanetY)
          ], BGRA(255, 0, 255, 120));
        end;
      end
      else
      begin
        if Sin(PlanetPhase * 2 * Pi) > 0 then
          ATargetBitmap.FillEllipseAntiAlias(PlanetX, PlanetY, PlanetDrawRadius, PlanetDrawRadius, BGRA(10, 10, 15, 255))
        else
          ATargetBitmap.FillEllipseAntiAlias(PlanetX, PlanetY, PlanetDrawRadius, PlanetDrawRadius, BGRA(0, 150, 255, 100));
      end;
    end;
  end
  else
  begin
    SpecificOrbitRadius := StarRadius + (BaseRadius * 2.0);
    ATargetBitmap.EllipseAntialias(CX, CY, SpecificOrbitRadius, SpecificOrbitRadius * 0.3, BGRA(0, 255, 255, 40), 1.0);

    PlanetPhase := APhase * 2.0;
    ATargetBitmap.EllipseAntialias(CX, CY, SpecificOrbitRadius * 0.7, SpecificOrbitRadius * 0.21, BGRA(0, 255, 200, 40), 1.0);

    PlanetX := CX + SpecificOrbitRadius * Cos(PlanetPhase * 2 * Pi);
    PlanetY := CY + (SpecificOrbitRadius * 0.3) * Sin(PlanetPhase * 2 * Pi);

    ATargetBitmap.DrawLineAntialias(PlanetX - 5, PlanetY, PlanetX + 5, PlanetY, BGRA(0, 255, 255, 255), 1.0);
    ATargetBitmap.DrawLineAntialias(PlanetX, PlanetY - 5, PlanetX, PlanetY + 5, BGRA(0, 255, 255, 255), 1.0);
  end;

  // =====================================================================
  // EFEK MONITOR CRT & SCANLINES (RETRO-FUTURISTIK)
  // =====================================================================
  MaxDistCRT := Hypot(CX, CY);

  for py := 0 to ATargetBitmap.Height - 1 do
  begin
    p := ATargetBitmap.ScanLine[py];
    for px := 0 to ATargetBitmap.Width - 1 do
    begin
      // 1. Scanlines: Gelapkan baris piksel setiap kelipatan 3
      if py mod 3 = 0 then
      begin
        p^.red := (p^.red * 60) div 100;
        p^.green := (p^.green * 60) div 100;
        p^.blue := (p^.blue * 60) div 100;
      end;

      // 2. Vignette: Efek bayangan gelap/melengkung di pinggiran layar
      DistCRT := Hypot(px - CX, py - CY);
      if DistCRT > (MaxDistCRT * 0.55) then
      begin
        Darken := 1.0 - ((DistCRT - (MaxDistCRT * 0.55)) / (MaxDistCRT * 0.45));
        if Darken < 0 then Darken := 0;

        p^.red := Round(p^.red * Darken);
        p^.green := Round(p^.green * Darken);
        p^.blue := Round(p^.blue * Darken);
      end;

      Inc(p); // Lanjut ke piksel berikutnya
    end;
  end;
end;

end.
