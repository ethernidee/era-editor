unit MapSettings;
{
DESCRIPTION:  Settings management
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  interface  (***)
uses
  SysUtils,
  Utils, Log, Ini,
  EraLog;

const
  GAME_SETTINGS_FILE  = 'heroes3.ini';
  ERA_VERSION         = '2.55';
  
  
type
  TDebugDestination = (DEST_CONSOLE, DEST_FILE);


var
  DebugOpt: boolean;
  
  DebugDestination: TDebugDestination;
  DebugFile:        string;


(***) implementation (***)


function GetOptValue (const OptionName: string): string;
const
  ERA_SECTION = 'Era';
  GAME_SETTINGS_FILE = 'heroes3.ini';

begin
  if Ini.ReadStrFromIni(OptionName, ERA_SECTION, GAME_SETTINGS_FILE, result) then begin
    result := SysUtils.Trim(result);
  end // .IF
  else begin
    result := '';
  end; // .ELSE
end; // .FUNCTION GetOptValue

procedure InstallLogger (Logger: Log.TLogger);
var
  LogRec: TLogRec;

begin
  {!} Assert(Logger <> nil);
  Log.Seek(0);

  while Log.Read(LogRec) do begin
    Logger.Write(LogRec.EventSource, LogRec.Operation, LogRec.Description);
  end; // .WHILE
  
  Log.InstallLogger(Logger, Log.FREE_OLD_LOGGER);
end; // .PROCEDURE InstallLogger

procedure LoadSettings;
begin
  DebugOpt  :=  GetOptValue('Debug') = '1';
  
  if DebugOpt then begin
    if GetOptValue('Debug.Destination') = 'File' then begin
      InstallLogger(EraLog.TFileLogger.Create(GetOptValue('Debug.File')));
    end // .IF
    else begin     
      InstallLogger(EraLog.TConsoleLogger.Create('Era Log'));
    end; // .ELSE
  end // .IF
  else begin
    InstallLogger(EraLog.TMemoryLogger.Create);
  end; // .ELSE
  
  Log.Write('Core', 'CheckVersion', 'Result: ' + ERA_VERSION);
end; // .PROCEDURE LoadSettings

begin
  LoadSettings;
end.
