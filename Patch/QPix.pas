unit QPix;
// Fast access to TBitmap pixels
// © Boris Novgorodov, Novosibirsk, mbo@mail.ru
// Alexey Radionov, Ulyanovsk
// 2003
// Sergey Rozhenko, Novosibirsk, sergroj@mail.ru
{$I RSPak.inc}

interface

uses Windows, Graphics;

type
  TLogPal = packed record
    palVersion: word;
    palNumEntries: word;
    palPalEntry: packed array[0..255] of TPaletteEntry;
  end;

  TGetPixelsMethod = function(X, Y: integer): TColor of object;
  TGetQPixelsMethod = function(X, Y: integer): LongInt of object;

  TQuickPixels = class
  private
    FBitmap: TBitmap;
    FWidth, FHeight: integer;
    FBPP: integer;
    FStart: integer;
    FDelta: integer;
    FPixelFormat: TPixelFormat;
    FLogPal: TLogPal;
    FHPal: HPalette;
    FLastIndex: integer;
    FLastColor: TColor;
    FTrackBitmapChange: boolean;
    FSetPixel: pointer;
    FGetPixel: pointer;
    FSetQPixel: pointer;
    FGetQPixel: pointer;

    function GetPixels(X, Y: integer): TColor;
    function GetQPixels(X, Y: integer): LongInt;

    function GetPixels1(X, Y: integer): TColor;
    function GetQPixels1(X, Y: integer): LongInt;
    function GetPixels4(X, Y: integer): TColor;
    function GetQPixels4(X, Y: integer): LongInt;
    function GetPixels8(X, Y: integer): TColor;
    function GetQPixels8(X, Y: integer): LongInt;
    function GetPixels15(X, Y: integer): TColor;
    function GetQPixels15(X, Y: integer): LongInt;
    function GetPixels16(X, Y: integer): TColor;
    function GetQPixels16(X, Y: integer): LongInt;
    function GetPixels24(X, Y: integer): TColor;
    function GetQPixels24(X, Y: integer): LongInt;
    function GetPixels32(X, Y: integer): TColor;
    function GetQPixels32(X, Y: integer): LongInt;

    procedure SetPixels1(X, Y: integer{; const Value: TColor});
    procedure SetQPixels1(X, Y: integer{; const Value: LongInt});
    procedure SetPixels4(X, Y: integer{; const Value: TColor});
    procedure SetQPixels4(X, Y: integer{; const Value: LongInt});
    procedure SetPixels8(X, Y: integer{; const Value: TColor});
    procedure SetQPixels8(X, Y: integer{; const Value: LongInt});
    procedure SetPixels15(X, Y: integer{; const Value: TColor});
    procedure SetQPixels15(X, Y: integer{; const Value: LongInt});
    procedure SetPixels16(X, Y: integer{; const Value: TColor});
    procedure SetQPixels16(X, Y: integer{; const Value: LongInt});
    procedure SetPixels24(X, Y: integer{; const Value: TColor});
    procedure SetQPixels24(X, Y: integer{; const Value: LongInt});
    procedure SetPixels32(X, Y: integer{; const Value: TColor});
    procedure SetQPixels32(X, Y: integer{; const Value: LongInt});

    procedure SetBPP(const Value: integer);
    procedure SetTrackBitmapChange(const Value: boolean);
    procedure BitmapChange(Sender: TObject);
  public

    GetPixel:TGetPixelsMethod;
    GetQPixel:TGetQPixelsMethod;
    procedure SetPixel(X, Y: integer; const Value: TColor);
    procedure SetQPixel(X, Y: integer; const Value: LongInt);

    constructor Create(Bmp:TBitmap=nil; ConvertToDIB:boolean=false);
    destructor Destroy; override;

    //установка соединения объекта с растром (DIB!)
    procedure Attach(Bmp: TBitmap; ConvertToDIB:boolean=false);

    //вспомог. функция для получения цвета из палитры
    function PalIndex(const Color: TColor): integer;

    property Width: integer read FWidth;
    property Height: integer read FHeight;

    //BitsPerPixel
    property BPP: integer read FBPP;

    //основное свойство для доступа к растру
    property Pixels[X, Y: integer]: TColor read GetPixels write SetPixel;
    default;

    //прямой доступ к пикселям - цвет из палитры, перевернутый цвет и т.д.
    property QPixels[X, Y: integer]: LongInt read GetQPixels write SetQPixel;

    //позволяет отслеживать изменения критических для доступа параметров растра:
    //размеров и цветового формата
    property TrackBitmapChange: boolean read FTrackBitmapChange write
      SetTrackBitmapChange;
  end;

