unit fraTerminalPanel;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Graphics, LCLType,
  uAudioSynthesizer; // Tambahkan referensi Audio Synthesizer

type
  TCommandEvent = procedure(Sender: TObject; const ACommand: string) of object;

  { TFrameTerminal }

  TFrameTerminal = class(TFrame)
    edtCommand: TEdit;
    lblPrompt: TLabel;
    memLog: TMemo;
    pnlBackground: TPanel;
    pnlInput: TPanel;
    procedure edtCommandKeyPress(Sender: TObject; var Key: char);
  private
    FOnCommandEntered: TCommandEvent;

    // Variabel untuk sistem Animasi Typewriter
    FMessageQueue: TStringList;
    FTypingTimer: TTimer;
    FCurrentMessage: string;
    FCurrentCharIdx: Integer;
    FIsTyping: Boolean;

    FAudioEngine: TAudioSynthesizer;

    procedure OnTypingTimerTick(Sender: TObject);
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure AddLog(const AMsg: string; AIsError: Boolean = False);

    property OnCommandEntered: TCommandEvent read FOnCommandEntered write FOnCommandEntered;
    property AudioEngine: TAudioSynthesizer read FAudioEngine write FAudioEngine;
  end;

implementation

{$R *.lfm}

{ TFrameTerminal }

constructor TFrameTerminal.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);

  // Inisialisasi Antrean Pesan
  FMessageQueue := TStringList.Create;
  FIsTyping := False;

  // Inisialisasi Timer Ketik (Sangat cepat: 15 milidetik per frame)
  FTypingTimer := TTimer.Create(Self);
  FTypingTimer.Interval := 15;
  FTypingTimer.OnTimer := @OnTypingTimerTick;
  FTypingTimer.Enabled := True;
end;

destructor TFrameTerminal.Destroy;
begin
  FTypingTimer.Free;
  FMessageQueue.Free;
  inherited Destroy;
end;

procedure TFrameTerminal.edtCommandKeyPress(Sender: TObject; var Key: char);
var
  Cmd: string;
begin
  if Key = #13 then // Tombol Enter
  begin
    Key := #0; // Konsumsi input agar tidak berbunyi 'ding' Windows
    Cmd := Trim(edtCommand.Text);

    if Cmd <> '' then
    begin
      if Assigned(FOnCommandEntered) then
        FOnCommandEntered(Self, Cmd);
      edtCommand.Clear;
    end;
  end;
end;

procedure TFrameTerminal.AddLog(const AMsg: string; AIsError: Boolean);
begin
  // Alih-alih langsung mencetak ke layar, masukkan pesan ke antrean
  // agar diproses satu per satu oleh TTypingTimer
  FMessageQueue.Add(AMsg);
end;

procedure TFrameTerminal.OnTypingTimerTick(Sender: TObject);
var
  TypingSpeed: Integer;
begin
  if not FIsTyping then
  begin
    // Jika sedang diam dan ada pesan mengantre, mulai mengetik pesan baru
    if FMessageQueue.Count > 0 then
    begin
      FCurrentMessage := FMessageQueue[0];
      FMessageQueue.Delete(0); // Hapus dari antrean setelah diambil
      FCurrentCharIdx := 0;
      FIsTyping := True;

      // Cegah kebocoran memori jika log terlalu panjang
      if memLog.Lines.Count > 1000 then
        memLog.Lines.Delete(0);

      // Siapkan baris kosong baru di bagian bawah untuk diketik
      memLog.Append('');
    end;
  end
  else
  begin
    // Logika Kecepatan Ketik Dinamis (Kalimat panjang diketik lebih cepat)
    TypingSpeed := 1;
    if Length(FCurrentMessage) > 30 then TypingSpeed := 2;
    if Length(FCurrentMessage) > 60 then TypingSpeed := 3;

    FCurrentCharIdx := FCurrentCharIdx + TypingSpeed;
    if FCurrentCharIdx > Length(FCurrentMessage) then
      FCurrentCharIdx := Length(FCurrentMessage);

    // Timpa teks di baris terakhir perlahan-lahan dari karakter pertama hingga saat ini
    memLog.Lines[memLog.Lines.Count - 1] := Copy(FCurrentMessage, 1, FCurrentCharIdx);

    // Mainkan suara blip (seperti bunyi pemrosesan data)
    if Assigned(FAudioEngine) then
      FAudioEngine.PlayBlip;

    // Paksa scrollbar agar selalu menyorot teks paling bawah
    memLog.SelStart := Length(memLog.Text);
    memLog.SelLength := 0;

    // Jika seluruh kalimat sudah selesai diketik, matikan status typing
    if FCurrentCharIdx >= Length(FCurrentMessage) then
      FIsTyping := False;
  end;
end;

end.
