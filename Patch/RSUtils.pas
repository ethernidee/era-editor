unit RSUtils;

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

uses
  SysUtils, Windows, Messages, Classes, Controls, Forms, RSSysUtils, RSQ,
  Graphics, TypInfo, Menus, RSPainters, Themes;

{ TRSSimpleHintWindow }

type
  TRSSimpleHintWindow = class(THintWindow)
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure Paint; override;
    procedure NCPaint(DC: HDC); override;
  public
    function CalcHintRect(MaxWidth: integer; const AHint: string;
      AData: pointer): TRect; override;
    procedure ActivateHint(Rect: TRect; const AHint: string); override;
  end;

var
  RSHintBorderColor: TColor; // = cl3DDkShadow;
  RSHintHasShadow: boolean = true;

 // In D7 themes aren't updated when turned on
procedure RSFixThemesBug;

function RSIsControlVisible(c:TControl):boolean;

function RSPtInControl(const pt:TPoint; c:TControl):boolean;

procedure RSSetFocus(c:TWinControl);

function RSIsChild(parent, c:TControl):boolean;

function RSIsEnabled(it:TMenuItem):boolean;

procedure RSRemoveBevels(Form: TComponent);
 // RSRemoveFlatBevels is based on the assumption that BevelInner is modified
procedure RSRemoveFlatBevels(Form: TComponent; Restore:boolean=false);
procedure RSHookFlatBevels(Form: TComponent);
procedure RSFlatBevelsIgnore(c: TClass); overload;
procedure RSFlatBevelsIgnore(c: TControl); overload;

function RSGetCursorHeightMargin: integer;

var
  RSHintWindowClass: THintWindowClass;
  RSHintHideAnimationTime: int = 200;

procedure RSShowHint(const Hint: string; const Pos: TRect; Timeout:int=0;
  htTransparent:boolean=false; HideOnDeactivate:boolean=false; Data:ptr=nil;
  BiDi:TBiDiMode=bdLeftToRight); overload;
procedure RSShowHint(const Hint: string; const Pos: TPoint; Timeout:int=0;
  htTransparent:boolean=false; HideOnDeactivate:boolean=false; Data:ptr=nil;
  BiDi:TBiDiMode=bdLeftToRight); overload;
procedure RSHideHint(Animate:boolean);
function RSHelpHint(Sender: TObject; Hint:string=''):boolean;
procedure RSErrorHint(c:TControl; const s:string; Timeout:int=0;
  Focus:boolean = true; Sound:int = MB_ICONWARNING);

procedure RSMakeTransparent(Wnd:TWinControl; AddBorder:boolean=true;
  UseRgn:boolean=false);

procedure RSPaintList(Control: TWinControl; Canvas:TCanvas; const AText:string;
   Rect: TRect; State: TOwnerDrawState; Pic:TBitmap = nil; Spacing:int = 4);

 // Also checks thread synchronozation and CM_MOUSEENTER/LEAVE messages
procedure RSProcessMessages;

{function RSMessageBox(AText:string; ACaption:string='';
                                        AType:integer=0); overload;

function RSMessageBox(AText, ACaption:string;
                             const Buttons:array of const); overload;
}
implementation

{
***************************** TRSSimpleHintWindow ******************************
}
procedure TRSSimpleHintWindow.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  if not RSHintHasShadow then
    with Params.WindowClass do
      Style:= Style and not CS_DROPSHADOW;
end;

procedure TRSSimpleHintWindow.Paint;
var
  R: TRect;
begin
  R := ClientRect;
  Inc(R.Left, 2);
  Inc(R.Top, 2);
  DrawText(Canvas.Handle, pchar(Caption), -1, R, DT_LEFT or DT_NOPREFIX or
    DT_WORDBREAK or DrawTextBiDiModeFlagsReadingOnly);
end;

procedure TRSSimpleHintWindow.NCPaint(DC: HDC);
var R:TRect;
begin
  R:=Rect(0, 0, Width, Height);
  with TBrush.Create do
    try
      Color:=RSHintBorderColor;
      FrameRect(DC, R, Handle);
    finally
      Free;
    end;
end;

function TRSSimpleHintWindow.CalcHintRect(MaxWidth: integer; const AHint: string;
           AData: pointer): TRect;
begin
  Canvas.Font:=Screen.HintFont;
  result:= inherited CalcHintRect(MaxWidth, AHint, AData);
end;

