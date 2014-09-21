unit RSDialogs;

{ *********************************************************************** }
{                                                                         }
{ RSPak                                    Copyright (c) Rozhenko Sergey  }
{ http://sites.google.com/site/sergroj/                                   }
{ sergroj@mail.ru                                                         }
{                                                                         }
{ This file is a subject to any one of these licenses at your choice:     }
{ BSD License, MIT License, Apache License, Mozilla Public License.       }
{                                                                         }
{ *********************************************************************** }
{$I RSPak.inc}

interface

uses Dialogs, Forms, Classes, CommDlg, Windows, Messages, RSCommon;

type
  TRSOpenSaveDialog = class;

  TRSOpenSaveDialogBeforeShow = procedure(Sender: TRSOpenSaveDialog;
     var DialogData: TOpenFilename) of object;
  TRSWndProcEvent = RSCommon.TRSWndProcEvent;

  TRSOpenSaveDialog = class(TOpenDialog)
  private
    FSaveDialog: boolean;
    FOnBeforeShow: TRSOpenSaveDialogBeforeShow;
    FOnWndProc: TRSWndProcEvent;
    FObjectInstance: pointer;
    procedure MainWndProc(var message: TMessage);
  protected
    function TaskModalDialog(DialogFunc: pointer; var DialogData): Bool; override;
    procedure TranslateWndProc(var Msg: TMessage);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function Execute: boolean; override;
  published
    property SaveDialog: boolean read FSaveDialog write FSaveDialog default false;
    property OnBeforeShow: TRSOpenSaveDialogBeforeShow read FOnBeforeShow write FOnBeforeShow;
    property OnWndProc: TRSWndProcEvent read FOnWndProc write FOnWndProc;
  end;

procedure register;

implementation

procedure register;
begin
  RegisterComponents('RSPak', [TRSOpenSaveDialog]);
end;

constructor TRSOpenSaveDialog.Create(AOwner: TComponent);
begin
  inherited;
  FObjectInstance:= MakeObjectInstance(MainWndProc);
end;

destructor TRSOpenSaveDialog.Destroy;
begin
  FreeObjectInstance(FObjectInstance);
  inherited;
end;

procedure GetSaveFileNamePreviewA; external 'MSVFW32.dll';
procedure GetOpenFileNamePreviewA; external 'MSVFW32.dll';

function TRSOpenSaveDialog.Execute: boolean;
begin
  if SaveDialog then
    result:= DoExecute(@GetSaveFileNamePreviewA)
  else
    result:= DoExecute(@GetOpenFileNamePreviewA);
{
  if SaveDialog then
    Result:= DoExecute(@GetSaveFileName)
  else
    Result:= DoExecute(@GetOpenFileName);
}
end;

procedure TRSOpenSaveDialog.MainWndProc(var message: TMessage);
begin
  try
    TranslateWndProc(message);
  except
    Application.HandleException(Self);
  end;
end;

function TRSOpenSaveDialog.TaskModalDialog(DialogFunc: pointer;
  var DialogData): Bool;
begin
  TOpenFilename(DialogData).lpfnHook:= FObjectInstance;
  if Assigned(FOnBeforeShow) then
    FOnBeforeShow(self, TOpenFilename(DialogData));
  result:= inherited TaskModalDialog(DialogFunc, DialogData);
end;

procedure TRSOpenSaveDialog.TranslateWndProc(var Msg: TMessage);
var b:boolean;
begin
  if Assigned(FOnWndProc) then
  begin
    b:=false;
    FOnWndProc(Self, Msg, b, WndProc);
    if b then exit;
  end;
  WndProc(Msg);
end;

end.
