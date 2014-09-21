unit RSDebug;

{ *********************************************************************** }
{                                                                         }
{ RSPak                                    Copyright (c) Rozhenko Sergey  }
{ http://sites.google.com/site/sergroj/                                   }
{ sergroj@mail.ru                                                         }
{                                                                         }
{ This file is a subject to any one of these licenses at your choice:     }
{ BSD License, MIT License, Apache License, Mozilla Public License.       }
{                                                                         }
{ *********************************************************************** )

 The trick is based on DebugHook variable.
 Delphi debugger uses it too and may set it to a lower value.
 As a result you may sometimes see a handled exception before the real one in
  a log, but this may happen only if the program is run under Delphi debugger.

{ *********************************************************************** }
{$I RSPak.inc}

interface

uses
  SysUtils, Windows, Messages, RSSysUtils, RSQ, SysConst;


function RSLogExceptions:string;
function RSLogExceptionPointers(const p: TExceptionPointers): string;
procedure RSDebugHook(Activate:boolean = true);
procedure RSDebugUseDefaults(CallTraceLineLimit: int = 100;
  StackTraceLineLimit: int = 200; StackFramesCount: int = 2);


type
  TRSExceptionParams = packed record
    ExceptObj: ptr;
    ExceptAddr: ptr;
    Context: PContext;
    OSException: boolean;
  end;

  PRSStackInfo = ^TRSStackInfo;
  TRSStackInfo = packed record
    FrameStart: ptr;
    FrameStop: ptr;
    NextFrame: ptr;
    StackFrame: ptr;
    ExcFrame: ptr;
    StackTop: ptr;
    FrameIsExcept: boolean;
  end;

  TRSExceptionLogProps = packed record
    HeaderTrace: string;
    RegistersTrace: string;
    FunctionsTrace: string;
    StackTrace: string;
  end;

  TRSFunctionChecks = set of (RSfcReadOnly, RSfcThisModule, RSfcValidCall);

function RSTraceHeader(const Params: TRSExceptionParams):string;
function RSTraceSystemInfo:string;
function RSTraceRegisters(const Params: TRSExceptionParams):string;
function RSTraceFunctionCalls(const Params: TRSExceptionParams):string;
function RSTraceStack(const Params: TRSExceptionParams):string;
function RSLogSingleException(ExcIndex, ExcCount:int;
   var LogProps:TRSExceptionLogProps; var UserData):string;

function RSDefultAddressDetails(Addr:ptr):string;
function RSDefaultTraceCall(StackAddr, CallAddr:ptr; TraceIndex:int; NoFrame:boolean):string;
function RSDefaultStackTrace(StackAddr, Data:ptr; TraceIndex:int; const Comment:string):string;
function RSDefaultStackTraceCall(StackAddr, CallAddr:ptr; TraceIndex:int; NoFrame:boolean):string;
procedure RSDefaultEndTrace(var Log:string; TraceCount:int; Cropped:boolean);

function RSCreateStackInfo(const Context:TContext):TRSStackInfo;
function RSStackInfoNextFrame(var StackInfo:TRSStackInfo):boolean;

function RSValidRetAddr(Addr:ptr; Checks:TRSFunctionChecks):boolean;

// Make sure that the code address is a valid call site
// Returns the size of CALL instruction or 0.
// From JclDebug, slightly modified
function RSValidCallSite(CodeAddr:pointer):integer;

function RSIsSecondaryException: boolean;

type
  TRSDebugOptions = packed record
    OnTraceHeader:  function(const Params: TRSExceptionParams):string;
    OnTraceFunctions:  function(const Params: TRSExceptionParams):string;
    OnTraceRegisters:  function(const Params: TRSExceptionParams):string;
    OnTraceStack:  function(const Params: TRSExceptionParams):string;

    OnAddressDetails: function(Addr: pointer):string;

    OnLogException: function(ExcIndex, ExcCount: integer;
      var LogProps:TRSExceptionLogProps; var UserData):string;
    OnAfterLogException: procedure(var Log:string; ExcIndex, ExcCount: integer;
      var LogProps:TRSExceptionLogProps; var UserData);
    OnAfterLogExceptions: procedure(var Log:string; ExcCount: integer);

    OnTraceUserData: procedure(var UserData; SecondaryException:boolean);
    OnFreeUserData: procedure(var UserData);
    UserDataSize: integer;

    SecondaryExcTraceHeader: boolean;
    SecondaryExcTraceFunctions: boolean;
    SecondaryExcTraceRegisters: boolean;
    SecondaryExcTraceStack: boolean;

    ContextFlags: int;

    OnException: procedure(const Params: TRSExceptionParams);
    OnDoneExceptions: procedure(ContinueFrom: pointer);
    OnUnhandledException: procedure(ExceptObj, ExceptAddr: pointer);
  end;

  TRSCheckRetAddrOptions = record
    FrameCallChecks: TRSFunctionChecks;
    OnFrameCallCheck: function(Addr: pointer):boolean;
    NoFrameCallChecks: TRSFunctionChecks;
    OnNoFrameCallCheck: function(Addr: pointer):boolean;
  end;

  TRSCallTraceOptions = packed record
    LineLimit: int;
    OnBeginTrace: function:string;
    OnEndTrace: procedure(var Log:string; TraceCount: integer; Cropped:boolean);
    OnTraceCall: function(StackAddr, CallAddr: pointer;
      TraceIndex: integer; NoFrame:boolean):string;
  end;

  TRSStackTraceOptions = packed record
    LineLimit: int;
    OnBeginTrace: function:string;
    OnEndTrace: procedure(var Log:string; TraceCount: integer; Cropped:boolean);
    OnTraceCall: function(StackAddr, CallAddr: pointer;
      TraceIndex: integer; NoFrame:boolean):string;
    OnTrace: function(StackAddr, Data: pointer; TraceIndex: integer;
      const Comment:string):string;
    StackFramesCount: int;
  end;

var
  RSDebugOptions: TRSDebugOptions =
    (SecondaryExcTraceHeader: true;
     SecondaryExcTraceFunctions: true;
     ContextFlags: CONTEXT_FULL);
  RSCheckRetAddrOptions: TRSCheckRetAddrOptions =
    (FrameCallChecks: [RSfcReadOnly, RSfcValidCall];
     NoFrameCallChecks: [RSfcReadOnly, RSfcValidCall]);
  RSCallTraceOptions: TRSCallTraceOptions =
    (LineLimit: 100);
  RSStackTraceOptions: TRSStackTraceOptions =
    (LineLimit: 200; StackFramesCount: 2);

implementation

{$DEFINE Debug}

{
********************************** Low Level ***********************************
}

var
  DebugActive: boolean;
  LastDebugHook: DWord;
  LastRaiseExceptionProc: ptr;

threadvar
  Recursion: boolean;

const { From System.pas }
  cContinuable        = 0;
  cNonContinuable     = 1;
  cUnwinding          = 2;
  cUnwindingForExit   = 4;
  cUnwindInProgress   = cUnwinding or cUnwindingForExit;
  cDelphiException    = $0EEDFADE;
  cDelphiReRaise      = $0EEDFADF;
  cDelphiExcept       = $0EEDFAE0;
  cDelphiFinally      = $0EEDFAE1;
  cDelphiTerminate    = $0EEDFAE2;
  cDelphiUnhandled    = $0EEDFAE3;
  cNonDelphiException = $0EEDFAE4;
  cDelphiExitFinally  = $0EEDFAE5;
  cCppException       = $0EEFFACE; { used by BCB }
  EXCEPTION_CONTINUE_SEARCH    = 0;
  EXCEPTION_EXECUTE_HANDLER    = 1;
  EXCEPTION_CONTINUE_EXECUTION = -1;

type
  TDelphiExceptionArgs = packed record
    RetAddr: ptr;
    ExceptObj: ptr;
    Ebx: int;
    Esi: int;
    Edi: int;
    Ebp: int;
    Esp: int;
  end;

  TNonDelphiExceptionArgs = packed record
    Context: PContext;
    ExceptObj: ptr;
  end;

  TNotifyTerminateArgs = packed record
    RetAddr: ptr;
  end;

  TNotifyUnhandledArgs = packed record
    ExceptAddr: ptr;
    ExceptObj: ptr;
  end;

  TRaiseExceptionParams = packed record
    Code: DWord;
    Flags: DWord;
    ArgCount: DWord;
    Arguments: pointer;
  end;

procedure RSOnException(const Params: TRSExceptionParams); forward;
procedure RSOnDoneExceptions(ContinueFrom:ptr); forward;

 // Just a good way to pack params into a record
procedure CallOnException(Obj, Addr:ptr; Context:PContext; OS:boolean); stdcall;
asm
  lea eax, [ebp+8]
  call RSOnException
end;

procedure RaiseExceptionHook(Params: TRaiseExceptionParams); stdcall;
type
  TRaiseException = procedure(Params: TRaiseExceptionParams); stdcall;
var
  DebugLevel:DWord; Context:TContext;
begin
  with Params do
  begin
    if Code = cDelphiTerminate then
      Recursion:= false;

    if not Recursion then
{$IFDEF Debug}
      try
{$ELSE}
      begin
{$ENDIF}
        Recursion:= true;
        case Code of
          cDelphiException:
            if ArgCount = sizeof(TDelphiExceptionArgs) div 4 then
              with TDelphiExceptionArgs(Arguments^) do
              begin
                Context.ContextFlags:= RSDebugOptions.ContextFlags;
                GetThreadContext(GetCurrentThread, Context);
                Context.Ebx:= Ebx;
                Context.Esi:= Esi;
                Context.Edi:= Edi;
                Context.Eip:= int(RetAddr) - RSValidCallSite(RetAddr);
                Context.Esp:= Esp;
                Context.Ebp:= Ebp;

                CallOnException(ExceptObj, RetAddr, @Context, false);
              end;

          cNonDelphiException:
            if ArgCount = sizeof(TNonDelphiExceptionArgs) div 4 then
              with TNonDelphiExceptionArgs(Arguments^) do
                CallOnException(ExceptObj, ptr(Context.Eip), Context, false);

          cDelphiTerminate:
            if ArgCount = sizeof(TNotifyTerminateArgs) div 4 then
              with TNotifyTerminateArgs(Arguments^) do
                RSOnDoneExceptions(RetAddr);

          cDelphiUnhandled:
            if ArgCount = sizeof(TNotifyUnhandledArgs) div 4 then
              with RSDebugOptions, TNotifyUnhandledArgs(Arguments^) do
                if @OnUnhandledException<>nil then
                  OnUnhandledException(ExceptObj, ExceptAddr);
        end;
        Recursion:= false;
{$IFDEF Debug}
      except
        ShowException(ExceptObject, ExceptAddr);
{$ENDIF}
      end;

    case Code of
      cDelphiException:  DebugLevel:=0;
      cNonDelphiException:  DebugLevel:=1;
      else  DebugLevel:=2;
    end;
    if LastDebugHook >= DebugLevel then
      TRaiseException(LastRaiseExceptionProc)(Params);
  end;
end;

procedure RSDebugHook(Activate:boolean = true);
begin
  if (Activate = DebugActive) and
     (not DebugActive or (RaiseExceptionProc = @RaiseExceptionHook)) then
    exit;

  if Activate then
  begin
    LastRaiseExceptionProc:= RaiseExceptionProc;
    RaiseExceptionProc:= @RaiseExceptionHook;
     // Not sure if this will work with exceptions raised by C++ units.
     // Most probably that's why Jedi raplaces RaiseException import address.
    if not DebugActive then
      LastDebugHook:= DebugHook;
    if DebugHook<2 then  DebugHook:=2;
  end else
  begin
    RaiseExceptionProc:= LastRaiseExceptionProc;
    DebugHook:= LastDebugHook;
  end;
  DebugActive:= Activate;
end;

{
********************************* Trace Utils **********************************
}

type
  PStackFrame = ^TStackFrame;
  TStackFrame = packed record
    CallersEBP: pointer;
    CallerAdr: pointer;
  end;

  PJmpInstruction = ^JmpInstruction;
  JmpInstruction = packed record // from System.pas
    OpCode: byte;
    Distance: Longint;
  end;

  TExcDescEntry = packed record // from System.pas
    VTable: pointer;
    Handler: pointer;
  end;

  PExcDesc = ^TExcDesc;
  TExcDesc = packed record // from System.pas
    Jmp: JmpInstruction;
    case integer of
    0:      (Instructions: array [0..0] of byte);
    1{...}: (Cnt: integer;
             ExcTab: array [0..0{cnt-1}] of TExcDescEntry);
  end;

  PExcFrame = ^TExcFrame;  // from System.pas
  TExcFrame = record
    Next: PExcFrame;
    Desc: PExcDesc;
    HEBP: pointer;
    case integer of
    0:  ( );
    1:  ( ConstructedObject: pointer );
    2:  ( SelfOfMethod: pointer );
  end;

  PExceptionArguments = ^TExceptionArguments;
  TExceptionArguments = packed record
    ExceptAddr: pointer;
    ExceptObj: Exception;
  end;

  PJmpTable = ^TJmpTable;
  TJmpTable = packed record
    OPCode: word; // FF 25 = JMP DWORD PTR [$xxxxxxxx], encoded as $25FF
    Ptr: pointer;
  end;

  TExceptFrameKind =
    (efkUnknown, efkFinally, efkAnyException, efkOnException, efkAutoException);

function GetStackTop:ptr;
asm
  mov  eax, fs:[4]
end;

function GetExcFrame:ptr;
asm
  mov  eax, fs:[0]
end;

type
  PStackInfo = ^TRSStackInfo;
  TStackInfo = packed record
    FrameStart: pchar;
    FrameStop: pchar;
    NextFrame: pchar;
    StackFrame: pchar;
    ExcFrame: pchar;
    StackTop: pchar;
    FrameIsExcept: boolean;
  end;

procedure ValidateFrames(var StackInfo:TRSStackInfo);
begin
  with TStackInfo(StackInfo) do
  begin
    if (StackFrame + 8 > StackTop) or (StackFrame < FrameStart) then
      StackFrame:= ptr(-1);
    if (ExcFrame + 8 > StackTop) or (ExcFrame < FrameStart) then
      ExcFrame:= ptr(-1);
      
    if StackFrame < ExcFrame then
    begin
      FrameIsExcept:= false;
      FrameStop:= StackFrame;
      NextFrame:= StackFrame + 8;
    end else
      if ExcFrame <> ptr(-1) then
      begin
        FrameIsExcept:= true;
        FrameStop:= ExcFrame;
        NextFrame:= ExcFrame + 8;
      end else
      begin
        FrameIsExcept:= false;
        FrameStop:= StackTop;
        NextFrame:= nil;
      end;
  end;
end;

function RSCreateStackInfo(const Context:TContext):TRSStackInfo;
begin
  with TStackInfo(result) do
  begin
    StackTop:= GetStackTop;
    FrameStart:= ptr(Context.Esp);
    StackFrame:= ptr(Context.Ebp);
    ExcFrame:= GetExcFrame;
    while (ExcFrame < FrameStart) and (ExcFrame<>ptr(-1)) and
          not IsBadReadPtr(ExcFrame, 8) do
      ExcFrame:= ptr(PExcFrame(ExcFrame).Next);
    ValidateFrames(result); // Sets FrameStop and FrameIsExcept
  end;
end;

function RSStackInfoNextFrame(var StackInfo:TRSStackInfo):boolean;
begin
  with TStackInfo(StackInfo) do
  begin
    FrameStart:= NextFrame;
    if FrameStart = nil then
    begin
      FrameStop:= nil;
      result:= false;
      exit;
    end;
    result:= true;

    if FrameIsExcept then
    begin
      if StackFrame = ptr(-1) then
        StackFrame:= PExcFrame(ExcFrame).HEBP;
      ExcFrame:= ptr(PExcFrame(ExcFrame).Next);
    end else
      StackFrame:= PStackFrame(StackFrame).CallersEBP;
      
    ValidateFrames(StackInfo);
  end;
end;

function StackTrace(const Params: TRSExceptionParams; FuncTrace:boolean;
  const Options:TRSStackTraceOptions):string;
var
  TraceIndex: int;
  FrameIndex: int;
  Done: boolean;

  procedure TryTrace;
  begin
    if (TraceIndex < 0) and (@Options.OnBeginTrace <> nil) then
      result:= Options.OnBeginTrace;
    if not Done then
    begin
      Inc(TraceIndex);
      Done:= TraceIndex = Options.LineLimit;
      if Done and (@Options.OnEndTrace <> nil) then
        Options.OnEndTrace(result, TraceIndex, true);
    end;
  end;

  procedure DoTrace(Addr:ptr; const Comment:string = '');
  begin
    if @Options.OnTrace = nil then  exit;
    TryTrace;
    if Done then  exit;
    result:= result + Options.OnTrace(Addr, pptr(Addr)^, TraceIndex, Comment);
  end;

  procedure DoTraceCall(Addr, Call:ptr; NoFrame:boolean; Strict:boolean = false);
  begin
    if @Options.OnTraceCall <> nil then
    begin
      TryTrace;
      if Done then  exit;
      if FuncTrace and not Strict then
        Call:= pchar(Call) - RSValidCallSite(Call);

      result:= result + Options.OnTraceCall(Addr, Call, TraceIndex, NoFrame);
    end else
      DoTrace(Addr);
  end;

var
  si:TRSStackInfo; p:pptr;
begin
  result:='';
  if (Options.LineLimit <= 0) or (Options.StackFramesCount <= 0) then  exit;
  Done:= false;
  TraceIndex:= -1;
  FrameIndex:= 0;
  if FuncTrace then
    DoTraceCall(nil, ptr(Params.Context^.Eip), false, true);

  si:= RSCreateStackInfo(Params.Context^);
  with RSCheckRetAddrOptions do
    while si.NextFrame<>nil do
    begin
      p:= si.FrameStart;
      while pchar(p) < si.FrameStop do
      begin
        if RSValidRetAddr(p^, NoFrameCallChecks) and
           ((@OnNoFrameCallCheck = nil) or OnNoFrameCallCheck(p^)) then
          DoTraceCall(p, p^, true)
        else
          DoTrace(p);
        if Done then  exit;
        Inc(p);
      end;

      if not si.FrameIsExcept then
      begin
        DoTrace(@PStackFrame(si.StackFrame).CallersEBP, 'Last EBP');
        p:= @PStackFrame(si.StackFrame).CallerAdr;
        if RSValidRetAddr(p^, FrameCallChecks) and
           ((@OnFrameCallCheck = nil) or OnFrameCallCheck(p^)) then
          DoTraceCall(p, p^, false)
        else
          DoTrace(p);
        Inc(FrameIndex);
        if Done then  exit;
        if FrameIndex >= Options.StackFramesCount then  break;
      end else
        if @Options.OnTrace <> nil then
        begin
          DoTrace(@PExcFrame(si.ExcFrame).Next, 'TExcFrame.next');
          p:= @PExcFrame(si.ExcFrame).Desc;
          if RSValidRetAddr(p^, []) then
          begin
            DoTraceCall(p, p^, false, true);
            if RSValidRetAddr(p^, [RSfcThisModule]) then
            begin
              DoTrace(@PExcFrame(si.ExcFrame).HEBP, 'TExcFrame.hEBP');
              Inc(pint(si.NextFrame));
            end;
          end else
            DoTrace(p, 'TExcFrame.desc');

          if Done then  exit;
        end;

      RSStackInfoNextFrame(si);
    end;

  if (@Options.OnEndTrace <> nil) and (TraceIndex >= 0) {and not Done} then
    Options.OnEndTrace(result, TraceIndex+1, false);
end;


function RSTraceFunctionCalls(const Params: TRSExceptionParams):string;
var
  Options: TRSStackTraceOptions;
  CallOptions: TRSCallTraceOptions absolute Options;
begin
  FillChar(Options, sizeof(Options), 0);
  CallOptions:= RSCallTraceOptions;
  Options.StackFramesCount:= MaxInt;
  result:= StackTrace(Params, true, Options);
end;

function RSTraceStack(const Params: TRSExceptionParams):string;
begin
  result:= StackTrace(Params, false, RSStackTraceOptions);
end;

function RSDefultAddressDetails(Addr:ptr):string;
var
  Temp: array[0..MAX_PATH] of char;
  h: hInst;
begin
  h:= FindHInstance(Addr);
  if h<>0 then
  begin
    if GetModuleFilename(h, Temp, sizeof(Temp))<>0 then
      result:= Temp
    else
      result:= '(' + IntToHex(h, 8) + ')';

    result:= result + ' + ' + IntToHex(DWord(Addr) - h, 0);
  end else
    result:='';
end;

function RSDefaultTraceCall(StackAddr, CallAddr:ptr; TraceIndex:int; NoFrame:boolean):string;
var
  s:string;
begin
  result:= IntToHex(int(CallAddr), 8);
  if @RSDebugOptions.OnAddressDetails <> nil then
    s:= RSDebugOptions.OnAddressDetails(CallAddr);
    
  if s<>'' then
    if NoFrame then
      result:= result + ' ? '
    else
      result:= result + ' | ';

  result:= result + s + #13#10;
end;

function RSDefaultStackTrace(StackAddr, Data:ptr; TraceIndex:int; const Comment:string):string;
begin
  result:= IntToHex(int(StackAddr), 8) + ': ' + IntToHex(int(Data), 8);
  if Comment<>'' then  result:= result + ' | ' + Comment;
  result:= result + #13#10;
end;

function RSDefaultStackTraceCall(StackAddr, CallAddr:ptr; TraceIndex:int; NoFrame:boolean):string;
begin
  result:= IntToHex(int(StackAddr), 8) + ': ' +
    RSDefaultTraceCall(StackAddr, CallAddr, TraceIndex, NoFrame);
end;

procedure RSDefaultEndTrace(var Log:string; TraceCount:int; Cropped:boolean);
begin
  if Cropped then
    Log:= Log + '...'#13#10;
end;

function RSTraceRegisters(const Params: TRSExceptionParams):string;
begin
  with Params.Context^ do
  begin
    result:= result +
      'EAX = ' + IntToHex(int(EAX), 8) + #13#10 +
      'EBX = ' + IntToHex(int(EBX), 8) + #13#10 +
      'ECX = ' + IntToHex(int(ECX), 8) + #13#10 +
      'EDX = ' + IntToHex(int(EDX), 8) + #13#10 +
      'ESI = ' + IntToHex(int(ESI), 8) + #13#10 +
      'EDI = ' + IntToHex(int(EDI), 8) + #13#10 +
      'EBP = ' + IntToHex(int(EBP), 8) + #13#10 +
      'ESP = ' + IntToHex(int(ESP), 8) + #13#10;
  end;
end;

function RSTraceHeader(const Params: TRSExceptionParams):string;
var
  Buffer: array of char;
   // On D7 StrLFmt causes buffer overflow despite of the size parameter, so
   // we the buffer must always be big enough.
var i:int;
begin
  with Params do
    if not IsBadReadPtr(ExceptObj, 4)  and
       not IsBadReadPtr(PPChar(ExceptObj)^ + vmtSelfPtr, -vmtSelfPtr) and
       (pint(pint(ExceptObj)^ + vmtSelfPtr)^ = pint(ExceptObj)^) then
    begin
      i:= 256 + MAX_PATH;
      if TObject(ExceptObj) is Exception then
        Inc(i, Length(Exception(ExceptObj).message));

      SetLength(Buffer, i);
      ExceptionErrorMessage(ExceptObj, ExceptAddr, pchar(Buffer), Length(Buffer));
      result:= pchar(Buffer);
    end else
      result:= 'Corrupt ExceptObj: ' + IntToHex(int(ExceptObj), 8) + #13#10;
end;

 // Uses Russian notation
function FormatSystemTime(const Time:TSystemTime):string;
const
  Template = '%.2d.%.2d.%.4d %.2d:%.2d:%.2d';
begin
  // for Eng or custom: GetLocaleFormatSettings, DateTimeToString
  with Time do
    result:= Format(Template, [wDay, wMonth, wYear, wHour, wMinute, wSecond]);
end;

function RSTraceSystemInfo:string;
const
  Template = 'Time: %s (%s UTC)'#13#10'Windows Version %d.%d %s'#13#10;
var
  Time: TSystemTime;
  s1, s2:string;
begin
  GetLocalTime(Time);
  s1:= DateTimeToStr(SystemTimeToDateTime(Time));
  GetSystemTime(Time);
  s2:= FormatSystemTime(Time);
  with RSOSVersionInfo do
    result:= Format(Template, [s1, s2, dwMajorVersion, dwMinorVersion, szCSDVersion]);
end;

function RSValidRetAddr(Addr:ptr; Checks:TRSFunctionChecks):boolean;
var h:HINST;
begin
  h:= FindHInstance(Addr);
  result:= not IsBadCodePtr(Addr) and (h<>0) and
    (not (RSfcReadOnly in Checks) or IsBadWritePtr(Addr, 1)) and
    (not (RSfcThisModule in Checks) or (h = HInstance)) and
    (not (RSfcValidCall in Checks) or (RSValidCallSite(Addr) > 0));
end;

// Validate that the code address is a valid code site
// Returns the size of CALL instruction or 0.
// From JclDebug, slightly modified
function RSValidCallSite( CodeAddr: pointer ): integer;
var
  C4, C8: DWORD;
begin
  result:= 0;

  if (DWord(CodeAddr)>8) and not Windows.IsBadReadPtr(pchar(CodeAddr)-8,8) then
  begin
    // Now check to see if the instruction preceding the return address
    // could be a valid CALL instruction
    try
      C8:= PDWORD(pchar(CodeAddr)-8)^;
      C4:= PDWORD(pchar(CodeAddr)-4)^;

      // Check the instruction prior to the potential call site.
      // We consider it a valid call site if we find a CALL instruction there
      // Check the most common CALL variants first
      if      (C8 and $FF000000)=$E8000000 then // 5-byte, CALL [-$1234567]
        result := 5
      else if (C4 and $38FF0000)=$10FF0000 then // 2 byte, CALL EAX
        result := 2
      else if (C4 and $0038FF00)=$0010FF00 then // 3 byte, CALL [EBP+0x8]
        result := 3
      else if (C4 and $000038FF)=$000010FF then // 4 byte, CALL ??
        result := 4
      else if (C8 and $38FF0000)=$10FF0000 then // 6-byte, CALL ??
        result := 6
      else if (C8 and $0038FF00)=$0010FF00 then // 7-byte, CALL [ESP-0x1234567]
        result := 7
      // Because we're not doing a complete disassembly, we will potentially report
      // false positives. If there is odd code that uses the CALL 16:32 format, we
      // can also get false negatives.
    except
      // ignore
    end;
  end;
end;

function RSLogSingleException(ExcIndex, ExcCount:int;
   var LogProps:TRSExceptionLogProps; var UserData):string;
const
  a1 = #13#10;
  a2 = #13#10#13#10;
begin
  with LogProps, RSDebugOptions do
  begin
    if ExcIndex = 0 then
    begin
      result:= RSTraceSystemInfo + a1;
      if ExcCount > 1 then
        result:= result + IntToStr(ExcCount) + ' Exceptions:' + a2;
    end else
      result:= '';

    if (HeaderTrace<>'') and ((ExcIndex = 0) or SecondaryExcTraceHeader) then
      result:= result + HeaderTrace + a1;
    if (FunctionsTrace<>'') and ((ExcIndex = 0) or SecondaryExcTraceFunctions) then
      result:= result + 'Function Calls:' + a2 + FunctionsTrace + a1;
    if (RegistersTrace<>'') and ((ExcIndex = 0) or SecondaryExcTraceRegisters) then
      result:= result + 'Registers:' + a2 + RegistersTrace + a1;
    if (StackTrace<>'') and ((ExcIndex = 0) or SecondaryExcTraceStack) then
      result:= result + 'Stack Trace:' + a2 + StackTrace + a1;

    if ExcIndex > 0 then
      result:= format('___________ Exception %d ___________', [ExcIndex+1]) +
               #13#10#13#10 + result;
  end;
end;

{
******************************* Exceptions List ********************************
}

type
  PExProps = ^TExProps;
  TExProps = packed record
    Next: PExProps; // 0 for none, -1 for pending (multithread support)
    LogProps: TRSExceptionLogProps;
    Eip: DWord;
  end;

var
  LastExcProps: PExProps;

procedure RSOnException(const Params: TRSExceptionParams);
var
  p: PExProps; Main: boolean;
begin
  with RSDebugOptions do
  begin
    //Main:= LastExcProps = nil;
    Main:= true;
    p:= LastExcProps;
    while Main and (p <> nil) and (p <> ptr(-1)) do
    begin
      Main:= p^.Eip <> Params.Context.Eip;
      p:= p^.Next;
    end;

    GetMem(p, sizeof(TExProps) + UserDataSize);
    FillChar(p^, sizeof(TExProps) + UserDataSize, 0);
    p^.Eip:= Params.Context.Eip;

    with p^.LogProps do
    begin
      if (@OnTraceHeader<>nil) and (Main or SecondaryExcTraceHeader) then
        HeaderTrace:= OnTraceHeader(Params);
      if (@OnTraceFunctions<>nil) and (Main or SecondaryExcTraceFunctions) then
        FunctionsTrace:= OnTraceFunctions(Params);
      if (@OnTraceRegisters<>nil) and (Main or SecondaryExcTraceRegisters) then
        RegistersTrace:= OnTraceRegisters(Params);
      if (@OnTraceStack<>nil) and (Main or SecondaryExcTraceStack) then
        StackTrace:= OnTraceStack(Params);
      if @OnTraceUserData<>nil then
        OnTraceUserData((pchar(p) + sizeof(TExProps))^, not Main);
    end;

    p^.Next:= ptr(-1);
    p^.Next:= ptr(InterlockedExchange(int(LastExcProps), int(p)));

    if @OnException<>nil then
      OnException(Params);
  end;
end;

procedure FreeException(Ex:PExProps);
begin
  if Ex = nil then  exit;
  try
    while Ex.Next = ptr(-1) do  Sleep(1);
    FreeException(Ex.Next);
    with Ex.LogProps do
    begin
      HeaderTrace:= '';
      RegistersTrace:= '';
      FunctionsTrace:= '';
      StackTrace:= '';
    end;
    if @RSDebugOptions.OnFreeUserData <> nil then
      RSDebugOptions.OnFreeUserData((pchar(Ex) + sizeof(TExProps))^);
  finally
    FreeMem(Ex);
  end;
end;

procedure RSOnDoneExceptions(ContinueFrom:ptr);
begin
  try
    if @RSDebugOptions.OnDoneExceptions<>nil then
      RSDebugOptions.OnDoneExceptions(ContinueFrom);
  finally
    FreeException(ptr(InterlockedExchange(int(LastExcProps), 0)));
  end;
end;


procedure ProcessException(Ex:PExProps; var Count:int; var Log:string);
var
  index:int; s:string;
begin
  if Ex = nil then  exit;
  Inc(Count);
  index:= Count;
  while Ex.Next = ptr(-1) do  Sleep(1);
  ProcessException(Ex.Next, Count, Log);
  index:= Count - index;
  with RSDebugOptions do
  begin
    if @OnLogException <> nil then
      s:= OnLogException(index, Count, Ex.LogProps, (pchar(Ex) + sizeof(TExProps))^);
    if @OnAfterLogException <> nil then
      OnAfterLogException(s, index, Count, Ex.LogProps, (pchar(Ex) + sizeof(TExProps))^);
    Log:= Log + s;
  end;
end;

function RSLogExceptions:string;
var Count:int;
begin
  Count:= 0;
  ProcessException(ptr(InterlockedExchange(int(LastExcProps), 0)), Count, result);
  with RSDebugOptions do
    if @OnAfterLogExceptions <> nil then
      OnAfterLogExceptions(result, Count);
end;

// for use in unhandled exceptions filter
function RSLogExceptionPointers(const p: TExceptionPointers): string;
type
  TExceptObjProc = function(p: Windows.PExceptionRecord): Exception;
var
  cont: PContext;
  ExceptObj: Exception;
begin
  cont:= p.ContextRecord;
  ExceptObj:= TExceptObjProc(ExceptObjProc)(p.ExceptionRecord);
  try
    CallOnException(ExceptObj, ptr(cont.Eip), cont, false);
    result:= RSLogExceptions;
    RSOnDoneExceptions(nil);
  finally
    ExceptObj.Free;
  end;
end;

{
********************************** Defaults ************************************
}

procedure RSDebugUseDefaults(CallTraceLineLimit: int = 100;
   StackTraceLineLimit: int = 200; StackFramesCount: int = 2);
begin
  with RSDebugOptions do
  begin
    OnTraceHeader:= RSTraceHeader;
    OnTraceFunctions:= RSTraceFunctionCalls;
    OnTraceRegisters:= RSTraceRegisters;
    OnTraceStack:= RSTraceStack;
    OnLogException:= RSLogSingleException;
    OnAddressDetails:= RSDefultAddressDetails;
  end;
  with RSCallTraceOptions do
  begin
    LineLimit:= CallTraceLineLimit;
    OnEndTrace:= RSDefaultEndTrace;
    OnTraceCall:= RSDefaultTraceCall;
  end;
  with RSStackTraceOptions do
  begin
    LineLimit:= StackTraceLineLimit;
    OnEndTrace:= RSDefaultEndTrace;
    OnTraceCall:= RSDefaultStackTraceCall;
    OnTrace:= RSDefaultStackTrace;
  end;
  RSStackTraceOptions.StackFramesCount:= StackFramesCount;
end;

function RSIsSecondaryException: boolean;
begin
  result:= LastExcProps<>nil;
end;

end.
