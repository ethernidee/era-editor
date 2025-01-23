unit Tweaks;
{
DESCRIPTION:  Fixed and improvements
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  interface  (***)
uses
  Windows, SysUtils, Utils, Debug, FilesEx, Concur, DataLib, ApiJack, PatchApi,
  MapExt, Editor;


(***) implementation (***)


var
{O} TopLevelExceptionHandlers: DataLib.TList {OF Handler: pointer};
    ExceptionsCritSection:     Concur.TCritSection;

procedure DumpWinPeModuleList;
const
  DEBUG_WINPE_MODULE_LIST_PATH = MapExt.DEBUG_DIR + '\pe modules.txt';

var
  i: integer;

begin
  {!} Debug.ModuleContext.Lock;
  Debug.ModuleContext.UpdateModuleList;

  with FilesEx.WriteFormattedOutput(MapExt.GameDir + '\' + DEBUG_WINPE_MODULE_LIST_PATH) do begin
    Line('> Win32 executable modules');
    EmptyLine;

    for i := 0 to Debug.ModuleContext.ModuleList.Count - 1 do begin
      Line(Debug.ModuleContext.ModuleInfo[i].ToStr);
    end; // .for
  end; // .with

  {!} Debug.ModuleContext.Unlock;
end; // .procedure DumpWinPeModuleList

procedure DumpExceptionContext (ExcRec: Windows.PExceptionRecord; Context: Windows.PContext);
const
  DEBUG_EXCEPTION_CONTEXT_PATH = MapExt.DEBUG_DIR + '\exception context.txt';

var
  ExceptionText: string;
  LineText:      string;
  Ebp:           integer;
  Esp:           integer;
  RetAddr:       integer;
  i:             integer;

begin
  {!} Debug.ModuleContext.Lock;
  Debug.ModuleContext.UpdateModuleList;

  with FilesEx.WriteFormattedOutput(MapExt.GameDir + '\' + DEBUG_EXCEPTION_CONTEXT_PATH) do begin
    case ExcRec.ExceptionCode of
      $C0000005: begin
        if ExcRec.ExceptionInformation[0] <> 0 then begin
          ExceptionText := 'Failed to write data at ' + Format('%x', [integer(ExcRec.ExceptionInformation[1])]);
        end else begin
          ExceptionText := 'Failed to read data at ' + Format('%x', [integer(ExcRec.ExceptionInformation[1])]);
        end; // .else
      end; // .case $C0000005

      $C000008C: ExceptionText := 'Array index is out of bounds';
      $80000003: ExceptionText := 'Breakpoint encountered';
      $80000002: ExceptionText := 'Data access misalignment';
      $C000008D: ExceptionText := 'One of the operands in a floating-point operation is denormal';
      $C000008E: ExceptionText := 'Attempt to divide a floating-point value by a floating-point divisor of zero';
      $C000008F: ExceptionText := 'The result of a floating-point operation cannot be represented exactly as a decimal fraction';
      $C0000090: ExceptionText := 'Invalid floating-point exception';
      $C0000091: ExceptionText := 'The exponent of a floating-point operation is greater than the magnitude allowed by the corresponding type';
      $C0000092: ExceptionText := 'The stack overflowed or underflowed as the result of a floating-point operation';
      $C0000093: ExceptionText := 'The exponent of a floating-point operation is less than the magnitude allowed by the corresponding type';
      $C000001D: ExceptionText := 'Attempt to execute an illegal instruction';
      $C0000006: ExceptionText := 'Attempt to access a page that was not present, and the system was unable to load the page';
      $C0000094: ExceptionText := 'Attempt to divide an integer value by an integer divisor of zero';
      $C0000095: ExceptionText := 'Integer arithmetic overflow';
      $C0000026: ExceptionText := 'An invalid exception disposition was returned by an exception handler';
      $C0000025: ExceptionText := 'Attempt to continue from an exception that isn''t continuable';
      $C0000096: ExceptionText := 'Attempt to execute a privilaged instruction.';
      $80000004: ExceptionText := 'Single step exception';
      $C00000FD: ExceptionText := 'Stack overflow';
      else       ExceptionText := 'Unknown exception';
    end; // .switch ExcRec.ExceptionCode

    Line(ExceptionText + '.');
    Line(Format('EIP: %s. Code: %x', [Debug.ModuleContext.AddrToStr(Ptr(Context.Eip)), ExcRec.ExceptionCode]));
    EmptyLine;
    Line('> Registers');

    Line('EAX: ' + Debug.ModuleContext.AddrToStr(Ptr(Context.Eax), Debug.ANALYZE_DATA));
    Line('ECX: ' + Debug.ModuleContext.AddrToStr(Ptr(Context.Ecx), Debug.ANALYZE_DATA));
    Line('EDC: ' + Debug.ModuleContext.AddrToStr(Ptr(Context.Edx), Debug.ANALYZE_DATA));
    Line('EBX: ' + Debug.ModuleContext.AddrToStr(Ptr(Context.Ebx), Debug.ANALYZE_DATA));
    Line('ESP: ' + Debug.ModuleContext.AddrToStr(Ptr(Context.Esp), Debug.ANALYZE_DATA));
    Line('EBP: ' + Debug.ModuleContext.AddrToStr(Ptr(Context.Ebp), Debug.ANALYZE_DATA));
    Line('ESI: ' + Debug.ModuleContext.AddrToStr(Ptr(Context.Esi), Debug.ANALYZE_DATA));
    Line('EDI: ' + Debug.ModuleContext.AddrToStr(Ptr(Context.Edi), Debug.ANALYZE_DATA));

    EmptyLine;
    Line('> Callstack');
    Ebp     := Context.Ebp;
    RetAddr := 1;

    try
      while (Ebp <> 0) and (RetAddr <> 0) do begin
        RetAddr := pinteger(Ebp + 4)^;

        if RetAddr <> 0 then begin
          Line(Debug.ModuleContext.AddrToStr(Ptr(RetAddr)));
          Ebp := pinteger(Ebp)^;
        end; // .if
      end; // .while
    except
      // Stop processing callstack
    end; // .try

    EmptyLine;
    Line('> Stack');
    Esp := Context.Esp - sizeof(integer) * 5;

    try
      for i := 1 to 40 do begin
        LineText := IntToHex(Esp, 8);

        if Esp = integer(Context.Esp) then begin
          LineText := LineText + '*';
        end; // .if

        LineText := LineText + ': ' + Debug.ModuleContext.AddrToStr(ppointer(Esp)^, Debug.ANALYZE_DATA);
        Inc(Esp, sizeof(integer));
        Line(LineText);
      end; // .for
    except
      // Stop stack traversing
    end; // .try
  end; // .with

  {!} Debug.ModuleContext.Unlock;
end; // .procedure DumpExceptionContext

function TopLevelExceptionHandler (const ExceptionPtrs: TExceptionPointers): integer; stdcall;
const
  EXCEPTION_CONTINUE_SEARCH = 0;

begin
  SysUtils.SetCurrentDir(GameDir);
  DumpExceptionContext(ExceptionPtrs.ExceptionRecord, ExceptionPtrs.ContextRecord);
  MapExt.FireEvent('OnGenerateDebugInfo', nil, 0);
  Windows.MessageBox(0, 'Editor is crashing, sorry. Look at "' + MapExt.DEBUG_DIR + '" for debug info.', 'Something went wrong :(', Windows.MB_OK or Windows.MB_ICONEXCLAMATION);

  result := EXCEPTION_CONTINUE_SEARCH;
end; // .function TopLevelExceptionHandler

function OnUnhandledException (const ExceptionPtrs: TExceptionPointers): integer; stdcall;
type
  THandler = function (const ExceptionPtrs: TExceptionPointers): integer; stdcall;

const
  EXCEPTION_CONTINUE_SEARCH = 0;

var
  i: integer;

begin
  {!} ExceptionsCritSection.Enter;

  for i := 0 to TopLevelExceptionHandlers.Count - 1 do begin
    THandler(TopLevelExceptionHandlers[i])(ExceptionPtrs);
  end;

  {!} ExceptionsCritSection.Leave;

  result := EXCEPTION_CONTINUE_SEARCH;
end; // .function OnUnhandledException

function Splice_SetUnhandledExceptionFilter (OrigFunc, NewHandler: pointer): pointer; stdcall;
begin
  if NewHandler <> nil then begin
    {!} ExceptionsCritSection.Enter;
    TopLevelExceptionHandlers.Add(NewHandler);
    {!} ExceptionsCritSection.Leave;
  end;

  result := nil;
end;

function Hook_FixGameVersion (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  Editor.GameVersion^ := AB_AND_SOD;
  result              := true;
end;

procedure OnGenerateDebugInfo (Event: PEvent); stdcall;
begin
  DumpWinPeModuleList;
end;

procedure OnInit (Event: MapExt.PEvent); stdcall;
begin
  (* Install global top-level exception filter *)
  Windows.SetErrorMode(SEM_NOGPFAULTERRORBOX);
  Windows.SetUnhandledExceptionFilter(@OnUnhandledException);
  ApiJack.StdSplice(@Windows.SetUnhandledExceptionFilter, @Splice_SetUnhandledExceptionFilter, ApiJack.CONV_STDCALL, 1);
  Windows.SetUnhandledExceptionFilter(@TopLevelExceptionHandler);

  (* Fix game version to allow generating random maps *)
  ApiJack.Hook(Ptr($45C5FD), @Hook_FixGameVersion, nil, 5, ApiJack.HOOKTYPE_BRIDGE);

  (* Fix crashing on exit is some kind of destructor *)
  PatchApi.p.WriteCodePatch(Ptr($4DC080), ['C3']);

  (* Use .msk files instead of .msg *)
  PatchApi.p.WriteCodePatch(Ptr($54097F), ['6B']);
  PatchApi.p.WriteCodePatch(Ptr($58E1EE), ['6B']);
end;

begin
  ExceptionsCritSection.Init;
  TopLevelExceptionHandlers := DataLib.NewList(not Utils.OWNS_ITEMS);
  MapExt.RegisterHandler(OnInit, 'OnInit');
  RegisterHandler(OnGenerateDebugInfo, 'OnGenerateDebugInfo');
end.
