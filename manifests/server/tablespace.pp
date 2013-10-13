# This module creates tablespace. See README.md for more details.
define postgresql::server::tablespace(
  $ensure  = 'present',
  $location,
  $owner   = undef,
  $spcname = $title,
  $connect_settings = $postgresql::server::default_connect_settings,
) {
  $user      = $postgresql::server::user
  $group     = $postgresql::server::group
  $psql_path = $postgresql::server::psql_path

  Postgresql_psql {
    psql_user  => $user,
    psql_group => $group,
    psql_path  => $psql_path,
    connect_settings => $connect_settings,
  }

  if ($owner == undef) {
    $owner_section = ''
  } else {
    $owner_section = "OWNER \"${owner}\""
  }

  if ($ensure == 'present') {

    $create_tablespace_command = "CREATE TABLESPACE \"${spcname}\" ${owner_section} LOCATION '${location}'"
  
    # TODO: This directory location is not cleared up when ensure => absent, review and think about
    file { $location:
      ensure => directory,
      owner  => $user,
      group  => $group,
      mode   => '0700',
    }
  
    $create_ts = "Create tablespace '${spcname}'"
    postgresql_psql { "${create_ts}":
      command => $create_tablespace_command,
      unless  => "SELECT spcname FROM pg_tablespace WHERE spcname='${spcname}'",
      require => [Class['postgresql::server'], File[$location]],
    }
  
    if($owner != undef and defined(Postgresql::Server::Role[$owner])) {
      Postgresql::Server::Role[$owner]->Postgresql_psql[$create_ts]
    }

  } elsif ($ensure == 'absent') {

    $drop_tablespace_command = "DROP TABLESPACE \"${spcname}\""

    $drop_ts = "Drop tablespace '${spcname}'"
    postgresql_psql { "${drop_ts}":
      command => $drop_tablespace_command,
      onlyif  => "SELECT spcname FROM pg_tablespace WHERE spcname='${spcname}'",
      require => Class['postgresql::server'],
    }
  
    if($owner != undef and defined(Postgresql::Server::Role[$owner])) {
      Postgresql::Server::Role[$owner]<-Postgresql_psql[$drop_ts]
    }

  } else {

     fail("Unknown value for ensure '${ensure}'.")

  }

}
