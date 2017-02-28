unit uStateRec;

interface

type
	TStateRec = record
    id_vehicle    : Integer;
    time_state    : TDateTime;
    latitude_ex   : Cardinal;
    longitude_ex  : Cardinal;
    altitude_ex   : Cardinal;
    latitude      : Double;
    longitude     : Double;
    altitude      : Double;
    din           : Byte;
    dout          : Byte;
    adc1          : Word;
    adc2          : Word;
    dac           : Byte;
    charge_level  : Byte;
    gsm_signal_str: Byte;
    flags_state   : Byte;
    speed_ex      : Word;
    course_ex     : Word;
    speed         : Double;
    course        : Double;
    running_hours : Cardinal;
    journal_size  : Cardinal;
    newjourn_size : Cardinal;
    exstatus      : Word;
    pos_exists    : Boolean;
    state_exists  : Boolean;
  end;

implementation

end.