implementation

{ TQuickPixels }

{$W-}

constructor TQuickPixels.Create(Bmp:TBitmap=nil; ConvertToDIB:boolean=false);
begin
  if Bmp<>nil then Attach(Bmp, ConvertToDIB);
end;

destructor TQuickPixels.Destroy;
begin
  if (FBitmap<>nil) and FTrackBitmapChange then
    FBitmap.OnChange:=nil;
  if FHPal <> 0 then
    DeleteObject(FHPal);
  inherited;
end;

procedure TQuickPixels.Attach(Bmp: TBitmap; ConvertToDIB:boolean=false);
type
  TAlignedDib = record // Workaround for packed records misaligment
    case integer of
      1: (AlignDummy: Longint);
      2: (ds: TDibSection);
  end;
var
  DS: TAlignedDib;
begin
  if ConvertToDIB then
    Bmp.HandleType:=bmDIB
  else
    Assert(Bmp.HandleType=bmDIB, 'The HandleType must be bmDIB');
  if (FBitmap<>nil) and FTrackBitmapChange then
    FBitmap.OnChange:=nil;
  FBPP := 0;
  FBitmap := Bmp;
  FWidth := FBitmap.Width;
  FHeight := FBitmap.Height;
  FPixelFormat := FBitmap.PixelFormat;
  case FPixelFormat of
    // для подобных режимов все просто
    pf1bit: SetBPP(1);
    pf4bit: SetBPP(4);
    pf8bit: SetBPP(8);
    pf15bit: SetBPP(15);
    pf16bit: SetBPP(16);
    pf24bit: SetBPP(24);
    pf32bit: SetBPP(32);
    pfCustom:
    // а здесь проведем небольшое исследование
      begin
        if GetObject(FBitmap.Handle, sizeof(DS), @DS) <> 0 then
        // получим информационный заголовок растра
          with DS.ds, dsBmih do
            case biBitCount of
              16: case biCompression of
                  BI_RGB: SetBPP(15);
                  BI_BITFIELDS:
        // анализируем стандартные маски доступа к цветовым составляющим
                    begin
                      if dsBitFields[1] = $7E0 then
                        SetBPP(16);
                      if dsBitFields[1] = $3E0 then
                        SetBPP(15);
                    end;
                end;
              32: case biCompression of
                  BI_RGB: SetBPP(32);
                  BI_BITFIELDS: if dsBitFields[1] = $FF0000 then
                      SetBPP(32);
                end;
            end;
      end;
  end;
  Assert(FBPP > 0, 'Bitmap format is not supported');
  if FHPal <> 0 then
    DeleteObject(FHPal);
  if FBPP <= 8 then
  begin
    //скопируем палитру во внутреннее поле, чтобы не обращаться к FBitmap:
    FLogPal.palVersion := $300;
    FLogPal.palNumEntries := 1 shl FBPP;
    GetPaletteEntries(FBitmap.Palette, 0, FLogPal.palNumEntries,
      FLogPal.palPalEntry[0]);
    // создадим для данной логической палитры и HPalette, что нам потребуется
    //при поиске ближайшего цвета
    FHPal := CreatePalette(PLogPalette(@FLogPal)^);
    FLastColor := $7FFFFFF;
  end;
  //базовый адрес блока данных
  if FHeight>0 then
    FStart := integer(FBitmap.Scanline[0])
  else
    FStart:=0;
  //разность между адресами соседних строк развертки растра (обычно отриц.)
  if FHeight>1 then
    FDelta := integer(FBitmap.Scanline[1]) - FStart
  else
    FDelta:=0;
  if FTrackBitmapChange then
    FBitmap.OnChange := BitmapChange;
end;

