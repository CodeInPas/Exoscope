unit uBackgroundWorkerThread;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uTelemetryDataModel, uKeplerPhysics; // Menambahkan uKeplerPhysics

type
  TWorkerTaskType = (wttGenerateData, wttApplyGaussian, wttApplyMovingAverage);

  { TBackgroundWorkerThread
    Thread sekali pakai (FreeOnTerminate = True) untuk menjalankan proses DSP
    dan generator data secara asinkron tanpa memblokir antarmuka pengguna (Main Thread). }
  TBackgroundWorkerThread = class(TThread)
  private
    FTaskType: TWorkerTaskType;
    FDataModel: TTelemetryDataModel;
    FOnComplete: TNotifyEvent;

    { Parameter spesifik untuk task Data Generation }
    FSectorName: string;
    FPointCount: Integer;
    FBaseFlux: Double;
    FNoiseStdDev: Double;
    FIncludePlanet: Boolean; // Jika True, akan memicu generasi Multi-Planetary System di Data Model
    FStarClass: TStarClass;  // PARAMETER BARU: Menyimpan kelas bintang yang dipilih radar

    { Parameter spesifik untuk task Filtering }
    FSigma: Double;
    FWindowSize: Integer;

    { Callback yang akan dijalankan di Main UI Thread }
    procedure DoComplete;
  protected
    procedure Execute; override;
  public
    // PERBAIKAN: Menambahkan AStarClass pada deklarasi parameter constructor
    constructor CreateGenerateData(ADataModel: TTelemetryDataModel; const ASectorName: string;
      APointCount: Integer; ABaseFlux, ANoiseStdDev: Double; AIncludePlanet: Boolean;
      AStarClass: TStarClass; AOnComplete: TNotifyEvent);

    constructor CreateFilterGaussian(ADataModel: TTelemetryDataModel; ASigma: Double;
      AOnComplete: TNotifyEvent);

    constructor CreateFilterMA(ADataModel: TTelemetryDataModel; AWindowSize: Integer;
      AOnComplete: TNotifyEvent);
  end;

implementation

{ TBackgroundWorkerThread }

// PERBAIKAN: Menambahkan AStarClass pada implementasi
constructor TBackgroundWorkerThread.CreateGenerateData(ADataModel: TTelemetryDataModel;
  const ASectorName: string; APointCount: Integer; ABaseFlux, ANoiseStdDev: Double;
  AIncludePlanet: Boolean; AStarClass: TStarClass; AOnComplete: TNotifyEvent);
begin
  inherited Create(False); // Thread langsung berjalan setelah diciptakan
  FreeOnTerminate := True; // Otomatis hapus instance dari memori saat Execute selesai

  FTaskType := wttGenerateData;
  FDataModel := ADataModel;
  FSectorName := ASectorName;
  FPointCount := APointCount;
  FBaseFlux := ABaseFlux;
  FNoiseStdDev := ANoiseStdDev;
  FIncludePlanet := AIncludePlanet;
  FStarClass := AStarClass; // Simpan nilai AStarClass
  FOnComplete := AOnComplete;
end;

constructor TBackgroundWorkerThread.CreateFilterGaussian(ADataModel: TTelemetryDataModel;
  ASigma: Double; AOnComplete: TNotifyEvent);
begin
  inherited Create(False);
  FreeOnTerminate := True;

  FTaskType := wttApplyGaussian;
  FDataModel := ADataModel;
  FSigma := ASigma;
  FOnComplete := AOnComplete;
end;

constructor TBackgroundWorkerThread.CreateFilterMA(ADataModel: TTelemetryDataModel;
  AWindowSize: Integer; AOnComplete: TNotifyEvent);
begin
  inherited Create(False);
  FreeOnTerminate := True;

  FTaskType := wttApplyMovingAverage;
  FDataModel := ADataModel;
  FWindowSize := AWindowSize;
  FOnComplete := AOnComplete;
end;

procedure TBackgroundWorkerThread.DoComplete;
begin
  if Assigned(FOnComplete) then
    FOnComplete(Self);
end;

procedure TBackgroundWorkerThread.Execute;
begin
  try
    if not Assigned(FDataModel) then Exit;

    case FTaskType of
      wttGenerateData:
        // PERBAIKAN: Meneruskan FStarClass sebagai parameter ke-6
        FDataModel.GenerateSectorData(FSectorName, FPointCount, FBaseFlux, FNoiseStdDev, FIncludePlanet, FStarClass);

      wttApplyGaussian:
        FDataModel.ApplyFilterGaussian(FSigma);

      wttApplyMovingAverage:
        FDataModel.ApplyFilterMovingAverage(FWindowSize);
    end;
  finally
    // Menggunakan Synchronize agar objek Thread ini ditahan hidup
    // sampai Main Thread selesai mengeksekusi UI Update (DoComplete).
    // Ini mencegah hilangnya sinyal karena race condition dengan FreeOnTerminate.
    if not Terminated then
      Synchronize(@DoComplete);
  end;
end;

end.
