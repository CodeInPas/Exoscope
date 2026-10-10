unit uReportExporter;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fppdf, Graphics; // Tambahkan Graphics untuk menggunakan konstanta TColor

type
  { TReportExporter
    Modul untuk membuat file PDF fisik secara native menggunakan library fppdf bawaan Lazarus. }
  TReportExporter = class
  public
    class function GeneratePDF(const ASectorName, AStarClass, APrimaryType: string;
      APlanetCount: Integer; AIsHabitable: Boolean; AEstimatedValue: Double): string;
  end;

implementation

{ TReportExporter }

class function TReportExporter.GeneratePDF(const ASectorName, AStarClass, APrimaryType: string;
  APlanetCount: Integer; AIsHabitable: Boolean; AEstimatedValue: Double): string;
var
  PDF: TPDFDocument;
  Page: TPDFPage;
  SaveDir, SavePath: string;
  FntTitle, FntNormal: Integer;
begin
  // Setup direktori penyimpanan PDF
  SaveDir := ExtractFilePath(ParamStr(0)) + '..\reports\';
  if not DirectoryExists(SaveDir) then
    ForceDirectories(SaveDir);

  SavePath := SaveDir + ASectorName + '_Classified_Report.pdf';

  PDF := TPDFDocument.Create(nil);
  try
    // Metadata PDF
    PDF.Infos.Title := 'Classified Report - ' + ASectorName;
    PDF.Infos.Author := 'EXO-SCOPE Research Command';
    PDF.Infos.CreationDate := Now;

    // Registrasi Font Standar PDF (Tidak perlu file font eksternal)
    FntTitle := PDF.AddFont('Helvetica-Bold');
    FntNormal := PDF.AddFont('Helvetica');

    PDF.StartDocument;
    Page := PDF.Pages.AddPage;
    Page.PaperType := ptA4;

    // === HEADER ===
    Page.SetFont(FntTitle, 22);
    Page.WriteText(50, 750, 'EXO-SCOPE OFFICIAL DISCOVERY REPORT');

    Page.SetColor(clSilver, False); // Garis abu-abu
    Page.DrawLine(50, 735, 545, 735, 2.0);

    // === METADATA ===
    Page.SetColor(clBlack, False); // Teks Hitam
    Page.SetFont(FntNormal, 12);
    Page.WriteText(50, 700, 'DATE OF REPORT : ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
    Page.WriteText(50, 680, 'SECTOR DESIGN. : ' + ASectorName);
    Page.WriteText(50, 660, 'STAR CLASS     : ' + AStarClass);

    // === TELEMETRY SUMMARY ===
    Page.SetFont(FntTitle, 14);
    Page.WriteText(50, 610, 'SYSTEM TELEMETRY SUMMARY');
    Page.SetColor(clSilver, False);
    Page.DrawLine(50, 600, 545, 600, 1.0);

    Page.SetColor(clBlack, False);
    Page.SetFont(FntNormal, 12);
    Page.WriteText(50, 570, 'TOTAL PLANETS DETECTED : ' + IntToStr(APlanetCount));
    Page.WriteText(50, 550, 'PRIMARY CLASSIFICATION : ' + APrimaryType);

    if AIsHabitable then
    begin
      Page.SetColor(clGreen, False); // Hijau
      Page.WriteText(50, 530, 'HABITABLE ZONE         : CONFIRMED (OPTIMAL FOR LIFE)');
    end
    else
    begin
      Page.SetColor(clRed, False); // Merah
      Page.WriteText(50, 530, 'HABITABLE ZONE         : NEGATIVE (DEAD SYSTEM)');
    end;

    // === FINANCIAL GRANTS ===
    Page.SetColor(clBlack, False);
    Page.SetFont(FntTitle, 14);
    Page.WriteText(50, 480, 'RESEARCH & FINANCIAL GRANTS');
    Page.SetColor(clSilver, False);
    Page.DrawLine(50, 470, 545, 470, 1.0);

    Page.SetColor(clBlack, False);
    Page.SetFont(FntNormal, 12);
    Page.WriteText(50, 440, 'ESTIMATED FUNDING YIELD: $' + FormatFloat('#,##0', AEstimatedValue));

    // === FOOTER (WARNING) ===
    Page.SetFont(FntTitle, 10);
    Page.SetColor(clRed, False); // Merah Gelap
    Page.WriteText(50, 100, '*** THIS DOCUMENT IS CLASSIFIED AND CONFIDENTIAL ***');
    Page.SetColor(clGray, False); // Abu-abu gelap
    Page.SetFont(FntNormal, 9);
    Page.WriteText(50, 85, 'Generated automatically by EXO-SCOPE Deep Space Telemetry Engine.');

    PDF.SaveToFile(SavePath);
  finally
    PDF.Free;
  end;
  Result := SavePath;
end;

end.