procedure TQuickPixels.SetPixels1(X, Y: integer{; const Value: TColor});
asm
  push ebx
  push esi
  mov esi,[ebp+8]   //цвет
  cmp esi,[eax].FLastColor
  //проверка, не использовался ли в прошлый раз этот же цвет
  jz @@TheSame
  //нет - ищем ближайший в палитре
  mov [eax].FLastColor,esi    //запомним цвет
  push ecx
  push edx
  push eax
  push esi
  mov eax,[eax].FHPal
  push eax
  call GetNearestPaletteIndex
  mov ebx,eax
  pop eax
  pop edx
  pop ecx
  mov [eax].FLastIndex,ebx
  jmp @@SetCol
@@TheSame:
  //да - используем сохраненный индекс
  mov ebx,[eax].FLastIndex
@@SetCol:
  mov esi,[eax].FDelta
  imul esi,ecx
  add esi,[eax].FStart
  mov eax,edx
  shr eax, 3   //X div 8
  add esi,eax  //адрес нужного байта FStart + FDelta * Y + (X Div 8);
  mov eax,[esi] //получили байт с данными о 8 точках
  mov ecx,edx
  and ecx, 7   //X mod 8
  mov edx, $80
  shr edx,cl   //маска для нужного бита
  or ebx,ebx
  jz @@IsZero
  or eax,edx   //установка бита в 1
  jmp @@SetByte
@@IsZero:
  not edx
  and eax,edx  //сброс бита в 0
@@SetByte:
  mov [esi],al   //запись байта с измененной точкой
  pop esi
  pop ebx
  pop ebp
  ret 4
end;

procedure TQuickPixels.SetQPixels1(X, Y: integer{; const Value: LongInt});
asm
  push ebx
  push esi
  mov ebx,[ebp+8]
  mov esi,[eax].FDelta
  imul esi,ecx
  add esi,[eax].FStart
  mov eax,edx
  shr eax, 3
  add esi,eax
  mov eax,[esi]
  mov ecx,edx
  and ecx, 7
  mov edx, $80
  shr edx,cl
  or ebx,ebx
  jz @@IsZero
  or eax,edx
  jmp @@SetByte
@@IsZero:
  not edx
  and eax,edx
@@SetByte:
  mov [esi],al
  pop esi
  pop ebx
  pop ebp
  ret 4
end;

procedure TQuickPixels.SetPixels4(X, Y: integer{; const Value: TColor});
asm
  push esi
  mov esi,ecx
  push ebx
  imul esi, [eax].FDelta
  mov ecx,[ebp+8]
  mov ebx,[eax].FLastIndex  //сохраненный индекс
  add esi,[eax].FStart
  cmp ecx, [eax].FLastColor
  jz @@SetCol
  mov [eax].FLastColor,ecx
  mov ebx,eax    //сохраним Self
  push edx
  push ecx
  push [eax].FHPal
  call GetNearestPaletteIndex
  xchg ebx,eax     //в EBX - найденный индекс цвета
  pop edx
  mov [eax].FLastIndex,ebx
@@SetCol:
  shr edx, 1      //X div 2
  mov ecx, $F0
  lea esi,[esi+edx]   //FStart + FDelta * Y + (X Div 2);
  jc @@SetByte
  //флаг переноса, свидетельствующий о нечетности,
  // устанавливается при выполнении shr
  mov ecx, $0f
  shl ebx, 4 //для четных точек устанавливаем старший полубайт
@@SetByte:
  mov eax,[esi]  //в AL - исходный байт, соотв. двум точкам
  and eax,ecx    //обнулим устанавливаемый полубайт
  or eax,ebx     //установим новое значение этого полубайта
  pop ebx
  mov [esi],al   //вернем измененный байт на свое место
  pop esi
  pop ebp
  ret 4
end;

procedure TQuickPixels.SetQPixels4(X, Y: integer{; const Value: LongInt});
asm
  push ebx
  push esi
  mov ebx,[ebp+8]
  mov esi,[eax].FDelta
  imul esi,ecx
  add esi,[eax].FStart
  mov eax,edx
  shr eax, 1
  add esi,eax
  mov eax,[esi]
  and edx, 1
  jz @@IsEven
  and eax, $F0
  or eax,ebx
  jmp @@SetByte
@@IsEven:
  and eax, $0F
  shl ebx, 4
  or eax,ebx
