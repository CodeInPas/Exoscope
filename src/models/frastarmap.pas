unit fraStarmap;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, ExtCtrls, StdCtrls, Graphics, Math,
  BGRABitmap, BGRABitmapTypes, uGalaxyMapModel, uKeplerPhysics, uAudioSynthesizer;

type
  TSectorSelectEvent = procedure(Sender: TObject; const ASectorName: string) of object;

  TFrameStarmap = class(TFrame)
    lblTitle: TLabel;
    pbStarmap: TPaintBox;
    pnlBackground: TPanel;
    shpDivider: TShape;
    procedure pbStarmapMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure pbStarmapMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure pbStarmapMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure pbStarmapPaint(Sender: TObject);
  private
    FMapModel: TGalaxyMapModel;
    FAnimationTimer: TTimer;
    FRadarPhase: Double;
    FSelectedSector: string;
    FOnSectorSelect: TSectorSelectEvent;

    FRadarLevel: Integer;
    FOffsetX, FOffsetY: Double;
    FIsDragging: Boolean;
    FLastMouseX, FLastMouseY: Integer;

    FAudioEngine: TAudioSynthesizer;

    { Variabel Transisi Fade In/Out }
    FFadeAlpha: Integer;
    FFadeState: Integer; // 1 = Fading In, -1 = Fading Out, 0 = Idle
    FIsFadeComplete: Boolean;

    procedure TimerTick(Sender: TObject);
    procedure DrawGrid(ABitmap: TBGRABitmap);
    procedure DrawSectors(ABitmap: TBGRABitmap);
    procedure DrawRadarSweep(ABitmap: TBGRABitmap);
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;

    procedure BindModel(AModel: TGalaxyMapModel);
    procedure SetSelectedSector(const ASectorName: string);

    { Method Publik untuk memicu transisi dari Dashboard }
    procedure StartFadeIn;
    procedure StartFadeOut;
    property FadeComplete: Boolean read FIsFadeComplete;

    property RadarLevel: Integer read FRadarLevel write FRadarLevel;
    property OnSectorSelect: TSectorSelectEvent read FOnSectorSelect write FOnSectorSelect;
    property AudioEngine: TAudioSynthesizer read FAudioEngine write FAudioEngine;
  end;

implementation

{$R *.lfm}

{ TFrameStarmap }

constructor TFrameStarmap.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  FRadarPhase := 0.0;
  FSelectedSector := '';
  FRadarLevel := 1;

  FOffsetX := -1200.0;
  FOffsetY := -1200.0;
  FIsDragging := False;

  // Set kondisi awal Fade In
  FFadeAlpha := 255;
  FFadeState := 1;
  FIsFadeComplete := False;

  pbStarmap.OnMouseMove := @pbStarmapMouseMove;
  pbStarmap.OnMouseUp := @pbStarmapMouseUp;

  FAnimationTimer := TTimer.Create(Self);
  FAnimationTimer.Interval := 40; // Percepat sedikit agar fade lebih mulus
  FAnimationTimer.OnTimer := @TimerTick;
  FAnimationTimer.Enabled := True;
end;

destructor TFrameStarmap.Destroy;
begin
  FAnimationTimer.Free;
  inherited Destroy;
end;

procedure TFrameStarmap.BindModel(AModel: TGalaxyMapModel);
begin
  FMapModel := AModel;
  pbStarmap.Invalidate;
end;

procedure TFrameStarmap.SetSelectedSector(const ASectorName: string);
begin
  FSelectedSector := ASectorName;
  pbStarmap.Invalidate;
end;

procedure TFrameStarmap.StartFadeIn;
begin
  FFadeAlpha := 255; // Mulai dari hitam pekat
  FFadeState := 1;
  FIsFadeComplete := False;
end;

procedure TFrameStarmap.StartFadeOut;
begin
  FFadeAlpha := 0;   // Mulai dari transparan
  FFadeState := -1;
  FIsFadeComplete := False;
