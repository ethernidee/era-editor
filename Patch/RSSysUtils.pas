unit RSSysUtils;

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
  SysUtils, Windows, Messages, SysConst, ShellAPI, Classes, RSQ, Types, Math;

type
  TRSApproveEvent = procedure(Sender:TObject; var Handled: boolean) of object;

  TRSByteArray = Types.TByteDynArray; //packed array of byte;
  PRSByteArray = ^TRSByteArray;

  PWMMoving = ^TWMMoving;

  TRSArrayStream = class(TMemoryStream)
  protected
    FArr: PRSByteArray;
    function Realloc(var NewCapacity: Longint): pointer; override;
  public
    constructor Create(var a: TRSByteArray);
    destructor Destroy; override;
  end;

  TRSStringStream = class(TMemoryStream)
  protected
    FStr: ^string;
    function Realloc(var NewCapacity: Longint): pointer; override;
  public
    constructor Create(var a: string);
    destructor Destroy; override;
  end;

  TRSReplaceStream = class(TStream)
  protected
    FMain: TStream;
    FReplace: TStream;
    FRepPos: Int64;
    FRepLim: Int64;
    FPos: Int64;
    FOwnMain: boolean;
    FOwnRep: boolean;
    function GetSize: Int64; override;
    procedure SetSize(NewSize: Longint); overload; override;
    procedure SetSize(const NewSize: Int64); overload; override;
  public
    constructor Create(Main, Replace: TStream; OwnMain, OwnReplace: boolean; Pos: Int64);
    destructor Destroy; override;
    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
  end;
  
  TRSCompositeStream = class(TStream) // never tested, just an unused draft
  protected
    FPosition: int;
    FStreams: TList;
    FOwnStreams: boolean;
    FCurrentStream: int;
    function GetSize: Int64; override;
    procedure SetSize(NewSize: Longint); overload; override;
    procedure SetSize(const NewSize: Int64); overload; override;
  public
    constructor Create;
    //constructor Create(const Streams: array of TStream; OwnStreams: Boolean);
    destructor Destroy; override;
    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
    procedure AddStream(a: TStream);
  end;

  TRSFileStreamProxy = class(TFileStream)
  protected
    FMode: word;
    FRights: cardinal;
{$IFNDEF D2006}
    FFileName: string;
{$ENDIF}
    procedure Check;
    procedure SetSize(NewSize: Longint); override;
    procedure SetSize(const NewSize: Int64); override;
  public
    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
    constructor Create(const AFileName: string; Mode: word); overload;
    constructor Create(const AFileName: string; Mode: word; Rights: cardinal); overload;
{$IFNDEF D2006}
    property FileName: string read FFileName;
{$ENDIF}
  end;

var
  RSWndExceptions: boolean = true;

type
   // Usage: TRSWnd(hWnd)
  TRSWnd = class
  private
    function GetAbsoluteRect: TRect;
    function GetBoundsRect: TRect;
    function GetClientRect: TRect;
    function GetClass: string;
    function GetExStyle: LongInt;
    function GetHeight: LongInt;
    function GetId: LongInt;
    function GetProcessId: DWord;
    function GetStayOnTop: boolean;
    function GetStyle: LongInt;
    function GetText: string;
    function GetThreadId: DWord;
    function GetVisible:boolean;
    function GetWidth: LongInt;
    procedure SetAbsoluteRect(v: TRect);
    procedure SetBoundsRect(const v: TRect);
    procedure SetExStyle(v: LongInt);
    procedure SetHeight(v: LongInt);
    procedure SetId(v: LongInt);
    procedure SetStayOnTop(v: boolean);
    procedure SetStyle(v: LongInt);
    procedure SetText(const v: string);
    procedure SetVisible(v: boolean);
    procedure SetWidth(v: LongInt);
    function GetLeft: LongInt;
    function GetTop: LongInt;
    procedure SetLeft(v: LongInt);
    procedure SetTop(v: LongInt);
  public
    class function Create(ClassName:pchar; WindowName:pchar; Style:DWORD;
      X, Y, Width, Height:integer; hWndParent: HWND; hMenu:HMENU;
      hInstance:HINST; lpParam:pointer=nil; ExStyle:DWORD=0):TRSWnd;
    destructor Destroy; override;
    procedure BorderChanged;
    function OpenProcess(dwDesiredAccess:DWORD=PROCESS_ALL_ACCESS;
            bInheritHandle:boolean=false): DWord;
    procedure SetBounds(x, y, w, h:int);
    procedure SetPosition(x, y:int);

    property AbsoluteRect: TRect read GetAbsoluteRect write SetAbsoluteRect;
    property BoundsRect: TRect read GetBoundsRect write SetBoundsRect;
    property ClientRect: TRect read GetClientRect;
{$WARNINGS OFF}
    property ClassName: string read GetClass;
{$WARNINGS ON}
    property ExStyle: LongInt read GetExStyle write SetExStyle;
    property Id: LongInt read GetId write SetId;
    property ProcessId: DWord read GetProcessId;
    property StayOnTop: boolean read GetStayOnTop write SetStayOnTop;
    property Style: LongInt read GetStyle write SetStyle;
    property Text: string read GetText write SetText;
    property ThreadId: DWord read GetThreadId;
    property Visible: boolean read GetVisible write SetVisible;
    property Width: LongInt read GetWidth write SetWidth;
    property Height: LongInt read GetHeight write SetHeight;
    property Top: LongInt read GetTop write SetTop;
    property Left: LongInt read GetLeft write SetLeft;
  end;

   // Usage: TRSBits(PByte, PWord or pointer to data of any size)
   // For example, TRSBits(@i).';
  TRSBits = class
  private
    function GetBit(i:DWord): boolean;
    procedure SetBit(i:DWord; v: boolean);
  public
    constructor Create;
    procedure FromBooleans(Buffer:pointer; Count:DWord; StartIndex:DWord = 0);
    procedure ToBooleans(Buffer:pointer; Count:DWord; StartIndex:DWord = 0);
    property Bit[i:DWord]: boolean read GetBit write SetBit; default;
  end;

   // No adding overhead at the cost of 4 bytes per block
  TRSCustomStack = class(TObject)
  private
    function GetSize:int;
  protected
    FBlockSize: int;
    FBlock: ptr; // First DWord = PLastBlock, then there goes data
    FNextBlock: ptr; // In case of pop
    FBlockCount: int;
    FLastSize: int; // Including PLastBlock
    FVirtualAlloc: boolean;
    function AllocBlock:ptr; virtual;
    procedure FreeBlock(ABlock:ptr); virtual;
    function NewBlock:ptr;
    function WholePush(Size:int):ptr;
    function WholePop(Size:int):ptr;
    function DoPeakAt(Offset:int):ptr;
    procedure DoPeak(var v; Size:int);

    function BlockNextTo(p:ptr):ptr; // For Queue
  public
    constructor Create(BlockSize:int);
    destructor Destroy; override;
    procedure Clear; virtual;
    property Size: int read GetSize;
  end;

  TRSFixedStack = class(TRSCustomStack)
  protected
    FItemSize: int;
    function GetCount:int; virtual;
     // Unsafe routines
    function AllocBlock:ptr; override;
    procedure FreeBlock(ABlock:ptr); override;
    function DoPush:ptr;
    function DoPop:ptr;
    function DoPeak:ptr; overload;
    function DoPeakAtIndex(index:int):ptr;
  public
    constructor Create(ItemSize:int; BlockSize:int=4096);

    procedure Peak(var v; Count:int);
    procedure PeakAll(var v);
    property Count: int read GetCount;
  end;

  TRSObjStack = class(TRSFixedStack)
  public
    constructor Create(BlockSize:int = 4096);
    procedure Push(Obj:TObject);
    function Pop:TObject;
    function Peak:TObject; overload;
    function PeakAt(index:int):TObject;
  end;

(*
   // Thread-safe in case of single writer and single reader
  TRSCustomQueue = class(TRSFixedStack)
  protected
    FCount: int;
    FPopBlock: ptr;
    FPopCount: int;
    FPopIndex: int; // Inside block
    FFillEvent: THandle;
    function GetCount:int; override;
    function DoPop:ptr;
    function AfterPush:ptr;
  public
    constructor Create(ItemSize:int; BlockSize:int=4096);
    destructor Destroy; override;
    procedure WaitFor(var Queue:TRSCustomQueue); // Queue var for safe Destroy 
  end;

  TRSObjQueue = class(TRSCustomQueue)
  public
    procedure Push(Obj:TObject);
    function Pop:TObject;
    function Peak:TObject; overload;
    function PeakAt(Index:int):TObject;
  public
    constructor Create(BlockSize:int=4096);
  end;
*)

{
   // В этом самом общем случае стека байтов нет особого смысла
  TRSStack = class(TRSCustomStack)
    procedure GetSize:int;
  public
    constructor Create(BlockSize:int=PageSize);
    destructor Destroy; override;
    procedure Push(const v; Count:int); overload;
    procedure Pop(var v; Count:int); overload;
    procedure Peak(var v; Count:int); overload;
    procedure PeakAll(var v);
    property Size: int read GetSize;
  end;
}

  TRSSharedData = class(TObject)
  protected
    FAlreadyExists: boolean;
    FData: ptr;
    FMMF: THandle;
    FSize: int;
  public
    constructor Create(Name:string; Size:int); overload;
    constructor Create(MMF:THandle; Size:int); overload;
    destructor Destroy; override;

    property AlreadyExists: boolean read FAlreadyExists;
    property Data: ptr read FData;
    property MMF: THandle read FMMF;
    property Size: int read FSize;
  end;


{ Example:

  with TRSFindFile.Create('C:\*.*') do
    try
      while FindNextAttributes(0, FILE_ATTRIBUTE_DIRECTORY) do // Only files
        DoSomething(FileName);
    finally
      Free;
    end;
}
  TRSFindFile = class(TObject)
  protected
    FHandle: THandle;
    FFileName: string;
    FFound: boolean;
    FNotFirst: boolean;
    FPath: string;
    procedure CheckError;
    function GetFileName: string;
  public
    Data: TWin32FindData;
    constructor Create(FileMask:string);
    destructor Destroy; override;
    function FindNext: boolean;
    function FindAttributes(Require, Exclude:DWord): boolean;
    function FindNextAttributes(Require, Exclude:DWord): boolean;
    property FileName: string read GetFileName;
    property Found: boolean read FFound;
    property Path: string read FPath;
  end;

   // Used in RSWindowProc.pas
  TRSEventHook = class(TObject)
  protected
    FEventProc:ptr;
    FPriority:int;
    FLastProc: TMethod;
    FNext: TRSEventHook;
    FLockCount: int;
    FDeleting: boolean;
    function GetEvent:TMethod; virtual; abstract;
    procedure SetEvent(const v:TMethod); virtual; abstract;
    function GetLast:TRSEventHook;
    property ObjEvent:TMethod read GetEvent write SetEvent;
  public
    constructor Create(Priority:int);
    procedure Delete;
    procedure Lock(aLock:boolean);
  end;

  TRSShellChangeNotifier = class(TThread)
  private
    FOnChange: TNotifyEvent;
    function GetNeedRefresh: boolean;
  protected
    FWakeEvent: THandle;
    FCS: TRTLCriticalSection;
    FReset: boolean;
    FNeedRefresh: boolean;

    FDirectory: string;
    FWatchSubTree: boolean;
    FFlags: DWord;

    procedure Execute; override;
    procedure CallOnChange;
  public
    constructor Create(OnChange: TNotifyEvent = nil); virtual;
    destructor Destroy; override;
    procedure Free;
    procedure Terminate;
    procedure SetOptions(Directory: string; WatchSubTree: boolean = false;
     Flags:DWord = FILE_NOTIFY_CHANGE_FILE_NAME or FILE_NOTIFY_CHANGE_DIR_NAME);
    procedure Cancel;
    procedure Reset;
    property NeedRefresh: boolean read GetNeedRefresh write FNeedRefresh;
    property Directory: string read FDirectory;
    property WatchSubTree: boolean read FWatchSubTree;
    property Flags: DWord read FFlags;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

{--------}

procedure RSCopyStream(Dest, Source: TStream; Count: int64);

procedure RSRaiseLastOSError;
function RSWin32Check(RetVal: BOOL): BOOL; register; overload;
function RSWin32Check(CheckForZero:int):int; register; overload;
function RSWin32Check(CheckForZero:ptr):ptr; register; overload;

procedure RSDispatchEx(Obj:TObject; AClass:TClass; var message);

 // From Grids.pas
procedure RSFillDWord(Dest:ptr; Count, Value: integer); register;

function RSQueryPerformanceCounter: int64;
function RSQueryPerformanceFrequency: int64;