@@SetByte:
  mov [esi],al
  pop esi
  pop ebx
  pop ebp
  ret 4
end;

procedure TQuickPixels.SetPixels8(X, Y: integer{; const Value: TColor});
asm
  push ebx
  push esi
  imul ecx,[eax].FDelta
  mov esi,[ebp+8]  //Value
  add ecx,[eax].FStart    //FStart + FDelta * Y
  cmp esi,[eax].FLastColor
  jz @@TheSame
  mov [eax].FLastColor,esi  //запомним цвет
  push ecx
  push edx
  push eax
  push esi
  mov eax,[eax].FHPal
  push eax
  //сохраняем регистры, нужные для вызова функции параметра укладываем в стек
  //в порядке, необходимом для соглашения stdcall
  call GetNearestPaletteIndex
  mov ebx,eax  //результат функции - индекс цвета
  pop eax
  pop edx
  pop ecx
  mov [eax].FLastIndex,ebx  //запомним индекс последнего цвета
  jmp @@SetCol
@@TheSame:
  mov ebx,[eax].FLastIndex
  //цвет с прошлого вызова остался таким же, индекс его уже хранится в поле FLastIndex
@@SetCol:
  pop esi
  mov [ecx+edx],bl
  //запишем байт индекса по вычисленному ранее адресу + X
  pop ebx
  pop ebp
  ret 4
end;

procedure TQuickPixels.SetQPixels8(X, Y: integer{; const Value: LongInt});
asm
  imul ecx,[eax].FDelta
  add ecx,[eax].FStart
  mov eax,[ebp+8]
  mov [ecx+edx], al   //PByte(FStart + FDelta * Y + X)^ := Value (т.е. индекс)
  pop ebp
  ret 4
end;

procedure TQuickPixels.SetPixels15(X, Y: integer{; const Value: TColor});
//PWord(FStart + FDelta * Y + (X Shl 1))^ :=
//((Value And $F8) Shl 7) or ((Value And $F800) Shr 6) or
//((Value And $FF0000) Shr 19);
asm
  imul ecx,[eax].FDelta
  add ecx,[eax].FStart
  mov eax,[ebp+$08]  //Value
  push esi
  mov esi,eax        //Value
  and esi, $F8       //маска
  shl esi, 7
  push edi
  mov edi,eax
  and edi, $F800
  shr edi, 6
  or esi,edi
  pop edi
  and eax, $FF0000
  shr eax, 19
  or eax,esi
  mov [ecx+edx*2],ax
  pop esi
  pop ebp
  ret 4
end;

procedure TQuickPixels.SetQPixels15(X, Y: integer{; const Value: LongInt});
//PWord(FStart + FDelta * Y + (X Shl 1))^ :=  word(Value);
asm
  imul ecx,[eax].FDelta
  add ecx,[eax].FStart
  mov eax,[ebp+$08]  //Value
  mov [ecx+edx*2],ax
  pop ebp
  ret 4
end;

procedure TQuickPixels.SetPixels16(X, Y: integer{; const Value: TColor});
//PWord(FStart + FDelta * Y + (X Shl 1))^ :=
//((Value And $F8) Shl 8) or ((Value And $FC00) Shr 5)
//or ((Value And $FF0000) Shr 19);
asm
  imul ecx,[eax].FDelta
  add ecx,[eax].FStart
  mov eax,[ebp+$08]  //Value
  push esi
  mov esi,eax
  and esi, $F8       //маска
  shl esi, 8
  push edi
  mov edi,[ebp+$08]
  and edi, $FC00
  shr edi, 5
  or esi,edi
  pop edi
  and eax, $FF0000
  shr eax, 19
  or eax,esi
  mov [ecx+edx*2],ax
  pop esi
  pop ebp
  ret 4
end;

procedure TQuickPixels.SetQPixels16(X, Y: integer{; const Value: LongInt});
//PWord(FStart + FDelta * Y + (X Shl 1))^ :=  word(Value);
asm
  imul ecx,[eax].FDelta
  add ecx,[eax].FStart
  mov eax,[ebp+$08]  //Value
  mov [ecx+edx*2],ax
  pop ebp
  ret 4
end;

