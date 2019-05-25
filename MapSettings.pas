unit MapSettings;
{
DESCRIPTION:  Settings management
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  interface  (***)
uses
  SysUtils, Math, Utils, Log, Ini, Core,
  VfsImport, MapExt, EraLog;
  
const
  GAME_SETTINGS_FILE = 'heroes3.ini';
  LOG_FILE_NAME      = 'log.txt';

implementation

var
  DebugOpt:           boolean;
  DebugEverythingOpt: boolean;

function GetOptValue (const OptionName: string; const DefVal: string = ''): string;
const
  ERA_SECTION               = 'Era';
  DEFAULT_ERA_SETTINGS_FILE = 'default era settings.ini';

begin
  if Ini.ReadStrFromIni(OptionName, ERA_SECTION, GAME_SETTINGS_FILE, result) or
     Ini.ReadStrFromIni(OptionName, ERA_SECTION, DEFAULT_ERA_SETTINGS_FILE, result)
  then begin
    result := SysUtils.Trim(result);
  end else begin
    result := DefVal;
  end;
end; // .function GetOptValue

function GetOptBoolValue (const OptionName: string; DefValue: boolean = false): boolean;
var
  OptVal: string;

begin
  OptVal := GetOptValue(OptionName, IfThen(DefValue, '1', '0'));
  result := OptVal = '1';
end; // .function GetOptBoolValue

function GetDebugOpt (const OptionName: string; DefValue: boolean = false): boolean;
begin
  result := DebugOpt and (DebugEverythingOpt or GetOptBoolValue(OptionName, DefValue)); 
end; // .function GetDebugOpt

function GetOptIntValue (const OptionName: string; DefValue: integer = 0): integer;
var
  OptVal: string;

begin
  OptVal := GetOptValue(OptionName, IntToStr(DefValue));

  if not TryStrToInt(OptVal, result) then begin
    Log.Write('Settings', 'GetOptIntValue', 'Error. Invalid option "' + OptionName
                                            + '" value: "' + OptVal + '". Assumed ' + IntToStr(DefValue));
    result := DefValue;
  end; // .if
end; // .function GetOptIntValue

procedure InstallLogger (Logger: Log.TLogger);
var
  LogRec: TLogRec;

begin
  {!} Assert(Logger <> nil);
  Log.Seek(0);

  while Log.Read(LogRec) do begin
    Logger.Write(LogRec.EventSource, LogRec.Operation, LogRec.Description);
  end; // .while
  
  Log.InstallLogger(Logger, Log.FREE_OLD_LOGGER);
end; // .procedure InstallLogger

procedure OnLoadSettings (Event: MapExt.PEvent); stdcall;
begin
  DebugOpt           := GetOptBoolValue('Debug', true);
  DebugEverythingOpt := GetOptBoolValue('Debug.Everything', false);

  if DebugOpt then begin
    if GetOptValue('Debug.LogDestination', 'File') = 'File' then begin
      InstallLogger(EraLog.TFileLogger.Create(MapExt.DEBUG_DIR + '\' + LOG_FILE_NAME));
    end else begin     
      InstallLogger(EraLog.TConsoleLogger.Create('Era Log'));
    end;
  end else begin
    InstallLogger(EraLog.TMemoryLogger.Create);
  end; // .else

  Log.Write('Core', 'CheckVersion', 'Result: ' + MapExt.ERA_EDITOR_VERSION);

  Core.AbortOnError := GetDebugOpt('Debug.AbortOnError',         true);
  //VFS.DebugOpt      := GetDebugOpt('Debug.LogVirtualFileSystem', false);
  // FIXME Rewrite me
end; // .procedure OnLoadSettings

begin
  MapExt.RegisterHandler(OnLoadSettings, 'OnLoadSettings');
end.
