object Form5: TForm5
  Left = 0
  Top = 0
  BorderStyle = bsNone
  ClientHeight = 184
  ClientWidth = 144
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  ShowHint = True
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object RSSpeedButton1: TRSSpeedButton
    Left = 72
    Top = 8
    Width = 72
    Height = 22
    Caption = 'Cancel'
    OnClick = RSSpeedButton1Click
  end
  object ButtonGround: TRSSpeedButton
    Left = 8
    Top = 8
    Width = 23
    Height = 22
    Hint = 'Paste Ground'
    AllowAllUp = True
    GroupIndex = 1
    Down = True
    Flat = True
    DrawFrame = True
    Highlighted = True
    HighlightedXP = True
  end
  object ButtonObjects: TRSSpeedButton
    Left = 37
    Top = 8
    Width = 23
    Height = 22
    Hint = 'Paste Objects'
    AllowAllUp = True
    GroupIndex = 2
    Down = True
    Flat = True
    Highlighted = True
    HighlightedXP = True
  end
  object LabelCopy1: TLabel
    Left = 8
    Top = 87
    Width = 223
    Height = 13
    Caption = 'Select the upper-left point of the rect to copy.'
    Visible = False
  end
  object LabelCopy2: TLabel
    Left = 8
    Top = 106
    Width = 235
    Height = 13
    Caption = 'Select the bottom-right point of the rect to copy.'
    Visible = False
  end
  object LabelPaste: TLabel
    Left = 8
    Top = 125
    Width = 381
    Height = 13
    Caption = 
      'Select the destination point. Top-left corner of copied area wil' +
      'l be placed there.'
    Visible = False
  end
  object Label1: TLabel
    Left = 9
    Top = 37
    Width = 135
    Height = 13
    AutoSize = False
  end
  object LabelCopyCaption: TLabel
    Left = 8
    Top = 144
    Width = 74
    Height = 13
    Caption = 'Copy Map Area'
  end
  object LabelPasteCaption: TLabel
    Left = 8
    Top = 163
    Width = 76
    Height = 13
    Caption = 'Paste Map Area'
  end
  object Memo1: TMemo
    Left = 4
    Top = 60
    Width = 140
    Height = 21
    Cursor = crArrow
    BorderStyle = bsNone
    Color = clBtnFace
    TabOrder = 0
  end
end
