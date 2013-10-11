# Define for creating a database. See README.md for more details.
define postgresql::server::database(
  $ensure     = 'present',
  $dbname     = $title,
  $owner      = $postgresql::server::user,
  $tablespace = undef,
  $encoding   = $postgresql::server::encoding,
  $locale     = $postgresql::server::locale,
  $istemplate = false,
  $connect_settings = $postgresql::server::default_connection_settings,
) {
  $createdb_path = $postgresql::server::createdb_path
  $user          = $postgresql::server::user
  $group         = $postgresql::server::group
  $psql_path     = $postgresql::server::psql_path
  $version       = $postgresql::server::version

  # Set the defaults for the postgresql_psql resource
  Postgresql_psql {
    psql_user  => $user,
    psql_group => $group,
    psql_path  => $psql_path,
    connect_settings => $connect_settings,
  }

  if ($ensure == 'present') {

    # Optionally set the locale switch. Older versions of createdb may not accept
    # --locale, so if the parameter is undefined its safer not to pass it.
    if ($version != '8.1') {
      $locale_option = $locale ? {
        undef   => '',
        default => "LC_COLLATE=${locale} LC_CTYPE=${locale}",
      }
      $public_revoke_privilege = 'CONNECT'
    } else {
      $locale_option = ''
      $public_revoke_privilege = 'ALL'
    }
  
    $encoding_option = $encoding ? {
      undef   => '',
      default => "ENCODING=${encoding}",
    }
  
    $tablespace_option = $tablespace ? {
      undef   => '',
      default => "TABLESPACE='${tablespace}'",
    }
  
    postgresql_psql { "Create db '${dbname}'":
      command => "CREATE DATABASE ${dbname} WITH OWNER=${owner} TEMPLATE=template0 ${encoding_option} ${locale_option} ${tablespace_option}",
      unless  => "SELECT datname FROM pg_database WHERE datname='${dbname}'",
      require => Class['postgresql::server']
    }~>
  
    # This will prevent users from connecting to the database unless they've been
    #  granted privileges.
    postgresql_psql {"REVOKE ${public_revoke_privilege} ON DATABASE \"${dbname}\" FROM public":
      refreshonly => true,
    }->
  
    postgresql_psql {"UPDATE pg_database SET datistemplate = ${istemplate} WHERE datname = '${dbname}'":
      unless => "SELECT datname FROM pg_database WHERE datname = '${dbname}' AND datistemplate = ${istemplate}",
    }
  
    # Build up dependencies on tablespace
    if($tablespace != undef and defined(Postgresql::Server::Tablespace[$tablespace])) {
      Postgresql::Server::Tablespace[$tablespace]->Postgresql_psql["Create db '${dbname}'"]
    }

  } elsif ($ensure == 'absent') {

    postgresql_psql { "Drop db '${dbname}'":
      command => "DROP DATABASE ${dbname}",
      onlyif  => "SELECT datname FROM pg_database WHERE datname='${dbname}'",
      require => Class['postgresql::server']
    }

    # Build up dependencies on tablespace
    if($tablespace != undef and defined(Postgresql::Server::Tablespace[$tablespace])) {
      Postgresql::Server::Tablespace[$tablespace]<-Postgresql_psql["Drop db '${dbname}'"]
    }


  } else {

     fail("Unknown value for ensure '${ensure}'.")

  }

}
