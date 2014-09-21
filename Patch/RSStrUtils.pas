unit RSStrUtils;

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
  SysUtils, Windows, RSQ;

type
  TRSParsedString = array of pchar;

function RSParseRange(FromP, ToP:pointer; const Separators:array of string):TRSParsedString;
function RSParseString(const s:string; const Separators:array of string; From:int=1):TRSParsedString;
function RSParseToken(const ps:TRSParsedString; index:int; const Separators:array of string):TRSParsedString;
function RSParseTokens(const ps:TRSParsedString; IndexFrom,IndexTo:int; const Separators:array of string):TRSParsedString;

function RSGetToken(const ps:TRSParsedString; index:int):string;
function RSGetTokenSep(const ps:TRSParsedString; index:int):string;
function RSGetTokens(const ps:TRSParsedString; IndexFrom:int; IndexTo:int = MaxInt div 2):string;
function RSGetTokensCount(const ps:TRSParsedString; IgnoreEmptyEnd:boolean=false):int;
procedure RSChangeStr(var ps:TRSParsedString; const OldStr, NewStr:string);

function RSStringReplace(const Str, OldPattern, NewPattern: string;
  Flags: TReplaceFlags=[rfReplaceAll]): string;

function RSIntToStr(Value:LongInt; Base:byte = 10; ThousSep:char = #0; BigChars:boolean=true; Digits:int = 0):string;
function RSUIntToStr(Value:DWord; Base:byte = 10; ThousSep:char = #0; BigChars:boolean=true; Digits:int = 0):string;
function RSInt64ToStr(Value:Int64; Base:DWord = 10; ThousSep:char = #0; BigChars:boolean=true; Digits:int = 0):string;

function RSVal(s:string; var i:integer):boolean;
function RSValEx(s:string; var i:integer):int;
function RSStrToInt(const Str:string; Base:DWord = 10; IgnoreChar:char=#0; IgnoreLeadSpaces:boolean=false; IgnoreTrailSpaces:boolean=false):LongInt; overload;
function RSStrToIntEx(const Str:string; var ErrorCode:int; Base:DWord = 10; IgnoreChar:char=#0; IgnoreLeadSpaces:boolean=false; IgnoreTrailSpaces:boolean=false):LongInt; overload;
function RSStrToIntEx(Str:pchar; ErrorCode:pint; Base:DWord = 10; IgnoreChar:char=#0; IgnoreLeadSpaces:boolean=false; IgnoreTrailSpaces:boolean=false):LongInt; overload;
function RSStrToIntVar(var Str:pchar; ErrorCode:pint; Base:LongInt = 10; IgnoreChar:char=#0; IgnoreLeadSpaces:boolean=false; IgnoreTrailSpaces:boolean=false):LongInt; overload;
function RSStrToInt64(const s:string; Base:LongInt = 10; IgnoreChar:char=#0; IgnoreLeadSpaces:boolean=false; IgnoreTrailSpaces:boolean=false):Int64; overload;
function RSStrToInt64Ex(const s:string; var ErrorCode:int; Base:LongInt = 10; IgnoreChar:char=#0; IgnoreLeadSpaces:boolean=false; IgnoreTrailSpaces:boolean=false):Int64; overload;
function RSStrToInt64Ex(s:pchar; ErrorCode:pint; Base:LongInt = 10; IgnoreChar:char=#0; IgnoreLeadSpaces:boolean=false; IgnoreTrailSpaces:boolean=false):Int64; overload;
function RSStrToInt64Var(var s:pchar; ErrorCode:pint; Base:LongInt = 10; IgnoreChar:char=#0; IgnoreLeadSpaces:boolean=false; IgnoreTrailSpaces:boolean=false):Int64; overload;

{ Error Codes:
0:  ok
1:  Пустая строка (result = 0)
2:  Слишком болшое число (result = high(Integer) или low(Integer) )
3:  Неверная система счисления (result = 0)
4:  Неверные символы в строке (result = "нормальная" часть строки)
6:  Строка со слишком большим числом и неверными символами после него
                         (result = high(Integer) или low(Integer) )
}

function RSStrToIntFloatVar(var s:pchar; ErrorCode:pint; Base:LongInt = 10; IgnoreChar:char=#0; IgnoreLeadSpaces:boolean=false; IgnoreTrailSpaces:boolean=false):extended; overload;

function RSFloatToStr(const Value:extended):string;
function RSStrToFloat(s:string):extended;

function RSCharToInt(c:char; Base:LongInt=36):LongInt;
//function RSFloatToStr()

implementation

{$R-} // No range checking

resourcestring
  SRSStrToIntEx1='RSStrToInt: The string is empty';
  SRSStrToIntEx2='RSStrToInt: The value is too big';
  SRSStrToIntEx3='RSStrToInt: Wrong base';
  SRSStrToIntEx4='RSStrToInt: Bad string';

var CharValues:array[0..255] of byte;

function IsThere1(a:pchar; s:string):boolean;
var l:int;
begin
  l:=Length(s);
  if l=1 then result:= a^=s[1]
  else
    if l=0 then result:=false
    else
      result:=CompareMem(a,pchar(s),l);
end;

function SimpleParse(p:pchar; l:DWord; const Sep:string):TRSParsedString;
//const Mem=64;
var n:int; k:DWord;
begin
  SetLength(result,2);
  result[0]:=p;
  n:=1;
  l:=DWord(p)+l;
  k:=DWord(Length(Sep));
  while DWord(p)<>l do
    if (DWord(p)<=l-k) and IsThere1(p, Sep) then
    begin
      result[n]:=p;
      Inc(n);
      //if n div Mem = 0 then
      SetLength(result,n+2);
      Inc(p,k);
      result[n]:=p;
      Inc(n);
    end else
      Inc(p);
  result[n]:=p;
  //SetLength(Result,n+1);
end;

function DoParse(p:pchar; l:DWord; const Sep:array of string):TRSParsedString;
label afterLoop;
//const Mem=64;
var j,n:int; k:DWord;
begin
  if Low(Sep)=High(Sep) then
  begin
    result:=SimpleParse(p,l,Sep[Low(Sep)]);
    exit;
  end;
  SetLength(result,2);
  result[0]:=p;
  n:=1;
  l:=DWord(p)+l;
  while DWord(p)<>l do
  begin
    for j:=Low(Sep) to High(Sep) do
    begin
      k:=Length(Sep[j]);
      if (DWord(p)+k<=l) and IsThere1(p, Sep[j]) then
      begin
        result[n]:=p;
        Inc(n);
        //if n div Mem = 0 then
        SetLength(result,n+2);
        Inc(p,k);
        result[n]:=p;
        Inc(n);
        goto afterLoop;
      end;
    end;
    Inc(p);
afterLoop:
  end;
  result[n]:=p;
  //SetLength(Result,n+1);
end;

function RSParseRange(FromP, ToP:pointer; const Separators:array of string):TRSParsedString;
begin
  result:=DoParse(FromP, DWord(ToP)-DWord(FromP), Separators);
end;

function RSParseString(const s:string; const Separators:array of string;
  From:int=1):TRSParsedString;
begin
  result:=DoParse(pchar(s)+(From-1), Length(s), Separators);
end;

function RSParseToken(const ps:TRSParsedString; index:int; const Separators:array of string):TRSParsedString;
begin
  result:=DoParse(ps[index*2], DWord(ps[index*2+1])-DWord(ps[index*2]),
                  Separators);
end;

function RSParseTokens(const ps:TRSParsedString; IndexFrom,IndexTo:int; const Separators:array of string):TRSParsedString;
begin
  if IndexTo<=IndexFrom then
    result:=nil
  else
    result:=DoParse(ps[IndexFrom*2],
                    DWord(ps[IndexTo*2-1])-DWord(ps[IndexFrom*2]), Separators);
end;

function RSGetToken(const ps:TRSParsedString; index:int):string;
begin
  index:= index*2;
  SetString(result, pchar(ps[index]), DWord(ps[index+1])-DWord(ps[index]));
end;

function RSGetTokenSep(const ps:TRSParsedString; index:int):string;
begin
  index:= index*2 + 1;
  SetString(result, pchar(ps[index]), DWord(ps[index+1])-DWord(ps[index]));
end;

function RSGetTokens(const ps:TRSParsedString; IndexFrom, IndexTo:int):string;
var i:integer;
begin
  if IndexTo<=IndexFrom then result:=''
  else begin
    IndexTo:=IndexTo*2;
    i:=Length(ps);
    if IndexTo<i then
      i:=IndexTo-1
    else  
      i:=i-1;
    SetString(result, pchar(ps[IndexFrom*2]), DWord(ps[i])-DWord(ps[IndexFrom*2]));
  end;
end;

function RSGetTokensCount(const ps:TRSParsedString; IgnoreEmptyEnd:boolean):int;
begin
  if not IgnoreEmptyEnd then
    result:=Length(ps) div 2
  else begin
    result:=Length(ps)-2;
    while (result>=0) and (DWord(ps[result])=DWord(ps[result+1])) do
      Dec(result,2);
    result:=result div 2 + 1;
  end;
end;

procedure RSChangeStr(var ps:TRSParsedString; const OldStr, NewStr:string);
var i,n:int;
begin
  n:=int(NewStr)-int(OldStr);
  for i:=High(ps) downto 0 do
    ps[i]:=ptr(int(ps[i])+n);
end;

{------------------------- StringReplace ----------------------------}

function RSStringReplace(const Str, OldPattern, NewPattern: string;
  Flags: TReplaceFlags=[rfReplaceAll]): string;
var s,s1:string; ps:TRSParsedString; i,j,k,L:DWord;
begin
  ps:=nil;

  if (OldPattern=NewPattern) or (Length(OldPattern)=0) or
     (Length(NewPattern)=0) then
  begin
    result:=Str;
  end;

  if rfIgnoreCase in Flags then
  begin
    s:=AnsiUpperCase(Str);
    s1:=AnsiUpperCase(OldPattern);
  end else
  begin
    s:=Str;
    s1:=OldPattern;
  end;

  if rfReplaceAll in Flags then
  begin
    ps:=RSParseString(s,[s1]);
    if Length(ps)=2 then
    begin
      result:=Str;
      exit;
    end;
  end else
  begin
    i:=pos(s1,s);
    if i=0 then
    begin
      result:=Str;
      exit;
    end;
    SetLength(ps,4);
    ps[0]:=@s[1];
    ps[1]:=@s[i];
    ps[2]:=@s[i+DWord(Length(OldPattern))];
    ps[3]:=ps[0];
    Inc(pchar(ps[3]),Length(s));
  end;

  L:=Length(NewPattern) - Length(OldPattern);
  if L=0 then
  begin
    SetString(result, pchar(ptr(Str)), Length(Str));
    for i:=1 to Length(ps) div 2 -1 do
      CopyMemory(ptr(DWord(result) + DWord(ps[i*2-1]) - DWord(ps[0])),
                 ptr(NewPattern), Length(NewPattern));
  end else
  begin
    s:='';
    i:=Length(ps)-2;
    SetLength(s, DWord(Length(Str)) + L*(i div 2));
    CopyMemory(ptr(s), ptr(Str), DWord(ps[1]) - DWord(ps[0]));
    j:=L*(i div 2);
    k:=Length(NewPattern);
    while i<>0 do
    begin
      if DWord(ps[i+1])<>DWord(ps[i]) then
        CopyMemory(@s[DWord(ps[i])-DWord(ps[0])+1+j],
                   @Str[DWord(ps[i])-DWord(ps[0])+1],
                   DWord(ps[i+1])-DWord(ps[i]));
      Dec(i);
      Dec(j,L);
      CopyMemory(@s[DWord(ps[i])-DWord(ps[0])+1+j],pointer(NewPattern),k);
      Dec(i);
    end;
    result:=s;
  end;
end;

{-------------------------- Int -> Str -----------------------------}

(*
These two functions work, but have less functionality than RSIntToStr does and
have the same speed.

procedure MyCvtInt;
// Based on CvtInt from SysUtils
{ IN:
    EAX:  The integer value to be converted to text
    ESI:  Ptr to the right-hand side of the output buffer:  LEA ESI, StrBuf[16]
    ECX:  Base for conversion: negative for signed, no 0 anymore
    EDX:  Precision: zero padded minimum field width
  OUT:
    ESI:  Ptr to start of converted text (not start of buffer)
    ECX:  Length of converted text
}
asm
        OR      ECX,ECX
        JNS     @CvtLoop
        NEG     ECX
@C1:    OR      EAX,EAX
        JNS     @CvtLoop
        NEG     EAX
        CALL    @CvtLoop
        MOV     AL,'-'
        INC     ECX
        DEC     ESI
        MOV     [ESI],AL
        RET

@CvtLoop:
        PUSH    EDX
        PUSH    ESI
@D1:    XOR     EDX,EDX
        DIV     ECX
        DEC     ESI
        ADD     DL,'0'
        CMP     DL,'0'+10
        JB      @D2
        ADD     DL,('A'-'0')-10
@D2:    MOV     [ESI],DL
        OR      EAX,EAX
        JNE     @D1
        POP     ECX
        POP     EDX
        SUB     ECX,ESI
        SUB     EDX,ECX
        JBE     @D5
        ADD     ECX,EDX
        MOV     AL,'0'
        SUB     ESI,EDX
        JMP     @z
@zloop: MOV     [ESI+EDX],AL
@z:     DEC     EDX
        JNZ     @zloop
        MOV     [ESI],AL
@D5:
end;

function IntToStrBase(Value: LongInt; Base:LongInt=10): string;
// Based on IntToStr     Use negateve base for signed value
asm
  PUSH    ESI
  MOV     ESI, ESP
  SUB     ESP, 33
  PUSH    ECX            // result ptr
  MOV     ECX, Base      // base
  XOR     EDX, EDX       // zero filled field width: 0 for no leading zeros
  CALL    MyCvtInt
  MOV     EDX, ESI
  POP     EAX            // result ptr
  CALL    System.@LStrFromPCharLen
  ADD     ESP, 33
  POP     ESI
end;

*)

function MyIntToStr(Value:DWord; Base:DWord; ThousSep:char;
                     BigChars:boolean; buf:pointer; Digits:byte):pchar;
var a:^byte; i,d:byte;
begin
  if BigChars then BigChars:=boolean($37) else BigChars:=boolean($57);

  a:=buf;
  if ThousSep=#0 then
    repeat
      i:=Value mod Base;
      Value:=Value div Base;
      if i<10 then Inc(i,$30)
      else Inc(i,byte(BigChars));
      a^:=i;
      Dec(a);
    until Value=0
  else
  begin
    d:=0;
    repeat
      if d=3 then
      begin
        a^:=ord(ThousSep);
        Dec(a);
        d:=0;
      end;
      i:=Value mod Base;
      Value:=Value div Base;
      if i<10 then Inc(i,$30)
      else Inc(i,byte(BigChars));
      a^:=i;
      Dec(a);
      Inc(d);
    until Value=0;
  end;

  if Digits>41 then  Digits:=41;
  for i:=uint(buf)-uint(a)+1 to Digits do
  begin
    a^:=ord('0');
    Dec(a);
  end;
  result:=ptr(a);
end;

function RSUIntToStr(Value:DWord; Base:byte = 10; ThousSep:char = #0; BigChars:boolean=true; Digits:int = 0):string;
var buf:array[0..41] of char; a:pchar; i:int;
begin
  result:='';
  if (Base<2) or (Base>36) then
    exit;

  a:=MyIntToStr(Value, Base, ThousSep, BigChars, @buf[41], Digits);
  i:=int(@buf[41])-int(a);
  Inc(a);
  SetLength(result, i);
  CopyMemory(ptr(result), a, i);
end;

function RSIntToStr(Value:int; Base:byte = 10; ThousSep:char = #0; BigChars:boolean=true; Digits:int = 0):string;
var buf:array[0..41] of char; a:pchar; i:int;
begin
  result:='';
  if (Base<2) or (Base>36) then
    exit;

  if Value>=0 then
  begin
    a:=MyIntToStr(Value, Base, ThousSep, BigChars, @buf[41], Digits);
    i:=int(@buf[41])-int(a);
    Inc(a);
  end else
  begin
    a:=MyIntToStr(-Value, Base, ThousSep, BigChars, @buf[41], Digits);
    i:=int(@buf[41])-int(a)+1;
    a^:='-';
  end;
  SetLength(result, i);
  CopyMemory(ptr(result), a, i);
end;

function RSInt64ToStr(Value:Int64; Base:DWord = 10; ThousSep:char = #0; BigChars:boolean=true; Digits:int = 0):string; overload;
var i:LongInt; bo:boolean; a:^byte; d:byte; buf:array[0..84] of char;
begin
  if int(Value) = Value then
  begin
    result:=RSIntToStr(Value, Base, ThousSep, BigChars, Digits);
    exit;
  end else
    if uint(Value) = Value then
    begin
      result:=RSUIntToStr(Value, Base, ThousSep, BigChars, Digits);
      exit;
    end;
  if (Base<2) or (Base>36) then
  begin
    result:='';
    exit;
  end;
  if Value<0 then bo:=true else bo:=false;

  if BigChars then BigChars:=boolean($37) else BigChars:=boolean($57);

  a:=@buf[84];
  if ThousSep=#0 then
    repeat
      a^:=abs(value mod Base);
      value:=value div Base;
      if a^<10 then Inc(a^,$30)
      else Inc(a^,byte(BigChars));
      Dec(a);
    until value=0
  else
  begin
    d:=0;
    repeat
      if d=3 then
      begin
        a^:=ord(ThousSep);
        Dec(a);
        d:=0;
      end;
      a^:=abs(value mod Base);
      value:=value div Base;
      if a^<10 then Inc(a^,$30)
      else Inc(a^,byte(BigChars));
      Inc(d);
      Dec(a);
    until value=0;
  end;

  if Digits>84 then  Digits:=84;
  for i:=uint(@buf[84])-uint(a)+1 to Digits do
  begin
    a^:=ord('0');
    Dec(a);
  end;

  if bo then
  begin
    i:=DWord(@buf[84])-DWord(a)+1;
    a^:=ord('-');
  end else
  begin
    i:=DWord(@buf[84])-DWord(a);
    Inc(a);
  end;
  SetLength(result,i);
  CopyMemory(ptr(result),a,i);
end;



{-------------------------- Int <- Str -----------------------------}

function RSVal(s:string; var i:integer):boolean;
var j:integer;
begin
  val(s, i, j);
  result:= j=0;
end;

function RSValEx(s:string; var i:integer):int;
begin
  val(s, i, result);
end;

function RSStrToInt(const Str:string; Base:DWord = 10; IgnoreChar:char=#0; IgnoreLeadSpaces:boolean=false; IgnoreTrailSpaces:boolean=false):LongInt; overload;
var i:integer; p:pchar;
begin
  p:=ptr(Str);
  result:= RSStrToIntVar(p, @i, Base, IgnoreChar,
                         IgnoreLeadSpaces, IgnoreTrailSpaces);
  case i of
    1: raise Exception.Create(SRSStrToIntEx1);
    2: raise Exception.Create(SRSStrToIntEx2);
    3: raise Exception.Create(SRSStrToIntEx3);
    4,5,6: raise Exception.Create(SRSStrToIntEx4);
  end;
end;

function RSStrToIntEx(const Str:string; var ErrorCode:int; Base:DWord = 10; IgnoreChar:char=#0; IgnoreLeadSpaces:boolean=false; IgnoreTrailSpaces:boolean=false):LongInt; overload;
var p:pchar;
begin
  p:=ptr(Str);
  result:= RSStrToIntVar(p, @ErrorCode, Base, IgnoreChar,
                         IgnoreLeadSpaces, IgnoreTrailSpaces);
end;

function RSStrToIntEx(Str:pchar; ErrorCode:pint; Base:DWord = 10;
  IgnoreChar:char=#0; IgnoreLeadSpaces:boolean=false;
  IgnoreTrailSpaces:boolean=false):LongInt; overload;
begin
  result:= RSStrToIntVar(Str, @ErrorCode, Base, IgnoreChar,
                         IgnoreLeadSpaces, IgnoreTrailSpaces);
end;

function RSStrToIntVar(var Str:pchar; ErrorCode:pint; Base:integer = 10;
  IgnoreChar:char=#0; IgnoreLeadSpaces:boolean=false;
  IgnoreTrailSpaces:boolean=false):LongInt; overload;
label over, done, trail;
var z:int; i,j:uint; neg:boolean; s:pchar;
begin
{ Error Codes:
0:  ok
1:  Empty string (result is 0)
2:  The value is too big (result is a maxum or a minimum integer value)
3:  Wrong Base (result is 0)
4:  String contains wrong chars (result is the valid part of string)
5:  String contains only wrong characters (result is 0)
6:  The value is too big and the string contains wrong chars
                         (result is a maxum or a minimum integer value)
}
  s:=Str;
  if ErrorCode=nil then ErrorCode:=@z;
  ErrorCode^:=0;
  Str:=s;
  result:=0;
  if s=nil then
  begin
    ErrorCode^:=1;
    exit;
  end;
  if (Base<2) or (Base>36) then
  begin
    ErrorCode^:=3;
    exit;
  end;

  if IgnoreLeadSpaces then
    while s^=' ' do Inc(s);

  if s^='-' then
  begin
    neg:=true;
    Inc(s);
  end else
  begin
    neg:=false;
    if s^='+' then Inc(s);
  end;

  if s^='$' then
  begin
    Base:=16;
    Inc(s);
  end;

  i:=0;
  Str:=s;
  if IgnoreChar=#0 then
    while true do
    begin
      j:=CharValues[ord(s^)];
      if j>=uint(Base) then
        goto done;
      i:=i*uint(Base);
      asm
        jo over
      end;
      i:=i+j;
      asm
        jo over
      end;
      Inc(s);
    end
  else
    while true do
    begin
      if s^=IgnoreChar then
      begin
        Inc(s);
        continue;
      end;
      j:=CharValues[ord(s^)];
      if j>=uint(Base) then
        goto done;
      i:=i*uint(Base);
      asm
        jo over
      end;
      i:=i+j;
      asm
        jo over
      end;
      Inc(s);
    end;

over:
  if neg then result:=Low(int)
  else result:=High(int);
  ErrorCode^:=2;

  if IgnoreChar=#0 then
    while true do
    begin
      if CharValues[ord(s^)]>=Base then
        goto trail;
      Inc(s);
    end
  else
    while true do
    begin
      if s^=IgnoreChar then
      begin
        Inc(s);
        continue;
      end;
      if CharValues[ord(s^)]>=Base then
        goto trail;
      Inc(s);
    end;

done:
  if s=Str then // Empty String
  begin
    ErrorCode^:=1;
    goto trail;
  end;

  if neg then
    j:=1
  else
    j:=0;
  if i>uint(High(int))+j then
  begin
    result:=int(j+uint(High(int)));
    ErrorCode^:=2;
  end else
    if neg then
      result:=-int(i)
    else
      result:=i;

trail:
  if IgnoreTrailSpaces then
    while s^=' ' do
      Inc(s);
  if s^<>#0 then
    ErrorCode^:=ErrorCode^ or 4;
  Str:=s;
end;

function RSStrToInt64(const s:string; Base:LongInt = 10; IgnoreChar:char=#0; IgnoreLeadSpaces:boolean=false; IgnoreTrailSpaces:boolean=false):Int64; overload;
var i:integer;
begin
  result:=RSStrToInt64Ex(pointer(s), @i, Base, IgnoreChar,
                                  IgnoreLeadSpaces, IgnoreTrailSpaces);
  case i of
    1: raise Exception.Create(SRSStrToIntEx1);
    2: raise Exception.Create(SRSStrToIntEx2);
    3: raise Exception.Create(SRSStrToIntEx3);
    4,5,6: raise Exception.Create(SRSStrToIntEx4);
  end;
end;

function RSStrToInt64Ex(const s:string; var ErrorCode:int; Base:LongInt = 10; IgnoreChar:char=#0; IgnoreLeadSpaces:boolean=false; IgnoreTrailSpaces:boolean=false):Int64; overload;
begin
  result:=RSStrToInt64Ex(pointer(s), @ErrorCode, Base, IgnoreChar,
                                  IgnoreLeadSpaces, IgnoreTrailSpaces);
end;

function RSStrToInt64Ex(s:pchar; ErrorCode:pint; Base:LongInt = 10; IgnoreChar:char=#0; IgnoreLeadSpaces:boolean=false; IgnoreTrailSpaces:boolean=false):int64; overload;
var z:LongInt; bo:boolean; b:byte; vMax:int64;
begin
{ Error Codes:
0:  ok
1:  Empty string (result is 0)
2:  The value is too big (result is a maxum or a minimum integer value)
3:  Wrong Base (result is 0)
4:  String contains wrong chars (result is the valid part of string)
6:  The value is too big and the string contains wrong chars
                         (result is a maxum or a minimum integer value)
}
  if ErrorCode=nil then ErrorCode:=@z;
  if (s=nil) or (s=#0) then
  begin
    result:=0;
    ErrorCode^:=1;
    exit;
  end;
  if IgnoreChar=' ' then
  begin
    IgnoreLeadSpaces:=true;
    IgnoreTrailSpaces:=false;
  end;
  ErrorCode^:=0;
  if (Base<2) or (Base>36) then
  begin
    result:=0;
    ErrorCode^:=3;
    exit;
  end;
  bo:=false; // Positive
  result:=0;
  if IgnoreLeadSpaces then
    while (s^<>#0) and ((s^=' ') or (s^=IgnoreChar)) do
      Inc(s);

  if s^='-' then
  begin
    bo:=true;
    Inc(s);
  end else
    if s^='+' then Inc(s);

  if s^='$' then
  begin
    Base:=16;
    Inc(s);
  end;

  if bo then vMax:=Low(int64) div Base
  else vMax:=High(int64) div Base;

  if IgnoreChar=#0 then
    if not bo then
      while s^<>#0 do
      begin
        b:=CharValues[ord(s^)];
        if b>=Base then
        begin
          ErrorCode^:=4;
          break;
        end;

        // Range checking doesn't work with int64
        if (result>vMax) or (High(int64)-b<result*Base) then
        begin
          result:=High(int64);
          ErrorCode^:=2;
          break;
        end else
          result:=result*Base+b;

        Inc(s);
      end
    else
      while s^<>#0 do
      begin
        b:=CharValues[ord(s^)];
        if b>=Base then
        begin
          ErrorCode^:=4;
          break;
        end;

        // Range checking doesn't work with int64
        if (result<vMax) or (Low(int64)+b>result*Base) then
        begin
          result:=Low(int64);
          ErrorCode^:=2;
          break;
        end else
          result:=result*Base-b;

        Inc(s);
      end
  else
    if not bo then
      while s^<>#0 do
      begin
        if s^=IgnoreChar then
        begin
          Inc(s);
          continue;
        end;
        b:=CharValues[ord(s^)];
        if b>=Base then
        begin
          ErrorCode^:=4;
          break;
        end;

        // Range checking doesn't work with int64
        if (result>vMax) or (High(int64)-b<result*Base) then
        begin
          result:=High(int64);
          ErrorCode^:=2;
          break;
        end else
          result:=result*Base+b;

        Inc(s);
      end
    else
      while s^<>#0 do
      begin
        if s^=IgnoreChar then
        begin
          Inc(s);
          continue;
        end;
        b:=CharValues[ord(s^)];
        if b>=Base then
        begin
          ErrorCode^:=4;
          break;
        end;

        // Range checking doesn't work with int64
        if (result<vMax) or (Low(int64)+b>result*Base) then
        begin
          result:=Low(int64);
          ErrorCode^:=2;
          break;
        end else
          result:=result*Base-b;

        Inc(s);
      end;

//  if (ErrorCode^<>0) and (ErrorCode^<>2) then exit;
  if ErrorCode^=4 then exit;

  if ErrorCode^=2 then
    while s^<>#0 do
    begin
      if s^=IgnoreChar then
      begin
        Inc(s);
        continue;
      end;

      b:=CharValues[ord(s^)];
      if b>=Base then
        if (s^=' ') and IgnoreTrailSpaces then break
        else begin
          ErrorCode^:=6;
          exit;
        end;
      Inc(s);
    end;

  if IgnoreTrailSpaces then
    while s^<>#0 do
      if (s^=IgnoreChar) or (s^=' ') then
        Inc(s)
      else begin
        ErrorCode^:=ErrorCode^ or 4;
        exit;
      end;
end;

function RSStrToInt64Var(var s:pchar; ErrorCode:pint; Base:LongInt = 10; IgnoreChar:char=#0; IgnoreLeadSpaces:boolean=false; IgnoreTrailSpaces:boolean=false):int64; overload;
var z:LongInt; bo:boolean; b:byte; vMax:int64;
begin
{ Error Codes:
0:  ok
1:  Empty string (result is 0)
2:  The value is too big (result is a maxum or a minimum integer value)
3:  Wrong Base (result is 0)
4:  String contains wrong chars (result is the valid part of string)
6:  The value is too big and the string contains wrong chars
                         (result is a maxum or a minimum integer value)
}
  if ErrorCode=nil then ErrorCode:=@z;
  if (s=nil) or (s^=#0) then
  begin
    result:=0;
    ErrorCode^:=1;
    exit;
  end;
  if IgnoreChar=' ' then
  begin
    IgnoreLeadSpaces:=true;
    IgnoreTrailSpaces:=false;
  end;
  ErrorCode^:=0;
  if (Base<2) or (Base>36) then
  begin
    result:=0;
    ErrorCode^:=3;
    exit;
  end;
  bo:=false; // Positive
  result:=0;
  if IgnoreLeadSpaces then
    while (s^<>#0) and ((s^=' ') or (s^=IgnoreChar)) do
      Inc(s);

  if s^='-' then
  begin
    bo:=true;
    Inc(s);
  end else
    if s^='+' then Inc(s);

  if s^='$' then
  begin
    Base:=16;
    Inc(s);
  end;

  if bo then vMax:=Low(int64) div Base
  else vMax:=High(int64) div Base;

  if IgnoreChar=#0 then
    if not bo then
      while s^<>#0 do
      begin
        b:=CharValues[ord(s^)];
        if b>=Base then
        begin
          ErrorCode^:=4;
          break;
        end;

        // Range checking doesn't work with int64
        if (result>vMax) or (High(int64)-b<result*Base) then
        begin
          result:=High(int64);
          ErrorCode^:=2;
          break;
        end else
          result:=result*Base+b;

        Inc(s);
      end
    else
      while s^<>#0 do
      begin
        b:=CharValues[ord(s^)];
        if b>=Base then
        begin
          ErrorCode^:=4;
          break;
        end;

        // Range checking doesn't work with int64
        if (result<vMax) or (Low(int64)+b>result*Base) then
        begin
          result:=Low(int64);
          ErrorCode^:=2;
          break;
        end else
          result:=result*Base-b;

        Inc(s);
      end
  else
    if not bo then
      while s^<>#0 do
      begin
        if s^=IgnoreChar then
        begin
          Inc(s);
          continue;
        end;
        b:=CharValues[ord(s^)];
        if b>=Base then
        begin
          ErrorCode^:=4;
          break;
        end;

        // Range checking doesn't work with int64
        if (result>vMax) or (High(int64)-b<result*Base) then
        begin
          result:=High(int64);
          ErrorCode^:=2;
          break;
        end else
          result:=result*Base+b;

        Inc(s);
      end
    else
      while s^<>#0 do
      begin
        if s^=IgnoreChar then
        begin
          Inc(s);
          continue;
        end;
        b:=CharValues[ord(s^)];
        if b>=Base then
        begin
          ErrorCode^:=4;
          break;
        end;

        // Range checking doesn't work with int64
        if (result<vMax) or (Low(int64)+b>result*Base) then
        begin
          result:=Low(int64);
          ErrorCode^:=2;
          break;
        end else
          result:=result*Base-b;

        Inc(s);
      end;

//  if (ErrorCode^<>0) and (ErrorCode^<>2) then exit;
  if ErrorCode^=4 then exit;

  if ErrorCode^=2 then
    while s^<>#0 do
    begin
      if s^=IgnoreChar then
      begin
        Inc(s);
        continue;
      end;

      b:=CharValues[ord(s^)];
      if b>=Base then
        if (s^=' ') and IgnoreTrailSpaces then break
        else begin
          ErrorCode^:=6;
          exit;
        end;
      Inc(s);
    end;

  if IgnoreTrailSpaces then
    while s^<>#0 do
      if (s^=IgnoreChar) or (s^=' ') then
        Inc(s)
      else begin
        ErrorCode^:=ErrorCode^ or 4;
        exit;
      end;
end;

function RSStrToIntFloatVar(var s:pchar; ErrorCode:pint; Base:LongInt = 10; IgnoreChar:char=#0; IgnoreLeadSpaces:boolean=false; IgnoreTrailSpaces:boolean=false):extended; overload;
var z, sgn:LongInt; b:byte;
begin
{ Error Codes:
0:  ok
1:  Empty string (result is 0)
3:  Wrong Base (result is 0)
4:  String contains wrong chars (result is the valid part of string)
}
  if ErrorCode=nil then ErrorCode:=@z;
  if (s=nil) or (s=#0) then
  begin
    result:=0;
    ErrorCode^:=1;
    exit;
  end;
  if IgnoreChar=' ' then
  begin
    IgnoreLeadSpaces:=true;
    IgnoreTrailSpaces:=false;
  end;
  ErrorCode^:=0;
  if (Base<2) or (Base>36) then
  begin
    result:=0;
    ErrorCode^:=3;
    exit;
  end;
  sgn:=1; // Positive
  result:=0;
  if IgnoreLeadSpaces then
    while (s^<>#0) and ((s^=' ') or (s^=IgnoreChar)) do
      Inc(s);

  if s^='-' then
  begin
    sgn:=-1;
    Inc(s);
  end else
    if s^='+' then Inc(s);

  if s^='$' then
  begin
    Base:=16;
    Inc(s);
  end;

  if IgnoreChar=#0 then
    while s^<>#0 do
    begin
      b:=CharValues[ord(s^)];
      if b>=Base then
      begin
        ErrorCode^:=4;
        exit;
      end;
      result:=result*Base + sgn*b;
      Inc(s);
    end
  else
    while s^<>#0 do
    begin
      if s^=IgnoreChar then
      begin
        Inc(s);
        continue;
      end;
      b:=CharValues[ord(s^)];
      if b>=Base then
      begin
        ErrorCode^:=4;
        exit;
      end;

      result:=result*Base+sgn*b;

      Inc(s);
    end;

  if IgnoreTrailSpaces then
    while s^<>#0 do
      if (s^=IgnoreChar) or (s^=' ') then
        Inc(s)
      else begin
        ErrorCode^:=ErrorCode^ or 4;
        exit;
      end;
end;

function RSCharToInt(c:char; Base:LongInt=36):LongInt;
begin
  result:=CharValues[ord(c)];
  if result>=Base then result:=-1;
end;

function RSFloatToStr(const Value:extended):string;
begin
  result:=FloatToStrF(Value, ffGeneral, 18, 0);
end;

function RSStrToFloat(s:string):extended;
begin
  result:= StrToFloat(RSStringReplace(s, '.', DecimalSeparator,[rfReplaceAll]));
end;

function InitCharToInt(c:char; Base:LongInt=36):LongInt;
begin
  result:=ord(c);
  if (result>=$30) and (result<=$39) then Dec(result,$30) else
  if (result>=$41) and (result<=$5a) then Dec(result,$37) else
  if (result>=$61) and (result<=$7a) then Dec(result,$57) else
  begin
    result:=-1;
    exit;
  end;
  if result>=Base then result:=-1;
end;

var i:LongInt;
initialization
  for i:=0 to 255 do
    CharValues[i]:=byte(smallInt(InitCharToInt(chr(i))));

end.