procedure TRSSimpleHintWindow.ActivateHint(Rect: TRect; const AHint: string);
begin
  Canvas.Font:=Screen.HintFont;
  inherited;
end;

{------------------------------------------------------------------------------}

type
  THookObj = class
    class function ThemesHook(var Msg: TMessage):boolean;
    function BevelsHook(var Msg: TMessage):boolean;
  end;

class function THookObj.ThemesHook(var Msg: TMessage): boolean;
begin
  result:=false;
  if (Msg.Msg = WM_THEMECHANGED) and not ThemeServices.ThemesEnabled then
    ThemeServices.ApplyThemeChange;
end;

function THookObj.BevelsHook(var Msg: TMessage):boolean;
begin
  result:=false;
  if Msg.Msg <> WM_THEMECHANGED then  exit;
  ThemeServices.UpdateThemes;
  RSRemoveFlatBevels(TComponent(self), not ThemeServices.ThemesEnabled);
end;

 // In D7 themes aren't updated when turned on
procedure RSFixThemesBug;
begin
{$IFNDEF D2005}
  Application.HookMainWindow(THookObj.ThemesHook);
{$ENDIF}
end;

function RSIsControlVisible(c:TControl):boolean;
begin
  result:=false;
  if not (c is TWinControl) then
  begin
    if not c.Visible then exit;
    c:=c.Parent;
  end;
  result:= TWinControl(c).HandleAllocated and
           IsWindowVisible(TWinControl(c).Handle);
end;

function RSPtInControl(const pt:TPoint; c:TControl):boolean;
begin
  if c is TWinControl then
    result:= TWinControl(c).HandleAllocated and
             PtInRect(TRSWnd(TWinControl(c).Handle).AbsoluteRect,pt)
  else
    result:= c.Parent.HandleAllocated and
             PtInRect(c.BoundsRect,c.Parent.ScreenToClient(pt));
end;

procedure RSSetFocus(c:TWinControl);
begin
  SetFocus(c.Handle);
   // TWinControl.SetFocus raises an exception if the control is hidden
end;

function RSIsChild(parent, c:TControl):boolean;
var c1:TWinControl;
begin
  if (parent is TWinControl) and (c<>parent) then
  begin
    c1:=c.Parent;
    result:=(c1=parent) or (c1<>nil) and TWinControl(parent).HandleAllocated and
                            IsChild(TWinControl(parent).Handle, c1.Handle);
  end else
    result:=false;
end;

function RSIsEnabled(it:TMenuItem):boolean;
begin
  result:= it.Enabled and ((it.Parent=nil) or RSIsEnabled(it.Parent));
end;

{
procedure RSRemoveBevels(Form:TComponent; Classes:array of TControlClass);
begin

end;
}

 // Mostly for backward compatibility
procedure RSRemoveBevels(Form: TComponent);
var c:TComponent; i:int;
  Prop:PPropInfo;
begin
  for i:=Form.ComponentCount-1 downto 0 do
  begin
    c:=Form.Components[i];
    if not (c is TControl) then continue;

    Prop:=GetPropInfo(c.ClassType, 'BevelKind', [tkEnumeration]);
    if (Prop=nil) or (Prop.PropType^.Name<>'TBevelKind') or
       (GetOrdProp(c, Prop)=ord(bkNone)) then
      continue;

    SetOrdProp(c, Prop, ord(bkNone));

    Prop:=GetPropInfo(c.ClassType, 'BorderStyle', [tkEnumeration]);
    if (Prop=nil) or (Prop.PropType^.Name<>'TBorderStyle') then
      continue;
    SetOrdProp(c, Prop, ord(bsSingle));
  end;
end;

var
  IgnoreClasses: array of TClass;
  IgnoreControls: array of TControl;

procedure RSRemoveFlatBevels(Form: TComponent; Restore:boolean=false);
label
  Next;
const
  BevelKinds: array[boolean] of TBevelKind = (bkNone, bkFlat);
  BorderStyles: array[boolean] of TBorderStyle = (bsSingle, bsNone);
var
  c:TComponent; i,j:int; Prop:PPropInfo;