procedure TQuickPixels.SetPixels24(X, Y: integer{; const Value: TColor});
//PRGBTriple(FStart + FDelta * Y + 3 * X)^ := PRGBTriple(@i)^
asm
  imul ecx,[eax].FDelta
  add ecx,[eax].FStart
  lea edx,[edx+edx*2]
  mov eax,[ebp+8]  //Value
  bswap eax
  shr eax, 8
  mov [ecx+edx],ax
  shr eax, 16
  mov [ecx+edx+2],al
  pop ebp
  ret 4
end;

procedure TQuickPixels.SetQPixels24(X, Y: integer{; const Value: LongInt});
//PRGBTriple(FStart + FDelta * Y + 3 * X)^ := PRGBTriple(@i)^
asm
  imul ecx,[eax].FDelta
  add ecx,[eax].FStart
  lea edx,[edx+edx*2]
  mov eax,[ebp+8]  //Value
  mov [ecx+edx],ax
  shr eax, 16
  mov [ecx+edx+2],al
  pop ebp
  ret 4
end;

procedure TQuickPixels.SetPixels32(X, Y: integer{; const Value: TColor});
//PInteger(FStart + FDelta * Y + (X Shl 2))^ := SwappedValue
asm
  imul ecx,[eax].FDelta
  add ecx,[eax].FStart
  mov eax, [ebp+8]
  bswap eax
  shr eax, 8
  mov [ecx+4*edx],eax
  pop ebp
  ret 4
end;

procedure TQuickPixels.SetQPixels32(X, Y: integer{; const Value: LongInt});
//PInteger(FStart + FDelta * Y + (X Shl 2))^ := SwappedValue
asm
  imul ecx,[eax].FDelta
  add ecx,[eax].FStart
  mov eax, [ebp+8]
  mov [ecx+4*edx],eax
  pop ebp
  ret 4
end;

function TQuickPixels.GetPixels(X, Y: integer): TColor;
asm
  jmp [eax].FGetPixel
end;

function TQuickPixels.GetQPixels(X, Y: integer): LongInt;
asm
  jmp [eax].FGetQPixel
end;

{$W+} // На всякий случай

procedure TQuickPixels.SetPixel(X, Y: integer; const Value: TColor);
asm
  // pop ebp будет сделан потом
  jmp [eax].FSetPixel
end;

procedure TQuickPixels.SetQPixel(X, Y: integer; const Value: LongInt);
asm
  // pop ebp будет сделан потом
  jmp [eax].FSetQPixel
end;

{$W-}

procedure TQuickPixels.SetBPP(const Value: integer);
begin
  FBPP := Value;
  case FBPP of
    1:
    begin
      FSetQPixel := @TQuickPixels.SetQPixels1;
      FGetQPixel := @TQuickPixels.GetQPixels1;
      FSetPixel := @TQuickPixels.SetPixels1;
      FGetPixel := @TQuickPixels.GetPixels1;
      GetPixel := GetPixels1;
      GetQPixel := GetQPixels1;
    end;
    4:
    begin
      FSetQPixel := @TQuickPixels.SetQPixels4;
      FGetQPixel := @TQuickPixels.GetQPixels4;
      FSetPixel := @TQuickPixels.SetPixels4;
      FGetPixel := @TQuickPixels.GetPixels4;
      GetPixel := GetPixels4;
      GetQPixel := GetQPixels4;
    end;
    8:
    begin
      FSetQPixel := @TQuickPixels.SetQPixels8;
      FGetQPixel := @TQuickPixels.GetQPixels8;
      FSetPixel := @TQuickPixels.SetPixels8;
      FGetPixel := @TQuickPixels.GetPixels8;
      GetPixel := GetPixels8;
      GetQPixel := GetQPixels8;
    end;
    15:
    begin
      FSetQPixel := @TQuickPixels.SetQPixels15;
      FGetQPixel := @TQuickPixels.GetQPixels15;
      FSetPixel := @TQuickPixels.SetPixels15;
      FGetPixel := @TQuickPixels.GetPixels15;
      GetPixel := GetPixels15;
      GetQPixel := GetQPixels15;
    end;
    16:
    begin
      FSetQPixel := @TQuickPixels.SetQPixels16;
      FGetQPixel := @TQuickPixels.GetQPixels16;
      FSetPixel := @TQuickPixels.SetPixels16;
      FGetPixel := @TQuickPixels.GetPixels16;
      GetPixel := GetPixels16;
      GetQPixel := GetQPixels16;
    end;
    24:
    begin
      FSetQPixel := @TQuickPixels.SetQPixels24;
      FGetQPixel := @TQuickPixels.GetQPixels24;
      FSetPixel := @TQuickPixels.SetPixels24;
      FGetPixel := @TQuickPixels.GetPixels24;
      GetPixel := GetPixels24;
      GetQPixel := GetQPixels24;
    end;
    32:
    begin
      FSetQPixel := @TQuickPixels.SetQPixels32;
      FGetQPixel := @TQuickPixels.GetQPixels32;
      FSetPixel := @TQuickPixels.SetPixels32;
      FGetPixel := @TQuickPixels.GetPixels32;
      GetPixel := GetPixels32;
      GetQPixel := GetQPixels32;
    end;
  end;
