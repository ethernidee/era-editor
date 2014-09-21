unit RSDef;
{ *********************************************************************** }
{ Copyright (c) Sergey Rozhenko                                           }
{ http://www.grayface.chat.ru                                             }
{ sergroj@mail.ru                                                         }
{ *********************************************************************** }
{$I RSPak.inc}

interface

uses
  Windows, Classes, Messages, SysUtils, RSSysUtils, RSQ, Graphics, RSDefLod,
  Math, RSGraphics, RTLConsts;

(*

Def format:
 <Header> { <Group> {Name} {Ptr} }   <Data>

Compressoins:
0   No special colors
1   255 special colors (only 8 are used)
2   7 special colors
3   7 special colors. Squares
Player's (blue) colors (found in some interface defs) aren't special in compression.

Code & Value meaning:
<255(7)   Special color number Code is repeated Value+1 times
255(7)    Then goes array of standard colors of Value+1 length

*)

type
  TLogPal = packed record
    palVersion: word;
    palNumEntries: word;
    palPalEntry: packed array[0..255] of TPaletteEntry;
  end;
  PLogPal = ^TLogPal;

  TRSDefWrapper = class;

  TRSPreparePaletteEvent = procedure(Sender: TRSDefWrapper; Pal:PLogPal)
                                                                    of object;

  TRSDefHeader = packed record
    TypeOfDef: int;
    Width: int;
    Height: int;
    GroupsCount: int;
    Palette: packed array [0..767] of byte;
  end;
  PRSDefHeader = ^TRSDefHeader;

  TRSDefGroup = packed record
    GroupNum: int;
    ItemsCount: int;
    Unk2: int; // Big number
    Unk3: int; // Another big Number
  end;
  PRSDefGroup = ^TRSDefGroup;

  TRSDefItemName = packed array[0..12] of char;
  PRSDefItemName = ^TRSDefItemName;
  TRSDefItemNames = packed array[0..MaxInt div sizeof(TRSDefItemName) -1] of TRSDefItemName;
  PRSDefItemNames = ^TRSDefItemNames;
  TRSDefPointers = packed array[0..MaxInt div 4 -1] of DWord;
  PRSDefPointers = ^TRSDefPointers;

  TRSDefPic = packed record
    FileSize: int;
    Compression: int;
    Width: int;
    Height: int;
    FrameWidth: int;
    FrameHeight: int;
    FrameLeft: int;
    FrameTop: int;
  end;
  PRSDefPic = ^TRSDefPic;

  TRSDefWrapper = class(TObject)
  protected
    FUseCustomPalette: boolean;
    FPicLinks: array of int;
    FPicNameLinks: array of PRSDefItemName;
    FPicturesCount: integer;
    FPal: PLogPalette;
    FPurePal: PLogPalette;
    FOnPreparePal: TRSPreparePaletteEvent;
    procedure PicLinksNeeded;
    procedure PicNameLinksNeeded;
    procedure DoExtractBuffer(Block:ptr; var PcxHdr:TRSDefPic;
                var Pic, Buffer, ShadowBuffer:ptr; BothBuffers:boolean);
    procedure DoExtractBmp(Block:ptr; Bmp, BmpSpec:TBitmap);
    function CreateExtractBmp(Block:ptr; Bmp, BmpSpec:TBitmap):TBitmap;
    procedure MakeFullBmp(Bmp, b1, b2:TBitmap);
  public
    Header: PRSDefHeader;
    Groups: array of PRSDefGroup;
    ItemNames: array of PRSDefItemNames;
    ItemPointers: array of PRSDefPointers;
    Data: TRSByteArray;
    constructor Create(AData:TRSByteArray);
    destructor Destroy; override;
    function ExtractBmp(PicNum:integer; Bitmap:TBitmap=nil;
               BmpSpec:TBitmap=nil):TBitmap; overload;
    function ExtractBmp(Group, PicNum:integer; Bitmap:TBitmap=nil;
               BmpSpec:TBitmap=nil):TBitmap; overload;
      // If Bitmap is specified, changes it and returns as the result
      // Creates a bitmap otherwise
    function GetPicHeader(PicNum:integer):PRSDefPic; overload;
    function GetPicHeader(Group, PicNum:integer):PRSDefPic; overload;
    function GetPicName(PicNum:integer):string; overload;
    function GetPicName(Group, PicNum:integer):string; overload;
    procedure RebuildPal;

    property PicturesCount: integer read FPicturesCount;
    property UseCustomPalette: boolean read FUseCustomPalette write FUseCustomPalette;
    property OnPreparePalette:TRSPreparePaletteEvent read FOnPreparePal write FOnPreparePal;
    property DefPalette:PLogPalette read FPurePal;
  end;

  TRSPicBuffer = class(TObject)
  protected
    FPics: array of TBitmap;
    FFiles: TStrings;
  public
    Links: array of int;
    procedure Initialize(Files:TStrings);
    function LoadPic(i:int):TBitmap;
  end;

  TRSDefMaker = class(TObject)
  protected
    Groups: array of array of int;
    function PackBitmap(Bmp, Spec:TBitmap; Compr:int):TRSByteArray;
  public
    PicNames: array of string;
    Pics: array of TBitmap;
    PicsSpec: array of TBitmap;

    Compression: int;
    DefType: int;
    function AddPic(Name:string; Pic:TBitmap; PicSpec:TBitmap=nil):int;
    procedure AddItem(Group, PicNum:int);
    procedure Make(Stream:TStream);
  end;

  TMsk = packed record
    Width: byte;
    Height: byte;
    MaskObject: array[0..5] of byte; // Без учета тени [Not counting shadow]
    MaskShadow: array[0..5] of byte; // Без учета объекта [Not counting object]
  end;
  PMsk = ^TMsk;

const
  RSFullBmp = TBitmap(1);

resourcestring
  SRSInvalidDef = 'Def file is invalid';

procedure RSMakeMsk(Def:TRSDefWrapper; var Msk:TMsk); overload;
function RSMakeMsk(Def:TRSDefWrapper):TMsk; overload;
procedure RSMakeMsk(const DefFile:TRSByteArray; var Msk:TMsk); overload;
function RSMakeMsk(const DefFile:TRSByteArray):TMsk; overload;

implementation

uses Types;

constructor TRSDefWrapper.Create(AData:TRSByteArray);
var p, p1:pchar; i:int;
begin
  inherited Create;
  FUseCustomPalette:= true;
  Data:= AData;
  Header:= ptr(Data);
  p1:= pchar(Data) + Length(Data);
  p:= @AData[sizeof(TRSDefHeader)];
  if p > p1 then  raise EReadError.CreateRes(@SRSInvalidDef);

  SetLength(Groups, Header.GroupsCount);
  SetLength(ItemNames, Header.GroupsCount);
  SetLength(ItemPointers, Header.GroupsCount);
  for i:=0 to Header.GroupsCount-1 do
  begin
    Groups[i]:= ptr(p);
    Inc(p, sizeof(TRSDefGroup));
    if p > p1 then  raise EReadError.CreateRes(@SRSInvalidDef);

    ItemNames[i]:= ptr(p);
    Inc(p, Groups[i].ItemsCount*sizeof(TRSDefItemName));
    ItemPointers[i]:= ptr(p);
    Inc(p, Groups[i].ItemsCount*4);
    Inc(FPicturesCount, Groups[i].ItemsCount);
  end;
  if p > p1 then  raise EReadError.CreateRes(@SRSInvalidDef);
end;

destructor TRSDefWrapper.Destroy;
//var i:int;
begin
  if FPal<>nil then
    FreeMem(FPal);
  if FPurePal<>nil then
    FreeMem(FPurePal);
//  for i:=0 to length(ItemNames)-1 do ItemNames[i]:=nil;
//  for i:=0 to length(ItemPointers)-1 do ItemPointers[i]:=nil;
  inherited Destroy;
end;

procedure TRSDefWrapper.PicLinksNeeded;
var i,j,k:int;
begin
  if FPicLinks = nil then
  begin
    SetLength(FPicLinks, PicturesCount);
    k:=0;
    for i:=0 to Length(Groups)-1 do
      for j:=0 to Groups[i].ItemsCount-1 do
      begin
        FPicLinks[k]:=ItemPointers[i][j];
        Inc(k);
      end;
  end;
end;

procedure TRSDefWrapper.PicNameLinksNeeded;
var i,j,k:int;
begin
  if FPicNameLinks = nil then
  begin
    SetLength(FPicNameLinks, PicturesCount);
    k:=0;
    for i:=0 to Length(Groups)-1 do
      for j:=0 to Groups[i].ItemsCount-1 do
      begin
        FPicNameLinks[k]:= @ItemNames[i][j];
        Inc(k);
      end;
  end;
end;

function TRSDefWrapper.ExtractBmp(PicNum:integer; Bitmap:TBitmap=nil;
           BmpSpec:TBitmap=nil):TBitmap;
begin
  PicLinksNeeded;
  result:= CreateExtractBmp(@Data[FPicLinks[PicNum]], Bitmap, BmpSpec);
end;

function TRSDefWrapper.ExtractBmp(Group, PicNum:integer;
           Bitmap:TBitmap=nil; BmpSpec:TBitmap=nil):TBitmap;
begin
  result:= CreateExtractBmp(@Data[ItemPointers[Group][PicNum]], Bitmap,BmpSpec);
end;

function TRSDefWrapper.GetPicHeader(PicNum:integer):PRSDefPic;
begin
  PicLinksNeeded;
  result:=PRSDefPic(@Data[FPicLinks[PicNum]]);
end;

function TRSDefWrapper.GetPicHeader(Group, PicNum:integer):PRSDefPic;
begin
  result:=PRSDefPic(@Data[ItemPointers[Group][PicNum]]);
end;

function TRSDefWrapper.GetPicName(PicNum: integer): string;
begin
  PicNameLinksNeeded;
  result:= FPicNameLinks[PicNum]^;
end;

function TRSDefWrapper.GetPicName(Group, PicNum: integer): string;
begin
  result:= ItemNames[Group][PicNum];
end;

procedure TRSDefWrapper.RebuildPal;
begin
  if FPal<>nil then
    FreeMem(FPal);
  FPal:=RSMakeLogPalette(@Header.Palette[0]);
  if Assigned(FOnPreparePal) then FOnPreparePal(self, ptr(FPal));
end;



procedure FillBitmap(Bitmap:TBitmap; Value:byte);
var p:PByte; i,dy,w,h:int;
begin
  w:=Bitmap.Width;
  h:=Bitmap.Height;
  if (w=0) or (h=0) then exit;
  p:=Bitmap.ScanLine[0];
  dy:= (w + 3) and not 3; // scanline length
  dy:=-dy;
  for i:=h-1 downto 0 do
  begin
    FillChar(p^, w, Value);
    Inc(p, dy);
  end;
end;

  // Based on ConvertDefFileToBmpFile by Alexander Karpeko
procedure TRSDefWrapper.DoExtractBuffer(Block:ptr; var PcxHdr:TRSDefPic;
             var Pic, Buffer, ShadowBuffer:ptr; BothBuffers:boolean);
var
  Offsets:PIntegerArray;
  Offsets23:PWordArray;
  i, j, x, y: integer;
  Buf, ShBuf: ptr;
  Code: byte;    //Operation code.
  Value: byte;   //Operand
  p, p1, p2:PByte;
begin
  Move(Block^, PcxHdr, sizeof(PcxHdr));
  Inc(PRSDefPic(Block));
  x := PcxHdr.Width;
  y := PcxHdr.Height;
  p:=Block;

   // For old format Defs: SGTWMTA.DEF and SGTWMTB.DEF
  with PcxHdr do
    if (FrameWidth>x) and (FrameHeight>y) and (Compression=1) then
    begin
      FrameLeft:=0;
      FrameTop:=0;
      FrameWidth:=x;
      FrameHeight:=y;
      Dec(PByte(Block), 16);
    end else
    begin
      x:=FrameWidth;
      y:=FrameHeight;
    end;

  if PcxHdr.Compression<>0 then
  begin
    GetMem(Buf, x*y);
    if BothBuffers then
    begin
      GetMem(ShBuf, x*y);
      FillChar(Buf^, x*y, 0);
      FillChar(ShBuf^, x*y, 255);
    end else
      ShBuf:=Buf;
  end else
  begin
    Buf:=nil;
    ShBuf:=nil;
  end;

  try
    case PcxHdr.Compression of
      0:;

      1:
      begin
        Offsets:=Block;
        p1:=Buf;
        p2:=ShBuf;
        for j:=0 to y-1 do
        begin
          p:=Block;
          Inc(p, Offsets[j]);
          i:=x;
          repeat
            Code:=p^;
            Inc(p);
            Value:=p^;
            Inc(p);
            if Code=255 then
            begin
              Move(p^, p1^, Value+1);
              Inc(p, Value+1);
            end else
              FillChar(p2^, Value+1, Code);
            Inc(p1, Value+1);
            Inc(p2, Value+1);
            Dec(i, Value+1);
          until i<=0;
          if i<0 then
          begin
            Inc(p1, i);
            Inc(p2, i);
          end;
        end;
      end;

      2, 3:
      begin
        if PcxHdr.Compression=3 then
        begin
          y:=y*(x div 32);
          x:=32;
        end;
        Offsets23:=Block;
        p1:=Buf;
        p2:=ShBuf;
        for j:=0 to y-1 do
        begin
          p:=Block;
          Inc(p, Offsets23[j]);
          i:=x;
          repeat
            Value:=p^;
            Inc(p);
            Code:= Value div 32;
            Value:= Value and 31 + 1;
            if Code=7 then
            begin
              Move(p^, p1^, Value);
              Inc(p, Value);
            end else
            begin
              FillChar(p2^, Value, Code);
              if (Code = 5) and BothBuffers then // Flag color
                FillChar(p1^, Value, Code);
            end;
            Inc(p1, Value);
            Inc(p2, Value);
            Dec(i, Value);
          until i<=0;
          if i<0 then
          begin
            Inc(p1, i);
            Inc(p2, i);
          end;
        end;
      end;

      else
        Assert(false);
    end;

    if Buf<>nil then
      p:=Buf;

    Pic:= p;
    Buffer:= Buf;
    ShadowBuffer:= ShBuf;

  except
    if ShBuf<>Buf then
      FreeMem(ShBuf, x*y);
    if Buf<>nil then
      FreeMem(Buf, x*y);
    raise;
  end;
end;


procedure TRSDefWrapper.DoExtractBmp(Block:ptr; Bmp, BmpSpec:TBitmap);
var
  PcxHdr: TRSDefPic;

  procedure InitBmp(Bmp:TBitmap);
  begin
    with Bmp do
    begin
      Width:=0;
      Height:=0;
      HandleType:=bmDIB;
      PixelFormat:=pf8bit;
    end;
  end;

  procedure BufToBmp(Bmp:TBitmap; Buf:ptr);
  begin
    with Bmp do
    begin
      Width:=PcxHdr.Width;
      Height:=PcxHdr.Height;
      FillBitmap(Bmp, 0);
      if Buf<>nil then
        with PcxHdr do
          RSBufferToBitmap(Buf, Bmp,
             Bounds(FrameLeft, FrameTop, FrameWidth, FrameHeight));
    end;
  end;

var
  Buf, ShBuf: ptr;
  Pal: HPalette;
begin
  DoExtractBuffer(Block, PcxHdr, Block, Buf, ShBuf, BmpSpec<>nil);
  try
    if Bmp<>nil then
    begin
      InitBmp(Bmp);

      if BmpSpec=nil then
      begin
        if FPal=nil then
          RebuildPal;
        Pal:=CreatePalette(FPal^);
      end else
      begin
        if FPurePal=nil then
          FPurePal:=RSMakeLogPalette(@Header.Palette[0]);
        Pal:=CreatePalette(FPurePal^);
      end;
      if Pal=0 then  RSRaiseLastOSError;
      Bmp.Palette:=Pal;

      BufToBmp(Bmp, Block);
    end;

    if BmpSpec<>nil then
    begin
      InitBmp(BmpSpec);
      if FPurePal=nil then
        FPurePal:=RSMakeLogPalette(@Header.Palette[0]);
      Pal:=CreatePalette(FPurePal^); // !!! use classical palette
      RSWin32Check(Pal);
      BmpSpec.Palette:= Pal;

      if ShBuf=nil then
      begin
        GetMem(ShBuf, PcxHdr.FrameWidth*PcxHdr.FrameHeight);
        FillMemory(ShBuf, PcxHdr.FrameWidth*PcxHdr.FrameHeight, 255);
      end;
      BufToBmp(BmpSpec, ShBuf);
    end;

  finally
    if ShBuf<>Buf then
      FreeMem(ShBuf);
    FreeMem(Buf);
  end;
end;

function TRSDefWrapper.CreateExtractBmp(Block:ptr; Bmp, BmpSpec:TBitmap):TBitmap;
var b1, b2:TBitmap;
begin
  if Bmp = RSFullBmp then
  begin
    Bmp:=BmpSpec;
    BmpSpec:=RSFullBmp;
    if Bmp = RSFullBmp then
      Bmp:=nil;
  end;

  if Bmp = nil then
    result:=TBitmap.Create
  else
    result:=Bmp;

  b1:=nil;
  b2:=nil;
  try
    if BmpSpec = RSFullBmp then
      try
        b1:=TBitmap.Create;
        b2:=TBitmap.Create;
        DoExtractBmp(Block, b1, b2);
        MakeFullBmp(result, b1, b2);
      finally
        b1.Free;
        b2.Free;
      end
    else
      DoExtractBmp(Block, result, BmpSpec);
  except
    if Bmp=nil then
      result.Free;
    raise;
  end;
end;

function SwapColor(c:TColor):TColor;
asm
  bswap eax
  shr eax, 8
end;

procedure TRSDefWrapper.MakeFullBmp(Bmp, b1, b2:TBitmap);
var
  Pal1, Pal2: array[0..255] of int;
  i,j,w,h,dy:int; p:pint; p1, p2:pbyte;
begin
  w:=b1.Width;
  h:=b1.Height;
  with Bmp do
  begin
    PixelFormat:=pf32bit;
    HandleType:=bmDIB;
    Width:=w;
    Height:=h;
  end;
  if h = 0 then
    exit;
  if FPurePal=nil then
    FPurePal:=RSMakeLogPalette(@Header.Palette[0]);
  if FPal=nil then
    RebuildPal;
  for i:=0 to 255 do
  begin
    Pal1[i]:=SwapColor(int(FPurePal^.palPalEntry[i]));
    Pal2[i]:=SwapColor(int(FPal^.palPalEntry[i]));
  end;

  dy:= (-w) and 3;
  p:=Bmp.ScanLine[h-1];
  p1:=b1.ScanLine[h-1];
  p2:=b2.ScanLine[h-1];
  for j:=h downto 1 do
  begin
    for i:=w downto 1 do
    begin
      if p2^=255 then
        p^:=Pal1[p1^]
      else
        p^:=Pal2[p2^];
      Inc(p);
      Inc(p1);
      Inc(p2);
    end;
    Inc(p1, dy);
    Inc(p2, dy);
  end;
  if Assigned(Bmp.OnChange) then
    Bmp.OnChange(Bmp);
end;


(*
  // Based on ConvertDefFileToBmpFile by Alexander Karpeko
function TRSDefWrapper.DoExtractBmp(Block:ptr; Bmp, BmpSpec:TBitmap):TBitmap;
var
  Offsets:PIntegerArray;
  Offsets23:PWordArray;
  i, j, x, y: Integer;
  Buf, ShBuf: ptr;
  Code: Byte;    //Operation code.
  Value: Byte;   //Operand
  Pal: HPalette;
  p, p1, p2:PByte;
  PcxHdr: TRSDefPic;
begin
  Move(Block^, PcxHdr, SizeOf(PcxHdr));
  inc(PRSDefPic(Block));
  x := PcxHdr.Width;
  y := PcxHdr.Height;
  p:=Block;

   // For old format Defs: SGTWMTA.DEF and SGTWMTB.DEF
  with PcxHdr do
    if (FrameWidth>x) and (FrameHeight>y) and (Compression=1) then
    begin
      FrameLeft:=0;
      FrameTop:=0;
      FrameWidth:=x;
      FrameHeight:=y;
      dec(PByte(Block), 16);
    end else
    begin
      x:=FrameWidth;
      y:=FrameHeight;
    end;

  if PcxHdr.Compression<>0 then
  begin
    GetMem(Buf, x*y);
    if BmpSpec<>nil then
    begin
      GetMem(ShBuf, x*y);
      FillChar(ShBuf^, x*y, 255);
    end else
      ShBuf:=Buf;
  end else
  begin
    Buf:=nil;
    ShBuf:=nil;
  end;

   // Fill Buffer

  try
    case PcxHdr.Compression of
      0:;

      1:
      begin
        Offsets:=Block;
        p1:=Buf;
        p2:=ShBuf;
        for j:=0 to y-1 do
        begin
          p:=Block;
          inc(p, Offsets[j]);
          i:=x;
          repeat
            Code:=p^;
            inc(p);
            Value:=p^;
            inc(p);
            if Code=255 then
            begin
              Move(p^, p1^, Value+1);
              inc(p, Value+1);
            end else
              FillChar(p2^, Value+1, Code);
            inc(p1, Value+1);
            inc(p2, Value+1);
            dec(i, Value+1);
          until i<=0;
          if i<0 then
          begin
            inc(p1, i);
            inc(p2, i);
          end;
        end;
      end;

      2, 3:
      begin
        if PcxHdr.Compression=3 then
        begin
          y:=y*(x div 32);
          x:=32;
        end;
        Offsets23:=Block;
        p1:=Buf;
        p2:=ShBuf;
        for j:=0 to y-1 do
        begin
          p:=Block;
          inc(p, Offsets23[j]);
          i:=x;
          repeat
            Value:=p^;
            inc(p);
            Code:= Value div 32;
            Value:= Value and 31 + 1;
            if Code=7 then
            begin
              Move(p^, p1^, Value);
              inc(p, Value);
            end else
              FillChar(p2^, Value, Code);
            inc(p1, Value);
            inc(p2, Value);
            dec(i, Value);
          until i<=0;
          if i<0 then
          begin
            inc(p1, i);
            inc(p2, i);
          end;
        end;
      end;

      else
        Assert(false);
    end;

     // Make Bitmaps

    if FPal=nil then
      RebuildPal;

    if Bmp=nil then
      Result:=TBitmap.Create
    else
      Result:=Bmp;

    if Buf<>nil then
      p:=Buf;
      
    with Result do
      try
        Width:=0;
        Height:=0;
        HandleType:=bmDIB;

        PixelFormat:=pf8bit;
        Pal:=CreatePalette(FPal^);
        if Pal=0 then RSRaiseLastOSError;
        Palette:=Pal;

        Width:=PcxHdr.Width;
        Height:=PcxHdr.Height;
        FillBitmap(Result, 0);
        with PcxHdr do
          BufferToBitmap(p, Result,
             Bounds(FrameLeft, FrameTop, FrameWidth, FrameHeight));
      except
        if Bmp=nil then Free;
        raise;
      end;

    if BmpSpec<>nil then
      with BmpSpec do
      begin
        Width:=0;
        Height:=0;
        HandleType:=bmDIB;
        PixelFormat:=pf8bit;

        Width:=PcxHdr.Width;
        Height:=PcxHdr.Height;
        FillBitmap(Result, 0);
        if ShBuf<>nil then
          with PcxHdr do
            BufferToBitmap(ShBuf, Result,
               Bounds(FrameLeft, FrameTop, FrameWidth, FrameHeight));
      end;

  finally
    if ShBuf<>Buf then
      FreeMem(ShBuf, x*y);
    FreeMem(Buf, x*y);
  end;
end;
*)

{------------------------------- TRSPicBuffer ---------------------------------}

procedure TRSPicBuffer.Initialize(Files:TStrings);
var i,j,k:int;
begin
  k:=Files.Count;
  FFiles:=Files;
  for i:=0 to Length(FPics)-1 do
    FPics[i].Free;
  FPics:=nil;
  SetLength(FPics, k);
  SetLength(Links, k);
  for i:=0 to k-1 do
  begin
    Links[i]:=i;
    for j:=0 to i-1 do
      if SameText(ExpandFileName(Files[i]), ExpandFileName(Files[j])) then
      begin
        Links[i]:=j;
        break;
      end;
  end;
end;

function TRSPicBuffer.LoadPic(i:int):TBitmap;
begin
  i:=Links[i];
  if FPics[i]=nil then
  begin
    FPics[i]:=TBitmap.Create;
    FPics[i].LoadFromFile(FFiles[i]);
  end;
  result:=FPics[i];
end;

{------------------------------- TRSDefMaker ----------------------------------}

procedure BufToShBuf(Buf:ptr; len:int; StdNum:int);
var p, p1:PByte;
begin
  p:=Buf;
  p1:=p;
  Inc(p1, len);
  while DWord(p)<DWord(p1) do
  begin
    if p^>=StdNum then p^:=255;
    Inc(p);
  end
end;

 // Frame otside which there are only 0 pixels.
function GetFrame(b:TBitmap):TRect;
var p:PByte; i,j,dy,w,h:int;
begin
  w:=b.Width;
  h:=b.Height;
  if (w=0) or (h=0) then
  begin
    result:=Rect(0,0,0,0);
    exit;
  end;
  p:=b.ScanLine[0];
  dy:= (w + 3) and not 3 + w; // scanline length
  dy:=-dy;
  with result do
  begin
    Left:=w;
    Right:=-1;
    Top:=h;
    Bottom:=-1;
  end;
  for j:=0 to h-1 do
  begin
    for i:=0 to w-1 do
    begin
      if p^<>0 then
        with result do
        begin
          if Left>i then Left:=i;
          if Top>j then Top:=j;
          if Right<i then Right:=i;
          if Bottom<j then Bottom:=j;
        end;
      Inc(p);
    end;
    Inc(p, dy);
  end;
  Inc(result.Right);
  Inc(result.Bottom);
  if result.Right=0 then
  begin
    result.Left:=0;
    result.Top:=0;
  end;
end;

 // Length of sequence of normal or special pixels.
function SeqLength(Seq:ptr; MaxLen:int):int;
var p,p1:pbyte; b:byte;
begin
  p:=Seq;
  p1:=p;
  Inc(p1, MaxLen);
  b:=p^;
  repeat
    Inc(p);
  until (int(p)>=int(p1)) or (p^<>b);
  result:= int(p) - int(Seq);
end;

function Add(var a:TRSByteArray; i:int):PByte;
var j:int;
begin
  j:=Length(a);
  SetLength(a, j+i);
  result:=@a[j];
end;

function TRSDefMaker.PackBitmap(Bmp, Spec:TBitmap; Compr:int):TRSByteArray;
var
  w,h,i,j,k:int; r:TRect; p,p1:PByte; Buf, ShBuf:pchar; b:byte;
begin
  result:=nil;
  with Bmp do
  begin
    Assert(PixelFormat=pf8bit, 'Paletted bitmaps needed');
    HandleType:=bmDIB;
    w:=Width;
    h:=Height;
    if Compr=3 then
      Assert((w or h) and 31 = 0, 'Dimensions must devide by 32');
  end;
  if Spec<>nil then
    with Spec do
    begin
      Assert(PixelFormat=pf8bit, 'Paletted bitmaps needed');
      Assert((w=Width) and (h=Height));
      HandleType:=bmDIB;
    end;

   // Get Frame Rect 
  if Compr<>0 then
  begin
    if Spec<>nil then
      r:=GetFrame(Spec)
    else
      r:=GetFrame(Bmp);
        
    if Compr=3 then
    begin
      r.Left:=r.Left and not 31;
      r.Top:=r.Top and not 31;
      r.Right:=(r.Right+31) and not 31;
      r.Bottom:=(r.Bottom+31) and not 31;
    end;
  end else
    r:=Rect(0,0,w,h);

  with PRSDefPic(Add(result, sizeof(TRSDefPic)))^ do
  begin
    Compression:=Compr;
    Width:=w;
    Height:=h;
    w:=r.Right-r.Left;
    h:=r.Bottom-r.Top;
    FrameWidth:=w;
    FrameHeight:=h;
    FrameLeft:=r.Left;
    FrameTop:=r.Top;
    // FileSize is set in the end
  end;

  if w=0 then
  begin
    PRSDefPic(result)^.FileSize:= Length(result)-sizeof(TRSDefPic);
    exit;
  end;

   // Fill Buffers
  if Compr<>0 then
  begin
    GetMem(Buf, w*h);
    GetMem(ShBuf, w*h);
    RSBitmapToBuffer(Buf, Bmp, r);
    if Spec=nil then
    begin
      CopyMemory(ShBuf, Buf, w*h);
      if Compr=1 then
        BufToShBuf(ShBuf, w*h, 8)
      else
        BufToShBuf(ShBuf, w*h, 7);
    end else
      RSBitmapToBuffer(ShBuf, Spec, r);
  end else
  begin
    Buf:=nil;
    ShBuf:=nil;
  end;

   // Write buffers
  try
    case Compr of
      0:
        RSBitmapToBuffer(Add(result, w*h), Bmp, r);

      1:
      begin
        Add(result, h*4);
        p:=ptr(Buf);
        p1:=ptr(ShBuf);
        for j:=0 to h-1 do
        begin
          pint(@result[sizeof(TRSDefPic)+j*4])^:=
             Length(result) - sizeof(TRSDefPic);
          i:=w;
          repeat
            b:=p1^;
            Add(result, 1)^:=b;
            k:=SeqLength(p1, min(256, i));
            Add(result, 1)^:=k-1;
            if b = 255 then
              CopyMemory(Add(result, k), p, k);
            Dec(i, k);
            Inc(p, k);
            Inc(p1, k);
          until i=0;
        end;
      end;

      2,3:
      begin
        if Compr=3 then
        begin
          h:=h*(w div 32);
          w:=32;
        end;
        Add(result, h*2);
        p:=ptr(Buf);
        p1:=ptr(ShBuf);
        for j:=0 to h-1 do
        begin
          pword(@result[sizeof(TRSDefPic)+j*2])^:=
             Length(result) - sizeof(TRSDefPic);
          i:=w;
          repeat
            b:=p1^;
            k:=SeqLength(p1, min(32, i));
            Add(result, 1)^:=(k-1) or (b*32);
            if b>=7 then
              CopyMemory(Add(result, k), p, k);
            Dec(i,k);
            Inc(p,k);
            Inc(p1,k);
          until i=0;
        end;
      end;

    end;
  finally
    FreeMem(Buf);
    FreeMem(ShBuf);
  end;
  PRSDefPic(result)^.FileSize:= Length(result)-sizeof(TRSDefPic);
end;

procedure TRSDefMaker.Make(Stream:TStream);
var
  Header: TRSByteArray;
  PicData: array of TRSByteArray;
  Offsets: array of int;
  i, j:int; GrCount:int; p:pbyte;
begin
  Assert(Length(Pics)>0, 'There must be at least one picture');

   // Calculate nonzero groups count & header size
  GrCount:=0;
  j:=sizeof(TRSDefHeader);
  for i:=Length(Groups)-1 downto 0 do
    if Groups[i]<>nil then
    begin
      Inc(GrCount);
      Inc(j, sizeof(TRSDefGroup) + 17*Length(Groups[i]));
    end;
  SetLength(Header, j);

   // Prepare pics
  SetLength(Offsets, Length(Pics));
  SetLength(PicData, Length(Pics));
  for i:=0 to Length(Pics)-1 do
  begin
    PicData[i]:= PackBitmap(Pics[i], PicsSpec[i], Compression);
    Offsets[i]:= j;
    Inc(j, Length(PicData[i]));
  end;

   // Prepare Header
  with PRSDefHeader(Header)^ do
  begin
    TypeOfDef:=DefType;
    Width:=Pics[0].Width;
    Height:=Pics[0].Height;
    GroupsCount:=GrCount;
    RSWritePalette(@Palette, Pics[0].Palette);
  end;
  p:=@Header[sizeof(TRSDefHeader)];
  for i:=0 to Length(Groups)-1 do
    if Groups[i]<>nil then
    begin
      with PRSDefGroup(p)^ do
      begin
        GroupNum:=i;
        ItemsCount:=Length(Groups[i]);
      end;
      Inc(p, sizeof(TRSDefGroup));
      for j:=0 to Length(Groups[i])-1 do
      begin
        CopyMemory(p, ptr(PicNames[Groups[i][j]]),
                   min(13, Length(PicNames[Groups[i][j]])+1));
        Inc(p, sizeof(TRSDefItemName));
      end;
      for j:=0 to Length(Groups[i])-1 do
      begin
        pint(p)^:=Offsets[Groups[i][j]];
        Inc(p, 4);
      end;
    end;

   // Write all
  Stream.WriteBuffer(Header[0], Length(Header));
  for i:=0 to Length(PicData)-1 do
    Stream.WriteBuffer(PicData[i][0], Length(PicData[i]));
end;

function TRSDefMaker.AddPic(Name:string; Pic:TBitmap; PicSpec:TBitmap=nil):int;
var i:int;
begin
  i:=Length(Pics);
  SetLength(Pics, i+1);
  SetLength(PicsSpec, i+1);
  SetLength(PicNames, i+1);
  Pics[i]:= Pic;
  PicsSpec[i]:= PicSpec;
  PicNames[i]:= Name;
  result:=i;
end;

procedure TRSDefMaker.AddItem(Group, PicNum:int);
var i:int;
begin
  if Length(Groups)<=Group then
    SetLength(Groups, Group+1);
  i:=Length(Groups[Group]);
  SetLength(Groups[Group], i+1);
  Groups[Group][i]:= PicNum;
end;

{-------------------------------- RSMakeMSK -----------------------------------}

type
  TMyArray = array[0..255] of boolean;

function ProcessSquare(p:PByte; dy:int; var Colors:TMyArray):boolean;
var x,y:int;
begin
  result:=true;
  for y:=32 downto 1 do
  begin
    for x:=32 downto 1 do
    begin
      Dec(p);
      if Colors[p^] then exit;
    end;
    Dec(p, dy - 32);
  end;
  result:=false;
end;

procedure ProcessPic(b:TBitmap; Mask:PByteArray; var Colors:TMyArray);
var x,y,w,h,dy:int; p:pchar;
begin
  w:=b.Width;
  h:=b.Height;
  Assert((w mod 32 = 0) and (h mod 32 = 0));
  dy:=-w;
  p:= b.ScanLine[h-1];
  Inc(p, w);
  for y:=0 to (h div 32) - 1 do
    for x:=0 to (w div 32) - 1 do
    begin
      if (Mask[5-y] and (1 shl (7-x)) = 0) and
          ProcessSquare(ptr( p - (x + y*dy)*32 ), dy, Colors) then
        Mask[5-y]:= Mask[5-y] or (1 shl (7-x));
    end;
end;

var
  ObjArray, ShArray:TMyArray; MskInitDone:boolean;

procedure RSMakeMsk(Def:TRSDefWrapper; var Msk:TMsk); overload;
var i:int; b:TBitmap;
begin
  if not MskInitDone then
  begin
    ShArray[1]:=true;
    ShArray[4]:=true;
    FillChar(ObjArray[5], 256 - 5, true);
    ObjArray[6]:=false;
    MskInitDone:=true;
  end;

  with Def.Header^ do
  begin
    Msk.Width:= Width div 32;
    Msk.Height:= Height div 32;
  end;
  Def.PicLinksNeeded;

  b:=TBitmap.Create;
  try
    for i:=0 to Def.PicturesCount-1 do
    begin
      with Def do
        DoExtractBmp(@Data[FPicLinks[i]], nil, b);

      ProcessPic(b, @Msk.MaskObject, ObjArray);
      ProcessPic(b, @Msk.MaskShadow, ShArray);
    end;
  finally
    b.Free;
  end;
end;

function RSMakeMsk(Def:TRSDefWrapper):TMsk; overload;
begin
  RSMakeMsk(Def, result);
end;

procedure RSMakeMsk(const DefFile:TRSByteArray; var Msk:TMsk); overload;
var a:TRSDefWrapper;
begin
  a:=TRSDefWrapper.Create(DefFile);
  try
    RSMakeMsk(a, Msk);
  finally
    a.Free;
  end;
end;

function RSMakeMsk(const DefFile:TRSByteArray):TMsk; overload;
begin
  RSMakeMsk(DefFile, result);
end;

end.
