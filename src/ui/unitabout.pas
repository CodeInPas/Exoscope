unit UnitAbout;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, LCLIntf, Graphics, Dialogs, ExtCtrls, StdCtrls,
  Buttons;

type

  { TFormAbout }

  TFormAbout = class(TForm)
    BtnClose: TButton;
    Image1: TImage;
    Image2: TImage;
    lbLink: TLabel;
    LblTitle: TLabel;
    LblVersion: TLabel;
    LblCopyright: TLabel;
    LblTech: TLabel;
    MemoDesc: TMemo;
    PanelHeader: TPanel;
    procedure BtnCloseClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure lbLinkClick(Sender: TObject);
  private
    { private declarations }
  public
    { public declarations }
  end;

var
  FormAbout: TFormAbout;

implementation

{$R *.lfm}

{ TFormAbout }

procedure TFormAbout.FormCreate(Sender: TObject);
begin
  Self.Caption := 'Tentang Aplikasi';


end;

procedure TFormAbout.lbLinkClick(Sender: TObject);
begin
  OpenDocument('https://github.com/CodeInPas?tab=repositories');
end;

procedure TFormAbout.BtnCloseClick(Sender: TObject);
begin
  Close;
end;

end.