end;

function TQuickPixels.PalIndex(const Color: TColor): integer;
asm
  push edx
  mov eax,[eax].FHPal
  push eax
  call GetNearestPaletteIndex
end;

function TQuickPixels.GetPixels1(X, Y: integer): TColor;
asm
  push ebx
  mov ebx,edx   //X
  imul ecx,[eax].FDelta
  add ecx,[eax].FStart
  shr edx,3     //X div 8
  movzx edx, byte PTR [ecx+edx ]
  //в DL теперь байт, соответствующий 8 точкам
  mov ecx,ebx
  and ecx,7     //X mod 8
  mov ebx,edx
  mov edx,$80   //1000000b
  shr edx,cl    //сдвигаем единичку вправо на X mod 8
  and ebx,edx   //накладываем маску
  pop ebx
  jz @@Zero     //если нужный бит нулевой, выставлен флаг ZF
  mov eax, DWORD PTR [eax+8].FLogPal  //бит единичный, берем из палитры 1-й цвет
  jmp @@exit
@@Zero:
  mov eax, DWORD PTR [eax+4].FLogPal  //берем из палитры 0-й цвет
@@exit:
end;

function TQuickPixels.GetQPixels1(X, Y: integer): LongInt;
asm
  push edx
  imul ecx,[eax].FDelta
  add ecx,[eax].FStart
  shr edx,3
  movzx eax, byte PTR [ecx+edx]
  pop ecx
  and ecx,7
  shl eax,cl
  shr eax,7
  and eax,1
end;

function TQuickPixels.GetPixels15(X, Y: integer): TColor;
asm
  imul ecx,[eax].FDelta
  add ecx,[eax].FStart
  movzx eax,word ptr [ecx+2*edx]  //PWord(FStart + FDelta * Y + (X * 2))^
  mov ecx,eax
  and ecx,$1F       //5 бит Blue
  imul ecx,541052   //масштабирование
  and ecx,$FF0000   //маска Blue

  mov edx,eax
  and edx,$3E0      //5 бит Green
  imul edx,135263
  shr edx,19
  shl edx,8         

  and eax,$7C00
  imul eax,135263   //5 бит Red
  shr eax,24

  or eax,ecx
  or eax,edx
end;

function TQuickPixels.GetQPixels15(X, Y: integer): LongInt;
asm
  imul ecx,[eax].FDelta
  add ecx,[eax].FStart
  movzx eax,word ptr [ecx+2*edx]  //PWord(FStart + FDelta * Y + (X * 2))^
end;

function TQuickPixels.GetPixels16(X, Y: integer): TColor;
asm
  imul ecx,[eax].FDelta
  add ecx,[eax].FStart
  movzx eax,word ptr [ecx+2*edx]  //PWord(FStart + FDelta * Y + (X * 2))^
  mov ecx,eax
  and ecx,$1F       //5 бит Blue
  imul ecx,541052   //масштабирование
  and ecx,$FF0000   //маска Blue

  mov edx,eax
  and edx,$7E0      //6 бит Green
  imul edx,65
  shr edx,9
  shl edx,8

  and eax,$F800
  imul eax,33       //5 бит Red
  shr eax,13

  or eax,ecx
  or eax,edx
end;

