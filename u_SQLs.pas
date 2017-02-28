unit u_SQLs;

interface

Const
  SQL_STATE_INSERTUPDATE =
      'UPDATE OR INSERT INTO vehicles_states (' +
      '  id_vehicle, time_state, latitude, longitude, altitude,' +
      '  din, dout, adc1, adc2, dac, charge_level, gsm_signal_strength,' +
      '  flags_state, speed, course, running_hours, journal_size,' +
      '  newjournal_size, exstatus) ' +
      'values (' +
      '  :id_vehicle, :time_state, :latitude, :longitude, :altitude,' +
      '  :din, :dout, :adc1, :adc2, :dac, :charge_level, :gsm_signal_strength,' +
      '  :flags_state, :speed, :course, :running_hours, :journal_size,' +
      '  :newjournal_size, :exstatus) ' +
      'MATCHING (id_vehicle)';

  SQL_STATE_NOGPS_INSERTUPDATE =
      'UPDATE OR INSERT INTO vehicles_states (' +
      '  id_vehicle, time_state, din, dout, adc1, adc2, dac, charge_level,' +
      '  gsm_signal_strength, flags_state, running_hours, journal_size,' +
      '  newjournal_size, exstatus) ' +
      'values (' +
      '  :id_vehicle, :time_state, :din, :dout, :adc1, :adc2, :dac,' +
      '  :charge_level, :gsm_signal_strength, :flags_state, :running_hours,' +
      '  :journal_size, :newjournal_size, :exstatus) ' +
      'MATCHING (id_vehicle)';

  SQL_STATE_ONLYGPS_INSERTUPDATE =
      'UPDATE OR INSERT INTO vehicles_states (' +
      '  id_vehicle, time_state, latitude, longitude, altitude,' +
      '  speed, course) ' +
      'values (' +
      '  :id_vehicle, :time_state, :latitude, :longitude, :altitude,' +
      '  :speed, :course) ' +
      'MATCHING (id_vehicle)';

  SQL_JOURNAL_INSERT =
      'insert into vehicles_journal ' +
      'values ( ' +
      '  :id_veh_journ, :id_vehicle, :phone_number, :recordtype_id, :absolute_time, ' +
      '  :latitude, :longitude, :altitude, :din, :dout, :adc1, :adc2, :dac, ' +
      '  :charge_level, :gsm_signal_strength, :flags_state, :event_id, ' +
      '  :event_data, :speed, :course, :exstatus)';

  SQL_READ_CONF =
      'select first 1 * from VEH_CONFIGURATION ' +
      'where ID_VEHICLE = :idv ' +
      'order by ID_VEH_CONF desc';

  SQL_CONF_WRITE =
      'insert into veh_configuration ' +
      'values ( ' +
      '  :id_veh_conf, :soft_ver, :hard_ver, :flash_size, :battery_type, ' +
      '  :capacity, :running_hours, :pin, :gps_scan_period, :di_ai_scan_period, ' +
      '  :di_mask, :gps_distance, :data_send_period, :conf_data_cc, :journal_send_period, ' +
      '  :conf_journal_cc, :dout, :aout, :id_vehicle, :zone_latitude, :zone_longitude, ' +
      '  :zone_radius, :probably, :serial_num, :movement_algorithm, ' +
      '  :distance_algorithm, :do_mask, :gprs_apn, :gprs_user, :gprs_pswd, ' +
      '  :gprs_ip, :gprs_port, :cipher_key)';

  SQL_SENSORS_INSERT =
      'insert into VEHICLE_SENSORS (UTC_TIME, VEHICLE, SENS_ID, SENS_DATA) ' +
      'values (:UTC_TIME, :VEHICLE, :SENS_ID, :SENS_DATA)';

  SQL_SERIAL_CHECK = 'select first 1 * from vehicles where SERIAL_NUM = :sn';

implementation

end.
