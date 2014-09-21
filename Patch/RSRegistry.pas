unit RSRegistry;

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
  SysUtils, Registry, RSQ;

type
  TRSRegistry = class(TRegistry)
  public
    function GetData(const Name: string; Buffer: pointer;
      BufSize: integer; var RegData: TRegDataType): integer;
    procedure PutData(const Name: string; Buffer: pointer; BufSize: integer;
      RegData: TRegDataType);
    function Read(const Name: string; var v: boolean):boolean; overload;
    function Read(const Name: string; var v: TDateTime):boolean; overload;
    function Read(const Name: string; var v: double):boolean; overload;
    function Read(const Name: string; var v: currency):boolean; overload;
    function Read(const Name: string; var v: integer):boolean; overload;
    function Read(const Name: string; var v: string):boolean; overload;
    // Maybe will do same things with Write...
  end;

implementation

function TRSRegistry.GetData(const Name: string; Buffer: pointer;
  BufSize: integer; var RegData: TRegDataType): integer;
begin
  result:=inherited GetData(Name, Buffer, BufSize, RegData);
end;

procedure TRSRegistry.PutData(const Name: string; Buffer: pointer;
  BufSize: integer; RegData: TRegDataType);
begin
  inherited PutData(Name, Buffer, BufSize, RegData);
end;

function TRSRegistry.Read(const Name: string; var v: boolean):boolean;
begin
  try
    v:=ReadBool(Name);
    result:=true;
  except
    result:=false;
  end;
end;

function TRSRegistry.Read(const Name: string; var v: TDateTime):boolean;
begin
  try
    v:=ReadDateTime(Name);
    result:=true;
  except
    result:=false;
  end;
end;

function TRSRegistry.Read(const Name: string; var v: double):boolean;
begin
  try
    v:=ReadFloat(Name);
    result:=true;
  except
    result:=false;
  end;
end;

function TRSRegistry.Read(const Name: string; var v: currency):boolean;
begin
  try
    v:=ReadCurrency(Name);
    result:=true;
  except
    result:=false;
  end;
end;

function TRSRegistry.Read(const Name: string; var v: integer):boolean;
begin
  try
    v:=ReadInteger(Name);
    result:=true;
  except
    result:=false;
  end;
end;

function TRSRegistry.Read(const Name: string; var v: string):boolean;
begin
  try
    v:= ReadString(Name);
    result:= GetDataSize(Name)>=0;
  except
    result:= false;
  end;
end;

end.
