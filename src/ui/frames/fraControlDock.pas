unit fraControlDock;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, ExtCtrls, StdCtrls, ComCtrls, Graphics;

type
  TApplyFilterEvent = procedure(Sender: TObject; const AFilterMode: string; ASigma: Double) of object;

  { TFrameControlDock }
  TFrameControlDock = class(TFrame)
    btnApplyFilter: TButton;
    btnReportDiscovery: TButton;
    cbFilterMode: TComboBox;
    chkDataStacking: TCheckBox;
    lblBandwidth: TLabel;
    lblBandwidthVal: TLabel;
    lblFilterMode: TLabel;
    lblNoiseGate: TLabel;
    lblNoiseGateVal: TLabel;
    lblThreshold: TLabel;
    lblThresholdVal: TLabel;
    lblTitle: TLabel;
    pnlLeft: TPanel;
    pnlRight: TPanel;
    shpDivider: TShape;
    tbBandwidth: TTrackBar;
    tbNoiseGate: TTrackBar;
    tbThreshold: TTrackBar;
    procedure btnApplyFilterClick(Sender: TObject);
    procedure btnReportDiscoveryClick(Sender: TObject);
    procedure tbBandwidthChange(Sender: TObject);
    procedure tbNoiseGateChange(Sender: TObject);
    procedure tbThresholdChange(Sender: TObject);
  private
    FOnApplyFilter: TApplyFilterEvent;
    FOnReportDiscovery: TNotifyEvent;
  public
    constructor Create(TheOwner: TComponent); override;
    property OnApplyFilter: TApplyFilterEvent read FOnApplyFilter write FOnApplyFilter;
    property OnReportDiscovery: TNotifyEvent read FOnReportDiscovery write FOnReportDiscovery;
  end;

implementation

{$R *.lfm}

{ TFrameControlDock }

constructor TFrameControlDock.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  // Sinkronisasi nilai label UI dengan posisi trackbar default
  tbNoiseGateChange(Self);
  tbThresholdChange(Self);
  tbBandwidthChange(Self);
end;

procedure TFrameControlDock.tbNoiseGateChange(Sender: TObject);
begin
  lblNoiseGateVal.Caption := IntToStr(tbNoiseGate.Position) + ' %';
end;

procedure TFrameControlDock.tbThresholdChange(Sender: TObject);
begin
  lblThresholdVal.Caption := FloatToStrF(tbThreshold.Position / 100, ffFixed, 4, 2);
end;

procedure TFrameControlDock.tbBandwidthChange(Sender: TObject);
begin
  lblBandwidthVal.Caption := IntToStr(tbBandwidth.Position) + ' nm';
end;

procedure TFrameControlDock.btnApplyFilterClick(Sender: TObject);
var
  FilterMode: string;
  SigmaVal: Double;
begin
  if Assigned(FOnApplyFilter) then
  begin
    FilterMode := 'GAUSSIAN';
    if cbFilterMode.ItemIndex = 1 then
      FilterMode := 'MOVINGAVG';

    // Konversi proporsi posisi trackbar (1-100) menjadi parameter Sigma DSP
    SigmaVal := (tbThreshold.Position / 100.0) * 10.0;
    if SigmaVal <= 0 then SigmaVal := 1.0;

    FOnApplyFilter(Self, FilterMode, SigmaVal);
  end;
end;

procedure TFrameControlDock.btnReportDiscoveryClick(Sender: TObject);
begin
  if Assigned(FOnReportDiscovery) then
    FOnReportDiscovery(Self);
end;

end.