end;

procedure TFrameStarmap.TimerTick(Sender: TObject);
begin
  FRadarPhase := FRadarPhase + 0.05;
  if FRadarPhase > 2 * Pi then
    FRadarPhase := FRadarPhase - (2 * Pi);

  // Kalkulasi Alpha Blend Transisi
  if FFadeState = 1 then
  begin
    FFadeAlpha := FFadeAlpha - 20; // Kecepatan Fade In
    if FFadeAlpha <= 0 then
    begin
      FFadeAlpha := 0;
      FFadeState := 0;
      FIsFadeComplete := True;
    end;
  end
  else if FFadeState = -1 then
  begin
    FFadeAlpha := FFadeAlpha + 25; // Kecepatan Fade Out (Sedikit lebih cepat)
    if FFadeAlpha >= 255 then
    begin
      FFadeAlpha := 255;
      FFadeState := 0;
      FIsFadeComplete := True;
    end;
  end;

  if Assigned(FMapModel) then
    pbStarmap.Invalidate;
end;

procedure TFrameStarmap.pbStarmapPaint(Sender: TObject);
var
  Bmp: TBGRABitmap;
  px, py: Integer;
  p: PBGRAPixel;
  CX, CY, DistCRT, MaxDistCRT, Darken: Double;
begin
  if not Assigned(FMapModel) then Exit;

  Bmp := TBGRABitmap.Create(pbStarmap.Width, pbStarmap.Height, BGRA(13, 17, 23, 255));
  try
    DrawGrid(Bmp);
    DrawRadarSweep(Bmp);
    DrawSectors(Bmp);

    // Efek CRT & Vignette
    CX := Bmp.Width * 0.5;
    CY := Bmp.Height * 0.5;
    MaxDistCRT := Hypot(CX, CY);

    for py := 0 to Bmp.Height - 1 do
    begin
      p := Bmp.ScanLine[py];
      for px := 0 to Bmp.Width - 1 do
      begin
        if py mod 3 = 0 then
        begin
          p^.red := (p^.red * 60) div 100;
          p^.green := (p^.green * 60) div 100;
          p^.blue := (p^.blue * 60) div 100;
        end;

        DistCRT := Hypot(px - CX, py - CY);
        if DistCRT > (MaxDistCRT * 0.55) then
        begin
          Darken := 1.0 - ((DistCRT - (MaxDistCRT * 0.55)) / (MaxDistCRT * 0.45));
          if Darken < 0 then Darken := 0;

          p^.red := Round(p^.red * Darken);
          p^.green := Round(p^.green * Darken);
          p^.blue := Round(p^.blue * Darken);
        end;
        Inc(p);
      end;
    end;

    // =====================================================================
    // EFEK ALPHA BLEND (FADE IN/OUT)
    // Lapisan hitam transparan menutupi seluruh gambar jika FFadeAlpha > 0
    // =====================================================================
    if FFadeAlpha > 0 then
      Bmp.Rectangle(0, 0, Bmp.Width, Bmp.Height, BGRA(10, 12, 16, FFadeAlpha), BGRA(10, 12, 16, FFadeAlpha), dmDrawWithTransparency);

    Bmp.Draw(pbStarmap.Canvas, 0, 0, True);
  finally
    Bmp.Free;
  end;
end;

procedure TFrameStarmap.DrawGrid(ABitmap: TBGRABitmap);
var
  I, StepX, StepY: Integer;