begin
  for i:= Form.ComponentCount-1 downto 0 do
  begin
    c:=Form.Components[i];
    if not (c is TControl) then  continue;

    for j:= High(IgnoreControls) downto 0 do
      if c = IgnoreControls[j] then
        goto Next;

    for j:= High(IgnoreClasses) downto 0 do
      if c.ClassType = IgnoreClasses[j] then
        goto Next;

    Prop:=GetPropInfo(c.ClassType, 'BevelInner', [tkEnumeration]);
    if (Prop=nil) or (Prop.PropType^.Name<>'TBevelCut') or
       (GetOrdProp(c, Prop) in [ord(bvRaised), ord(bkNone)]) then
      continue;

    Prop:=GetPropInfo(c.ClassType, 'BevelKind', [tkEnumeration]);
    if (Prop=nil) or (Prop.PropType^.Name<>'TBevelKind') or
       (GetOrdProp(c, Prop)<>ord(BevelKinds[not Restore])) then
      continue;

    SetOrdProp(c, Prop, ord(BevelKinds[Restore]));

    Prop:=GetPropInfo(c.ClassType, 'BorderStyle', [tkEnumeration]);
    if (Prop=nil) or (Prop.PropType^.Name<>'TBorderStyle') then
      continue;
    SetOrdProp(c, Prop, ord(BorderStyles[Restore]));
Next:
  end;
end;

procedure RSHookFlatBevels(Form: TComponent);
begin
  Application.HookMainWindow(THookObj(Form).BevelsHook);
  RSRemoveFlatBevels(Form, not ThemeServices.ThemesEnabled);
end;

procedure RSFlatBevelsIgnore(c: TClass); overload;
var i:int;
begin
  for i:= High(IgnoreClasses) downto 0 do
    if IgnoreClasses[i] = c then  exit;
  i:= Length(IgnoreClasses);
  SetLength(IgnoreClasses, i + 1);
  IgnoreClasses[i]:= c;
end;

procedure RSFlatBevelsIgnore(c: TControl); overload;
var i:int;
begin
  for i:= High(IgnoreControls) downto 0 do
    if IgnoreControls[i] = c then  exit;
  i:= Length(IgnoreControls);
  SetLength(IgnoreControls, i + 1);
  IgnoreControls[i]:= c;
end;

 // Taken from Application.ActivateHint
{ Return number of scanlines between the scanline containing cursor hotspot
  and the last scanline included in the cursor mask. }
function RSGetCursorHeightMargin: integer;
var
  IconInfo: TIconInfo;
  BitmapInfoSize, BitmapBitsSize, ImageSize: DWORD;
  Bitmap: PBitmapInfoHeader;
  Bits: pointer;
  BytesPerScanline: integer;

    function FindScanline(Source: pointer; MaxLen: cardinal;
      Value: cardinal): cardinal; assembler;
    asm
            PUSH    ECX
            MOV     ECX,EDX
            MOV     EDX,EDI
            MOV     EDI,EAX
            POP     EAX
            REPE    SCASB
            MOV     EAX,ECX
            MOV     EDI,EDX
    end;

begin
  { Default value is entire icon height }
  result := GetSystemMetrics(SM_CYCURSOR);
  if GetIconInfo(GetCursor, IconInfo) then
  try
    GetDIBSizes(IconInfo.hbmMask, BitmapInfoSize, BitmapBitsSize);
    Bitmap := AllocMem(DWORD(BitmapInfoSize) + BitmapBitsSize);
    try
    Bits := pointer(DWORD(Bitmap) + BitmapInfoSize);
    if GetDIB(IconInfo.hbmMask, 0, Bitmap^, Bits^) and
      (Bitmap^.biBitCount = 1) then
    begin
      { Point Bits to the end of this bottom-up bitmap }
      with Bitmap^ do
      begin
        BytesPerScanline := ((biWidth * biBitCount + 31) and not 31) div 8;
        ImageSize := biWidth * BytesPerScanline;
        Bits := pointer(DWORD(Bits) + BitmapBitsSize - ImageSize);
        { Use the width to determine the height since another mask bitmap
          may immediately follow }
        result := FindScanline(Bits, ImageSize, $FF);
        { In case the and mask is blank, look for an empty scanline in the
          xor mask. }
        if (result = 0) and (biHeight >= 2 * biWidth) then
          result := FindScanline(pointer(DWORD(Bits) - ImageSize),
          ImageSize, $00);
        result := result div BytesPerScanline;
      end;
      Dec(result, IconInfo.yHotSpot);
    end;
    finally
      FreeMem(Bitmap, BitmapInfoSize + BitmapBitsSize);
    end;
  finally
    if IconInfo.hbmColor <> 0 then DeleteObject(IconInfo.hbmColor);
    if IconInfo.hbmMask <> 0 then DeleteObject(IconInfo.hbmMask);
  end;
  if result<0 then // Small correction
    result:=0;
