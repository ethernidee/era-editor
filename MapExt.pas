unit MapExt;
{
DESCRIPTION:  Editor extension support
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  interface  (***)
uses
  Windows, SysUtils, Utils, Lists, Files,
  Core, AssocArrays, TypeWrappers, DlgMes, StrLib, Log;

const
  (* Pathes *)
  PLUGINS_PATH  = 'EraEditor';
  PATCHES_PATH  = 'EraEditor';
  
  MAX_NUM_LODS  = 100;
  
  AB_AND_SOD  = 3;
  
  GameVersion:  PINTEGER  = Ptr($596F58);
  
  LINE_END  = #13#10;
  
  ZEOBJTS_DIR = 'Data\Objects';


type
  PPatchFile  = ^TPatchFile;
  TPatchFile  = packed record (* FORMAT *)
    NumPatches: integer;
    (*
    Patches:    ARRAY NumPatches OF TBinPatch;
    *)
    Patches:    Utils.TEmptyRec;
  end; // .RECORD TPatchFile

  PBinPatch = ^TBinPatch;
  TBinPatch = packed record (* FORMAT *)
    Addr:     pointer;
    NumBytes: integer;
    (*
    Bytes:    ARRAY NumBytes OF BYTE;
    *)
    Bytes:    Utils.TEmptyRec;
  end; // .RECORD TBinPatch
  
  PLod  = ^TLod;
  TLod  = packed record
    Dummy:  array [0..399] of byte;
  end; // .RECORD TLod
  
  PLodTable = ^TLodTable;
  TLodTable = array [0..99] of TLod;
  
  TGameVersion  = 0..3;
  TLodType      = (LOD_SPRITE = 1, LOD_BITMAP = 2, LOD_WAV = 3);
  
  PIndexes  = ^TIndexes;
  TIndexes  = array [0..MAX_NUM_LODS - 1] of integer;
  
  TLodIndexes = packed record
    NumLods:  integer;
    Indexes:  ^TIndexes;
  end; // .RECORD TLodIndexes
  
  TLodTypes = packed record
    Table:    array [LOD_SPRITE..LOD_WAV, TGameVersion] of TLodIndexes;
    Indexes:  array [LOD_SPRITE..LOD_WAV, TGameVersion] of TIndexes;
  end; // .RECORD TLodTypes
  
  TObjItem  = class
    Pos:    integer;
    Value:  string;
  end; // .CLASS TObjItem
  
  TMAlloc = function (Size: integer): pointer; cdecl;
  TMFree  = procedure (Addr: pointer); cdecl;


const
  MAlloc: TMAlloc = Ptr($504A8E);
  MFree:  TMFree  = Ptr($504AB7);


var
{O} LodList:  Lists.TStringList;
    hMe:      integer;
    LodTable: TLodTable;
    LodTypes: TLodTypes;
    
{O} ZEObjList: Lists.TStringList;


procedure AsmInit; ASSEMBLER;


(***) implementation (***)


procedure LoadPlugins;
var
{O} Locator:    Files.TFileLocator;
{O} ItemInfo:   Files.TItemInfo;
    DllName:    string;
    DllHandle:  integer;
  
begin
  Locator   :=  Files.TFileLocator.Create;
  ItemInfo  :=  nil;
  // * * * * * //
  Locator.DirPath :=  PLUGINS_PATH;
  Locator.InitSearch('*.dll');
  
  while Locator.NotEnd do begin
    DllName   :=  Locator.GetNextItem(ItemInfo);
    DllHandle :=  Windows.LoadLibrary(pchar(PLUGINS_PATH + '\' + DllName));
    {!} Assert(DllHandle <> 0);
    Windows.DisableThreadLibraryCalls(DllHandle);
    
    SysUtils.FreeAndNil(ItemInfo);
  end; // .WHILE
  
  Locator.FinitSearch;
  // * * * * * //
  SysUtils.FreeAndNil(Locator);
end; // .PROCEDURE LoadPlugins

procedure ApplyBinPatch (const FilePath: string);
var
{U} Patch:      PBinPatch;
    FileData:   string;
    NumPatches: integer;
    i:          integer;  
  
begin
  if not Files.ReadFileContents(FilePath, FileData) then begin
    Core.FatalError('Cannot open binary patch file "' + FilePath + '"');
  end // .IF
  else begin
    NumPatches  :=  PPatchFile(FileData).NumPatches;
    Patch       :=  @PPatchFile(FileData).Patches;
    
    try
      for i:=1 to NumPatches do begin
        Core.WriteAtCode(Patch.NumBytes, @Patch.Bytes, Patch.Addr);
        Patch :=  Utils.PtrOfs(Patch, sizeof(Patch^) + Patch.NumBytes);
      end; // .FOR 
    except
      Core.FatalError('Cannot apply binary patch file "' + FilePath + '"'#13#10'Access violation');
    end; // .TRY
  end; // .ELSE
end; // .PROCEDURE ApplyBinPatch

procedure ApplyPatches;
var
{O} Locator:  Files.TFileLocator;
{O} ItemInfo: Files.TItemInfo;
  
begin
  Locator   :=  Files.TFileLocator.Create;
  ItemInfo  :=  nil;
  // * * * * * //
  Locator.DirPath :=  PATCHES_PATH;
  Locator.InitSearch('*.bin');
  
  while Locator.NotEnd do begin
    ApplyBinPatch(Locator.DirPath + '\' + Locator.GetNextItem(ItemInfo));
    
    SysUtils.FreeAndNil(ItemInfo);
  end; // .WHILE
  
  Locator.FinitSearch;
  // * * * * * //
  SysUtils.FreeAndNil(Locator);
end; // .PROCEDURE ApplyPatches

procedure WriteInt (Value: integer; Addr: pointer); inline;
begin
  Core.WriteAtCode(sizeof(Value), @Value, Addr);
end; // .PROCEDURE WriteInt

procedure RegisterDefaultLodTypes;
begin
  (* LOD_SPRITE *)
  LodTypes.Table[LOD_SPRITE, 0].NumLods :=  2;
  LodTypes.Table[LOD_SPRITE, 0].Indexes :=  @LodTypes.Indexes[LOD_SPRITE, 0];
  LodTypes.Table[LOD_SPRITE, 1].NumLods :=  2;
  LodTypes.Table[LOD_SPRITE, 1].Indexes :=  @LodTypes.Indexes[LOD_SPRITE, 1];
  LodTypes.Table[LOD_SPRITE, 2].NumLods :=  2;
  LodTypes.Table[LOD_SPRITE, 2].Indexes :=  @LodTypes.Indexes[LOD_SPRITE, 2];
  LodTypes.Table[LOD_SPRITE, 3].NumLods :=  3;
  LodTypes.Table[LOD_SPRITE, 3].Indexes :=  @LodTypes.Indexes[LOD_SPRITE, 3];
  
  (* LOD_BITMAP *)
  LodTypes.Table[LOD_BITMAP, 0].NumLods :=  3;
  LodTypes.Table[LOD_BITMAP, 0].Indexes :=  @LodTypes.Indexes[LOD_BITMAP, 0];
  LodTypes.Table[LOD_BITMAP, 1].NumLods :=  3;
  LodTypes.Table[LOD_BITMAP, 1].Indexes :=  @LodTypes.Indexes[LOD_BITMAP, 1];
  LodTypes.Table[LOD_BITMAP, 2].NumLods :=  1;
  LodTypes.Table[LOD_BITMAP, 2].Indexes :=  @LodTypes.Indexes[LOD_BITMAP, 2];
  LodTypes.Table[LOD_BITMAP, 3].NumLods :=  1;
  LodTypes.Table[LOD_BITMAP, 3].Indexes :=  @LodTypes.Indexes[LOD_BITMAP, 3];
  
  (* LOD_WAV *)
  LodTypes.Table[LOD_WAV, 0].NumLods :=  2;
  LodTypes.Table[LOD_WAV, 0].Indexes :=  @LodTypes.Indexes[LOD_WAV, 0];
  LodTypes.Table[LOD_WAV, 1].NumLods :=  2;
  LodTypes.Table[LOD_WAV, 1].Indexes :=  @LodTypes.Indexes[LOD_WAV, 1];
  LodTypes.Table[LOD_WAV, 2].NumLods :=  2;
  LodTypes.Table[LOD_WAV, 2].Indexes :=  @LodTypes.Indexes[LOD_WAV, 2];
  LodTypes.Table[LOD_WAV, 3].NumLods :=  2;
  LodTypes.Table[LOD_WAV, 3].Indexes :=  @LodTypes.Indexes[LOD_WAV, 3];
  
  (* LOD_SPRITE *)
  LodTypes.Indexes[LOD_SPRITE, 0][0]  :=  5;
  LodTypes.Indexes[LOD_SPRITE, 0][1]  :=  1;
  
  LodTypes.Indexes[LOD_SPRITE, 1][0]  :=  4;
  LodTypes.Indexes[LOD_SPRITE, 1][1]  :=  0;
  
  LodTypes.Indexes[LOD_SPRITE, 2][0]  :=  1;
  LodTypes.Indexes[LOD_SPRITE, 2][1]  :=  0;
  
  LodTypes.Indexes[LOD_SPRITE, 3][0]  :=  7;
  LodTypes.Indexes[LOD_SPRITE, 3][1]  :=  3;
  LodTypes.Indexes[LOD_SPRITE, 3][2]  :=  1;
  
  (* LOD_BITMAP *)
  LodTypes.Indexes[LOD_BITMAP, 0][0]  :=  6;
  LodTypes.Indexes[LOD_BITMAP, 0][1]  :=  2;
  LodTypes.Indexes[LOD_BITMAP, 0][2]  :=  0;
  
  LodTypes.Indexes[LOD_BITMAP, 1][0]  :=  2;
  LodTypes.Indexes[LOD_BITMAP, 1][1]  :=  1;
  LodTypes.Indexes[LOD_BITMAP, 1][2]  :=  0;
  
  LodTypes.Indexes[LOD_BITMAP, 2][0]  :=  1;
  
  LodTypes.Indexes[LOD_BITMAP, 3][0]  :=  0;
  
  (* LOD_WAV *)
  LodTypes.Indexes[LOD_WAV, 0][0]  :=  1;
  LodTypes.Indexes[LOD_WAV, 0][1]  :=  0;
  
  LodTypes.Indexes[LOD_WAV, 1][0]  :=  1;
  LodTypes.Indexes[LOD_WAV, 1][1]  :=  3;
  
  LodTypes.Indexes[LOD_WAV, 2][0]  :=  0;
  LodTypes.Indexes[LOD_WAV, 2][1]  :=  2;
  
  LodTypes.Indexes[LOD_WAV, 3][0]  :=  1;
  LodTypes.Indexes[LOD_WAV, 3][1]  :=  0;
end; // .PROCEDURE RegisterDefaultLodTypes

procedure LoadLod (const LodName: string; Res: PLod);
begin
  {!} Assert(Res <> nil);
  asm
    MOV ECX, Res
    PUSH LodName
    MOV EAX, $4DAD60
    CALL EAX
  end; // .ASM
end; // .PROCEDURE LoadLod

procedure AddLodToList (LodInd: integer);
var
{U} Indexes:      PIndexes;
    LodType:      TLodType;
    GameVersion:  TGameVersion;
    i:            integer;
   
begin
  for LodType := LOD_SPRITE to LOD_WAV do begin
    for GameVersion := Low(TGameVersion) to High(TGameVersion) do begin
      Indexes :=  @LodTypes.Indexes[LodType, GameVersion];
      
      for i := LodTypes.Table[LodType, GameVersion].NumLods - 1 downto 0 do begin
        Indexes[i + 1] :=  Indexes[i];
      end; // .FOR
      
      Indexes[0]  :=  LodInd;
      
      Inc(LodTypes.Table[LodType, GameVersion].NumLods);
    end; // .FOR
  end; // .FOR
end; // .PROCEDURE AddLodToList

procedure LoadLods;
const
  NUM_OBLIG_LODS  = 8;
  MIN_LOD_SIZE    = 12;

var
{O} Locator:  Files.TFileLocator;
{O} FileInfo: Files.TFileItemInfo;
    FileName: string;
    NumLods:  integer;
    i:        integer;

begin
  Locator   :=  Files.TFileLocator.Create;
  FileInfo  :=  nil;
  // * * * * * //
  RegisterDefaultLodTypes;
  
  Locator.DirPath :=  'Data';
  Locator.InitSearch('*.pac');
  
  NumLods :=  NUM_OBLIG_LODS;
  
  while Locator.NotEnd and (LodList.Count < (Length(LodTable) - NUM_OBLIG_LODS)) do begin
    FileName  :=  SysUtils.AnsiLowerCase(Locator.GetNextItem(Files.TItemInfo(FileInfo)));
    
    if
      (SysUtils.ExtractFileExt(FileName) = '.pac')  and
      not FileInfo.IsDir                            and
      FileInfo.HasKnownSize                         and
      (FileInfo.FileSize > MIN_LOD_SIZE)
    then begin
      LodList.Add(FileName);
    end; // .IF
    
    SysUtils.FreeAndNil(FileInfo);
  end; // .WHILE
  
  Locator.FinitSearch;
  
  for i := LodList.Count - 1 downto 0 do begin
    LoadLod(LodList[i], @LodTable[NumLods]);
    AddLodToList(NumLods);
    Inc(NumLods);
  end; // .FOR

  // * * * * * //
  SysUtils.FreeAndNil(Locator);
end; // .PROCEDURE LoadLods

{$W-}
procedure Hook_SetLodTypes; ASSEMBLER;
asm
  CALL LoadLods
  // RET
end; // .PROCEDURE Hook_SetLodTypes
{$W+}

procedure ExtendLods;
begin
  (* Fix lod constructors args *)
  WriteInt(integer(@LodTable[0]), Ptr($4DACE6 + 15 * 0));
  WriteInt(integer(@LodTable[1]), Ptr($4DACE6 + 15 * 1));
  WriteInt(integer(@LodTable[2]), Ptr($4DACE6 + 15 * 2));
  WriteInt(integer(@LodTable[3]), Ptr($4DACE6 + 15 * 3));
  WriteInt(integer(@LodTable[4]), Ptr($4DACE6 + 15 * 4));
  WriteInt(integer(@LodTable[5]), Ptr($4DACE6 + 15 * 5));
  WriteInt(integer(@LodTable[6]), Ptr($4DACE6 + 15 * 6));
  WriteInt(integer(@LodTable[7]), Ptr($4DACE6 + 15 * 7));
  
  (* Fix refs to LodTable[0] *)
  WriteInt(integer(@LodTable[0]), Ptr($4DAD9D));
  WriteInt(integer(@LodTable[0]), Ptr($4DB1A9));
  
  (* Fix refs to LodTable[0].F4 *)
  WriteInt(integer(@LodTable[0]) + 4, Ptr($4DB1AF));
  WriteInt(integer(@LodTable[0]) + 4, Ptr($4DB275));
  WriteInt(integer(@LodTable[0]) + 4, Ptr($4DB298));
  WriteInt(integer(@LodTable[0]) + 4, Ptr($4DB2F5));
  WriteInt(integer(@LodTable[0]) + 4, Ptr($4DB318));
  WriteInt(integer(@LodTable[0]) + 4, Ptr($4DC029));
  WriteInt(integer(@LodTable[0]) + 4, Ptr($4DC087));
  
  (* Fix refs to LodTypes.Table *)
  WriteInt(integer(@LodTypes.Table), Ptr($4DB25D));
  WriteInt(integer(@LodTypes.Table), Ptr($4DB264));
  WriteInt(integer(@LodTypes.Table), Ptr($4DB2E4));
  WriteInt(integer(@LodTypes.Table), Ptr($4DBF0F));
  
  (* Fix refs to LodTypes.Table.f4 *)
  WriteInt(integer(@LodTypes.Table) + 4, Ptr($4DB256));
  
  (* Fix refs to LodTypes.Table.f8 *)
  WriteInt(integer(@LodTypes.Table) + 8, Ptr($4DB2DD));
  
  (* Fix refs to LodTypes.Table.f12 *)
  WriteInt(integer(@LodTypes.Table) + 12, Ptr($4DB2D6));
  
  Core.Hook(@Hook_SetLodTypes, Core.HOOKTYPE_JUMP, 5, Ptr($4DAED0));
end; // .PROCEDURE ExtendLods

function Hook_FixGameVersion (Context: Core.PHookHandlerArgs): LONGBOOL; stdcall;
begin
  GameVersion^  :=  AB_AND_SOD;
  result        :=  Core.EXEC_DEF_CODE;
end; // .FUNCTION Hook_FixGameVersion

function LoadObjList (RawFileData: string; out ObjList: Lists.TStringList): boolean;
var
{U} ObjItem:      TObjItem;
    StrItems:     StrLib.TArrayOfString;
    StrItem:      StrLib.TArrayOfString;
    NumStrItems:  integer;
    i:            integer;

begin
  {!} Assert(ObjList = nil);
  ObjItem :=  nil;
  // * * * * * //
  StrItems    :=  StrLib.Explode(RawFileData, LINE_END);
  NumStrItems :=  Length(StrItems) - 2;
  result      :=  (NumStrItems > 0) and (StrItems[Length(StrItems) - 1] = '');
  
  if result then begin
    ObjList :=  Lists.NewStrictStrList(TObjItem);
    i       :=  1;
    
    while result and (i <= NumStrItems) do begin
      StrItem :=  StrLib.ExplodeEx
      (
        StrItems[i],
        ' ',
        not StrLib.INCLUDE_DELIM,
        StrLib.LIMIT_TOKENS,
        2
      );
      
      result  :=  (Length(StrItem) = 2) and (Length(StrLib.Explode(StrItems[i], ' ')) >= 9);
      
      if result then begin
        ObjItem       :=  TObjItem.Create;
        ObjItem.Pos   :=  i - 1;
        ObjItem.Value :=  StrItem[1];
        ObjList.AddObj(SysUtils.AnsiLowerCase(StrItem[0]), ObjItem);
      end // .IF
      else begin
        Log.Write
        (
          'zeobjt.txt',
          'LoadObjList',
          'Line should have at least 9 elements: "' + StrItems[i] + '"'
        );
      end; // .ELSE

      Inc(i);
    end; // .WHILE
    
    ObjList.Sorted  :=  TRUE;
  end // .IF
  else begin
    Log.Write
    (
      'zeobjt.txt',
      'LoadObjList',
      'File has zero items or does not have terminating end of line'
    );
  end; // .ELSE
  
  if not result then begin
    SysUtils.FreeAndNil(ObjList);
  end; // .IF
end; // .FUNCTION LoadObjList

function ObjListToStr ({IN} var ObjList: Lists.TStringList): string;
var
{O} Res:      StrLib.TStrBuilder;
{U} ObjItem:  TObjItem;
    NumItems: integer;
    i:        integer;

begin
  {!} Assert(ObjList <> nil);
  Res     :=  StrLib.TStrBuilder.Create;
  ObjItem :=  nil;
  // * * * * * //
  NumItems        :=  ObjList.Count;
  ObjList.Sorted  :=  FALSE;
  Res.Append(SysUtils.IntToStr(NumItems));
  Res.Append(LINE_END);
  i :=  0;
  
  while i < NumItems do begin
    ObjItem :=  ObjList.Values[i];
    
    if ObjItem.Pos <> i then begin
      ObjList.Exchange(i, ObjItem.Pos);
    end // .IF
    else begin
      Inc(i);
    end; // .ELSE
  end; // .WHILE

  for i := 0 to NumItems - 1 do begin
    ObjItem :=  ObjList.Values[i];
    Res.Append(ObjList.Keys[i]);
    Res.Append(' ');
    Res.Append(ObjItem.Value);
    Res.Append(LINE_END);
  end; // .FOR

  result  :=  Res.BuildStr();
  // * * * * * //
  SysUtils.FreeAndNil(Res);
  SysUtils.FreeAndNil(ObjList);
end; // .FUNCTION ObjListToStr

function MergeObjLists
(
  ParentObjList:  Lists.TStringList;
  ChildObjList:   Lists.TStringList;
  SafeMode:       boolean
): boolean;

const
  CATEGORY_ID = 6;

var
{U} ObjItem:          TObjItem;
    OldAssertHandler: TAssertErrorProc;
    ExplodedSrc:      StrLib.TArrayOfString;
    ExplodedDst:      StrLib.TArrayOfString;
    ItemInd:          integer;
    ContinueLoop:     boolean;
    i:                integer;
  
begin
  {!} Assert(ParentObjList <> nil);
  {!} Assert(ChildObjList <> nil);
  ParentObjList.Sorted    :=  TRUE;
  ChildObjList.Sorted     :=  TRUE;
  OldAssertHandler        :=  System.AssertErrorProc;
  System.AssertErrorProc  :=  nil;
  
  try
    ChildObjList.ForbidDuplicates :=  TRUE;
    result                        :=  TRUE;
  except
    result  :=  FALSE;
  end; // .TRY
  
  System.AssertErrorProc  :=  OldAssertHandler;
  
  if result then begin
    i :=  0;
    
    while result and (i < ChildObjList.Count) do begin
      ObjItem :=  ChildObjList.Values[i];
      
      if ParentObjList.Find(ChildObjList.Keys[i], ItemInd) then begin
        if not SafeMode then begin
          ContinueLoop  :=  TRUE;
          
          while result and ContinueLoop do begin
            ExplodedDst :=  StrLib.Explode(TObjItem(ParentObjList.Values[ItemInd]).Value, ' ');
            ExplodedSrc :=  StrLib.Explode(ObjItem.Value, ' ');
            ExplodedSrc[CATEGORY_ID]  :=  ExplodedDst[CATEGORY_ID];
            TObjItem(ParentObjList.Values[ItemInd]).Value :=  StrLib.Join(ExplodedSrc, ' ');
            Dec(ItemInd);
            ContinueLoop  :=
              (ItemInd >= 0)  and
              (ParentObjList.Keys[ItemInd] = ChildObjList.Keys[i]);
          end; // .WHILE
        end; // .IF
      end // .IF
      else begin
        ObjItem.Pos :=  ParentObjList.Count;
        ParentObjList.AddObj(ChildObjList.Keys[i], ObjItem); ChildObjList.TakeValue(i);
      end; // .ELSE
      
      Inc(i);
    end; // .WHILE
  end; // .IF
end; // .FUNCTION MergeObjLists

function LoadZeobjt (var FileInfo: SysUtils.TSearchRec): boolean;
var
{O} ChildObjList: Lists.TStringList;
    FileName:     string;
    FileContents: string;
   
begin
  ChildObjList  :=  nil;
  // * * * * * //
  FileName  :=  FileInfo.Name;
  
  if
    (FileInfo.Size > 0) and
    Files.ReadFileContents(ZEOBJTS_DIR + '\' + FileName, FileContents)
  then begin
    if
      not LoadObjList(FileContents, ChildObjList) or
      not MergeObjLists(ZEObjList, ChildObjList, FALSE)
    then begin     
      DlgMes.MsgError
      (
        'Editor objects file contains duplicates or has invalid format: "'
        + ZEOBJTS_DIR + '\' + FileName + '"'
      );
    end; // .IF
    
    SysUtils.FreeAndNil(ChildObjList);
  end; // .IF
  
  result  :=  TRUE;
end; // .FUNCTION LoadZeobjt

procedure LoadZeobjts;
begin
  {!} Assert(ZEObjList <> nil);
  Files.Scan(ZEOBJTS_DIR + '\*.txt', Files.faNotDirectory, '.txt', LoadZeobjt);
end; // .PROCEDURE LoadZeobjts

function Hook_ReadTxt (Context: Core.PHookHandlerArgs): LONGBOOL; stdcall;
const
  ZEOBJTS_NAME  = 'zeobjts.txt';

var
  TextName:     string;
  TextContents: string;
  TextBuffer:   pointer;

begin
  (*
  All ESP offsets were increased by 4 to compensate call to bridge 
  *)
  TextName  :=  SysUtils.AnsiLowerCase(PPCHAR(Context.ESP + $28)^);
  
  if TextName = ZEOBJTS_NAME then begin
    if ZEObjList <> nil then begin
      SysUtils.FreeAndNil(ZEObjList);
    end; // .IF
    
    TextContents  :=  PPCHAR(Context.ESP + $14)^;
    
    if LoadObjList(TextContents, ZEObjList) then begin
      LoadZeobjts;
      TextContents                :=  ObjListToStr(ZEObjList);
      MFree(PPCHAR(Context.ESP + $14)^);
      TextBuffer                  :=  MAlloc(Length(TextContents));
      PPCHAR(Context.ESP + $14)^  :=  TextBuffer;
      Context.EDI                 :=  Length(TextContents);
      Context.ESI                 :=  integer(TextBuffer);
      Utils.CopyMem(Length(TextContents), pointer(TextContents), TextBuffer);
    end // .IF
    else begin
      DlgMes.MsgError('Invalid editor objects file: "' + ZEOBJTS_NAME + '"');
    end; // .ELSE
  end; // .IF
  
  result  :=  Core.EXEC_DEF_CODE;
end; // .FUNCTION Hook_ReadTxt

procedure AssertHandler (const Mes, FileName: string; LineNumber: integer; Address: pointer);
begin
  Core.FatalError(StrLib.BuildStr(
    'Assert violation in file "~FileName~" on line ~Line~.'#13#10'Error at address: $~Address~.',
    [
      'FileName', FileName,
      'Line',     SysUtils.IntToStr(LineNumber),
      'Address',  SysUtils.Format('%x', [integer(Address)])
    ],
    '~'
  ));
end; // .PROCEDURE AssertHandler

procedure Init (hDll: integer);
const
  RDATA_SECTION_ADDR  = Ptr($530000);
  RDATA_SECTION_SIZE  = $4B000;

var
  Buffer:         string;
  OldProtection:  integer;

begin
  hMe :=  hDll;
  Windows.DisableThreadLibraryCalls(hMe);
  System.AssertErrorProc :=  AssertHandler;
  
  (* Restore default editor constant overwritten by "eramap.dll" *)
  Buffer  :=  'GetSpreadsheet';
  Core.WriteAtCode(Length(Buffer) + 1, pointer(Buffer), Ptr($596ED4));
  
  (* GrayFace mapedpatch requires .rdata section to have WRITE flag *)
  Windows.VirtualProtect
  (
    RDATA_SECTION_ADDR,
    RDATA_SECTION_SIZE,
    Windows.PAGE_EXECUTE_READWRITE,
    @OldProtection
  );
  
  ExtendLods;
  
  LoadPlugins;
  ApplyPatches;

  (* Fix game version to allow generating random maps *)
  Core.Hook(@Hook_FixGameVersion, Core.HOOKTYPE_BRIDGE, 5, Ptr($45C5FD));
  
  (* Add support for extended zeobjts.txt *)
  Core.ApiHook(@Hook_ReadTxt, Core.HOOKTYPE_BRIDGE, Ptr($4DC8D4));
end; // .PROCEDURE Init

procedure AsmInit; ASSEMBLER;
asm
  (* Remove ret addr *)
  POP ECX
  
  CALL Init
  
  (* Default code *)
  PUSH EBP
  MOV EBP, ESP
  PUSH -1
  PUSH $54CA58
  PUSH $4EA77C
  PUSH [FS:0]
  
  (* Place new ret addr *)
  PUSH $4E84EA
  // RET
end; // .PROCEDURE AsmInit

begin
  LodList :=  Lists.NewSimpleStrList;
end.