begin
  StepX := ABitmap.Width div 10;
  StepY := ABitmap.Height div 10;

  for I := 1 to 9 do
  begin
    ABitmap.DrawLineAntialias(I * StepX, 0, I * StepX, ABitmap.Height, BGRA(0, 255, 255, 15), 1.0);
    ABitmap.DrawLineAntialias(0, I * StepY, ABitmap.Width, I * StepY, BGRA(0, 255, 255, 15), 1.0);
  end;

  ABitmap.EllipseAntialias(ABitmap.Width / 2, ABitmap.Height / 2, ABitmap.Width * 0.4, ABitmap.Width * 0.4, BGRA(0, 255, 255, 30), 1.0);
  ABitmap.EllipseAntialias(ABitmap.Width / 2, ABitmap.Height / 2, ABitmap.Width * 0.2, ABitmap.Width * 0.2, BGRA(0, 255, 255, 20), 1.0);
end;

procedure TFrameStarmap.DrawRadarSweep(ABitmap: TBGRABitmap);
var
  CX, CY, Radius, EndX, EndY: Double;
begin
  CX := ABitmap.Width / 2;
  CY := ABitmap.Height / 2;
  Radius := Hypot(CX, CY);

  EndX := CX + Radius * Cos(FRadarPhase);
  EndY := CY + Radius * Sin(FRadarPhase);

  ABitmap.DrawLineAntialias(CX, CY, EndX, EndY, BGRA(0, 255, 255, 150), 2.0);
end;

procedure TFrameStarmap.DrawSectors(ABitmap: TBGRABitmap);
var
  I, J: Integer;
  SX, SY, BH_X, BH_Y, Dist, Angle, Bend: Double;
  PColor: TBGRAPixel;
  Sector, BHSector: TStarSector;
begin
  for I := 0 to FMapModel.GetSectorCount - 1 do
  begin
    Sector := FMapModel.Sectors[I];

    SX := Sector.X + FOffsetX;
    SY := Sector.Y + FOffsetY;

    if not Sector.IsBlackHole then
    begin
      for J := 0 to FMapModel.GetSectorCount - 1 do
      begin
        BHSector := FMapModel.Sectors[J];
        if BHSector.IsBlackHole then
        begin
          BH_X := BHSector.X + FOffsetX;
          BH_Y := BHSector.Y + FOffsetY;
          Dist := Hypot(SX - BH_X, SY - BH_Y);

          if (Dist > 0) and (Dist < 70.0) then
          begin
            Bend := 300.0 / (Dist + 5.0);
            Angle := ArcTan2(SY - BH_Y, SX - BH_X);
            SX := SX + Cos(Angle + Pi/3) * Bend;
            SY := SY + Sin(Angle + Pi/3) * Bend;
          end;
        end;
      end;
    end;

    if (SX < -50) or (SX > ABitmap.Width + 50) or (SY < -50) or (SY > ABitmap.Height + 50) then
      Continue;

    if Sector.IsBlackHole then
    begin
      ABitmap.FillEllipseAntialias(SX, SY, 5, 5, BGRA(0, 0, 0, 255));
      ABitmap.EllipseAntialias(SX, SY, 7, 7, BGRA(30, 0, 50, 40), 1.0);
    end
    else
    begin
      case Sector.Status of
        ssUnexplored:
        begin
          if FRadarLevel > 1 then
          begin
            case Sector.StarClass of
              scO, scB, scA: PColor := BGRA(150, 200, 255, 180);
              scF, scG:      PColor := BGRA(255, 220, 100, 180);
              scK, scM:      PColor := BGRA(255, 100, 50, 180);
              else           PColor := BGRA(200, 200, 200, 180);
            end;
          end
          else
            PColor := BGRA(100, 100, 100, 120);
        end;
        ssScannedEmpty:   PColor := BGRA(255, 50, 50, 200);
        ssScannedPlanets: PColor := BGRA(0, 255, 255, 255);
      end;

      ABitmap.FillEllipseAntialias(SX, SY, 3, 3, PColor);

      if Sector.Status = ssUnexplored then
        ABitmap.EllipseAntialias(SX, SY, 4, 4, BGRA(PColor.red, PColor.green, PColor.blue, 30), 1.0);
    end;

    if SameText(Sector.Name, FSelectedSector) then
    begin
      ABitmap.DrawLineAntialias(SX - 8, SY - 8, SX - 4, SY - 8, BGRA(255, 200, 0, 255), 1.5);
      ABitmap.DrawLineAntialias(SX - 8, SY - 8, SX - 8, SY - 4, BGRA(255, 200, 0, 255), 1.5);

      ABitmap.DrawLineAntialias(SX + 8, SY + 8, SX + 4, SY + 8, BGRA(255, 200, 0, 255), 1.5);
      ABitmap.DrawLineAntialias(SX + 8, SY + 8, SX + 8, SY + 4, BGRA(255, 200, 0, 255), 1.5);

      ABitmap.TextOut(Round(SX) + 10, Round(SY) - 10, Sector.Name, BGRA(255, 200, 0, 255), taLeftJustify);
    end;
  end;
