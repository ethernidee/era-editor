unit RSCodeHook;

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
  Windows, RSSysUtils, RSQ, Math;

type
  TRSHookType = (RShtNop, RSht1, RSht2, RSht4, RShtCall, RShtJmp, RShtJmp6, RShtJmp2);

  PRSHookInfo = ^TRSHookInfo;
  TRSHookInfo = record
    p: int;
    pref: boolean;
    old: int;
    backup: ptr;
    add: int;
    New: int;
    newp: ptr;
    newref: boolean;
    t: TRSHookType;
    size: int;
    Querry: int;
  end;

procedure RSApplyHook(const Hook: TRSHookInfo);
procedure RSApplyHooks(const Hooks; Querry: int = 0);
function RSCheckHook(const hk:TRSHookInfo):boolean;
function RSCheckHooks(const Hooks):boolean; overload;
function RSCheckHooks(const Hooks; Querry: int):boolean; overload;

implementation

function GetHookValue(const hk: TRSHookInfo):int;
var p: int;
begin
  p:= hk.p;
  case hk.t of
    RSht1:  result:= pbyte(p)^;
    RSht2:  result:= pword(p)^;
    RSht4:  result:= pint(p)^;
    RShtCall, RShtJmp:
      result:= pint(p+1)^ + p + 5;
    RShtJmp6:
      result:= pint(p+2)^ + p + 6;
    RShtJmp2:
      result:= pint1(p+1)^ + p + 2;
    else
      result:= 0;
  end;
end;

procedure RSApplyHook(const Hook: TRSHookInfo);
var
  OldProtect: DWord;
  sz, sz0, New, i, p: int;
begin
  case Hook.t of
    RShtNop:  sz0:= 0;
    RSht1:    sz0:= 1;
    RSht2:    sz0:= 2;
    RSht4:    sz0:= 4;
    RShtJmp2: sz0:= 2;
    RShtJmp6: sz0:= 6;
    else      sz0:= 5;
  end;
  sz:= max(Hook.size, sz0);
  if sz = 0 then  exit;
  p:= Hook.p;
  if Hook.pref then  p:= pint(p)^;
  New:= int(Hook.newp);
  if New = 0 then  New:= Hook.New;
  if Hook.newref then  New:= pint(New)^;
  if Hook.add <> 0 then  New:= GetHookValue(Hook) + Hook.add;
  if Hook.backup <> nil then  pint(Hook.backup)^:= GetHookValue(Hook);

  VirtualProtect(ptr(p), sz, PAGE_EXECUTE_READWRITE, @OldProtect);
  case Hook.t of
    RSht1:  pbyte(p)^:= New;
    RSht2:  pword(p)^:= New;
    RSht4:  pint(p)^:= New;
    RShtCall:
    begin
      pbyte(p)^:= $E8;
      pint(p+1)^:= New - p - 5;
    end;
    RShtJmp:
    begin
      pbyte(p)^:= $E9;
      pint(p+1)^:= New - p - 5;
    end;
    RShtJmp6: pint(p+2)^:= New - p - 6;
    RShtJmp2: pint1(p+1)^:= New - p - 2;
  end;
  for i := sz0 to sz - 1 do
    pbyte(p+i)^:= $90;
  VirtualProtect(ptr(p), sz, OldProtect, @OldProtect);
end;

procedure RSApplyHooks(const Hooks; Querry: int = 0);
var
  hk: PRSHookInfo;
begin
  hk:= @Hooks;
  while hk.p <> 0 do
  begin
    if hk.Querry = Querry then
      RSApplyHook(hk^);
    Inc(hk);
  end;
end;

function RSCheckHook(const hk:TRSHookInfo):boolean;
begin
  result:= true;
  if hk.old = 0 then
    if (hk.newp <> nil) or (hk.add <> 0) or (hk.t in [RShtCall, RShtJmp, RShtJmp6, RShtJmp2]) then
      exit;

  if hk.t <> RShtNop then
    result:= GetHookValue(hk) = hk.old;
end;

function RSCheckHooks(const Hooks):boolean;
var
  hk: PRSHookInfo;
begin
  hk:= @Hooks;
  result:= false;
  while hk.p <> 0 do
  begin
    if not RSCheckHook(hk^) then  exit;
    Inc(hk);
  end;
  result:= true;
end;

function RSCheckHooks(const Hooks; Querry: int):boolean;
var
  hk: PRSHookInfo;
begin
  hk:= @Hooks;
  result:= false;
  while hk.p <> 0 do
  begin
    if (hk.Querry = Querry) and not RSCheckHook(hk^) then  exit;
    Inc(hk);
  end;
  result:= true;
end;

end.
