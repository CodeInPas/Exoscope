unit uAudioSynthesizer;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, BASS;

type
  TSignalType = (stNoise, stBiosignature, stMegastructure);

  { TAudioSynthesizer }
  TAudioSynthesizer = class
  private
    FAmbientChannel: HSTREAM;
    FPanChannel: HSTREAM;
    FSliderChannel: HSTREAM;
    FSuccessChannel: HSTREAM;
    FFailChannel: HSTREAM;
    FSignalChannel: HSTREAM;
    FBlipChannel: HSTREAM; // Channel baru untuk suara ketikan terminal

    FAudioPath: string;

    procedure LoadSounds;
  public
    constructor Create;
    destructor Destroy; override;

    procedure PlayAmbient;
    procedure StopAmbient;

    procedure PlayRadarPan;
    procedure PlaySlider;
    procedure PlaySuccess;
    procedure PlayFail;
    procedure PlayBlip; // Prosedur baru untuk animasi terminal

    procedure PlaySignal(ASignal: TSignalType);
    procedure Stop;
  end;

implementation

{ TAudioSynthesizer }

constructor TAudioSynthesizer.Create;
begin
  inherited Create;

  if not BASS_Init(-1, 44100, 0, 0, nil) then
  begin
    if BASS_ErrorGetCode <> BASS_ERROR_ALREADY then
      WriteLn('BASS Init Error: ', BASS_ErrorGetCode);
  end;

  FAudioPath := ExtractFilePath(ParamStr(0)) + 'assets\audio\';
  if not DirectoryExists(FAudioPath) then
    ForceDirectories(FAudioPath);

  LoadSounds;
end;

destructor TAudioSynthesizer.Destroy;
begin
  BASS_StreamFree(FAmbientChannel);
  BASS_StreamFree(FPanChannel);
  BASS_StreamFree(FSliderChannel);
  BASS_StreamFree(FSuccessChannel);
  BASS_StreamFree(FFailChannel);
  BASS_StreamFree(FSignalChannel);
  BASS_StreamFree(FBlipChannel);

  BASS_Free();
  inherited Destroy;
end;

procedure TAudioSynthesizer.LoadSounds;
begin
  FAmbientChannel := BASS_StreamCreateFile(False, PChar(FAudioPath + 'ambient.mp3'), 0, 0, BASS_SAMPLE_LOOP);
  FPanChannel := BASS_StreamCreateFile(False, PChar(FAudioPath + 'radar_pan.wav'), 0, 0, 0);
  FSliderChannel := BASS_StreamCreateFile(False, PChar(FAudioPath + 'slider.wav'), 0, 0, 0);
  FSuccessChannel := BASS_StreamCreateFile(False, PChar(FAudioPath + 'success.wav'), 0, 0, 0);
  FFailChannel := BASS_StreamCreateFile(False, PChar(FAudioPath + 'fail.wav'), 0, 0, 0);
  FBlipChannel := BASS_StreamCreateFile(False, PChar(FAudioPath + 'blip.wav'), 0, 0, 0);
end;

procedure TAudioSynthesizer.PlayAmbient;
begin
  if FAmbientChannel <> 0 then
    BASS_ChannelPlay(FAmbientChannel, False);
end;

procedure TAudioSynthesizer.StopAmbient;
begin
  if FAmbientChannel <> 0 then
    BASS_ChannelPause(FAmbientChannel);
end;

procedure TAudioSynthesizer.PlayRadarPan;
begin
  if FPanChannel <> 0 then
    BASS_ChannelPlay(FPanChannel, True);
end;

procedure TAudioSynthesizer.PlaySlider;
begin
  if FSliderChannel <> 0 then
    BASS_ChannelPlay(FSliderChannel, True);
end;

procedure TAudioSynthesizer.PlaySuccess;
begin
  if FSuccessChannel <> 0 then
    BASS_ChannelPlay(FSuccessChannel, True);
end;

procedure TAudioSynthesizer.PlayFail;
begin
  if FFailChannel <> 0 then
    BASS_ChannelPlay(FFailChannel, True);
end;

procedure TAudioSynthesizer.PlayBlip;
begin
  if FBlipChannel <> 0 then
  begin
    // Reset posisi audio ke awal agar bisa diputar cepat beruntun
    BASS_ChannelSetPosition(FBlipChannel, 0, BASS_POS_BYTE);
    BASS_ChannelPlay(FBlipChannel, False);
  end;
end;

procedure TAudioSynthesizer.PlaySignal(ASignal: TSignalType);
var
  FileName: string;
begin
  Stop;

  case ASignal of
    stBiosignature: FileName := 'biosignal.wav';
    stMegastructure: FileName := 'megastructure.wav';
    else FileName := 'noise.wav';
  end;

  FSignalChannel := BASS_StreamCreateFile(False, PChar(FAudioPath + FileName), 0, 0, BASS_SAMPLE_LOOP);

  if FSignalChannel <> 0 then
    BASS_ChannelPlay(FSignalChannel, True);
end;

procedure TAudioSynthesizer.Stop;
begin
  if FSignalChannel <> 0 then
  begin
    BASS_ChannelStop(FSignalChannel);
    BASS_StreamFree(FSignalChannel);
    FSignalChannel := 0;
  end;
end;

end.
