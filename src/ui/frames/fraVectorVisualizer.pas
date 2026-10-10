unit fraVectorVisualizer;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, ExtCtrls, Graphics,
  BGRABitmap, BGRABitmapTypes;

type
  { Event kustom untuk mendelegasikan render vektor ke uViewDashboardRenderer }
  TVectorRenderEvent = procedure(ABitmap: TBGRABitmap; APhase: Double; AHasAnomaly: Boolean) of object;

  { TFrameVectorVisualizer }
  TFrameVectorVisualizer = class(TFrame)
    pbVectorCanvas: TPaintBox;
    pnlBackground: TPanel;
    tmrAnimation: TTimer;
    procedure pbVectorCanvasPaint(Sender: TObject);
    procedure tmrAnimationTimer(Sender: TObject);
  private
    FBuffer: TBGRABitmap;
    FOrbitPhase: Double;
    FHasAnomaly: Boolean;
    FOnRenderFrame: TVectorRenderEvent;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;

    procedure StartAnimation(AHasAnomaly: Boolean);
    procedure StopAnimation;

    property OnRenderFrame: TVectorRenderEvent read FOnRenderFrame write FOnRenderFrame;
  end;

implementation

{$R *.lfm}

{ TFrameVectorVisualizer }

constructor TFrameVectorVisualizer.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  // Alokasi awal buffer memori BGRABitmap untuk menghindari flickering
  FBuffer := TBGRABitmap.Create;
  FOrbitPhase := 0.0;
  FHasAnomaly := False;
end;

destructor TFrameVectorVisualizer.Destroy;
begin
  FBuffer.Free;
  inherited Destroy;
end;

procedure TFrameVectorVisualizer.StartAnimation(AHasAnomaly: Boolean);
begin
  FHasAnomaly := AHasAnomaly;
  FOrbitPhase := 0.0;
  tmrAnimation.Enabled := True; // Timer dengan interval ~33ms (30 FPS)
end;

procedure TFrameVectorVisualizer.StopAnimation;
begin
  tmrAnimation.Enabled := False;
  pbVectorCanvas.Invalidate;
end;

procedure TFrameVectorVisualizer.pbVectorCanvasPaint(Sender: TObject);
begin
  // Realokasi ukuran buffer hanya jika PaintBox mengalami perubahan ukuran
  if (FBuffer.Width <> pbVectorCanvas.Width) or (FBuffer.Height <> pbVectorCanvas.Height) then
    FBuffer.SetSize(pbVectorCanvas.Width, pbVectorCanvas.Height);

  // Jika render delegasi terhubung, panggil fungsi render 3D/Vektor utama
  if Assigned(FOnRenderFrame) then
    FOnRenderFrame(FBuffer, FOrbitPhase, FHasAnomaly)
  else
    FBuffer.Fill(BGRA(13, 17, 23, 255)); // Latar default jika idle

  // Salin buffer off-screen ke kanvas antarmuka (Double Buffering)
  FBuffer.Draw(pbVectorCanvas.Canvas, 0, 0, False);
end;

procedure TFrameVectorVisualizer.tmrAnimationTimer(Sender: TObject);
begin
  // Update rotasi planet secara siklikal
  FOrbitPhase := FOrbitPhase + 0.005;
  if FOrbitPhase >= 1.0 then
    FOrbitPhase := FOrbitPhase - 1.0;

  // Pemicu event OnPaint untuk merender frame berikutnya
  pbVectorCanvas.Invalidate;
end;

end.

