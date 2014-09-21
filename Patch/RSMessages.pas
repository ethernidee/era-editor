unit RSMessages;

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
  SysUtils, Classes, Controls, Buttons, Graphics, Messages, Forms, Windows;


type
  TRSWMNoParams = packed record
    Msg: cardinal;
    UnusedW: Longint;
    UnusedL: Longint;
    result: Longint;
  end;

  TCMMouseLeave = packed record
    Msg: cardinal;
    Unused: Longint;
    Sender: TControl;
    result: Longint;
  end;

  TCMMouseEnter = TCMMouseLeave;

  TCMParentFontChanged = packed record
    Msg: cardinal;
    FontIncluded: Longbool;
    Font: TFont;
    result: Longint;
  end;

  TCMParentColorChanged = packed record
    Msg: cardinal;
    ColorIncluded: Longbool;
    Color: TColor;
    result: Longint;
  end;

  TCMVisibleChanged = packed record
    Msg: cardinal;
    Visible: Longbool;
    Unused: Longint;
    result: Longint;
  end;

  TCMParentCtl3DChanged = packed record
    Msg: cardinal;
    Ctl3DIncluded: Longbool;
    Ctl3D: Longbool;
    result: Longint;
  end;

  TCMAppSysCommand = packed record
    Msg: cardinal;
    Unused: Longint;
    message: PMessage;
    result: Longint;
  end;

  TCMButtonPressed = packed record
    Msg: cardinal;
    GroupIndex: Longint;
    Sender: TSpeedButton;
    result: Longint;
  end;

  TCMInvokeHelp = packed record
    Msg: cardinal;
    Command: Longint;
    Data: Longint;
    result: Longint;
  end;

  TCMWindowHook = packed record
    Msg: cardinal;
    UnHook: Longbool;
    WindowHook: ^TWindowHook;
    result: Longint;
  end;

  TCMDocWindowActivate = packed record
    Msg: cardinal;
    Active: Longbool;
    Unused: Longint;
    result: Longint;
  end;

  TCMDialogHandle = packed record
    Msg: cardinal;
    Get: LongBool; // 1 - Get, otherwise Set
    Handle: HWnd;
    result: Longint;
  end;

  TCMInvalidate = packed record
    Msg: cardinal;
    Notification: Longbool;
    Unused: Longint;
    result: Longint;
  end;

  TCMBiDiModeChanged = packed record
    Msg: cardinal;
    NoMiddleEastRecreate: Longbool;
    Unused: Longint;
    result: Longint;
  end;

  TCMActionUpdate = packed record
    Msg: cardinal;
    Unused: Longint;
    Action: TBasicAction;
    result: Longint;
  end;

  TCMActionExecute = TCMActionUpdate;

  TCMAppKeyDown = TWMKey;
  TCMWinIniChange = TWMWinIniChange;
  TCMIsShortCut = TWMKey;

  TCMEnabledChanged = TRSWMNoParams;
  TCMColorChanged = TRSWMNoParams;
  TCMFontChanged = TRSWMNoParams;
  TCMCursorChanged = TRSWMNoParams;
  TCMCtl3DChanged = TRSWMNoParams;
  TCMTextChanged = TRSWMNoParams;
  TCMMenuChanged = TRSWMNoParams;
  TCMShowingChanged = TRSWMNoParams;
  TCMIconChanged = TRSWMNoParams;
  TCMRelease = TRSWMNoParams;
  TCMShowHintChanged = TRSWMNoParams;
  TCMParentShowHintChanged = TRSWMNoParams;
  TCMSysColorChange = TRSWMNoParams;
  TCMFontChange = TRSWMNoParams;
  TCMTimeChange = TRSWMNoParams;
  TCMTabStopChanged = TRSWMNoParams;
  TCMUIActivate = TRSWMNoParams;
  TCMUIDeactivate = TRSWMNoParams;
  TCMGetDataLink = TRSWMNoParams;
  TCMIsToolControl = TRSWMNoParams;
  TCMRecreateWnd = TRSWMNoParams;
  TCMSysFontChanged = TRSWMNoParams;
  TCMBorderChanged = TRSWMNoParams;
  TCMParentBiDiModeChanged = TRSWMNoParams;
  TCMAllChildrenFlipped = TRSWMNoParams;

// CN messages are equal to WM analogs

implementation

end.
 