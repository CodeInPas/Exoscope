unit fraSpectrumChart;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, ExtCtrls, Graphics,
  TAGraph, TASeries;

type
  { TFrameSpectrum }
  TFrameSpectrum = class(TFrame)
    chrtSpectrum: TChart;
    pnlBackground: TPanel;
    serSpectrum: TLineSeries;
  public
    constructor Create(TheOwner: TComponent); override;
  end;

implementation

{$R *.lfm}

{ TFrameSpectrum }

constructor TFrameSpectrum.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  // Mengaktifkan DoubleBuffering untuk meminimalkan flickering
  // pada pembaruan gelombang spektrum berkecepatan tinggi
  chrtSpectrum.DoubleBuffered := True;
end;

end.

