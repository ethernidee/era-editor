unit MapExt;
{
DESCRIPTION:  Editor extension support
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  interface  (***)
uses
  Windows, Math, SysUtils,
  Utils, DataLib, Files, FilesEx, StrLib,
  Debug, PatchApi, ApiJack, WinUtils, Log, DlgMes, CmdApp,
  VfsImport,
  BinPatching;

const
  (* Command line arguments *)
  CMDLINE_ARG_MODLIST = 'modlist';

  ERA_EDITOR_VERSION        = '3.9.20';
  DEBUG_DIR                 = 'Debug\EraEditor';
  DEBUG_MAPS_DIR            = 'DebugMaps';
  DEBUG_EVENT_LIST_PATH     = DEBUG_DIR + '\event list.txt';
  DEBUG_PATCH_LIST_PATH     = DEBUG_DIR + '\patch list.txt';
  DEBUG_MOD_LIST_PATH       = DEBUG_DIR + '\mod list.txt';
  DEBUG_X86_PATCH_LIST_PATH = DEBUG_DIR + '\x86 patches.txt';

  (* Paths *)
  MODS_DIR              = 'Mods';
  DEFAULT_MOD_LIST_FILE = MODS_DIR + '\list.txt';
  PLUGINS_PATH          = 'EraEditor';
  PATCHES_PATH          = 'EraEditor';


type
  EAssertFailure = class (Exception) end;

  PEvent  = ^TEvent;
  TEvent  = packed record
      Name:     string;
  {n} Data:     pointer;
      DataSize: integer;
  end; // .record TEvent

  TEventHandler = procedure (Event: PEvent); stdcall;

  TEventInfo = class
   protected
    {On} fHandlers:      TList {of TEventHandler};
         fNumTimesFired: integer;

    function GetNumHandlers: integer;
   public
    destructor Destroy; override;

    procedure AddHandler (Handler: pointer);

    property Handlers:      {n} TList {of TEventHandler} read fHandlers;
    property NumHandlers:   integer                      read GetNumHandlers;
    property NumTimesFired: integer                      read fNumTimesFired write fNumTimesFired;
  end; // .class TEventInfo


var
{O} PluginsList: DataLib.TStrList {OF TDllHandle};
{O} Events:      {O} DataLib.TDict {OF TEventInfo};
    hMe:         integer;
    GameDir:     string;
    ModsDir:     string;
    DumpVfsOpt:  boolean;


procedure AsmInit; assembler;
procedure GenerateDebugInfo;
procedure RegisterHandler (Handler: TEventHandler; const EventName: string); stdcall;
procedure FireEvent (const EventName: string; {n} EventData: pointer; DataSize: integer); stdcall;


(***) implementation (***)


destructor TEventInfo.Destroy;
begin
  FreeAndNil(fHandlers);
end;

procedure TEventInfo.AddHandler (Handler: pointer);
begin
  {!} Assert(Handler <> nil);
  if fHandlers = nil then begin
    fHandlers := DataLib.NewList(not Utils.OWNS_ITEMS);
  end; // .if

  fHandlers.Add(Handler);
end;

function TEventInfo.GetNumHandlers: integer;
begin
  if fHandlers = nil then begin
    result := 0;
  end else begin
    result := fHandlers.Count;
  end; // .else
end;

procedure RegisterHandler (Handler: TEventHandler; const EventName: string);
var
{U} EventInfo: TEventInfo;

begin
  {!} Assert(@Handler <> nil);
  EventInfo := Events[EventName];
  // * * * * * //
  if EventInfo = nil then begin
    EventInfo         := TEventInfo.Create;
    Events[EventName] := EventInfo;
  end; // .if

  EventInfo.AddHandler(@Handler);
end; // .procedure RegisterHandler

procedure FireEvent (const EventName: string; {n} EventData: pointer; DataSize: integer);
var
    Event:     TEvent;
{U} EventInfo: TEventInfo;
    i:         integer;

begin
  {!} Assert(Utils.IsValidBuf(EventData, DataSize));
  EventInfo := Events[EventName];
  // * * * * * //
  Event.Name     := EventName;
  Event.Data     := EventData;
  Event.DataSize := DataSize;

  if EventInfo = nil then begin
    EventInfo         := TEventInfo.Create;
    Events[EventName] := EventInfo;
  end; // .if

  EventInfo.NumTimesFired := EventInfo.NumTimesFired + 1;

  if EventInfo.Handlers <> nil then begin
    for i := 0 to EventInfo.Handlers.Count - 1 do begin
      TEventHandler(EventInfo.Handlers[i])(@Event);
    end; // .for
  end; // .if
end; // .procedure FireEvent

procedure LoadPlugins;
var
  DllHandle: THandle;

begin
  with Files.Locate(GameDir + '\' + PLUGINS_PATH + '\*.dll', Files.ONLY_FILES) do begin
    while FindNext do begin
      if not FoundRec.IsDir and (FoundRec.Rec.Size > 0) then begin
        DllHandle := Windows.LoadLibrary(pchar(FoundPath));
        {!} Assert(DllHandle <> 0, 'Failed to load plugin DLL at "' + FoundPath + '"');
        PluginsList.AddObj(FoundPath, Ptr(DllHandle));
      end;
    end;
  end;
end; // .procedure LoadPlugins

procedure GenerateDebugInfo;
begin
  FireEvent('OnGenerateDebugInfo', nil, 0);
end;

procedure DumpEventList;
var
{O} EventList: TStrList {of TEventInfo};
{U} EventInfo: TEventInfo;
    i, j:      integer;

begin
  EventList := nil;
  EventInfo := nil;
  // * * * * * //
  {!} Debug.ModuleContext.Lock;

  with FilesEx.WriteFormattedOutput(GameDir + '\' + DEBUG_EVENT_LIST_PATH) do begin
    Line('> Format: [Event name] ([Number of handlers], [Fired N times])');
    EmptyLine;

    EventList := DataLib.DictToStrList(Events, DataLib.CASE_INSENSITIVE);
    EventList.Sort;

    for i := 0 to EventList.Count - 1 do begin
      EventInfo := TEventInfo(EventList.Values[i]);
      Line(Format('%s (%d, %d)', [EventList[i], EventInfo.NumHandlers, EventInfo.NumTimesFired]));
    end; // .for

    EmptyLine; EmptyLine;
    Line('> Event handlers');
    EmptyLine;

    for i := 0 to EventList.Count - 1 do begin
      EventInfo := TEventInfo(EventList.Values[i]);

      if EventInfo.NumHandlers > 0 then begin
        Line(EventList[i] + ':');
      end; // .if

      Indent;

      for j := 0 to EventInfo.NumHandlers - 1 do begin
        Line(Debug.ModuleContext.AddrToStr(EventInfo.Handlers[j]));
      end; // .for

      Unindent;
    end; // .for
  end; // .with

  {!} Debug.ModuleContext.Unlock;
  // * * * * * //
  FreeAndNil(EventList);
end; // .procedure DumpEventList

procedure DumpPatchList;
var
  i: integer;

begin
  BinPatching.PatchList.Sort;

  with FilesEx.WriteFormattedOutput(GameDir + '\' + DEBUG_PATCH_LIST_PATH) do begin
    Line('> Format: [Patch name] (Patch size)');
    EmptyLine;

    for i := 0 to BinPatching.PatchList.Count - 1 do begin
      Line(Format('%s (%d)', [BinPatching.PatchList[i], integer(BinPatching.PatchList.Values[i])]));
    end; // .for
  end; // .with
end; // .procedure DumpPatchList

procedure DumpModList;
var
{O} MappingsReport: pchar;

begin
  MappingsReport := VfsImport.GetMappingsReportA;
  Files.WriteFileContents(MappingsReport, GameDir + '\' + DEBUG_MOD_LIST_PATH);
  // * * * * * //
  VfsImport.MemFree(MappingsReport);
end;

procedure OnGenerateDebugInfo (Event: PEvent); stdcall;
begin
  DumpModList;
  DumpEventList;
  DumpPatchList;
  PatchApi.GetPatcher().SaveDump(pchar(GameDir + '\' + DEBUG_X86_PATCH_LIST_PATH));
end;

procedure Init (hDll: integer);
const
  RDATA_SECTION_ADDR = Ptr($530000);
  RDATA_SECTION_SIZE = $4B000;

var
  Buffer:          string;
  OldProtection:   integer;
  ModListFilePath: string;

begin
  hMe := hDll;
  Windows.DisableThreadLibraryCalls(hMe);
  Files.ForcePath(GameDir + '\' + DEBUG_DIR);
  FireEvent('OnLoadSettings', nil, 0);

  // Run VFS
  ModListFilePath := CmdApp.GetArg(CMDLINE_ARG_MODLIST);

  if ModListFilePath = '' then begin
    ModListFilePath := GameDir + '\' + DEFAULT_MOD_LIST_FILE;
  end;

  VfsImport.MapModsFromListA(pchar(GameDir), pchar(ModsDir), pchar(ModListFilePath));
  Log.Write('Core', 'ReportModList', #13#10 + VfsImport.GetMappingsReportA);

  if DumpVfsOpt then begin
    Log.Write('Core', 'DumpVFS', #13#10 + VfsImport.GetDetailedMappingsReportA);
  end;

  VfsImport.RunVfs(VfsImport.SORT_FIFO);
  VfsImport.RunWatcherA(pchar(GameDir + '\Mods'), 250);

  (* Restore default editor constant overwritten by "eramap.dll" *)
  Buffer := 'GetSpreadsheet';
  ApiJack.WriteAtCode(Length(Buffer) + 1, pointer(Buffer), Ptr($596ED4));

  (* GrayFace mapedpatch requires .rdata section to have WRITE flag *)
  Windows.VirtualProtect
  (
    RDATA_SECTION_ADDR,
    RDATA_SECTION_SIZE,
    Windows.PAGE_EXECUTE_READWRITE,
    @OldProtection
  );

  FireEvent('OnInit', nil, 0);

  RegisterHandler(OnGenerateDebugInfo, 'OnGenerateDebugInfo');

  LoadPlugins;
  BinPatching.ApplyPatches(PATCHES_PATH);
end; // .procedure Init

procedure AsmInit; assembler;
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
end; // .procedure AsmInit

procedure AssertHandler (const Mes, FileName: string; LineNumber: integer; Address: pointer);
var
  CrashMes: string;

begin
  CrashMes := StrLib.BuildStr
  (
    'Assert violation in file "~FileName~" on line ~Line~.'#13#10'Error at address: $~Address~.'#13#10'Message: "~Message~"',
    [
      'FileName', FileName,
      'Line',     SysUtils.IntToStr(LineNumber),
      'Address',  SysUtils.Format('%x', [integer(Address)]),
      'Message',  Mes
    ],
    '~'
  );

  Log.Write('Core', 'AssertHandler', CrashMes);
  DlgMes.MsgError(CrashMes);

  raise EAssertFailure.Create(CrashMes) at Address;
end; // .procedure AssertHandler

begin
  AssertErrorProc := AssertHandler;
  PluginsList     := DataLib.NewStrList(not Utils.OWNS_ITEMS, DataLib.CASE_INSENSITIVE);
  Events          := DataLib.NewDict(Utils.OWNS_ITEMS, DataLib.CASE_INSENSITIVE);

  // Find out path to game directory and force it as current directory
  GameDir := StrLib.ExtractDirPathW(WinUtils.GetExePath());
  {!} Assert(GameDir <> '', 'Failed to obtain game directory path');
  SysUtils.SetCurrentDir(GameDir);
  ModsDir := GameDir + '\' + MODS_DIR;

  Debug.SetDebugMapsDir(GameDir + '\' + DEBUG_MAPS_DIR);
end.