{
procedure RSSetLayeredAttribs(Handle:HWnd;
             AlphaBlend:boolean; AlphaBlendValue:byte;
             TransparentColor:boolean; TransparentColorValue:int);
{}

{--------}

function RSGetModuleFileName(hModule: HINST = 0):string;
function PathFileExists(pszPath: pchar):Bool; stdcall; external 'shlwapi.dll' name 'PathFileExistsA';
function PathIsRoot(pPath: pchar):Bool; stdcall; external 'shlwapi.dll' name 'PathIsRootA';
function RSFileExists(const FileName: string): boolean; {$IFDEF D2005}inline;{$ENDIF}

function RSMoveFile(const OldName, NewName: string; FailIfExists: boolean): Bool;

function RSCreateFile(const FileName:string;
           dwDesiredAccess:DWord = GENERIC_READ or GENERIC_WRITE;
           dwShareMode:DWord = 0;
           lpSecurityAttributes:PSecurityAttributes = nil;
           dwCreationDistribution:DWord = CREATE_ALWAYS;
           dwFlagsAndAttributes:DWord = FILE_ATTRIBUTE_NORMAL;
           hTemplateFile:HFile=0):HFile;

function RSLoadFile(FileName:string):TRSByteArray;
procedure RSSaveFile(FileName:string; Data:TRSByteArray); overload;
procedure RSSaveFile(FileName:string; Data:TMemoryStream; RespectPosition: boolean = false); overload;
procedure RSAppendFile(FileName:string; Data:TRSByteArray); overload;
procedure RSAppendFile(FileName:string; Data:TMemoryStream; RespectPosition: boolean = false); overload;

function RSLoadTextFile(FileName:string):string;
procedure RSSaveTextFile(FileName:string; Data:string);
procedure RSAppendTextFile(FileName:string; Data:string);

function RSCreateDir(const PathName:string):boolean;

function RSCreateDirectory(const PathName:string;
           lpSecurityAttributes:PSecurityAttributes = nil):boolean;

function RSCreateDirectoryEx(const lpTemplateDirectory, NewDirectory:string;
           lpSecurityAttributes:PSecurityAttributes = nil):boolean;

function RSRemoveDir(const Dir:string):boolean;

const
  FO_MOVE = ShellAPI.FO_MOVE;
  FO_COPY = ShellAPI.FO_COPY;
  FO_DELETE = ShellAPI.FO_DELETE;
  FO_RENAME = ShellAPI.FO_RENAME;

function RSFileOperation(const aFrom, aTo:string; FileOperation: uint;
   Flags: FILEOP_FLAGS = FOF_NOCONFIRMATION or FOF_NOCONFIRMMKDIR or
          FOF_NOERRORUI or FOF_SILENT) : boolean; overload;

function RSFileOperation(const aFrom, aTo:array of string; FileOperation: uint;
   Flags: FILEOP_FLAGS = FOF_NOCONFIRMATION or FOF_NOCONFIRMMKDIR or
          FOF_NOERRORUI or FOF_SILENT) : boolean; overload;

function RSSearchPath(Path, FileName, Extension:string):string;

{--------}

function RSLoadProc(var Proc:pointer; const LibName, ProcName:string; LoadLib:boolean = true):hInst; overload;
function RSLoadProc(var Proc:pointer; const LibName:string; ProcIndex:word; LoadLib:boolean = true):hInst; overload;

function RSLoadProc(var Proc:pointer; const LibName, ProcName:string;
   LoadLib:boolean; RaiseException:boolean):hInst; overload;
function RSLoadProc(var Proc:pointer; const LibName:string; ProcIndex:word;
   LoadLib:boolean; RaiseException:boolean):hInst; overload;

procedure RSDelayLoad(var ProcAddress:pointer; const LibName, ProcName:string;
   LoadLib:boolean = true); overload;
procedure RSDelayLoad(var ProcAddress:pointer; const LibName:string;
   ProcIndex:word; LoadLib:boolean = true); overload;

{--------}

type
  TRSObjectInstance = packed record
    Code: array[0..4] of byte;
    Proc: ptr;
    Obj: ptr;
  end;

procedure RSMakeObjectInstance(var ObjInst:TRSObjectInstance;
             Obj, ProcStdCall:ptr); deprecated;

procedure RSCustomObjectInstance(var ObjInst:TRSObjectInstance;
             Obj, Proc, CustomProc:ptr); deprecated;

function RSMakeLessParamsFunction(
            ProcStdCall, Param:ptr):pointer; overload; deprecated;

function RSMakeLessParamsFunction(
            ProcStdCall:pointer; DWordParams:pointer;
            Count:integer; ResultInParam:integer=-1):pointer; overload; deprecated;

function RSMakeLessParamsFunction(
            ProcStdCall:pointer; const DWordParams:array of DWord;
            ResultInParam:integer=-1):pointer; overload; deprecated;

procedure RSFreeLessParamsFunction(Ptr:pointer); deprecated;

{--------}

function RSEnableTokenPrivilege(TokenHandle:THandle; const Privilege:string;
  Enable:boolean):boolean;

function RSEnableProcessPrivilege(hProcess:THandle; const Privilege:string;
  Enable:boolean):boolean;

function RSEnableDebugPrivilege(Enable:boolean):boolean;

{--------}

function RSCreateRemoteCopy(CurPtr:pointer; var RemPtr:pointer;
                      Len, hProcess:DWord; var Mapping:DWord):boolean;

function RSCreateRemoteCopyID(CurPtr:pointer; var RemPtr:pointer;
                      Len, ProcessID:DWord; var Mapping:DWord):boolean;

function RSCreateRemoteCopyWnd(CurPtr:pointer; var RemPtr:pointer;
                     Len:DWord; wnd:hWnd; var Mapping:DWord):boolean;

function RSFreeRemoteCopy(CurPtr, RemPtr:pointer;
                           Len, hProcess, Mapping:DWord):boolean;

function RSFreeRemoteCopyID(CurPtr, RemPtr:pointer;
                             Len, ProcessID, Mapping:DWord):boolean;

function RSFreeRemoteCopyWnd(CurPtr, RemPtr:pointer;
                          Len:DWord; wnd:hWnd; Mapping:DWord):boolean;

{--------}

function RSSendDataMessage(hWnd:HWnd; Msg:DWord; wParam:WParam;
           lParam:LParam; var lpdwResult:DWord; wDataLength:DWord=0;
           lDataLength:DWord=0; wReadOnly:boolean=false;
           lReadOnly:boolean=false):boolean;

function RSSendDataMessageTimeout(hWnd:HWnd; Msg:DWord; wParam:WParam;
           lParam:LParam; fuFlags,uTimeout:DWord; var lpdwResult:DWord;
           wDataLength:DWord=0; lDataLength:DWord=0;
           wReadOnly:boolean=false; lReadOnly:boolean=false):boolean;

function RSSendDataMessageCallback(hWnd:HWnd; Msg:DWord; wParam:WParam;
           lParam:LParam; lpCallBack:pointer; dwData:DWord;
           wDataLength:DWord=0; lDataLength:DWord=0;
           wReadOnly:boolean=true; lReadOnly:boolean=true):boolean;

function RSPostDataMessage(hWnd:HWnd; Msg:DWord; wParam:WParam;
           lParam:LParam; wDataLength:DWord=0;
           lDataLength:DWord=0; wReadOnly:boolean=true;
           lReadOnly:boolean=true):boolean;

{--------}

function RSRunWait(Command:string; Dir:string;
           Timeout:DWord=INFINITE; showCmd:word=SW_NORMAL):boolean;

{--------}

procedure RSShowException;

 // Usage: AssertErrorProc:=RSAssertDisable
procedure RSAssertDisable(const message, FileName: string;
    LineNumber: integer; ErrorAddr: pointer);

 // Usage: AssertErrorProc:=RSAssertErrorHandler
procedure RSAssertErrorHandler(const message, FileName: string;
    LineNumber: integer; ErrorAddr: pointer);

 // Use RSDebug instead
function RSHandleException(FuncSkip:integer=0; TraceLimit:integer=0; EAddr:pointer=nil; EObj:TObject=nil):string; deprecated;

{--------}

function RSMessageBox(hWnd:hwnd; Text, Caption:string; uType:DWord=0):int;

{--------}

var
  RSOSVersionInfo: OSVERSIONINFO;

resourcestring
  sRSCantLoadProc = 'Can''t load the "%s" procedure from "%s"';
  sRSCantLoadIndexProc = 'Can''t load the procedure number %d from "%s"';

implementation

var
  OSVersion: OSVERSIONINFO absolute RSOSVersionInfo;

const
  PageSize = 4096;

{$W-} // Unused stack frames are not welcome here (RSDelayLoad)
{$H+} // Long strings

function CalcJmpOffset(Src, Dest: pointer): pointer;
begin
  result := ptr(Longint(Dest) - (Longint(Src) + 5));
end;

function MakeCall(Caller, JumpTo:ptr):ptr;
begin
  PByte(Caller)^:=$E8;
  Inc(PByte(Caller));
  result:=pchar(Caller)+4;
  pptr(Caller)^:= ptr(int(JumpTo) - int(result));
end;

{
******************************** TRSArrayStream ********************************
}
constructor TRSArrayStream.Create(var a: TRSByteArray);
begin
  inherited Create;
  FArr:=@a;
  SetPointer(ptr(a), Length(a));
end;

destructor TRSArrayStream.Destroy;
begin
  FArr:=nil;
end;

function TRSArrayStream.Realloc(var NewCapacity: Longint): pointer;
begin
  if FArr<>nil then
  begin
    SetLength(FArr^, NewCapacity);
    result:=ptr(FArr^);
  end else
    result:=nil;
end;

{
******************************* TRSStringStream ********************************
}

constructor TRSStringStream.Create(var a: string);
begin
  inherited Create;
  FStr:=@a;
  SetPointer(ptr(a), Length(a));
end;

destructor TRSStringStream.Destroy;
begin
  FStr:=nil;
end;

function TRSStringStream.Realloc(var NewCapacity: integer): pointer;
begin
  if FStr<>nil then
  begin
    SetLength(FStr^, NewCapacity);
    result:=ptr(FStr^);
  end else
    result:=nil;
end;

{
****************************** TRSReplcaeStream ******************************
}

constructor TRSReplaceStream.Create(Main, Replace: TStream; OwnMain,
  OwnReplace: boolean; Pos: Int64);
begin
  FMain:= Main;
  FReplace:= Replace;
  FOwnMain:= OwnMain;
  FOwnRep:= OwnReplace;
  FRepPos:= Pos;
  FRepLim:= Pos + FReplace.Size;
  FPos:= FMain.Position;
end;

destructor TRSReplaceStream.Destroy;
begin
  if FOwnMain then
    FreeAndNil(FMain);
  if FOwnRep then
    FreeAndNil(FReplace);
  inherited;
end;

function TRSReplaceStream.GetSize: Int64;
begin
  result:= FMain.Size;
end;

function TRSReplaceStream.Read(var Buffer; Count: integer): Longint;
var
  i: int;
//  p: PChar;
begin
  result:= Count;
//  p:= @Buffer;
  if (Count > 0) and (FPos < FRepPos) then
  begin
    i:= FMain.Read(Buffer, min(Count, FRepPos - FPos));
    Inc(FPos, i);
    Dec(Count, i);
//    inc(p, i);
    if FPos >= FRepPos then
      FReplace.Seek(0, 0);
  end;
  if (Count > 0) and (FPos >= FRepPos) and (FPos < FRepLim) then
  begin
    i:= FReplace.Read(Buffer, min(Count, FRepLim - FPos));
    Inc(FPos, i);
    Dec(Count, i);
//    inc(p, i);
    FMain.Seek(i, soCurrent);
  end;
  if FPos >= FRepLim then
  begin
    i:= FMain.Read(Buffer, Count);
    Inc(FPos, i);
    Dec(Count, i);
  end;
  Dec(result, Count);
end;

function TRSReplaceStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  result:= FMain.Seek(Offset, Origin);
  FPos:= result;
  if (result >= FRepPos) and (result < FRepLim) then
    FReplace.Seek(result - FRepPos, 0);
end;

procedure TRSReplaceStream.SetSize(NewSize: integer);
begin
  FMain.Size:= NewSize;
end;

procedure TRSReplaceStream.SetSize(const NewSize: Int64);
begin
  FMain.Size:= NewSize;
end;

function TRSReplaceStream.Write(const Buffer; Count: integer): Longint;
begin
  Assert(false); // copy from Read
  result:= 0;
end;

{
****************************** TRSCompositeStream ******************************
}

constructor TRSCompositeStream.Create;
begin
  inherited;
  FStreams:= TList.Create;
  FOwnStreams:= true;
end;

destructor TRSCompositeStream.Destroy;
var
  i: int;
begin
  if FOwnStreams then
    for i := 0 to FStreams.Count - 1 do
      TObject(FStreams.Items[i]).Destroy;
  inherited;
end;

function TRSCompositeStream.GetSize: Int64;
var
  i: int;
begin
  result:= 0;
  for i := 0 to FStreams.Count - 1 do
    Inc(result, TStream(FStreams[i]).Size);
end;

function TRSCompositeStream.Read(var Buffer; Count: integer): Longint;
var
  i, j: int;
  p: pchar;
begin
  result:= Count;
  if Count = 0 then  exit;
  p:= @Buffer;
  for i := FCurrentStream to FStreams.Count - 2 do
  begin
    j:= TStream(FStreams[i]).Read(p^, Count);
    Inc(p, j);
    Dec(Count, j);
    if Count = 0 then  exit;
    TStream(FStreams[i]).Seek(0, 0);
    Inc(FCurrentStream);
  end;
  if FStreams.Count > 0 then
    Dec(Count, TStream(FStreams[FCurrentStream]).Read(p^, Count));
  Dec(result, Count);
end;

function TRSCompositeStream.Seek(const Offset: Int64;
  Origin: TSeekOrigin): Int64;
var
  i, j, sz, off, n: int;
  a: TStream;
//  orig: TSeekOrigin;
begin
  result:= 0;
  n:= FStreams.Count;
  if n = 0 then  exit;

  case Origin of
    soBeginning:
      i:= 0;
    soCurrent:
      i:= FCurrentStream;
    else //soEnd:
      i:= n - 1;
  end;
  if FCurrentStream <> i then
    TStream(FStreams[FCurrentStream]).Seek(0, 0);
  a:= TStream(FStreams[i]);
  off:= a.Seek(0, Origin) + Offset;
  if Origin <> soBeginning then
    a.Seek(0, 0);
  if off <= 0 then
  begin
    while (off < 0) and (i > 0) do
    begin
      Dec(i);
      a:= TStream(FStreams[i]);
      Inc(off, a.Size);
    end;
    result:= a.Seek(off, 0);
    FCurrentStream:= i;
    for j := i - 1 downto 0 do
      Inc(result, TStream(FStreams[j]).Size);
  end else
  begin
    for j := i - 1 downto 0 do
      Inc(result, TStream(FStreams[j]).Size);
    sz:= a.Size;
    while (sz <= off) and (i < n - 1) do
    begin
      Inc(result, sz);
      Dec(off, sz);
      Inc(i);
      a:= TStream(FStreams[i]);
      sz:= a.Size;
    end;
    Inc(result, a.Seek(off, 0));
    FCurrentStream:= i;
  end;
end;

procedure TRSCompositeStream.SetSize(NewSize: integer);
begin
  SetSize(Int64(NewSize));
end;

procedure TRSCompositeStream.SetSize(const NewSize: Int64);
var
  sz: Int64;
//  a: TStream;
  i: int;
begin
  sz:= NewSize;
  for i := 0 to FStreams.Count - 2 do
    Dec(sz, TStream(FStreams[i]).Size);
  i:= FStreams.Count;
  Assert((i > 0) and (sz >= 0));
  TStream(FStreams[i - 1]).Size:= sz;
end;

function TRSCompositeStream.Write(const Buffer; Count: integer): Longint;
var
  i, j: int;
  p: pchar;
  a: TStream;
begin
  result:= Count;
  if Count = 0 then  exit;
  p:= @Buffer;
  for i := FCurrentStream to FStreams.Count - 2 do
  begin
    a:= TStream(FStreams[i]);
    j:= a.Size - a.Position;
    if Count < j then
      j:= Count;
    j:= a.Write(p^, j);
    Inc(p, j);
    Dec(Count, j);
    if Count = 0 then  exit;
    TStream(FStreams[i]).Seek(0, 0);
    Inc(FCurrentStream);
  end;
  if FStreams.Count > 0 then
    Dec(Count, TStream(FStreams[FCurrentStream]).Write(p^, Count));
  Dec(result, Count);
end;

procedure TRSCompositeStream.AddStream(a: TStream);
begin
  a.Seek(0, 0);
  FStreams.Add(a);
end;

{
****************************** TRSFileStreamProxy ******************************
}

constructor TRSFileStreamProxy.Create(const AFileName: string; Mode: word);
begin
{$IFDEF MSWINDOWS}
  Create(AFileName, Mode, 0);
{$ELSE}
  Create(AFileName, Mode, FileAccessRights);
{$ENDIF}
end;

constructor TRSFileStreamProxy.Create(const AFileName: string; Mode: word;
  Rights: cardinal);
begin
  inherited Create(-1);
{$IFDEF D2006}
  string((@FileName)^):= AFileName;
{$ELSE}
  FFileName:= AFileName;
{$ENDIF}
  FMode:= Mode;
  FRights:= Rights;
end;

procedure TRSFileStreamProxy.Check;
begin
  if Handle < 0 then
    inherited Create(FileName, FMode, FRights);
end;

function TRSFileStreamProxy.Read(var Buffer; Count: integer): Longint;
begin
  Check;
  result:= inherited Read(Buffer, Count);
end;

function TRSFileStreamProxy.Seek(const Offset: Int64;
  Origin: TSeekOrigin): Int64;
begin
  Check;
  result:= inherited Seek(Offset, Origin);
end;

procedure TRSFileStreamProxy.SetSize(NewSize: integer);
begin
  Check;
  inherited;
end;

procedure TRSFileStreamProxy.SetSize(const NewSize: Int64);
begin
  Check;
  inherited;
end;

function TRSFileStreamProxy.Write(const Buffer; Count: integer): Longint;
begin
  Check;
  result:= inherited Write(Buffer, Count);
end;

{
************************************ TRSWnd ************************************
}

procedure RSWndCheck(b:boolean);
asm
  test eax, eax
  jnz @exit
  cmp RSWndExceptions, false
  jnz RSRaiseLastOSError
@exit:
end;

class function TRSWnd.Create(ClassName:pchar; WindowName:pchar; Style:DWORD;
  X, Y, Width, Height:integer; hWndParent: HWND; hMenu:HMENU;
  hInstance:HINST; lpParam:pointer=nil; ExStyle:DWORD=0):TRSWnd;
begin
  result:=TRSWnd(CreateWindowEx(ExStyle, ClassName, WindowName, Style, X, Y,
    Width, Height, hWndParent, hMenu, hInstance, lpParam));
end;

destructor TRSWnd.Destroy;
begin
  Assert(false);
  // TRSWnd isn't a normal class. Don't destroy it!
end;

procedure TRSWnd.BorderChanged;
begin
  SetWindowPos(HWnd(self),0,0,0,0,0,SWP_DRAWFRAME or SWP_FRAMECHANGED or
               SWP_NOZORDER or SWP_NOACTIVATE or SWP_NOMOVE or
               SWP_NOOWNERZORDER or SWP_NOSIZE or SWP_NOSENDCHANGING);
end;

function TRSWnd.GetAbsoluteRect: TRect;
begin
  RSWndCheck(GetWindowRect(HWnd(self), result));
end;

function TRSWnd.GetBoundsRect: TRect;
var
  h: HWnd;
begin
  RSWndCheck(GetWindowRect(HWnd(self), result));
  h:=GetParent(HWnd(self));
  if h=0 then exit;
  MapWindowPoints(0, h, result, 2);
end;

function TRSWnd.GetClientRect: TRect;
begin
  RSWndCheck(windows.GetClientRect(HWnd(self), result));
end;

function TRSWnd.GetClass: string;
var
  i: integer;
begin
  SetLength(result,255);
  i:=GetClassName(HWnd(self),pointer(result),256);
  SetLength(result, i);
  RSWndCheck(i<>0);
end;

function TRSWnd.GetExStyle: LongInt;
begin
  result:=GetWindowLong(HWnd(self),GWL_EXSTYLE);
end;

function TRSWnd.GetHeight: LongInt;
begin
  with GetAbsoluteRect do
    result:=Bottom-Top;
end;

function TRSWnd.GetId: LongInt;
begin
  result:=GetWindowLong(HWnd(self),GWL_ID);
end;

function TRSWnd.GetProcessId: DWord;
begin
  RSWndCheck(GetWindowThreadProcessId(HWnd(self), result) <> 0);
end;

function TRSWnd.GetStayOnTop: boolean;
begin
  result:=(GetWindowLong(HWnd(self),GWL_EXSTYLE) and WS_EX_Topmost)<>0;
end;

function TRSWnd.GetStyle: LongInt;
begin
  result:=GetWindowLong(HWnd(self),GWL_STYLE);
end;

function TRSWnd.GetText: string;
var
  i: integer;
begin
  i:=GetWindowTextLength(HWnd(self));
  if i<=0 then exit;
  SetLength(result,i);
  GetWindowText(HWnd(self),pointer(result),i+1);
end;

function TRSWnd.GetThreadId: DWord;
begin
  result:= GetWindowThreadProcessId(HWnd(self), DWord(nil^));
  RSWndCheck(result<>0);
end;

function TRSWnd.GetVisible:boolean;
begin
  result:= GetWindowLong(HWnd(self),GWL_STYLE) and WS_VISIBLE <> 0;
end;

function TRSWnd.GetWidth: LongInt;
begin
  with GetAbsoluteRect do
    result:=Right-Left;
end;

function TRSWnd.OpenProcess(dwDesiredAccess:DWORD=PROCESS_ALL_ACCESS; 
        bInheritHandle:boolean=false): DWord;
var
  pID: Dword;
begin
  GetWindowThreadProcessId(HWnd(self), pID);
  if pID=0 then
    result:=0
  else
    result:=Windows.OpenProcess(dwDesiredAccess, bInheritHandle, pID);
end;

procedure TRSWnd.SetAbsoluteRect(v: TRect);
var
  h: HWnd;
begin
  h:=GetParent(HWnd(self));
  if h<>0 then
    MapWindowPoints(0, h, v, 2);

  RSWndCheck(SetWindowPos(HWnd(self), 0,
                        v.Left, v.Top, v.Right-v.Left, v.Bottom-v.Top,
                        SWP_NOACTIVATE or SWP_NOOWNERZORDER or SWP_NOZORDER));
end;

procedure TRSWnd.SetBoundsRect(const v: TRect);
begin
  SetBounds(v.Left, v.Top, v.Right-v.Left, v.Bottom-v.Top);
end;

procedure TRSWnd.SetExStyle(v: LongInt);
begin
  SetWindowLong(HWnd(self), GWL_EXSTYLE, v);
end;

procedure TRSWnd.SetHeight(v: LongInt);
begin
  RSWndCheck(SetWindowPos(HWnd(self), 0, 0, 0, Width, v,
           SWP_NOMOVE or SWP_NOACTIVATE or SWP_NOOWNERZORDER or SWP_NOZORDER));
end;

procedure TRSWnd.SetId(v: LongInt);
begin
  SetWindowLong(HWnd(self), GWL_ID, v);
end;

procedure TRSWnd.SetStayOnTop(v: boolean);
var h:hwnd;
begin
  if v then
    h:=HWND_TOPMOST
  else
    h:=HWND_NOTOPMOST;
  RSWndCheck(SetWindowPos(HWnd(self), h, 0, 0, 0, 0,
     SWP_NOACTIVATE or SWP_NOSIZE or SWP_NOMOVE or SWP_NOOWNERZORDER or SWP_NOSENDCHANGING))
end;

procedure TRSWnd.SetStyle(v: LongInt);
begin
  SetWindowLong(HWnd(self),GWL_STYLE,v);
end;

procedure TRSWnd.SetText(const v: string);
begin
  RSWndCheck(SetWindowText(HWnd(self),pchar(v)));
end;

procedure TRSWnd.SetVisible(v: boolean);
begin
  if v then
    ShowWindow(HWnd(self), SW_SHOWNOACTIVATE)
  else
    ShowWindow(HWnd(self), SW_HIDE);
end;

procedure TRSWnd.SetWidth(v: LongInt);
begin
  RSWndCheck(SetWindowPos(HWnd(self),0,0,0,v,Height,
             SWP_NOMOVE or SWP_NOACTIVATE or SWP_NOOWNERZORDER or SWP_NOZORDER));
end;

function TRSWnd.GetLeft: LongInt;
begin
  result:=AbsoluteRect.Left;
end;

function TRSWnd.GetTop: LongInt;
begin
  result:=AbsoluteRect.Top;
end;

procedure TRSWnd.SetBounds(x, y, w, h:int);
begin
  RSWndCheck(SetWindowPos(HWnd(self), 0, x, y, w, h,
     SWP_NOACTIVATE or SWP_NOOWNERZORDER or SWP_NOZORDER));
end;

procedure TRSWnd.SetPosition(x, y:int);
begin
  RSWndCheck(SetWindowPos(HWnd(self), 0, x, y, 0, 0,
     SWP_NOACTIVATE or SWP_NOOWNERZORDER or SWP_NOZORDER or SWP_NOMOVE));
end;

procedure TRSWnd.SetLeft(v: LongInt);
begin
  SetPosition(v, BoundsRect.Top);
end;

procedure TRSWnd.SetTop(v: LongInt);
begin
  SetPosition(BoundsRect.Left, v);
end;

{
*********************************** TRSBits ************************************
}
constructor TRSBits.Create;
begin
  Assert(false);
  // Don't try to create TRSBits objects.
  // Use TRSBits(PByte, PWord or pointer to data of any size) instead.
  // For example, TRSBits(@i).
end;

function TRSBits.GetBit(i:DWord): boolean;
begin
  result := PByte(DWord(self) + i div 8)^ and (1 shl (i mod 8)) <> 0;
end;

procedure TRSBits.SetBit(i:DWord; v: boolean);
var
  j: PByte;
begin
  j:=PByte(DWord(self) + i div 8);
  if v then
    j^ := j^ or (1 shl (i mod 8))
  else
    j^ := j^ and not (1 shl (i mod 8));
end;

procedure TRSBits.FromBooleans(Buffer:pointer; Count:DWord; StartIndex:DWord=0);
var
  p:PByte; i,j:DWord; k:byte;
begin
   // Optimized to death

  if Count=0 then exit;
  
  p:=PByte(pchar(self) + StartIndex div 8);
  i:=StartIndex mod 8;
  if i<>0 then
  begin
    k:=p^;
    j:=1 shl i;
    i:=8-i;
    if Count<i then i:=Count;
    Dec(Count,i);
    while i<>0 do
    begin
      if PBoolean(Buffer)^ then
        k := k or j
      else
        k := k and not j;
      j:=j shl 1;
      Inc(PBoolean(Buffer));
      Dec(i);
    end;
    p^:=k;
    Inc(p);
  end;

  for i:=(Count div 8) downto 1 do
  begin
    k:=0;
    j:=pint(Buffer)^;
    Inc(pint(Buffer));
    if j and $ff <> 0 then  k := k or 1;
    if j and $ff00 <> 0 then  k := k or 2;
    if j and $ff0000 <> 0 then  k := k or 4;
    if j and $ff000000 <> 0 then  k := k or 8;
    j:=pint(Buffer)^;
    Inc(pint(Buffer));
    if j and $ff <> 0 then  k := k or 16;
    if j and $ff00 <> 0 then  k := k or 32;
    if j and $ff0000 <> 0 then  k := k or 64;
    if j and $ff000000 <> 0 then  k := k or 128;
    p^:=k;
    Inc(p);
  end;

  i:=Count mod 8;
  if i<>0 then
  begin
    k:=p^;
    j:=1;
    for i:=i downto 1 do
    begin
      if PBoolean(Buffer)^ then
        k := k or j
      else
        k := k and not j;
      j:=j shl 1;
      Inc(PBoolean(Buffer));
    end;
    p^:=k;
  end;
end;

procedure TRSBits.ToBooleans(Buffer:pointer; Count:DWord; StartIndex:DWord = 0);
var
  j, k: byte;
  p: PByte;
  i: DWord;
begin
   // Optimized to death
  
  if Count=0 then exit;

  p:=PByte(DWord(self) + StartIndex div 8);
  i:=StartIndex mod 8;
  if i<>0 then
  begin
    k:=p^;
    j:=1 shl i;
    i:=8-i;
    if Count<i then i:=Count;
    Dec(Count,i);
    while i<>0 do
    begin
      PBoolean(Buffer)^:=k and j <> 0;
      j:=j shl 1;
      Inc(PBoolean(Buffer));
      Dec(i);
    end;
    Inc(p);
  end;
  
  for i:=(Count div 8) downto 1 do
  begin
    k:=p^;
    PBoolean(Buffer)^:=k and 1 <> 0;
    Inc(PBoolean(Buffer));
    PBoolean(Buffer)^:=k and 2 <> 0;
    Inc(PBoolean(Buffer));
    PBoolean(Buffer)^:=k and 4 <> 0;
    Inc(PBoolean(Buffer));
    PBoolean(Buffer)^:=k and 8 <> 0;
    Inc(PBoolean(Buffer));
    PBoolean(Buffer)^:=k and 16 <> 0;
    Inc(PBoolean(Buffer));
    PBoolean(Buffer)^:=k and 32 <> 0;
    Inc(PBoolean(Buffer));
    PBoolean(Buffer)^:=k and 64 <> 0;
    Inc(PBoolean(Buffer));
    PBoolean(Buffer)^:=k and 128 <> 0;
    Inc(PBoolean(Buffer));
    Inc(p);
  end;

  i:=Count mod 8;
  if i<>0 then
  begin
    k:=p^;
    j:=1;
    for i:=i downto 1 do
    begin
      PBoolean(Buffer)^:=k and j <> 0;
      j:=j shl 1;
      Inc(PBoolean(Buffer));
    end;
  end;
end;

{
******************************** TRSCustomStack *********************************
}

constructor TRSCustomStack.Create(BlockSize:int);
begin
  FBlockSize:=BlockSize;
  FLastSize:=BlockSize;
end;

destructor TRSCustomStack.Destroy;
begin
  Clear;
  if FNextBlock<>nil then
    FreeBlock(FNextBlock);
  inherited Destroy;
end;

function TRSCustomStack.AllocBlock: ptr;
begin
  GetMem(result, FBlockSize);
end;

procedure TRSCustomStack.FreeBlock(ABlock: ptr);
begin
  FreeMem(ABlock, FBlockSize);
end;

procedure TRSCustomStack.Clear;
var p:pptr; p1:ptr;
begin
//  FreeMem(FNextBlock);
//  FNextBlock:=nil;
  p:=FBlock;
  while p<>nil do
  begin
    p1:=p;
    p:=p^;
    FreeBlock(p1);
  end;
  FBlock:=nil;
  FBlockCount:=0;
end;

function TRSCustomStack.NewBlock:ptr;
begin
  result:=FNextBlock;
  if result=nil then
    result:=AllocBlock
  else
    FNextBlock:=nil;
  pptr(result)^:=FBlock;
  FBlock:=result;
  Inc(FBlockCount);
end;

function TRSCustomStack.WholePush(Size:int):ptr;
var i:int;
begin
  i:=FLastSize;
  if i=FBlockSize then
  begin
    result:=NewBlock;
    i:=4;
  end else
    result:=FBlock;

  Inc(pbyte(result), i);
  FLastSize:=i+Size;
end;

function TRSCustomStack.WholePop(Size:int):ptr;
var i:int;
begin
  result:=FBlock;
  if result=nil then exit;
  i:=FLastSize-Size;
  if i=4 then
  begin
    FreeBlock(FNextBlock);
    FNextBlock:=result;
    FBlock:=pptr(result)^;
    FLastSize:=FBlockSize;
    Dec(FBlockCount);
  end else
    FLastSize:=i;
  Inc(pbyte(result), i);
end;

function TRSCustomStack.DoPeakAt(Offset:int):ptr;
var l:int;
begin
  if Offset > FLastSize-4 then
  begin
    Dec(Offset, FLastSize-4);
    result:=pptr(FBlock)^;
    l:=FBlockSize-4;
    while Offset>l do
    begin
      result:=pptr(result)^;
      Dec(Offset, l);
    end;
    result:=pchar(result)+FBlockSize-Offset;
  end else
    result:=pchar(FBlock)+FLastSize-Offset;
end;

procedure TRSCustomStack.DoPeak(var v; Size:int);
var l,Offset:int; p,result:pchar;
begin
  Offset:=Size;
  p:=pchar(@v);
  if Offset > FLastSize-4 then
  begin
    Dec(Offset, FLastSize-4);
    CopyMemory(p+Offset, pchar(FBlock)+4, FLastSize-4);
    result:=pptr(FBlock)^;
    l:=FBlockSize-4;
    while Offset>l do
    begin
      Dec(Offset, l);
      CopyMemory(p+Offset, pchar(result)+4, l);
      result:=pptr(result)^;
    end;
    CopyMemory(p, result+FBlockSize-Offset, Offset);
  end else
    CopyMemory(p, pchar(FBlock)+FLastSize-Offset, Offset);
end;

function TRSCustomStack.GetSize:int;
begin
  result:= (FBlockSize-4)*FBlockCount + FLastSize - FBlockSize;
end;

function TRSCustomStack.BlockNextTo(p:ptr):ptr;
begin
  result:= FBlock;
  if result <> p then
    while result<>nil do
    begin
      if pptr(result)^ = p then  exit;
      result:= pptr(result)^;
    end;
  result:=nil;
end;

{
******************************** TRSFixedStack *********************************
}

constructor TRSFixedStack.Create(ItemSize:int; BlockSize:int=4096);
begin
  if BlockSize > PageSize then
    BlockSize:= (BlockSize + PageSize - 1) and not (PageSize - 1);
  BlockSize:= BlockSize - (BlockSize-4) mod ItemSize;
  if BlockSize<=4 then
  begin
    Assert(BlockSize>4);
    BlockSize:= max(PageSize - (PageSize-4) mod ItemSize, ItemSize + 4);
  end;
  inherited Create(BlockSize);
  FItemSize:=ItemSize;
end;

function TRSFixedStack.AllocBlock: ptr;
begin
  if FBlockSize + FItemSize > PageSize then
    result:=VirtualAlloc(nil, FBlockSize, MEM_COMMIT or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
  else
    GetMem(result, FBlockSize);
end;

procedure TRSFixedStack.FreeBlock(ABlock: ptr);
begin
  if FBlockSize + FItemSize > PageSize then
    VirtualFree(ABlock, 0, MEM_DECOMMIT	or MEM_RELEASE)
  else
    FreeMem(ABlock, FBlockSize);
end;

function TRSFixedStack.DoPush:ptr;
begin
  result:=WholePush(FItemSize);
end;

function TRSFixedStack.DoPop:ptr;
begin
  result:=WholePop(FItemSize);
end;

function TRSFixedStack.DoPeak:ptr;
begin
  result:=pchar(FBlock)+FLastSize-FItemSize;
end;

function TRSFixedStack.DoPeakAtIndex(index:int):ptr;
begin
  Inc(index);
  result:=DoPeakAt(index*FItemSize);
end;

procedure TRSFixedStack.Peak(var v; Count:int);
begin
  DoPeak(v, Count*FItemSize);
end;

procedure TRSFixedStack.PeakAll(var v);
begin
  DoPeak(v, Size);
end;

function TRSFixedStack.GetCount:int;
begin
  result:= Size div FItemSize;
end;

{
********************************* TRSObjStack **********************************
}

constructor TRSObjStack.Create(BlockSize:int=4096);
begin
  inherited Create(sizeof(TObject), BlockSize);
end;

procedure TRSObjStack.Push(Obj:TObject);
begin
  pptr(WholePush(FItemSize))^:=Obj;
end;

function TRSObjStack.Pop:TObject;
begin
  result:=pptr(WholePop(FItemSize))^;
end;

function TRSObjStack.Peak:TObject;
begin
  result:=pptr(DoPeak)^;
end;

function TRSObjStack.PeakAt(index:int):TObject;
begin
  Inc(index);
  result:=pptr(DoPeakAt(index*sizeof(TObject)))^;
end;

(*
{
******************************** TRSCustomQueue ********************************
}

constructor TRSCustomQueue.Create(ItemSize:int; BlockSize:int=4096);
begin
  inherited;
  FFillEvent:= CreateEvent(nil, true, false, nil);
  FCount:= 0;
end;

destructor TRSCustomQueue.Destroy;
begin
  CloseHandle(FFillEvent);
  inherited;
end;

function TRSCustomQueue.DoPop: ptr;
begin
  if FCount<>FPopCount then
  begin
    inc(FPopCount);

  end else
    Result:= nil;
end;

function TRSCustomQueue.AfterPush: ptr;
begin
  inc(FCount);
  SetEvent(FFillEvent);
end;

function TRSCustomQueue.GetCount: int;
begin
  Result:= FCount - FPopCount;
end;

procedure TRSCustomQueue.WaitFor(var Queue:TRSCustomQueue);
begin
  while (self = Queue) and (FCount = FPopCount) do
    WaitForSingleObject(FFillEvent, INFINITE);
end;

{
********************************* TRSObjQueue **********************************
}

constructor TRSObjQueue.Create(BlockSize: int);
begin

end;

function TRSObjQueue.Peak: TObject;
begin

end;

function TRSObjQueue.PeakAt(Index: int): TObject;
begin

end;

function TRSObjQueue.Pop: TObject;
begin

end;

procedure TRSObjQueue.Push(Obj: TObject);
begin

end;

*)

{
******************************** TRSSharedData *********************************
}

constructor TRSSharedData.Create(Name:string; Size:int);
begin
  FSize:=Size;
  FMMF:= RSWin32Check(CreateFileMapping(INVALID_HANDLE_VALUE, nil,
                        PAGE_READWRITE, 0, Size, ptr(Name)));
  FAlreadyExists:= GetLastError = ERROR_ALREADY_EXISTS;
  FData:= RSWin32Check(MapViewOfFile(FMMF, FILE_MAP_ALL_ACCESS, 0, 0, 0));
end;

constructor TRSSharedData.Create(MMF:THandle; Size:int);
begin
  FSize:=Size;
  FMMF:=MMF;
  FAlreadyExists:= true;
  FData:= RSWin32Check(MapViewOfFile(MMF, FILE_MAP_ALL_ACCESS, 0, 0, 0));
end;

destructor TRSSharedData.Destroy;
begin
  UnmapViewOfFile(FData);
  CloseHandle(FMMF);
  inherited;
end;

{
********************************* TRSFindFile **********************************
}

constructor TRSFindFile.Create(FileMask:string);
begin
  FPath:= ExtractFilePath(FileMask);
  FHandle:= FindFirstFile(ptr(FileMask), Data);
  FFound:= FHandle<>INVALID_HANDLE_VALUE;
  if not Found then
    CheckError;
end;

destructor TRSFindFile.Destroy;
begin
  FindClose(FHandle);
  inherited;
end;

procedure TRSFindFile.CheckError;
begin
  case GetLastError of
    ERROR_FILE_NOT_FOUND, ERROR_PATH_NOT_FOUND, ERROR_NO_MORE_FILES: ;
    else  RSRaiseLastOSError;
  end;
end;

function TRSFindFile.FindNext: boolean;
begin
  FNotFirst:= true;
  FFileName:='';
  result:= FindNextFile(FHandle, Data);
  FFound:= result;
  if not result then
    CheckError;
end;

function TRSFindFile.FindNextAttributes(Require, Exclude: DWord): boolean;
begin
  if FNotFirst then
    FindNext;
  FNotFirst:= true;
  result:= FindAttributes(Require, Exclude);
end;

function TRSFindFile.FindAttributes(Require, Exclude: DWord): boolean;
var bits:DWord;
begin
  bits:= Require or Exclude;
  while Found and ((Data.dwFileAttributes and bits) <> Require) do
    FindNext;
  result:=Found;
end;

function TRSFindFile.GetFileName: string;
begin
  if Found and (FFileName = '') then
    FFileName:= Path + Data.cFileName;
  result:= FFileName;
end;

{
********************************* TRSEventHook *********************************
}

constructor TRSEventHook.Create(Priority:int);
var Obj:TRSEventHook; NewMethod:TMethod;
begin
  inherited Create;
  FPriority:=Priority;

  NewMethod.Data:=self;
  NewMethod.Code:=FEventProc;
  FLastProc:=ObjEvent;
  Obj:=nil;
  while FLastProc.Code = NewMethod.Code do
  begin
    Obj:=FLastProc.Data;
    FLastProc:=Obj.FLastProc;
    if Obj.FPriority<=Priority then
      break;
  end;
  if Obj<>nil then
  begin
    FNext:=Obj;
    Obj.FLastProc:=NewMethod;
    if FLastProc.Code = NewMethod.Code then
      TRSEventHook(FLastProc.Data).FNext:=self;
  end else
    SetEvent(NewMethod);
end;

procedure TRSEventHook.Delete;
begin
  if FDeleting then exit;
  FDeleting:=true;

  if FNext<>nil then
    FNext.FLastProc:=FLastProc
  else
    if ObjEvent.Data<>self then
      exit
    else
      ObjEvent:=FLastProc;

  if FLastProc.Code = FEventProc then
    TRSEventHook(FLastProc.Data).FNext:=FNext;
  Lock(false);
end;

procedure TRSEventHook.Lock(aLock:boolean);
begin
  if self=nil then exit;
  if not aLock then
  begin
    Dec(FLockCount);
    if FLockCount<0 then
      Free;
  end else
    Inc(FLockCount);
end;

function TRSEventHook.GetLast:TRSEventHook;
begin
  result:=FLastProc.Data;
  if FLastProc.Code<>FEventProc then
    result:=nil;
end;


{
***************************** TRSShellChangeNotifier *****************************
}

constructor TRSShellChangeNotifier.Create(OnChange: TNotifyEvent = nil);
begin
  FOnChange:= OnChange;
  InitializeCriticalSection(FCS);
  inherited Create(false);
end;

destructor TRSShellChangeNotifier.Destroy;
begin
  FreeOnTerminate:= false;
  Terminate;
  DeleteCriticalSection(FCS);
  inherited Destroy;
end;

procedure TRSShellChangeNotifier.Free;
begin
  if self=nil then  exit;
  if FWakeEvent <> 0 then
  begin
    EnterCriticalSection(FCS);
    try
      if FWakeEvent <> 0 then
      begin
        FreeOnTerminate:=true;
        Terminate;
        exit;
      end;
    finally
      LeaveCriticalSection(FCS);
    end;
  end;
  Destroy;
end;

procedure TRSShellChangeNotifier.Terminate;
begin
  if not Terminated then
  begin
    inherited Terminate;
    if FWakeEvent <> 0 then
      SetEvent(FWakeEvent);
  end;
end;

procedure TRSShellChangeNotifier.Execute;
var
  WaitHandle: integer; Handles: array[0..1] of integer;
begin
  try
    FWakeEvent:= CreateEvent(nil, false, false, nil);
    Handles[0]:= FWakeEvent;
    while true do
    begin
      WaitHandle:= ERROR_INVALID_HANDLE;
      while true do
      begin
        if Terminated then  exit;
        EnterCriticalSection(FCS);
        try
          FReset:= false;
          if FDirectory<>'' then
            WaitHandle:= FindFirstChangeNotification(pchar(FDirectory),
               LongBool(FWatchSubTree), FFlags);
        finally
          LeaveCriticalSection(FCS);
        end;
        
        if WaitHandle <> ERROR_INVALID_HANDLE then  break;
        if WaitForSingleObject(FWakeEvent, INFINITE) = WAIT_FAILED then
          exit;
      end;
      Handles[1] := WaitHandle;
      case WaitForMultipleObjects(2, @Handles, false, INFINITE) of
        WAIT_OBJECT_0:
          FindCloseChangeNotification(WaitHandle);

        WAIT_OBJECT_0 + 1:
          if not Terminated and not FReset and TryEnterCriticalSection(FCS) then
          begin
            FNeedRefresh:=true;
            LeaveCriticalSection(FCS);
            Synchronize(CallOnChange);
            FindNextChangeNotification(WaitHandle);
          end else
            FindCloseChangeNotification(WaitHandle);

        WAIT_FAILED:
        begin
          FindCloseChangeNotification(WaitHandle);
          if WaitForSingleObject(FWakeEvent, INFINITE) = WAIT_FAILED then
            exit;
        end;
      end;
    end;
  finally
    EnterCriticalSection(FCS);
    CloseHandle(FWakeEvent);
    FWakeEvent:= 0;
    LeaveCriticalSection(FCS);
  end;
end;

procedure TRSShellChangeNotifier.CallOnChange;
var b:boolean;
begin
  b:=FNeedRefresh;
  FNeedRefresh:=false;
  if b and not FReset and Assigned(FOnChange) then
    FOnChange(self);
end;

procedure TRSShellChangeNotifier.SetOptions(Directory: string;
  WatchSubTree: boolean; Flags: DWord);
begin
  EnterCriticalSection(FCS);
  try
    FReset:= true;
    if FWakeEvent<>0 then  SetEvent(FWakeEvent);
    FDirectory:= Directory;
    FWatchSubTree:= WatchSubTree;
    FFlags:= Flags;
  except
    ptr(FDirectory):=nil;
    LeaveCriticalSection(FCS);
    raise;
  end;
  LeaveCriticalSection(FCS);
end;

procedure TRSShellChangeNotifier.Cancel;
begin
  SetOptions('', false, 0);
end;

procedure TRSShellChangeNotifier.Reset;
begin
  EnterCriticalSection(FCS);
  FReset:= true;
  if FWakeEvent<>0 then  SetEvent(FWakeEvent);
  LeaveCriticalSection(FCS);
end;

function TRSShellChangeNotifier.GetNeedRefresh: boolean;
begin
  result:= FNeedRefresh and not FReset;
end;

{---------------------------------------------------------------------}

procedure RaiseLastOSErrorAt(Offset:pchar);
var
  LastError: integer;
  Error: EOSError;
begin
  LastError := GetLastError;
  if LastError <> 0 then
    Error := EOSError.CreateResFmt(@SOSError, [LastError,
      SysErrorMessage(LastError)])
  else
    Error := EOSError.CreateRes(@SUnkOSError);
  Error.ErrorCode := LastError;
  raise Error at Offset;
end;

procedure RSRaiseLastOSError;
asm
  mov eax, [esp]
  sub eax, 5
  jmp RaiseLastOSErrorAt
end;

function RSWin32Check(RetVal: LongBool): LongBool;
asm
  test eax, eax
  jz RSRaiseLastOSError
end;

function RSWin32Check(CheckForZero:int):int;
asm
  test eax, eax
  jz RSRaiseLastOSError
end;

function RSWin32Check(CheckForZero:ptr):ptr;
asm
  test eax, eax
  jz RSRaiseLastOSError
end;

function FindDynaClass(AClass:TClass; DMIndex:int):ptr; register;
asm
  jmp System.@FindDynaClass
end;

procedure RSDispatchEx(Obj:TObject; AClass:TClass; var message);
var a:TMethod;
begin
  a.Data:=Obj;
  try
    a.Code:= FindDynaClass(AClass, word(message));
  except
    Obj.DefaultHandler(message);
    exit;
  end;
  TWndMethod(a)(TMessage(message));
end;

 // From Grids.pas
procedure RSFillDWord(Dest:ptr; Count, Value: integer); register;
asm
  XCHG  EDX, ECX
  PUSH  EDI
  MOV   EDI, EAX
  MOV   EAX, EDX
  REP   STOSD
  POP   EDI
end;


function RSQueryPerformanceCounter: int64;
begin
  RSWin32Check(QueryPerformanceCounter(result));
end;

function RSQueryPerformanceFrequency: int64;
begin
  RSWin32Check(QueryPerformanceFrequency(result));
end;


{
procedure RSSetLayeredAttribs(Handle:HWnd;
             AlphaBlend:boolean; AlphaBlendValue:byte;
             TransparentColor:boolean; TransparentColorValue:int);
const
  cUseAlpha: array [Boolean] of Integer = (0, LWA_ALPHA);
  cUseColorKey: array [Boolean] of Integer = (0, LWA_COLORKEY);
var
  Style: Integer;
begin
  if OSVersion.dwMajorVersion<5 then exit;
  Style := GetWindowLong(Handle, GWL_EXSTYLE);
  if AlphaBlend or TransparentColor then
  begin
    if (Style and WS_EX_LAYERED) = 0 then
      SetWindowLong(Handle, GWL_EXSTYLE, Style or WS_EX_LAYERED);
    SetLayeredWindowAttributes(Handle, TransparentColorValue, AlphaBlendValue,
      cUseAlpha[AlphaBlend] or cUseColorKey[TransparentColor]);
  end else
  if (Style and WS_EX_LAYERED) <> 0 then
  begin
    SetWindowLong(Handle, GWL_EXSTYLE, Style and not WS_EX_LAYERED);
    RedrawWindow(Handle, nil, 0, RDW_ERASE or RDW_INVALIDATE or RDW_FRAME or RDW_ALLCHILDREN);
  end;
end;
{}

function RSGetModuleFileName(hModule: HINST = 0):string;
var ss:array[0..MAX_PATH] of char;
begin
  RSWin32Check(GetModuleFileName(hModule, ss, MAX_PATH+1));
  result:= pchar(@ss[0]);
end;

function RSFileExists(const FileName: string): boolean; {$IFDEF D2005}inline;{$ENDIF}
begin
  result:= RSQ.FileExists(FileName);
end;

function RSMoveFile(const OldName, NewName: string; FailIfExists: boolean): Bool;
begin
  if not FailIfExists and FileExists(OldName) then
  begin
    //FileSetReadOnly(NewName, false);
    DeleteFile(ptr(NewName));
  end;
  result:= MoveFile(ptr(OldName), ptr(NewName));
end;

function RSCreateFile(const FileName:string; dwDesiredAccess:DWord;
           dwShareMode:DWord;
           lpSecurityAttributes:PSecurityAttributes;
           dwCreationDistribution, dwFlagsAndAttributes:DWord;
           hTemplateFile:HFile):HFile;
begin
  if ((dwCreationDistribution =CREATE_ALWAYS)
     or (dwCreationDistribution = CREATE_NEW)
     or (dwCreationDistribution = OPEN_ALWAYS))
     and not RSCreateDir(ExtractFilePath(FileName)) then
  begin
    result:=INVALID_HANDLE_VALUE;
  end else
    result:=CreateFile(pchar(FileName), dwDesiredAccess, dwShareMode,
     lpSecurityAttributes, dwCreationDistribution, dwFlagsAndAttributes,
     hTemplateFile);
end;

function RSLoadFile(FileName:string):TRSByteArray;
var f:hfile; i:DWord;
begin
  f:=RSCreateFile(FileName, GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING,
                   FILE_ATTRIBUTE_NORMAL or FILE_FLAG_SEQUENTIAL_SCAN);
  if f=INVALID_HANDLE_VALUE then RSRaiseLastOSError;
  try
    i:=GetFileSize(f,nil);
    if i=DWord(-1) then RSRaiseLastOSError;
    SetLength(result,i);
    if (i<>0) and (DWord(FileRead(f,result[0],i))<>i) then RSRaiseLastOSError;
  finally
    FileClose(f);
  end;
end;

function RSLoadTextFile(FileName:string):string;
var f:hfile; i:DWord;
begin
  f:=RSCreateFile(FileName, GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING,
                   FILE_ATTRIBUTE_NORMAL or FILE_FLAG_SEQUENTIAL_SCAN);
  if f=INVALID_HANDLE_VALUE then RSRaiseLastOSError;
  try
    i:=GetFileSize(f,nil);
    if i=DWord(-1) then RSRaiseLastOSError;
    SetLength(result,i);
    if (i<>0) and (DWord(FileRead(f,result[1],i))<>i) then RSRaiseLastOSError;
  finally
    FileClose(f);
  end;
end;

procedure DoSaveFile(FileName:string; var Data; L:int);
var f:HFile;
begin
  //FileSetReadOnly(FileName, false);
  f:=RSCreateFile(FileName, GENERIC_WRITE);
  if f=INVALID_HANDLE_VALUE then RSRaiseLastOSError;
  try
    if (L<>0) and (FileWrite(f,Data,L)<>L) then  RSRaiseLastOSError;
  finally
    FileClose(f);
  end;
end;

procedure RSSaveFile(FileName:string; Data:TRSByteArray);
begin
  DoSaveFile(FileName, Data[0], Length(Data));
end;

procedure RSSaveFile(FileName:string; Data:TMemoryStream; RespectPosition: boolean = false);
var
  pos: Int64;
begin
  if RespectPosition then
  begin
    pos:= Data.Position;
    DoSaveFile(FileName, (pchar(Data.Memory) + pos)^, Data.Size - pos);
  end else
    DoSaveFile(FileName, Data.Memory^, Data.Size);
end;

procedure RSSaveTextFile(FileName:string; Data:string);
begin
  DoSaveFile(FileName, Data[1], Length(Data));
end;

procedure DoAppendFile(FileName:string; var Data; L:int);
var f:hfile;
begin
  FileSetReadOnly(FileName, false);
  f:=RSCreateFile(FileName, GENERIC_WRITE, 0, nil, OPEN_ALWAYS);
  if f=INVALID_HANDLE_VALUE then RSRaiseLastOSError;
  try
    if (L<>0) and ((FileSeek(f, 0, 2) = -1) or (FileWrite(f,Data,L) <> L)) then
      RSRaiseLastOSError;
  finally
    FileClose(f);
  end;
end;

procedure RSAppendFile(FileName:string; Data:TRSByteArray);
begin
  DoAppendFile(FileName, Data[0], Length(Data));
end;

procedure RSAppendFile(FileName:string; Data:TMemoryStream; RespectPosition: boolean = false);
var
  pos: Int64;
begin
  if RespectPosition then
  begin
    pos:= Data.Position;
    DoAppendFile(FileName, (pchar(Data.Memory) + pos)^, Data.Size - pos);
  end else
    DoAppendFile(FileName, Data.Memory^, Data.Size);
end;

procedure RSAppendTextFile(FileName:string; Data:string);
begin
  DoAppendFile(FileName, Data[1], Length(Data));
end;

function RSCreateDir(const PathName:string):boolean;
var s:string;
begin
  result:=(PathName='') or DirectoryExists(PathName);
  if result then exit;
  s:= ExtractFilePath(ExcludeTrailingPathDelimiter(ExpandFileName(PathName)));
  result:= (s = PathName) or RSCreateDir(s) and CreateDir(PathName);
end;

function RSCreateDirectory(const PathName:string;
           lpSecurityAttributes:PSecurityAttributes):boolean;
begin
  result:=RSCreateDir(
            ExtractFilePath(ExcludeTrailingPathDelimiter(PathName)));
  if result then
    result:=CreateDirectory(pchar(PathName), lpSecurityAttributes);
end;

function RSCreateDirectoryEx(const lpTemplateDirectory, NewDirectory:string;
   lpSecurityAttributes:PSecurityAttributes = nil):boolean;
begin
  result:=RSCreateDir(
         ExtractFilePath(ExcludeTrailingPathDelimiter(NewDirectory)));
  if result then
    result:=CreateDirectoryEx(ptr(lpTemplateDirectory),
              ptr(NewDirectory), lpSecurityAttributes);
end;

function RSRemoveDir(const Dir:string):boolean;
begin
  result:=RSFileOperation(Dir, '', FO_DELETE);
end;

function DoubleNull(const s:string):string;
begin
  if s <> '' then
    SetString(result, pchar(ptr(s)), Length(s))
  else
    result:= '';
end;

function NullArray(const a:array of string):string;
var i,j,k:int;
begin
  j:=0;
  for i:=High(a) downto Low(a) do
    if a[i]<>'' then
      Inc(j, Length(a[i])+1);
  SetLength(result, j);
  if j=0 then exit;
  j:=1;
  for i:=High(a) downto Low(a) do
    if a[i]<>'' then
    begin
      k:=Length(a[i])+1;
      CopyMemory(@result[j], @a[i][1], k);
      Inc(j, k);
    end;
end;

function RSFileOperation(const aFrom, aTo:string; FileOperation: uint;
 Flags: FILEOP_FLAGS = FOF_NOCONFIRMATION or FOF_NOCONFIRMMKDIR or FOF_NOERRORUI or FOF_SILENT):boolean; overload;
var a:TSHFileOpStruct; s, s1:string;
begin
  s:= DoubleNull(aFrom);
  if FileOperation <> FO_DELETE then
    s1:= DoubleNull(aTo);

  with a do
  begin
    Wnd:=0;
    wFunc:=FileOperation;
    pFrom:=ptr(s);
    pTo:=ptr(s1);
    fFlags:=Flags and not (FOF_MULTIDESTFILES or FOF_WANTMAPPINGHANDLE);
    fAnyOperationsAborted:=false;
    hNameMappings:=nil;
    lpszProgressTitle:=nil;
  end;
  result:= SHFileOperation(a)=0;
end;

function RSFileOperation(const aFrom, aTo: array of string; FileOperation: uint;
   Flags: FILEOP_FLAGS = FOF_NOCONFIRMATION or FOF_NOCONFIRMMKDIR or
          FOF_NOERRORUI or FOF_SILENT) : boolean; overload;
var a:TSHFileOpStruct; s, s1:string;
begin
  s:= NullArray(aFrom);
  if FileOperation <> FO_DELETE then
    s1:= NullArray(aTo);

  with a do
  begin
    Wnd:=0;
    wFunc:=FileOperation;
    pFrom:=ptr(s);
    pTo:=ptr(s1);
    fFlags:=Flags and not FOF_WANTMAPPINGHANDLE;
    fAnyOperationsAborted:=false;
    hNameMappings:=nil;
    lpszProgressTitle:=nil;
  end;
  result:= SHFileOperation(a)=0;
end;

function RSSearchPath(Path, FileName, Extension:string):string;
var
  Buffer: array[0..MAX_PATH] of char;
  i:int; p:pchar;
begin
  i:= SearchPath(ptr(Path), ptr(FileName), ptr(Extension), MAX_PATH + 1, @Buffer, p);
  RSWin32Check(i);
  if i <= MAX_PATH + 1 then
  begin
    SetLength(result, i - 1);
    if result<>'' then
      Move(Buffer, result[1], i - 1);
  end else
  begin
    SetLength(result, i - 1);
    i:= SearchPath(ptr(Path), ptr(FileName), ptr(Extension), 0, ptr(result), p);
    RSWin32Check(i);
  end;
end;

procedure RSCopyStream(Dest, Source: TStream; Count: int64);
var
  i: int64;
begin
  if (Source is TCustomMemoryStream) and (zSet(i, Source.Position) + Count < Source.Size) then
  begin
    Dest.WriteBuffer((pchar(TCustomMemoryStream(Source).Memory) + i)^, Count);
    Source.Seek(Count, soCurrent);
  end else
    if Dest is TMemoryStream then
      with TMemoryStream(Dest) do
      begin
        i:= Position;
        if i + Count > Size then
          Size:= i + Count;
        Source.ReadBuffer((pchar(Memory) + UintPtr(i))^, Count);
        Seek(Count, soCurrent);
      end
    else
      Dest.CopyFrom(Source, Count);
end;

{----------------------- RSLoadProc --------------------------}

function DoLoadProc(var Proc:pointer; const LibName:string; ProcName:pointer;
   LoadLib:boolean):hInst; overload;
var p:ptr;
begin
  if LoadLib then
    result:= LoadLibrary(ptr(LibName))
  else
    result:= GetModuleHandle(ptr(LibName));

  if result<>0 then
  begin
    p:=GetProcAddress(result, ProcName);
    if p = nil then
    begin
      if LoadLib then  FreeLibrary(result);
      result:=0;
    end else
      Proc:=p;
  end;
end;

function RSLoadProc(var Proc:pointer; const LibName, ProcName:string;
   LoadLib:boolean = true):hInst; overload;
begin
  result:=DoLoadProc(Proc, LibName, ptr(ProcName), LoadLib);
end;

function RSLoadProc(var Proc:pointer; const LibName:string; ProcIndex:word;
   LoadLib:boolean = true):hInst; overload;
begin
  result:=DoLoadProc(Proc, LibName, ptr(ProcIndex), LoadLib);
end;

function RSLoadProc(var Proc:pointer; const LibName, ProcName:string;
   LoadLib:boolean; RaiseException:boolean):hInst; overload;
begin
  result:=DoLoadProc(Proc, LibName, ptr(ProcName), LoadLib);
  if (result=0) and RaiseException then
    raise Exception.Create(Format(sRSCantLoadProc, [ProcName, LibName]));
end;

function RSLoadProc(var Proc:pointer; const LibName:string; ProcIndex:word;
   LoadLib:boolean; RaiseException:boolean):hInst; overload;
begin
  result:=DoLoadProc(Proc, LibName, ptr(ProcIndex), LoadLib);
  if (result=0) and RaiseException then
    raise Exception.Create(Format(sRSCantLoadIndexProc, [ProcIndex, LibName]));
end;

{---------------------- RSDelayLoad ---------------------}

type
  PDelayedImport = ^TDelayedImport;
  TDelayedImport = packed record
    Call: byte;
    Adress: pointer;
    State: byte;
    Proc: PPointer;
    LibN: string;
    ProcN: pointer;
    Module: hInst;
  end;

const
  DelaySize = PageSize;
  DINamed = 1;
  DILoadLib = 2;

var
  Delays: TRSFixedStack;
  DelaysOnClose: procedure;

 // Returns the address to call
function DelayProc(var Import:TDelayedImport):pointer;
var h:hInst;
begin
  with Import do
    if Proc^=@Import then
    begin
      if State and DINamed <> 0 then
        h:=RSLoadProc(Proc^, LibN, string(ProcN), State and DILoadLib <> 0,true)
      else
        h:=RSLoadProc(Proc^, LibN, word(ProcN), State and DILoadLib <> 0, true);

      h:= InterlockedExchange(int(Module), h);
      if h<>0 then  FreeLibrary(h);
    end;
  result:= Import.Proc^;
end;

procedure DelayAsmProc;
asm
   // Stack: <TDelayData adress + 5> <return adress> <proc params>
  xchg [esp], eax
  push ecx
  push edx

  add eax, -5
  call DelayProc

  pop edx
  pop ecx
  xchg [esp], eax
   // Stack: <loaded proc adress> <return adress> <proc params>
end;

procedure FreeDelayImports; forward;

procedure DoDelayLoad(var ProcAddress:pointer; const LibName:string;
                      ProcName:pointer; LoadLib:boolean; ANamed:boolean);
begin
  if Delays=nil then
  begin
    Delays:=TRSFixedStack.Create(sizeof(TDelayedImport), DelaySize);
    if IsLibrary then  DelaysOnClose:=@FreeDelayImports;
  end;

  ProcAddress:=Delays.DoPush;
  with PDelayedImport(ProcAddress)^ do
  begin
    MakeCall(ProcAddress, @DelayAsmProc);
    Proc:= @ProcAddress;
    ptr(LibN):=nil;
    LibN:= LibName;
    ProcN:= ProcName;
    Module:= 0;
    State:= BoolToInt[ANamed]*DINamed + BoolToInt[LoadLib]*DILoadLib;
  end;
end;

procedure RSDelayLoad(var ProcAddress:pointer; const LibName, ProcName:string;
   LoadLib:boolean = true);
var s:string;
begin
  s:=ProcName;
  DoDelayLoad(ProcAddress, LibName, ptr(s), LoadLib, true);
  pointer(s):=nil;
end;

procedure RSDelayLoad(var ProcAddress:pointer; const LibName:string;
  ProcIndex:word; LoadLib:boolean = true);
begin
  DoDelayLoad(ProcAddress, LibName, ptr(ProcIndex), LoadLib, false);
end;

procedure FreeDelayImports;
var p:PDelayedImport;
begin
  p:=Delays.DoPop;
  repeat
    with p^ do
    begin
      LibN:='';
      if State and DINamed <> 0 then
        string(ProcN):='';
      if Module <> 0 then
        FreeLibrary(Module);
    end;
    p:=Delays.DoPop;
  until p=nil;

  FreeAndNil(Delays);
end;

{---------------------- RSMakeLessParamsFunction ---------------------}

procedure ObjectInstanceProc;
asm
  pop eax
  pop edx // Return address
  push [eax + 4] // Param
  push edx // Return address
  jmp [eax]
end;

procedure ObjectInstanceProcRegisterSmall;
asm
  mov ecx, edx
  mov edx, eax
  pop eax
  push [eax] // Return address
  mov eax, [eax+4] // Param
end;

{
procedure ObjectInstanceProcRegisterBig;
asm
  xchg ecx, [esp+4]
  xchg ecx, [esp]
  xchg edx, ecx
  xchg eax, edx
  push [eax] // Return address
  mov eax, [eax+4] // Param
end;
}

procedure RSMakeObjectInstance(var ObjInst:TRSObjectInstance;
   Obj, ProcStdCall:ptr);
begin
  MakeCall(@ObjInst.Code, @ObjectInstanceProc);
  ObjInst.Proc:=ProcStdCall;
  ObjInst.Obj:=Obj;
end;

procedure RSCustomObjectInstance(var ObjInst:TRSObjectInstance;
             Obj, Proc, CustomProc:ptr);
begin
  MakeCall(@ObjInst.Code, CustomProc);
  ObjInst.Proc:=Proc;
  ObjInst.Obj:=Obj;
end;

function RSMakeLessParamsFunction(
   ProcStdCall:pointer; Param:ptr):pointer; overload;
begin
  GetMem(result, sizeof(TRSObjectInstance));
  RSMakeObjectInstance(TRSObjectInstance(result^), ProcStdCall, Param);
end;

procedure LessParamsProc;
asm
  pop eax
  
// EAX structure:
//  Params Count
//  Proc address
//  Params...

  mov ecx, [eax] // Count
  add eax, 4 // Skip Count
   // Don't skip Proc address, ecx*4 will skip it
  pop edx // Return address

@loop:
  push [eax + ecx*4]
  Dec ecx
  jz @loop

  push edx // Return address
  jmp [eax]
end;

function RSMakeLessParamsFunction(
            ProcStdCall:pointer; DWordParams:pointer;
            Count:int; ResultInParam:int=-1):pointer; overload;
var i:integer; n:int; p:pptr;
begin
  if (ResultInParam>=0) and (ResultInParam<=Count) then
    n:=Count+1
  else
    n:=Count;
  GetMem(result, 5+8 + 4*n);
  p:=MakeCall(result, @LessParamsProc);
  p^:=ptr(Count);
  Inc(p);
  p^:=ProcStdCall;
  Inc(p);

  for i:=0 to Count-1 do
  begin
    if ResultInParam=i then
    begin
      p^:=result;
      Inc(p);
    end;
    p^:=pptr(DWordParams)^;
    Inc(p);
    Inc(pptr(DWordParams));
  end;
  
  if ResultInParam=Count then p^:=result;
end;

{
function RSMakeLessParamsFunction(
            ProcStdCall:pointer; DWordParams:Pointer;
            Count:integer; ResultInParam:integer=-1):Pointer; overload;
const First=$58;    // POP EAX
      Loop=$68;     // PUSH DWordParams[i]
      Middle=$B850; // PUSH EAX
                    // MOV EAX ProcPtr
      Last=$E0FF;   // JMP EAX
      EdgesSize = SizeOf(First) + SizeOf(Middle) + SizeOf(Last) + 4;
      LoopSize = SizeOf(Loop) + 4;

var p:Pointer;

  procedure AddParam(const i:DWord);
  begin
    PByte(p)^:=Loop;
    inc(PByte(p));
    PDWord(p)^:=i;
    inc(PDWord(p));
  end;

var i:integer; n:DWord;
begin
  if (ResultInParam>=0) and (ResultInParam<=Count) then n:=Count+1
  else n:=Count;
  i:= EdgesSize + LoopSize*n;
  GetMem(p,i);
  Result:=p;
  if Result=nil then exit;
  PByte(p)^:=First;
  inc(PByte(p));
  DWordParams:=pointer(DWord(DWordParams)+Dword(Count)*4);
  if ResultInParam=Count then AddParam(DWord(Result));
  for i:=Count-1 downto 0 do
  begin
    dec(PDWord(DWordParams));
    AddParam(PDWord(DWordParams)^);
    if ResultInParam=i then AddParam(DWord(Result));
  end;
  PWord(p)^:=Middle;
  inc(PWord(p));
  PPointer(p)^:=ProcStdCall;
  inc(PPointer(p));
  PWord(p)^:=Last;
//  inc(PWord(p));
end;
}

function RSMakeLessParamsFunction(
            ProcStdCall:pointer; const DWordParams:array of DWord;
            ResultInParam:integer=-1):pointer; overload;
begin
  result:=RSMakeLessParamsFunction(
                  ProcStdCall, @DWordParams[Low(DWordParams)],
                  High(DWordParams)-Low(DWordParams)+1, ResultInParam);
end;

procedure RSFreeLessParamsFunction(Ptr:pointer);
begin
  FreeMem(Ptr);
end;

{
procedure ReplaceIATEntryInOneMod(PCSTR pszCalleeModName,
   PROC pfnCurrent, PROC pfnNew, HMODULE hmodCaller)
var Size:uint; pImportDesc:PIMAGE_IMPORT_DESCRIPTOR;
begin
     = (PIMAGE_IMPORT_DESCRIPTOR)
      ImageDirectoryEntryToData(hmodCaller, TRUE,
      IMAGE_DIRECTORY_ENTRY_IMPORT, &ulSize);

   if (pImportDesc == NULL)
      return;  // This module has no import section.

   for (; pImportDesc->Name; pImportDesc++) begin
      PSTR pszModName = (PSTR)
         ((PBYTE) hmodCaller + pImportDesc->Name);
      if (lstrcmpiA(pszModName, pszCalleeModName) == 0)
         break;
   end;

   if (pImportDesc->Name == 0)
      return;

   PIMAGE_THUNK_DATA pThunk = (PIMAGE_THUNK_DATA)
      ((PBYTE) hmodCaller + pImportDesc->FirstThunk);

   for (; pThunk->u1.Function; pThunk++) begin

      PROC* ppfn = (PROC*) &pThunk->u1.Function;

      BOOL fFound = ( *ppfn == pfnCurrent);

      if (fFound) begin
         // The addresses match; change the import section address.
         WriteProcessMemory(GetCurrentProcess(), ppfn, &pfnNew,
            sizeof(pfnNew), NULL);
         return;  // We did it; get out.
      end;
   end;
end;
}

{----------------------- TokenPrivileges --------------------------}

function RSEnableTokenPrivilege(TokenHandle:THandle; const Privilege:string;
  Enable:boolean):boolean;
var
  Priv: TTokenPrivileges;
begin
  Priv.PrivilegeCount:= 1;
  if Enable then
    Priv.Privileges[0].Attributes:= SE_PRIVILEGE_ENABLED
  else
    Priv.Privileges[0].Attributes:= 0;

  result:=
    LookupPrivilegeValue(nil, pchar(Privilege), Priv.Privileges[0].Luid) and
    AdjustTokenPrivileges(TokenHandle, false, Priv, 0, nil, DWord(nil^));
end;

function RSEnableProcessPrivilege(hProcess:THandle; const Privilege:string;
  Enable:boolean):boolean;
var
  TokenHandle:THandle; i:DWord;
begin
  result:= OpenProcessToken(hProcess, TOKEN_ADJUST_PRIVILEGES, TokenHandle);
  if result then
    try
      result:= RSEnableTokenPrivilege(TokenHandle, Privilege, Enable);
    finally
      i:=GetLastError;
      CloseHandle(TokenHandle);
      SetLastError(i);
    end;
end;

function RSEnableDebugPrivilege(Enable:boolean):boolean;
const
  Priv = 'SeDebugPrivilege';
begin
  result:= RSEnableProcessPrivilege(GetCurrentProcess, Priv, Enable);
end;

{----------------------- RSCreateRemoteCopy --------------------------}

function RSCreateRemoteCopy(CurPtr:pointer; var RemPtr:pointer;
                      Len, hProcess:DWord; var Mapping:DWord):boolean;
begin
  result:=false;
  if OSVersion.dwPlatformId = VER_PLATFORM_WIN32_WINDOWS then
  begin // Win 9x
    Mapping:=CreateFileMapping(INVALID_HANDLE_VALUE, nil,
                                     PAGE_READWRITE, 0, Len, nil);
    if Mapping=0 then exit;
    RemPtr:=MapViewOfFile(Mapping,FILE_MAP_ALL_ACCESS,0,0,0);
    if RemPtr=nil then
    begin
      CloseHandle(Mapping);
      exit;
    end;
    Move(CurPtr^,RemPtr^,Len);
    result:=true;
  end else
  begin // Win NT
    if hProcess=0 then exit;
    Mapping:=0;
    RemPtr:=VirtualAllocEx(hProcess, nil, Len, MEM_COMMIT,
                                   PAGE_EXECUTE_READWRITE);
    if RemPtr=nil then exit;
    result:=WriteProcessMemory(hProcess, RemPtr,
                                       CurPtr, Len, cardinal(nil^));
  end;
end;

function RSCreateRemoteCopyID(CurPtr:pointer; var RemPtr:pointer;
                      Len, ProcessID:DWord; var Mapping:DWord):boolean;
var Pr:DWord;
begin
  if OSVersion.dwPlatformId <> VER_PLATFORM_WIN32_WINDOWS then
    if ProcessID=0 then result:=false
    else begin
      Pr:=OpenProcess(PROCESS_VM_OPERATION or PROCESS_VM_WRITE, false,
         ProcessID);
      result:=RSCreateRemoteCopy(CurPtr, RemPtr, Len, Pr, Mapping);
      if Pr<>0 then CloseHandle(Pr);
    end
  else result:=RSCreateRemoteCopy(CurPtr, RemPtr, Len, 0, Mapping);
end;

function RSCreateRemoteCopyWnd(CurPtr:pointer; var RemPtr:pointer;
                     Len:DWord; wnd:hWnd; var Mapping:DWord):boolean;
var pID, Pr:DWord;
begin
  if OSVersion.dwPlatformId <> VER_PLATFORM_WIN32_WINDOWS then
  begin
    GetWindowThreadProcessId(wnd, pID);
    if pID=0 then result:=false
    else begin
      Pr:=OpenProcess(PROCESS_VM_OPERATION or PROCESS_VM_WRITE,
                         false, pID);
      result:=RSCreateRemoteCopy(CurPtr, RemPtr, Len, Pr, Mapping);
      if Pr<>0 then CloseHandle(Pr);
    end;
  end else result:=RSCreateRemoteCopy(CurPtr, RemPtr, Len, 0, Mapping);
end;

{------------------------- RSFreeRemoteCopy --------------------------}

function RSFreeRemoteCopy(CurPtr, RemPtr:pointer;
                           Len, hProcess, Mapping:DWord):boolean;
begin
  if OSVersion.dwPlatformId = VER_PLATFORM_WIN32_WINDOWS then
  begin // Win 9x
    try
      if Len<>0 then Move(RemPtr^, CurPtr^, Len);
      result:=true;
    except
      result:=false;
    end;
    UnmapViewOfFile(RemPtr);
    CloseHandle(Mapping);
  end else
  begin // Win NT
    if hProcess=0 then
    begin
      result:=false;
      exit;
    end;
    result:=(Len=0) or ReadProcessMemory(hProcess, RemPtr,
                                        CurPtr, Len, cardinal(nil^));
    VirtualFreeEx(hProcess, RemPtr, 0, MEM_RELEASE);
  end;
end;

function RSFreeRemoteCopyID(CurPtr, RemPtr:pointer;
                             Len, ProcessID, Mapping:DWord):boolean;
var Pr:DWord;
begin
  if OSVersion.dwPlatformId <> VER_PLATFORM_WIN32_WINDOWS then
    if ProcessID=0 then result:=false
    else begin
      Pr:=OpenProcess(PROCESS_VM_OPERATION or PROCESS_VM_READ, false,
         ProcessID);
      result:=RSFreeRemoteCopy(CurPtr, RemPtr, Len, Pr, Mapping);
      if Pr<>0 then CloseHandle(Pr);
    end
  else result:=RSFreeRemoteCopy(CurPtr, RemPtr, Len, 0, Mapping);
end;

function RSFreeRemoteCopyWnd(CurPtr, RemPtr:pointer;
                          Len:DWord; wnd:hWnd; Mapping:DWord):boolean;
var pID, Pr:DWord;
begin
  if OSVersion.dwPlatformId <> VER_PLATFORM_WIN32_WINDOWS then
  begin
    GetWindowThreadProcessId(wnd, pID);
    if pID=0 then result:=false
    else begin
      Pr:=OpenProcess(PROCESS_VM_OPERATION or PROCESS_VM_READ,
                       false, pID);
      result:=RSFreeRemoteCopy(CurPtr, RemPtr, Len, Pr, Mapping);
      if Pr<>0 then CloseHandle(Pr);
    end
  end else result:=RSFreeRemoteCopy(CurPtr, RemPtr, Len, 0, Mapping);
end;

{------------------------- SendDataMessage ---------------------------}

type
  TCallback=procedure(hwnd:HWND; uMsg, dwData:DWord; lResult:LRESULT);
  TSendDetails=record
    Process:DWord;
    wMap:DWord;
    wParam:pointer;
    wPtr:pointer;
    wLen:DWord;
    lMap:DWord;
    lParam:pointer;
    lPtr:pointer;
    lLen:DWord;
    Callback:pointer;
    CallData:DWord;
  end;
  PSendDetails=^TSendDetails;

function PrepareDataMessage(var SD:TSendDetails; hWnd:HWnd; var wParam:WParam;
           var lParam:LParam; wDataLength:DWord;
           lDataLength:DWord; wReadOnly:boolean;
           lReadOnly:boolean):boolean;
begin
  result:=false;
  if OSVersion.dwPlatformId<>VER_PLATFORM_WIN32_WINDOWS then
  begin
    SD.Process:=TRSWnd(hWnd).OpenProcess(PROCESS_VM_OPERATION or
                        PROCESS_VM_READ or PROCESS_VM_WRITE, false);
    if SD.Process=0 then exit;
  end else SD.Process:=0; // For compiler

  SD.wParam:=pointer(wParam);
  if wReadOnly then SD.wLen:=0
  else SD.wLen:=wDataLength;
  if wDataLength=0 then SD.wPtr:=nil
  else begin
    if not RSCreateRemoteCopy(pointer(wParam),SD.wPtr,
                              wDataLength, SD.Process, SD.wMap)
    then exit;
    wParam:=DWord(SD.wPtr);
  end;

  SD.lParam:=pointer(lParam);
  if lReadOnly then SD.lLen:=0
  else SD.lLen:=lDataLength;

  if lDataLength=0 then SD.lPtr:=nil
  else begin
    if not RSCreateRemoteCopy(pointer(lParam),SD.lPtr,
          lDataLength, SD.Process, SD.lMap) and (wDataLength<>0) then
    begin
      RSFreeRemoteCopy(SD.wParam, SD.wPtr, 0, SD.Process, SD.wMap);
      exit;
    end;
    lParam:=DWord(SD.lPtr);
  end;

  SD.Callback:=nil;
  result:=true;
end;

function FreeDataMessage(var SD:TSendDetails):boolean;
begin
  with SD do
  begin
    if wPtr<>nil then
      result:=RSFreeRemoteCopy(wParam, wPtr, wLen, Process, wMap)
    else result:=true;
    if lPtr<>nil then
      result:=RSFreeRemoteCopy(lParam, lPtr, lLen, Process, lMap)
                                                         and result;
    if Process<>0 then CloseHandle(Process);
  end;
end;

procedure FreeDataCallback(hwnd:HWND; uMsg, dwData:DWord;
                                            lResult:LRESULT); stdcall;
var SD:PSendDetails;
begin
  SD:=pointer(dwData);
  FreeDataMessage(SD^);
  if SD^.Callback<>nil then
    TCallback(SD^.Callback)(hwnd, uMsg, SD^.CallData, lResult);
  Dispose(SD);
end;

function RSSendDataMessage(hWnd:HWnd; Msg:DWord; wParam:WParam;
           lParam:LParam; var lpdwResult:DWord; wDataLength:DWord=0;
           lDataLength:DWord=0; wReadOnly:boolean=false;
           lReadOnly:boolean=false):boolean;
var SD:TSendDetails;
begin
  result:=PrepareDataMessage(SD, hwnd, wParam, lParam, wDataLength,
                                 lDataLength, wReadOnly, lReadOnly);
  if not result then exit;
  lpdwResult:=SendMessage(hWnd, Msg, wParam, lParam);
  result:=FreeDataMessage(SD);
end;

function RSSendDataMessageTimeout(hWnd:HWnd; Msg:DWord; wParam:WParam;
           lParam:LParam; fuFlags,uTimeout:DWord; var lpdwResult:DWord;
           wDataLength:DWord=0; lDataLength:DWord=0;
           wReadOnly:boolean=false; lReadOnly:boolean=false):boolean;
var SD:PSendDetails;
begin
  New(SD);
  result:=PrepareDataMessage(SD^,hwnd,wParam,lParam,wDataLength,
                                 lDataLength,wReadOnly,lReadOnly);
  if not result then
  begin
    lpdwResult:=0;
    Dispose(SD);
    exit;
  end;
  result:=SendMessageTimeout(hWnd, Msg, wParam, lParam, fuFlags,
                                             uTimeout, lpdwResult)<>0;
  if result then
  begin
    result:=FreeDataMessage(SD^);
    Dispose(SD);
  end else
  begin
    SD.wLen:=0;
    SD.lLen:=0;
    if not SendMessageCallback(hWnd, WM_NULL, 0, 0,
            @FreeDataCallback, DWord(SD)) then
    begin
      FreeDataMessage(SD^);
      Dispose(SD);
    end;
  end;
end;

function RSSendDataMessageCallback(hWnd:HWnd; Msg:DWord; wParam:WParam;
           lParam:LParam; lpCallBack:pointer; dwData:DWord;
           wDataLength:DWord=0; lDataLength:DWord=0;
           wReadOnly:boolean=true; lReadOnly:boolean=true):boolean;
var SD:PSendDetails;
begin
  New(SD);
  result:=PrepareDataMessage(SD^,hwnd,wParam,lParam,wDataLength,
                                 lDataLength,wReadOnly,lReadOnly);
  if not result then
  begin
    Dispose(SD);
    exit;
  end;
  SD^.Callback:=lpCallBack;
  SD^.CallData:=dwData;
  result:=SendMessageCallback(hWnd, Msg, wParam, lParam,
                                 @FreeDataCallback, DWord(SD));
  if not result then
  begin
    SD.wLen:=0;
    SD.lLen:=0;
    FreeDataMessage(SD^);
    Dispose(SD);
  end;
end;

function RSPostDataMessage(hWnd:HWnd; Msg:DWord; wParam:WParam;
           lParam:LParam; wDataLength:DWord=0;
           lDataLength:DWord=0; wReadOnly:boolean=true;
           lReadOnly:boolean=true):boolean;
begin
  result:=RSSendDataMessageCallback(hWnd, Msg, wParam, lParam, nil, 0,
            wDataLength, lDataLength, wReadOnly, lReadOnly);
end;

function RSRunWait(Command:string; Dir:string; Timeout:DWord;
           showCmd:word):boolean;
var
  SI: TStartupInfo; PI: TProcessInformation;
  i:integer;
begin
  FillChar(SI, sizeof(SI), 0);
  FillChar(PI, sizeof(PI), 0);
  SI.cb := sizeof(SI);
  SI.dwFlags:=STARTF_USESHOWWINDOW;
  SI.wShowWindow:=showCmd;
  if not CreateProcess(nil, ptr(Command), nil, nil, false, 0, nil, ptr(Dir), SI, PI) then
    RSRaiseLastOSError;
  CloseHandle(PI.hThread);
  try
    i:= WaitForSingleObject(pi.hProcess, Timeout);
    result:= i=WAIT_OBJECT_0;
    if not result and (i<>WAIT_TIMEOUT) then  RSRaiseLastOSError;
  finally
    CloseHandle(PI.hProcess);
  end;
end;

procedure RSShowException;
begin
  ShowException(ExceptObject, ExceptAddr);
end;

 // Usage: AssertErrorProc:=RSAssertDisable
procedure RSAssertDisable(const message, FileName: string;
    LineNumber: integer; ErrorAddr: pointer);
begin
end;

 // Copied from SysUtils
procedure RaiseAssertException(const E: Exception; const ErrorAddr, ErrorStack: pointer);
asm
        MOV     ESP,ECX
        MOV     [ESP],EDX
        MOV     EBP,[EBP]
        JMP     System.@RaiseExcept
end;

function CreateAssertException(const message, Filename: string;
  LineNumber: integer): Exception;
var
  S: string;
begin
  if message <> '' then S := message else S := SAssertionFailed;
  result := EAssertionFailed.CreateFmt(SAssertError,
    [S, ExtractFileName(FileName), LineNumber]);
end;

 // Usage: AssertErrorProc:=RSAssertErrorHandler
 // Based on SysUtils.AssertErrorHandler
procedure RSAssertErrorHandler(const message, FileName: string;
    LineNumber: integer; ErrorAddr: pointer);
var
  E: Exception;
begin
  E := CreateAssertException(message, Filename, LineNumber);
  RaiseAssertException(E, ErrorAddr, pchar(@ErrorAddr)+4);
end;

function MethodsList(EBP:pointer; FuncSkip:integer):string;
const
  CallInfo=
    'EBP = %p    Return address: %p'#13#10;
  Bug=
    '...'#13#10;
var p,p1:PPtr;
begin
  p:=EBP;
  p1:=p;
  Inc(p1);
  try
    while (p<>nil) and (p^<>p) do
    begin
      if FuncSkip<=0 then
        result:=result+Format(CallInfo, [p, p1^])
      else
        Dec(FuncSkip);
      p:=p^;
      p1:=p;
      Inc(p1);
    end;
  except
    result:=result+Bug; // К сожалению, нередкая ситуация.
  end;
end;

function StackTrace(EBP:pointer; Lim:integer):string;
const
  CallInfo=
    'Call: EBP=%p  RetAddr=%p';
begin

end;

function Registers(Context:PContext):string;
begin
end;

function RSHandleException(FuncSkip:integer=0; TraceLimit:integer=0; EAddr:pointer=nil; EObj:TObject=nil):string;
const
  TextShort=
    'Exception %s in module %s at %p.'#13#10+
    '%s.';
  TextMain=
     TextShort+#13#10+
        #13#10+
    'Absolute address: %p  Allocation base: %p'#13#10+
    'Module: %s  Base address: %p'#13#10;
  TextProc=
        #13#10+
        #13#10+
    'Methods calls:'#13#10+
        #13#10;
  TextStack=
        #13#10+
        #13#10+
    'Stack trace:'#13#10+
        #13#10;

  function ConvertAddr(Address: pointer): pointer;
  asm
    test eax, eax // Always convert nil to nil
    je @exit
    sub eax, $1000 // offset from code start; code start set by linker to $1000
  @exit:
  end;

var
  ModuleName, ModulePath, EText, EName:string;
  Temp:array[0..MAX_PATH] of char;
  Info:TMemoryBasicInformation;
  ConvertedAddress:pointer; p, ModuleBase:pointer;
begin
  if EObj=nil then
  begin
    EObj:=ExceptObject;
    EAddr:=ExceptAddr;
  end;
  //if TraceLimit<=0 then TraceLimit:=MaxInt;
  if VirtualQuery(EAddr, Info, sizeof(Info))=0 then
  begin

  end else
  begin
    if (Info.State <> MEM_COMMIT) or
      (GetModuleFilename(THandle(Info.AllocationBase), Temp, sizeof(Temp)) = 0)
      then
    begin
      ModuleBase:=ptr(HInstance);
      GetModuleFileName(HInstance, Temp, sizeof(Temp));
      ConvertedAddress := ConvertAddr(EAddr);
    end else
    begin
      ModuleBase:=Info.AllocationBase;
      int(ConvertedAddress):=int(EAddr)-int(ModuleBase);
    end;
    ModulePath:=Temp;
    ModuleName:=ExtractFileName(ModulePath);
    if EObj<>nil then
    begin
      EName:=EObj.ClassName;
      if EObj is Exception then
        EText:=Exception(EObj).message;
    end;
    result:=Format(TextMain, [EName, ModuleName, ConvertedAddress, EText,
                    EAddr, Info.AllocationBase, ModulePath, ModuleBase]);

    asm
      mov p, ebp
    end;

    result:= result + TextProc + MethodsList(p, FuncSkip);
    //Result:=Result+TextStack+StackTrace(p,TraceLimit);
  end;
end;

function RSMessageBox(hWnd:hwnd; Text, Caption:string; uType:DWord=0):int;
begin
  result:=MessageBox(hWnd, ptr(Text), ptr(Caption), uType);
end;

{-------------------------------------------------------}

initialization
  OSVersion.dwOSVersionInfoSize:=sizeof(OSVersion);
  GetVersionEx(OSVersion);

finalization
  if @DelaysOnClose<>nil then
    DelaysOnClose;
end.
