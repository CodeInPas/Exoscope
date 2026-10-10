unit fraLightCurveChart;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, ExtCtrls, StdCtrls, TAGraph, TASeries;

type
  { TFrameLightCurve }
  TFrameLightCurve = class(TFrame)
    chrtLightCurve: TChart;
    lblTitle: TLabel;
    pnlBackground: TPanel;
    serFlux: TLineSeries;     // Garis Cyan untuk Filtered Data
    serRawFlux: TLineSeries;  // Titik Putih untuk Raw Data
  private
  public
    constructor Create(TheOwner: TComponent); override;
  end;

implementation

{$R *.lfm}

{ TFrameLightCurve }

constructor TFrameLightCurve.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  // Optimalisasi visual: TChart LCL secara otomatis menangani DoubleBuffering
  // Mencegah flickering saat data di-update secara real-time
  chrtLightCurve.DoubleBuffered := True;
end;

end.