end;

{********************************* RSShowHint *********************************}
 // Based on Application.ActivateHint and stuff

type
  TMyWndProc = class
  public
    procedure MyWindowProc(var Msg:TMessage);
  end;

var
  FHintWindow: THintWindow; FTimerHandle: DWord;
  DefWinProc: TWndMethod; htTransp, HideDeact:boolean; LastActive:hwnd;

procedure DoHideHint(Animate:boolean);
begin
  if (FHintWindow = nil) or not FHintWindow.HandleAllocated then
    exit;

  if GetCapture = FHintWindow.Handle then
    ReleaseCapture;
  if Animate and (@AnimateWindowProc<>nil) then
    AnimateWindowProc(FHintWindow.Handle, RSHintHideAnimationTime,
      AW_BLEND or AW_HIDE);

  FHintWindow.ReleaseHandle;
end;

procedure StopHintTimer;
begin
  if FTimerHandle <> 0 then
  begin
    KillTimer(0, FTimerHandle);
    FTimerHandle := 0;
  end;
end;

procedure HintTimerProc(Wnd: HWnd; Msg, TimerID, SysTime: Longint); stdcall;
begin
  RSHideHint(true);
end;

procedure StartHintTimer(Value: integer);
begin
  StopHintTimer;
  FTimerHandle := SetTimer(0, 0, Value, @HintTimerProc);
  if FTimerHandle = 0 then
    DoHideHint(false);
end;

procedure TMyWndProc.MyWindowProc(var Msg:TMessage);
begin
  with THintWindow(self) do
    if not HandleAllocated or (csDestroyingHandle in ControlState) then  exit;

  case Msg.Msg of
    WM_NCHitTest:
      if not htTransp then
        Msg.result:=HTCLIENT
      else
        DefWinProc(Msg);
    WM_LButtonDown, WM_RBUTTONDOWN, WM_MBUTTONDOWN:
    begin
      DefWinProc(Msg);
      RSHideHint(false);
      if LastActive<>0 then
        SetActiveWindow(LastActive);
    end;
    WM_ACTIVATE:
      if (Msg.WParamLo=WA_INACTIVE) and HideDeact then
      begin
        DefWinProc(Msg);
        RSHideHint(false);
        SetActiveWindow(Msg.LParam);
      end else
        if Msg.WParamLo=WA_CLICKACTIVE then
        begin
          DefWinProc(Msg);
          RSHideHint(false);
          SetActiveWindow(Msg.LParam);
        end else
          if (Msg.WParamLo=WA_ACTIVE) and HideDeact then
          begin
            LastActive:=Msg.LParam;
            DefWinProc(Msg);
          end else
            DefWinProc(Msg);
    WM_KEYDOWN:
    begin
      RSHideHint(false);
      if LastActive<>0 then
        SetActiveWindow(LastActive);
    end;

    else
      DefWinProc(Msg);
  end;
end;

procedure RSHideHint(Animate:boolean);
begin
  StopHintTimer;
  DoHideHint(Animate);
end;

function ValidateHintWindow:boolean;
var c:THintWindowClass;
begin
  c:=RSHintWindowClass;
  if c=nil then c:=HintWindowClass;

  result:=(FHintWindow=nil) or (FHintWindow.ClassType<>c);
  if result then
  begin
    FHintWindow.Free;
    FHintWindow:=c.Create(Application);
    DefWinProc:=FHintWindow.WindowProc;
    FHintWindow.WindowProc:= TMyWndProc(FHintWindow).MyWindowProc;
  end;
end;

procedure RSShowHint(const Hint: string; const Pos: TRect; Timeout:int=0;
  htTransparent:boolean=false; HideOnDeactivate:boolean=false; Data:ptr=nil;
  BiDi:TBiDiMode=bdLeftToRight);
var
  AnimateProc: ptr; {$IFNDEF D2006} c:TControl; {$ENDIF}
