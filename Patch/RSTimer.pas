unit RSTimer;

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

{$IFDEF LINUX}
uses Messages, Windows, SysUtils, Classes, Forms, Consts, WinUtils;
{$ENDIF}
{$IFDEF MSWINDOWS}
uses Messages, Windows, SysUtils, Forms, Classes, Consts;
{$ENDIF}

type
  TRSTimer = class(TComponent)
  private
    FInterval: cardinal;
    FOnTimer: TNotifyEvent;
    FEnabled: boolean;
    FUseWindow: boolean;
    procedure SetEnabled(Value: boolean);
    procedure SetInterval(Value: cardinal);
    procedure SetOnTimer(Value: TNotifyEvent);
    procedure SetUseWindow(const Value: boolean);
  protected
    FHandle: HWND;
    FTimer: uint;
    FObjectInstance: pointer;
    IsActive: boolean;
    procedure Timer; virtual;
    procedure WndProc(var Msg: TMessage);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure UpdateTimer;
  published
     // UseWindow should be the first
    property UseWindow: boolean read FUseWindow write SetUseWindow default true;
    property Enabled: boolean read FEnabled write SetEnabled default True;
    property Interval: cardinal read FInterval write SetInterval default 1000;
    property OnTimer: TNotifyEvent read FOnTimer write SetOnTimer;
  end;


procedure register;

implementation

procedure register;
begin
  RegisterComponents('RSPak', [TRSTimer]);
end;

constructor TRSTimer.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FEnabled:= true;
  FInterval:= 1000;
  FUseWindow:= true;
end;

destructor TRSTimer.Destroy;
begin
  FEnabled := False;
  UpdateTimer;
  FreeObjectInstance(FObjectInstance);
  inherited Destroy;
end;

procedure TRSTimer.WndProc(var Msg: TMessage);
begin
  with Msg do
    if Msg = WM_TIMER then
      try
        Timer;
      except
        Application.HandleException(Self);
      end
    else
      result := DefWindowProc(FHandle, Msg, wParam, lParam);
end;

procedure TRSTimer.UpdateTimer;
var Active:boolean;
begin
  Active:= (FInterval <> 0) and FEnabled and Assigned(FOnTimer);
  if not Active and not IsActive then
    exit;

  if IsActive then
  begin
    KillTimer(FHandle, FTimer);
    IsActive:=false;
  end;

  if Active then
  begin
    if FUseWindow and (FHandle = 0) then
      FHandle:= AllocateHWnd(WndProc);

    if FHandle<>0 then
    begin
      IsActive:= SetTimer(FHandle, 1, FInterval, nil) <> 0;
      FTimer:= 1;
    end else
    begin
      if FObjectInstance = nil then
        FObjectInstance:= MakeObjectInstance(WndProc);
      FTimer:= SetTimer(0, 1, FInterval, FObjectInstance);
      IsActive:= FTimer<>0;
    end
  end;

  if not IsActive and (FHandle<>0) then
  begin
    DeallocateHWnd(FHandle);
    FHandle:=0;
  end;
  
  if Active<>IsActive then
    raise EOutOfResources.Create(SNoTimers);
end;

procedure TRSTimer.SetEnabled(Value: boolean);
begin
  if Value <> FEnabled then
  begin
    FEnabled := Value;
    UpdateTimer;
  end;
end;

procedure TRSTimer.SetInterval(Value: cardinal);
begin
  if Value <> FInterval then
  begin
    FInterval := Value;
    UpdateTimer;
  end;
end;

procedure TRSTimer.SetOnTimer(Value: TNotifyEvent);
begin
  FOnTimer := Value;
  UpdateTimer;
end;

procedure TRSTimer.Timer;
begin
  if Assigned(FOnTimer) then FOnTimer(Self);
end;

procedure TRSTimer.SetUseWindow(const Value: boolean);
begin
  if Value <> FUseWindow then
  begin
    FUseWindow := Value;
    UpdateTimer;
  end;
end;

end.
 