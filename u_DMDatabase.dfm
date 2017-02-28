object dmDatabase: TdmDatabase
  OldCreateOrder = False
  Left = 337
  Top = 237
  Height = 150
  Width = 215
  object db3C: TpFIBDatabase
    DefaultTransaction = trRead
    DefaultUpdateTransaction = trWrite
    SQLDialect = 3
    Timeout = 0
    WaitForRestoreConnect = 0
    Left = 5
    Top = 5
  end
  object trRead: TpFIBTransaction
    DefaultDatabase = db3C
    TimeoutAction = TARollback
    TRParams.Strings = (
      'read'
      'read_committed'
      'rec_version')
    TPBMode = tpbDefault
    Left = 35
    Top = 5
  end
  object trWrite: TpFIBTransaction
    DefaultDatabase = db3C
    TimeoutAction = TARollback
    TRParams.Strings = (
      'write'
      'read_committed'
      'rec_version'
      'nowait'
      '')
    TPBMode = tpbDefault
    Left = 65
    Top = 5
  end
  object dsVehiclesRO: TpFIBDataSet
    SelectSQL.Strings = (
      'select * from vehicles')
    AllowedUpdateKinds = []
    Transaction = trRead
    Database = db3C
    UpdateTransaction = trWrite
    Left = 95
    Top = 5
  end
end