begin
  if Timeout<=0 then Timeout:=Application.HintHidePause;

  ValidateHintWindow;
  FHintWindow.BiDiMode:=BiDi;
  htTransp:=htTransparent;
  HideDeact:=HideOnDeactivate;
  LastActive:=0;

  {$IFNDEF D2006} // Workaround for a bug in TAppplication.DoMouseIdle
  if HideOnDeactivate then
  begin
    c:= FindDragTarget(Mouse.CursorPos, true);
    if c<>nil then
      c.Perform(CM_MOUSELEAVE, 0, 0);
  end;
  {$ENDIF}

  FHintWindow.Color:=Application.HintColor;
  AnimateProc:=@AnimateWindowProc;
  @AnimateWindowProc:=nil;
  try
    FHintWindow.ActivateHint(Pos, Hint);
  finally
    @AnimateWindowProc:=AnimateProc;
  end;
  StartHintTimer(Timeout);
  if HideOnDeactivate then
  begin
    BringWindowToTop(FHintWindow.Handle);
    SetCapture(FHintWindow.Handle);
  end;
end;

procedure RSShowHint(const Hint: string; const Pos: TPoint; Timeout:int=0;
  htTransparent:boolean=false; HideOnDeactivate:boolean=false; Data:ptr=nil;
  BiDi:TBiDiMode=bdLeftToRight); overload;
var r:TRect;
begin
  ValidateHintWindow;
  r:=FHintWindow.CalcHintRect(Screen.Width, Hint, Data);
  OffsetRect(r, Pos.X, Pos.Y);
  RSShowHint(Hint, r, Timeout, htTransparent, HideOnDeactivate, Data, BiDi);
end;

function RSHelpHint(Sender: TObject; Hint:string=''):boolean;
var r:TRect; p:TPoint; s:string;
begin
  result:=false;
  if Hint='' then
    Hint:=(Sender as TControl).Hint;
  s:= GetLongHint(Hint);
  if (s = '') or (Length(s) = Length(Hint)) then exit;
  Hint:= s;
  if ValidateHintWindow then
  begin
     // Workaround for a strange shadow bug
    RSShowHint('', Point(0,0));
    RSHideHint(false);
  end;
  r:=FHintWindow.CalcHintRect(Screen.Width, Hint, nil);
  GetCursorPos(p);
  OffsetRect(r, p.X - r.Right div 2 +10, p.Y + RSGetCursorHeightMargin + 1);
  SetCursor(Screen.Cursors[crArrow]);
  RSShowHint(Hint, r, MaxInt, false, true);
  result:=true;
end;

procedure RSErrorHint(c:TControl; const s:string; Timeout:int=0;
   Focus:boolean = true; Sound:int = MB_ICONWARNING);
var p:TPoint;
begin
  p.X:=c.Left;
  p.Y:=c.BoundsRect.Bottom;
  p:=c.Parent.ClientToScreen(p);
  if Focus and (c is TWinControl) then
    RSSetFocus(TWinControl(c));
  if Sound <> 0 then
    MessageBeep(Sound);
  RSShowHint(s, p, Timeout);
end;

function MyCombineRgn(Dest, Src1, Src2:HRGN; Mode:integer):integer;
begin
  result:=CombineRgn(Dest, Src1, Src2, Mode);
  if result=ERROR then RSRaiseLastOSError;
end;

function MyCreateRectRgn(Left, Top, Right, Bottom: integer):HRGN;
begin
  result:=CreateRectRgn(Left, Top, Right, Bottom);
  if result=0 then RSRaiseLastOSError;
end;

procedure RSMakeTransparent(Wnd:TWinControl; AddBorder:boolean=true;
  UseRgn:boolean=false);
var
  i, j: integer;
  FullRgn, FormRgn, Rgn: HRGN;
  ClientR, r:TRect; WndTopLeft:TPoint;
  c: TControl;
