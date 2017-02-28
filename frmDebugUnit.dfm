object frmDebug: TfrmDebug
  Left = 351
  Top = 290
  Width = 485
  Height = 359
  Caption = 'frmDebug'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 5
    Top = 5
    Width = 61
    Height = 13
    Caption = 'Packet data:'
  end
  object memPackedData: TMemo
    Left = 5
    Top = 20
    Width = 466
    Height = 89
    Lines.Strings = (
      
        '010310020CD50010F747020120000000000000206626D719DE1260F6BA7B446A' +
        '1804A1206626DC19DE1164F6BAA6E46A15049C206626E119DE1092F6BACD2469' +
        '12D485206626E477C04F000670066000673FE0206626E454030025281DF40300' +
        '000000206626E45707FF00FFFFFDE600000400206626E45308B2861301FFFF29' +
        '000400206626E619DE0FFCF6BAF44469142411206626EB19DE0F9AF6BB27C46A' +
        '1AA3C2206626F019DE0F68F6BB66246A1E03A8206626F519DE0F34F6BBAE846B' +
        '2243A9206626FA19DE0EFAF6BBFE846B2423AB206626FF19DE0EB8F6BC52E46B' +
        '26C3AD2066270277C04F000670066000673FF02066270257030026281DF40300' +
        '000000206627025207FF00FFFF39E7000004002066270255080A871301FFFF36' +
        '0004002066270419DE0E70F6BCAA846C2743A52066270919DE0E2CF6BD01646E' +
        '2693AE2066270E19DE0DE6F6BD5744702663AB2066271319DE0DA6F6BDAD8471' +
        '26E3AC2066271819DE0D6CF6BE04E47127839C2066271D19DE0D4CF6BE5F8472' +
        '29539D2066272077C04F000670066000673FF02066272056030027281DF40300' +
        '0000002066272219DE0D18F6BEBEE4702BC3B32066272719DE0CA4F6BF21C46F' +
        '2CE3D42066272C19DE0BD0F6BF85046F2D94112066273119DE0A8CF6BFE6446F' +
        '2D64492066273619DE0900F6C043A4702C24622066273B19DE0776F6C09DC471'
      
        '2AD4662066273E78C04F0006700660006740009F8D010401018C34A510F74702' +
        '02180000000000002066273E56030027281DF403000000002066274019DE05F0' +
        'F6C0F584722A545E2066274519DE046AF6C14C84732A54692066274A19DE02EC' +
        'F6C1A4A4732A845C2066274F19DE0168F6C1FE04722BC4642066275419DDFFD2' +
        'F6C25A44712D34612066275919DDFE2EF6C2B9046F2E24642066275C78C04F00' +
        '06700660006740002066275C56030027281DF403000000002066275C5307FF00' +
        'FFFFE8E7000004002066275C510868881301FFFF3F0004002066275E19DDFC8C' +
        'F6C318A46E2E245E2066276319DDFAF0F6C377046E2D14622066276819DDF956' +
        'F6C3D4246E2D14642066276D19DDF7BCF6C431846E2D245D2066277219DDF636' +
        'F6C48F646F2CD4512066277719DDF4C6F6C4ECC46F2C944A2066277A78C04F00' +
        '06700660006740002066277A59030028281DF403000000002066277A5407FF00' +
        'FFFF20E8000004002066277A5A08E2881301FFFF3E0004002066277C19DDF358' +
        'F6C54B246F2D04482066278119DDF1EEF6C5A9A46E2CE4462066278278C04F00' +
        '0670066000674010EE59')
    TabOrder = 0
    WantReturns = False
    WordWrap = False
  end
  object btnTestPacket: TButton
    Left = 5
    Top = 115
    Width = 75
    Height = 25
    Caption = 'Test Packet'
    TabOrder = 1
    OnClick = btnTestPacketClick
  end
  object btnStartServer: TButton
    Left = 5
    Top = 160
    Width = 75
    Height = 25
    Caption = 'Start Server'
    TabOrder = 2
    OnClick = btnStartServerClick
  end
  object btnStopServer: TButton
    Left = 85
    Top = 160
    Width = 75
    Height = 25
    Caption = 'Stop Server'
    Enabled = False
    TabOrder = 3
    OnClick = btnStopServerClick
  end
  object IBQuery1: TIBQuery
    Left = 208
    Top = 192
  end
  object IBSQL1: TIBSQL
    Left = 272
    Top = 192
  end
end