function TQuickPixels.GetQPixels16(X, Y: integer): LongInt;
asm
  imul ecx,[eax].FDelta
  add ecx,[eax].FStart
  movzx eax,word ptr [ecx+2*edx]  //PWord(FStart + FDelta * Y + (X * 2))^
end;

function TQuickPixels.GetPixels24(X, Y: integer): TColor;
//PRGBTriple(@i)^ := PRGBTriple(FStart + FDelta * Y + 3 * X)^;
asm
  imul ecx,[eax].FDelta
  add ecx,[eax].FStart
  add ecx,edx
  movzx eax,word PTR [ecx+2*edx]
  bswap eax
  shr eax,8
  movzx ecx, byte PTR [ecx+2*edx+2]
  or eax,ecx
end;

function TQuickPixels.GetQPixels24(X, Y: integer): LongInt;
//PRGBTriple(@i)^ := PRGBTriple(FStart + FDelta * Y + 3 * X)^;
asm
  imul ecx,[eax].FDelta
  add ecx,[eax].FStart
  add ecx,edx
  movzx eax,word PTR [ecx+2*edx]
  movzx ecx, byte PTR [ecx+2*edx+2]
  shl ecx,16
  or eax,ecx
end;

function TQuickPixels.GetPixels32(X, Y: integer): TColor;
//SwappedValue := PInteger(FStart + FDelta * Y + 4 * X )^;
asm
  imul ecx,[eax].FDelta
  add ecx,[eax].FStart
  mov eax,[ecx+4*edx]
  bswap eax
  shr eax, 8
end;

function TQuickPixels.GetQPixels32(X, Y: integer): LongInt;
//SwappedValue := PInteger(FStart + FDelta * Y + 4 * X )^;
asm
  imul ecx,[eax].FDelta
  add ecx,[eax].FStart
  mov eax,[ecx+4*edx]
end;

function TQuickPixels.GetPixels4(X, Y: integer): TColor;
asm
  imul ecx,[eax].FDelta
  add ecx,[eax].FStart  //в ECX теперь номер цвета в палитре
  shr edx,1     //X div 2
  movzx ecx, byte PTR [ecx+edx]
  jnc @@IsEven
  //флаг переноса CF установлен при выполнении Shr,
  //если младший бит был единичным, т.е. X нечетно
  and ecx,$0F    //маска младшего полубайта
  jmp @@GetCol
@@IsEven:
  shr ecx,4      //старший полубайт, сдвинутый вправо
@@GetCol:
  mov eax, DWORD PTR [eax+ecx*4+4].FLogPal
  //Self + смещение поля FLogPal + смещение массива цветов + номер цвета*4
  //(4 = SizeOf(TPaletteEntry))

end;

function TQuickPixels.GetQPixels4(X, Y: integer): LongInt;
asm
  imul ecx,[eax].FDelta
  add ecx,[eax].FStart  //в ECX теперь номер цвета в палитре
  shr edx,1
  movzx eax, byte PTR [ecx+edx]
  jnc @@IsEven
  and eax,$0F
  jmp @@exit
@@IsEven:
  shr eax,4
@@exit:
end;

function TQuickPixels.GetPixels8(X, Y: integer): TColor;
asm
  imul ecx,[eax].FDelta
  add ecx,[eax].FStart  //в ECX теперь номер цвета в палитре
  movzx ecx, byte PTR [ecx+edx]
  mov eax, DWORD PTR [eax+ecx*4+4].FLogPal
end;

function TQuickPixels.GetQPixels8(X, Y: integer): LongInt;
asm
  imul ecx,[eax].FDelta
  add ecx,[eax].FStart
  movzx eax, byte PTR [ecx+edx]
end;

procedure TQuickPixels.SetTrackBitmapChange(const Value: boolean);
begin
  FTrackBitmapChange := Value;
  if Assigned(FBitmap) then
    if FTrackBitmapChange then
      FBitmap.OnChange := BitmapChange
    else
      FBitmap.OnChange := nil;
end;

procedure TQuickPixels.BitmapChange(Sender: TObject);
begin
  if (FBitmap.Width <> FWidth) or (FBitmap.Height <> FHeight) or
    (FBitmap.PixelFormat <> FPixelFormat) then
      Attach(FBitmap);
end;

end.