end;

procedure TFrameStarmap.pbStarmapMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  I, J: Integer;
  SX, SY, BH_X, BH_Y, Dist, Angle, Bend: Double;
  Sector, BHSector: TStarSector;
  Threshold: Double;
  ClickedAStar: Boolean;
begin
  if not Assigned(FMapModel) then Exit;
  if FFadeAlpha > 0 then Exit; // Nonaktifkan klik saat layar sedang memudar!

  if Button <> mbLeft then Exit;

  Threshold := 10.0;
  ClickedAStar := False;

  for I := 0 to FMapModel.GetSectorCount - 1 do
  begin
    Sector := FMapModel.Sectors[I];

    SX := Sector.X + FOffsetX;
    SY := Sector.Y + FOffsetY;

    if not Sector.IsBlackHole then
    begin
      for J := 0 to FMapModel.GetSectorCount - 1 do
      begin
        BHSector := FMapModel.Sectors[J];
        if BHSector.IsBlackHole then
        begin
          BH_X := BHSector.X + FOffsetX;
          BH_Y := BHSector.Y + FOffsetY;
          Dist := Hypot(SX - BH_X, SY - BH_Y);

          if (Dist > 0) and (Dist < 70.0) then
          begin
            Bend := 300.0 / (Dist + 5.0);
            Angle := ArcTan2(SY - BH_Y, SX - BH_X);
            SX := SX + Cos(Angle + Pi/3) * Bend;
            SY := SY + Sin(Angle + Pi/3) * Bend;
          end;
        end;
      end;
    end;

    if Hypot(SX - X, SY - Y) <= Threshold then
    begin
      FSelectedSector := Sector.Name;
      pbStarmap.Invalidate;
      ClickedAStar := True;

      if Assigned(FAudioEngine) then
        FAudioEngine.PlaySlider;

      if Assigned(FOnSectorSelect) then
        FOnSectorSelect(Self, Sector.Name);
      Break;
    end;
  end;

  if not ClickedAStar then
  begin
    FIsDragging := True;
    FLastMouseX := X;
    FLastMouseY := Y;
  end;
end;

procedure TFrameStarmap.pbStarmapMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  if FIsDragging then
  begin
    if (Abs(X - FLastMouseX) > 2) or (Abs(Y - FLastMouseY) > 2) then
    begin
      if Assigned(FAudioEngine) then
        FAudioEngine.PlayRadarPan;
    end;

    FOffsetX := FOffsetX + (X - FLastMouseX);
    FOffsetY := FOffsetY + (Y - FLastMouseY);

    if FOffsetX > 200 then FOffsetX := 200;
    if FOffsetX < -3200 then FOffsetX := -3200;
    if FOffsetY > 200 then FOffsetY := 200;
    if FOffsetY < -3200 then FOffsetY := -3200;

    FLastMouseX := X;
    FLastMouseY := Y;

    pbStarmap.Invalidate;
  end;
end;

procedure TFrameStarmap.pbStarmapMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then
    FIsDragging := False;
end;

end.