begin
  FullRgn:=0;
  FormRgn:=0;
  Rgn:=0;
  with Wnd do
  try
     // ��� ���������� �������� ������������ ��������-������ ���� �����
     // ClientR - ���������� ���������� ����� �����.
    with ClientR do
    begin
      TopLeft:=ClientOrigin;
      RSWin32Check(GetWindowRect(wnd.Handle, r));
      Dec(TopLeft.X, r.Left);
      Dec(TopLeft.Y, r.Top);
      ClientR:=Bounds(Left, Top, ClientWidth, ClientHeight);

       // ���������� ���������� ��������-������ ���� �����
      WndTopLeft:=r.TopLeft;
    end;

     // FullRgn - ������ ���� �����, �� ���� ����� �������� ������� ����������
    FullRgn:=MyCreateRectRgn(0, 0, Width, Height);
    if UseRgn then GetWindowRgn(wnd.Handle, FullRgn);

    Rgn:=MyCreateRectRgn(ClientR.Left, ClientR.Top,
                         ClientR.Right, ClientR.Bottom);

     // ���� ������ �����������, �� ��������� ��� � ������� �����,
     // ����� ���� �������� �� ���� ���������� �����
    FormRgn:=MyCreateRectRgn(0, 0, 0, 0);
    if AddBorder then
      MyCombineRgn(FormRgn, FullRgn, Rgn, rgn_Diff)
    else
      MyCombineRgn(FullRgn, FullRgn, Rgn, RGN_AND);

    for i:= 0 to ControlCount-1 do
    begin
      c:=Controls[i];
      if not c.Visible then continue;

      DeleteObject(Rgn);
      Rgn:=0;

      if c is TWinControl then
      begin
        RSWin32Check(GetWindowRect(TWinControl(c).Handle, r));
        OffsetRect(r, -WndTopLeft.X, -WndTopLeft.Y);
        Rgn:=MyCreateRectRgn(r.Left, r.Top, r.Right, r.Bottom);

        j:=GetWindowRgn(TWinControl(c).Handle, Rgn);
         // ������ ��������, ��� ������� ��� � ���� ����� ����� ��������������
         // � ������ ������ ������ �� ��������
        if (j<>NULLREGION) and (j<>ERROR) then
          OffsetRgn(rgn, r.Left, r.Top);
      end else
        with ClientR do
          Rgn:= MyCreateRectRgn(Left + c.Left, Top + c.Top,
                      Left + c.Left + c.Width, Top + c.Top + Height);
      MyCombineRgn(FormRgn, FormRgn, Rgn, rgn_Or);
    end;
    MyCombineRgn(FormRgn, FormRgn, FullRgn, rgn_And);
    if SetWindowRgn(Handle, FormRgn, True)=0 then RSRaiseLastOSError;
    FormRgn:=0; // ��� ������� ��������� �������, ��� �� ���� ����������
  finally
    if FullRgn<>0 then DeleteObject(FullRgn);
    if FormRgn<>0 then DeleteObject(FormRgn);
    if Rgn<>0 then DeleteObject(Rgn);
  end;
end;

procedure RSPaintList(Control: TWinControl; Canvas:TCanvas; const AText:string;
   Rect: TRect; State: TOwnerDrawState; Pic:TBitmap = nil; Spacing:int = 4);
begin
  RSColorTheme.CheckColors;
  with Control, Canvas do
  begin
    Font:= TForm(Control).Font;
    if odSelected in State then
    begin
      RSColorTheme.DrawHotTrackBackground(Canvas, Rect);
      Brush.Color:=RSColorTheme.Selected1; //Color;
      if not (odFocused in State) then
        FrameRect(Rect);
    end else
    begin
      Brush.Color:= TForm(Control).Color;
      FillRect(Rect);
    end;
    if Pic<>nil then
    begin
      RSColorTheme.DrawGlyph(Canvas, Rect.Left+2,
        (Rect.Top + Rect.Bottom - Pic.Height) div 2, Pic, State, clBtnFace, true);
      Inc(Rect.Left, Pic.Width + Spacing);
    end;
    Brush.Style:=bsClear;
    TextRect(Rect,Rect.Left + 2,
             (Rect.Top+Rect.Bottom-TextHeight('a')) div 2, AText);
  end;
end;

procedure MyOnIdle(self:TObject; Sender: TObject; var Done: boolean);
begin
  Done:=false;
end;

const
  MyOnIdleMethod: TMethod = (Code:@MyOnIdle);

 // Also checks thread synchronozation and CM_MOUSEENTER/LEAVE messages  
procedure RSProcessMessages;
var
  Old:TIdleEvent;
begin
  if GetQueueStatus(QS_ALLEVENTS) shr 16 = 0 then
    exit;
  Application.ProcessMessages;
  Old:= Application.OnIdle;
  Application.OnIdle:= TIdleEvent(MyOnIdleMethod);
  try
    Application.HandleMessage; // Will most probably call Application.Idle 
  finally
    Application.OnIdle:= Old;
  end;  
end;

{
function MakeDialog(AText, ACaption:string; var Buttons:array of TButton;
                      const ButText:array of const):TForm;
begin

end;

function RSMessageBox(AText:string; ACaption:string='';
                                        AType:integer=0); overload;
begin

end;

function RSMessageBox(AText, ACaption:string;
                             const Buttons:array of const); overload;
begin

end;
}
{ TUnBug }

end.
