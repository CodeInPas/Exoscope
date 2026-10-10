unit uGlassmorphismCache;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, Types,
  BGRABitmap, BGRABitmapTypes;

type
  { TGlassmorphismCache
    Menangani off-screen rendering untuk efek glassmorphism (blur & overlay).
    Caching digunakan agar efek blur yang berat tidak dihitung di setiap frame. }
  TGlassmorphismCache = class
  private
    FBackgroundCache: TBGRABitmap;
    FGlassCache: TBGRABitmap;
    FBlurRadius: Integer;
    FOverlayColor: TBGRAPixel;
    FIsDirty: Boolean;

    procedure FreeCaches;
  public
    constructor Create;
    destructor Destroy; override;

    { Menandai cache tidak valid sehingga perlu dirender ulang pada frame berikutnya }
    procedure Invalidate;

    { Mengatur parameter visual }
    procedure SetProperties(ABlurRadius: Integer; AOverlayColor: TColor; AAlpha: Byte);

    { Update cache dari bitmap background (misal: layer di bawah UI saat ini) }
    procedure UpdateBackground(ABgBitmap: TBGRABitmap; ARect: TRect);

    { Menggambar hasil akhir ke canvas target (Double Buffering siap pakai) }
    procedure DrawToCanvas(ACanvas: TCanvas; X, Y: Integer);

    property IsDirty: Boolean read FIsDirty;
  end;

implementation

{ TGlassmorphismCache }

constructor TGlassmorphismCache.Create;
begin
  inherited Create;
  FBackgroundCache := nil;
  FGlassCache := nil;
  FBlurRadius := 15;
  FOverlayColor := BGRA(15, 20, 25, 180); // Default dark glass overlay semi-transparan
  FIsDirty := True;
end;

destructor TGlassmorphismCache.Destroy;
begin
  FreeCaches;
  inherited Destroy;
end;

procedure TGlassmorphismCache.FreeCaches;
begin
  if Assigned(FBackgroundCache) then FreeAndNil(FBackgroundCache);
  if Assigned(FGlassCache) then FreeAndNil(FGlassCache);
end;

procedure TGlassmorphismCache.Invalidate;
begin
  FIsDirty := True;
end;

procedure TGlassmorphismCache.SetProperties(ABlurRadius: Integer; AOverlayColor: TColor; AAlpha: Byte);
var
  NewOverlay: TBGRAPixel;
begin
  NewOverlay := ColorToBGRA(AOverlayColor, AAlpha);
  if (FBlurRadius <> ABlurRadius) or (FOverlayColor <> NewOverlay) then
  begin
    FBlurRadius := ABlurRadius;
    FOverlayColor := NewOverlay;
    FIsDirty := True;
  end;
end;

procedure TGlassmorphismCache.UpdateBackground(ABgBitmap: TBGRABitmap; ARect: TRect);
var
  W, H: Integer;
  TempBlur: TBGRABitmap;
begin
  if not Assigned(ABgBitmap) then Exit;

  W := ARect.Width;
  H := ARect.Height;

  if (W <= 0) or (H <= 0) then Exit;

  // Cek apakah ukuran cache perlu diubah/dibuat ulang
  if not Assigned(FBackgroundCache) or (FBackgroundCache.Width <> W) or (FBackgroundCache.Height <> H) then
  begin
    FreeCaches;
    FBackgroundCache := TBGRABitmap.Create(W, H);
    FGlassCache := TBGRABitmap.Create(W, H);
    FIsDirty := True;
  end;

  if FIsDirty then
  begin
    // 1. Salin area background yang berada tepat di belakang panel ini
    // PERBAIKAN: Offset negatif memposisikan gambar secara akurat sesuai rect & format signature yang benar
    FBackgroundCache.PutImage(-ARect.Left, -ARect.Top, ABgBitmap, dmSet, 255);

    // 2. Terapkan algoritma Fast Radial Blur (O(N) complexity) dari BGRABitmap
    TempBlur := FBackgroundCache.FilterBlurRadial(FBlurRadius, rbFast) as TBGRABitmap;
    try
      FGlassCache.Assign(TempBlur);
    finally
      TempBlur.Free;
    end;

    // 3. Aplikasikan warna overlay dengan mode blending transparan
    FGlassCache.Rectangle(0, 0, W, H, FOverlayColor, FOverlayColor, dmDrawWithTransparency);

    // 4. Tambahkan highlight/stroke tepi (border) tipis untuk estetika kaca
    // PERBAIKAN: Menggunakan Rectangle dengan parameter border (W-1, H-1) untuk single color edge
    FGlassCache.Rectangle(0, 0, W - 1, H - 1, BGRA(255, 255, 255, 30), dmDrawWithTransparency);

    FIsDirty := False;
  end;
end;

procedure TGlassmorphismCache.DrawToCanvas(ACanvas: TCanvas; X, Y: Integer);
begin
  if Assigned(FGlassCache) and not FIsDirty then
    FGlassCache.Draw(ACanvas, X, Y, False);
end;

end.
