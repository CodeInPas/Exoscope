unit uSurfaceProbeRenderer;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Graphics, BGRABitmap, BGRABitmapTypes;

type
  { TSurfaceProbeRenderer
    Modul untuk menghasilkan gambar permukaan 2D (Pixel-Art) dari planet
    yang dikunjungi oleh satelit Probe. }
  TSurfaceProbeRenderer = class
  public
    { Meng-generate gambar, menyimpannya ke folder, dan mengembalikan path lokasinya }
    class function LaunchProbe(const ASectorName, APlanetType: string): string;
  end;

implementation

{ TSurfaceProbeRenderer }

class function TSurfaceProbeRenderer.LaunchProbe(const ASectorName, APlanetType: string): string;
var
  Bmp, FinalBmp: TBGRABitmap;
  X, Y, I, J, WalkX, WalkY: Integer;
  NoiseVal, V: Double;
  PColor: TBGRAPixel;
  SaveDir, SavePath, UpperType: string;
begin
  // Setup folder penyimpanan hasil foto (di luar folder bin)
  SaveDir := ExtractFilePath(ParamStr(0)) + '..\probes\';
  if not DirectoryExists(SaveDir) then
    ForceDirectories(SaveDir);

  SavePath := SaveDir + ASectorName + '_' + StringReplace(APlanetType, ' ', '', [rfReplaceAll]) + '.png';
  UpperType := UpperCase(APlanetType);

  // Buat kanvas resolusi rendah (128x128) untuk mendapatkan estetika "Pixel-Art" bergaya retro
  Bmp := TBGRABitmap.Create(128, 128, BGRA(0, 0, 0, 255));
  try
    Randomize;

    { 1. ALIEN MEGASTRUCTURE }
    if Pos('MEGASTRUCTURE', UpperType) > 0 then
    begin
      Bmp.Fill(BGRA(20, 25, 30, 255));
      for Y := 0 to 127 do
      begin
        for X := 0 to 127 do
        begin
          // Gambar panel pelat besi raksasa (Grid)
          if (X mod 16 = 0) or (Y mod 16 = 0) then
            Bmp.SetPixel(X, Y, BGRA(10, 10, 10, 255))
          // Tambahkan node sirkuit acak
          else if (X mod 32 = 8) and (Y mod 32 = 8) then
          begin
            if Random(10) > 5 then
            begin
              // Lampu neon fuchsia atau cyan
              if Random(2) = 0 then PColor := BGRA(0, 255, 255, 255) else PColor := BGRA(255, 0, 255, 255);
              Bmp.FillRect(X, Y, X + Random(4) + 2, Y + Random(4) + 2, PColor, dmSet);
            end;
          end;
        end;
      end;
    end

    { 2. GAS GIANT (Badai Atmosferik ala Jupiter) }
    else if Pos('GAS GIANT', UpperType) > 0 then
    begin
      for Y := 0 to 127 do
      begin
        for X := 0 to 127 do
        begin
          // Gelombang sinus yang ditumpuk untuk membuat ilusi pita gas
          NoiseVal := Sin(Y * 0.1 + Sin(X * 0.05) * 3.0) + Cos(Y * 0.03) * 2.0;
          V := (NoiseVal + 3.0) / 6.0; // Normalisasi ke 0..1

          if V < 0.3 then PColor := BGRA(120, 80, 50, 255)         // Coklat gelap
          else if V < 0.6 then PColor := BGRA(180, 130, 80, 255)   // Oranye pudar
          else if V < 0.85 then PColor := BGRA(220, 190, 140, 255) // Krem terang
          else PColor := BGRA(240, 220, 200, 255);                 // Putih gas

          Bmp.SetPixel(X, Y, PColor);
        end;
      end;
    end

    { 3. BIO-CONFIRMED (Dunia kehidupan organik yang subur) }
    else if Pos('BIO-CONFIRMED', UpperType) > 0 then
    begin
      for Y := 0 to 127 do
        for X := 0 to 127 do
        begin
          // Fractal noise matematis sederhana untuk memisahkan daratan & lautan
          V := Sin(X * 0.05) * Cos(Y * 0.05) + Sin(X * 0.1 + Y * 0.1) * 0.5;
          if V < 0 then
            PColor := BGRA(20, 80, 150, 255) // Laut biru gelap
          else if V < 0.3 then
            PColor := BGRA(150, 200, 255, 255) // Perairan dangkal
          else if V < 0.8 then
            PColor := BGRA(30, 140, 50, 255) // Hutan Hijau/Daratan
          else
            PColor := BGRA(120, 50, 150, 255); // Tumbuhan Alien Ungu di dataran tinggi

          Bmp.SetPixel(X, Y, PColor);
        end;
    end

    { 4. TERRESTRIAL / LAVA WORLD }
    else
    begin
      // Basis kerak batu gelap
      Bmp.Fill(BGRA(40, 35, 35, 255));

      // Kawah (Craters)
      for I := 1 to 20 do
      begin
        WalkX := Random(128); WalkY := Random(128);
        Bmp.EllipseAntialias(WalkX, WalkY, Random(6) + 2, Random(6) + 2, BGRA(20, 15, 15, 255), 1.0);
      end;

      // Random Walk untuk menghasilkan retakan magma pijar (Lava Rivers)
      for I := 1 to 5 do
      begin
        WalkX := Random(128);
        WalkY := Random(128);
        for J := 1 to 100 do
        begin
          Bmp.FillRect(WalkX, WalkY, WalkX + 2, WalkY + 2, BGRA(255, 50 + Random(100), 0, 255), dmSet);
          WalkX := WalkX + (Random(3) - 1); // Geser X acak (-1, 0, 1)
          WalkY := WalkY + (Random(3) - 1); // Geser Y acak (-1, 0, 1)

          if (WalkX < 0) or (WalkX > 127) or (WalkY < 0) or (WalkY > 127) then Break;
        end;
      end;
    end;

    // 5. Upscale (Perbesar) gambar ke 512x512 dengan metode SimpleStretch
    // agar blok pikselnya tetap tajam dan tidak blur (estetika Pixel Art).
    FinalBmp := Bmp.Resample(512, 512, rmSimpleStretch) as TBGRABitmap;
    try
      // Tambahkan UI Overlay Sci-fi / Telemetry text
      FinalBmp.FontName := 'Courier New';
      FinalBmp.FontHeight := 16;
      FinalBmp.FontStyle := [fsBold];

      FinalBmp.TextOut(10, 10, 'EXO-SCOPE PROBE CAMERA V1.0', BGRA(0, 255, 0, 255));
      FinalBmp.TextOut(10, 30, 'TARGET SECTOR  : ' + ASectorName, BGRA(0, 255, 0, 255));
      FinalBmp.TextOut(10, 50, 'CLASSIFICATION : ' + UpperType, BGRA(0, 255, 0, 255));

      // Grid Crosshair kamera
      FinalBmp.DrawLineAntialias(256, 240, 256, 272, BGRA(0, 255, 0, 150), 1.5);
      FinalBmp.DrawLineAntialias(240, 256, 272, 256, BGRA(0, 255, 0, 150), 1.5);
      FinalBmp.EllipseAntialias(256, 256, 12, 12, BGRA(0, 255, 0, 100), 1.0);

      // Simpan ke Disk!
      FinalBmp.SaveToFile(SavePath);
    finally
      FinalBmp.Free;
    end;

  finally
    Bmp.Free;
  end;

  Result := SavePath;
end;

end.
