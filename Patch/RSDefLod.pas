unit RSDefLod;
{ *********************************************************************** }
{ Copyright (c) Sergey Rozhenko                                           }
{ http://sites.google.com/site/sergroj/                                   }
{ sergroj@mail.ru                                                         }
{ *********************************************************************** }
{$I RSPak.inc}

interface

uses
  Windows, Classes, Messages, SysUtils, RSQ, Graphics, RSSysUtils, RSGraphics;

function RSMakePalette(HeroesPal:pointer):HPalette;

function RSMakeLogPalette(HeroesPal:pointer):PLogPalette;
procedure RSWritePalette(HeroesPal:pointer; Pal:HPALETTE);

implementation

type
  TLogPal = packed record
    palVersion: word;
    palNumEntries: word;
    palPalEntry: packed array[0..255] of TPaletteEntry;
  end;

  THeroesPalEntry = packed record
    Red:byte;
    Green:byte;
    Blue:byte;
  end;
  THeroesPal = packed array[0..255] of THeroesPalEntry;
  PHeroesPal = ^THeroesPal;

function RSMakePalette(HeroesPal:pointer):HPalette;
var Pal:PLogPalette;
begin
  Pal:=RSMakeLogPalette(HeroesPal);
  result:=RSWin32Check(CreatePalette(Pal^));
  FreeMem(Pal, 4 + 256*4);
end;

function RSMakeLogPalette(HeroesPal:pointer):PLogPalette;
var
  HerPal: PHeroesPal;
  i: int;
begin
  GetMem(result, 4 + 256*4);
  HerPal:=HeroesPal;
  result.palVersion:=$300;
  result.palNumEntries:=256;
  for i:=0 to 255 do
  begin
    result.palPalEntry[i].peRed:= HerPal[i].Red;
    result.palPalEntry[i].peGreen:= HerPal[i].Green;
    result.palPalEntry[i].peBlue:= HerPal[i].Blue;
    result.palPalEntry[i].peFlags:= 0;
  end;
end;

procedure RSWritePalette(HeroesPal:pointer; Pal:HPALETTE);
var
  HerPal: PHeroesPal; LogPal: TLogPal;
  i: int;
begin
  HerPal:=HeroesPal;
  GetPaletteEntries(Pal, 0, 256, LogPal.palPalEntry[0]);
  for i:=0 to 255 do
  begin
    HerPal[i].Red:= LogPal.palPalEntry[i].peRed;
    HerPal[i].Green:= LogPal.palPalEntry[i].peGreen;
    HerPal[i].Blue:= LogPal.palPalEntry[i].peBlue;
  end;
end;

end.
