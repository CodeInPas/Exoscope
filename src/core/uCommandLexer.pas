unit uCommandLexer;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  SysUtils, StrUtils;

type
  { Struktur data untuk menampung flag/parameter bernama (contoh: -MODE GAUSSIAN) }
  TCommandFlag = record
    Key: string;
    Value: string;
  end;

  { Struktur data hasil parsing dari raw input CLI }
  TCommandData = record
    Command: string;
    Args: array of string;         { Positional Arguments (contoh: FILTER) }
    Flags: array of TCommandFlag;  { Named Arguments }
    IsValid: Boolean;

    { Helper statis pada record untuk pencarian flag efisien (O(N)) }
    function GetFlagValue(const AKey: string; const ADefault: string = ''): string;

    { FITUR BARU: Helper khusus untuk mem-parsing angka desimal Frekuensi/Fase pada minigame }
    function GetFlagValueAsFloat(const AKey: string; const ADefault: Double = 0.0): Double;

    function HasFlag(const AKey: string): Boolean;
  end;

  { TCommandLexer
    Lexer/Tokenizer statis yang dirancang bebas memori (tanpa instansiasi class)
    untuk memproses string input dengan kompleksitas O(N). }
  TCommandLexer = class
  public
    { Mengurai string mentah menjadi token terstruktur }
    class function Parse(const ARawInput: string): TCommandData;
  end;

implementation

{ TCommandData }

function TCommandData.GetFlagValue(const AKey: string; const ADefault: string = ''): string;
var
  I: Integer;
begin
  Result := ADefault;
  for I := 0 to High(Flags) do
  begin
    if SameText(Flags[I].Key, AKey) then
      Exit(Flags[I].Value);
  end;
end;

function TCommandData.GetFlagValueAsFloat(const AKey: string; const ADefault: Double = 0.0): Double;
var
  StrVal: string;
  Fmt: TFormatSettings;
begin
  StrVal := GetFlagValue(AKey, '');
  if StrVal = '' then Exit(ADefault);

  // Memastikan titik atau koma bisa diproses sebagai desimal dengan aman
  // untuk mencegah crash konversi StrToFloat pada regional OS yang berbeda
  Fmt := DefaultFormatSettings;
  Fmt.DecimalSeparator := '.';
  StrVal := StringReplace(StrVal, ',', '.', [rfReplaceAll]);

  Result := StrToFloatDef(StrVal, ADefault, Fmt);
end;

function TCommandData.HasFlag(const AKey: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(Flags) do
  begin
    if SameText(Flags[I].Key, AKey) then
      Exit(True);
  end;
end;

{ TCommandLexer }

class function TCommandLexer.Parse(const ARawInput: string): TCommandData;
var
  Tokens: TStringArray;
  I: Integer;
  CurrentToken: string;
begin
  Result.Command := '';
  SetLength(Result.Args, 0);
  SetLength(Result.Flags, 0);
  Result.IsValid := False;

  // Optimasi pemisahan string: TStringSplitOptions.ExcludeEmpty otomatis
  // membersihkan spasi ganda tanpa perlu perulangan manual
  Tokens := ARawInput.Trim.Split([' '], TStringSplitOptions.ExcludeEmpty);

  if Length(Tokens) = 0 then Exit;

  // Token pertama selalu di-treat sebagai Main Command
  Result.Command := UpperCase(Tokens[0]);
  Result.IsValid := True;

  I := 1;
  while I < Length(Tokens) do
  begin
    CurrentToken := Tokens[I];

    // Deteksi Flag (Token yang diawali karakter '-')
    if CurrentToken.StartsWith('-') then
    begin
      SetLength(Result.Flags, Length(Result.Flags) + 1);

      // Hapus karakter '-' menggunakan Substring dan standarisasi ke UpperCase
      Result.Flags[High(Result.Flags)].Key := UpperCase(CurrentToken.Substring(1));

      // Cek Lookahead: Apakah token berikutnya adalah nilai dari flag ini?
      // (Bukan akhir array, dan tidak diawali dengan '-')
      if (I + 1 < Length(Tokens)) and not Tokens[I + 1].StartsWith('-') then
      begin
        Result.Flags[High(Result.Flags)].Value := Tokens[I + 1]; // Case-sensitive untuk value
        Inc(I); // Lewati token nilai agar tidak diproses sebagai Positional Arg
      end
      else
        Result.Flags[High(Result.Flags)].Value := ''; // Flag boolean (contoh: -FORCE)
    end
    else
    begin
      // Deteksi Positional Argument (contoh: 'FILTER' dalam 'RUN FILTER')
      SetLength(Result.Args, Length(Result.Args) + 1);
      Result.Args[High(Result.Args)] := UpperCase(CurrentToken);
    end;

    Inc(I);
  end;
end;

end.
