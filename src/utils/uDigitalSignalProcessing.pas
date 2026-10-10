unit uDigitalSignalProcessing;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math;

type
  { Array dinamis untuk menampung data telemetri (amplitudo cahaya/flux) }
  TSignalArray = array of Double;

  { TSignalProcessor
    Menyediakan fungsi statis untuk manipulasi sinyal digital berkinerja tinggi
    tanpa perlu inisiasi object berulang kali }
  TSignalProcessor = class
  public
    { Menambahkan noise Gaussian ke data sinyal mentah (Simulasi noise teleskop) }
    class procedure AddGaussianNoise(var ASignal: TSignalArray; AMean, AStdDev: Double);

    { Filter Low-Pass menggunakan Moving Average dengan kompleksitas O(N) }
    class function MovingAverage(const ASignal: TSignalArray; AWindowSize: Integer): TSignalArray;

    { Konvolusi 1D menggunakan Kernel Gaussian untuk pemulusan kurva cahaya }
    class function GaussianSmooth(const ASignal: TSignalArray; ASigma: Double): TSignalArray;

    { Mendeteksi anomali (penurunan/dip) untuk kalkulasi transit planet }
    class function DetectTransitDips(const ASignal: TSignalArray; AThreshold: Double; AMinDuration: Integer): Integer;
  end;

implementation

{ TSignalProcessor }

class procedure TSignalProcessor.AddGaussianNoise(var ASignal: TSignalArray; AMean, AStdDev: Double);
var
  I: Integer;
begin
  if Length(ASignal) = 0 then Exit;

  // RandG merupakan fungsi bawaan FPC (Math) yang sangat efisien
  // untuk menghasilkan nilai random berdistribusi normal (Gaussian)
  for I := Low(ASignal) to High(ASignal) do
    ASignal[I] := ASignal[I] + RandG(AMean, AStdDev);
end;

class function TSignalProcessor.MovingAverage(const ASignal: TSignalArray; AWindowSize: Integer): TSignalArray;
var
  I, Len, HalfWin: Integer;
  Sum: Double;
begin
  Len := Length(ASignal);
  SetLength(Result, Len);

  if (Len = 0) then Exit;
  if (AWindowSize <= 1) or (AWindowSize > Len) then
  begin
    Result := Copy(ASignal); // Bypass jika ukuran window tidak valid
    Exit;
  end;

  HalfWin := AWindowSize div 2;
  Sum := 0;

  // Inisialisasi jumlah elemen window pertama
  for I := 0 to AWindowSize - 1 do
    Sum := Sum + ASignal[I];

  // Algoritma Sliding Window: Menghindari loop bersarang (O(N) vs O(N*W))
  for I := 0 to Len - 1 do
  begin
    Result[I] := Sum / AWindowSize;

    // Kurangi elemen paling belakang yang keluar dari window
    if (I - HalfWin >= 0) then
      Sum := Sum - ASignal[I - HalfWin];

    // Tambahkan elemen paling depan yang masuk ke window
    if (I + HalfWin + 1 < Len) then
      Sum := Sum + ASignal[I + HalfWin + 1];
  end;
end;

class function TSignalProcessor.GaussianSmooth(const ASignal: TSignalArray; ASigma: Double): TSignalArray;
var
  Kernel: array of Double;
  I, J, KSize, HalfK, Len: Integer;
  Sum, KernelSum: Double;
  TargetIndex: Integer;
begin
  Len := Length(ASignal);
  SetLength(Result, Len);

  if (Len = 0) or (ASigma <= 0) then
  begin
    Result := Copy(ASignal);
    Exit;
  end;

  // Ukuran kernel ideal adalah 6x sigma untuk mencakup 99.7% distribusi kurva
  KSize := Ceil(6 * ASigma);
  if not Odd(KSize) then Inc(KSize); // Pastikan kernel ganjil untuk titik tengah absolut
  HalfK := KSize div 2;

  // Pre-kalkulasi Kernel Gaussian (1D)
  SetLength(Kernel, KSize);
  KernelSum := 0;
  for I := 0 to KSize - 1 do
  begin
    Kernel[I] := Exp(-0.5 * Sqr((I - HalfK) / ASigma)) / (ASigma * Sqrt(2 * Pi));
    KernelSum := KernelSum + Kernel[I];
  end;

  // Normalisasi Kernel agar total area = 1 (menghindari penambahan amplitudo keseluruhan)
  for I := 0 to KSize - 1 do
    Kernel[I] := Kernel[I] / KernelSum;

  // Proses Konvolusi
  for I := 0 to Len - 1 do
  begin
    Sum := 0;
    for J := 0 to KSize - 1 do
    begin
      TargetIndex := I - HalfK + J;

      // Penanganan tepi (Edge handling) menggunakan metode nearest-neighbor replikasi
      if TargetIndex < 0 then TargetIndex := 0
      else if TargetIndex >= Len then TargetIndex := Len - 1;

      Sum := Sum + (ASignal[TargetIndex] * Kernel[J]);
    end;
    Result[I] := Sum;
  end;
end;

class function TSignalProcessor.DetectTransitDips(const ASignal: TSignalArray; AThreshold: Double; AMinDuration: Integer): Integer;
var
  I, DipCount, CurrentDuration: Integer;
begin
  Result := 0;
  DipCount := 0;
  CurrentDuration := 0;

  // Iterasi linier untuk mencari rentang data berurutan di bawah Threshold
  for I := 0 to High(ASignal) do
  begin
    if ASignal[I] < AThreshold then
      Inc(CurrentDuration)
    else
    begin
      // Validasi dip: harus lebih lama dari durasi minimal
      if CurrentDuration >= AMinDuration then
        Inc(DipCount);
      CurrentDuration := 0;
    end;
  end;

  // Validasi batas ujung (edge case) jika array berakhir saat status sedang dip
  if CurrentDuration >= AMinDuration then
    Inc(DipCount);

  Result := DipCount;
end;

end.

