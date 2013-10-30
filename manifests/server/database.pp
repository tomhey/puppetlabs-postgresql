# Define for creating a database. See README.md for more details.
define postgresql::server::database(
  $ensure     = 'present',
  $dbname     = $title,
  $owner      = $postgresql::server::user,
  $tablespace = undef,
  $encoding   = $postgresql::server::encoding,
  $locale     = $postgresql::server::locale,
  $istemplate = false,
  $connect_settings = $postgresql::server::default_connect_settings,
  $server_id,
) {
  $user          = $postgresql::server::user
  $group         = $postgresql::server::group
  $psql_path     = $postgresql::server::psql_path

  if has_key( $connect_settings, 'DBVERSION') {
    $version = $connect_settings['DBVERSION']
  } else {
    $version = $postgresql::server::version
  }

  if has_key( $connect_settings, 'DBTYPE') {
    $db_type = $connect_settings['DBTYPE']
  } else {
    $db_type = 'POSTGRES'
  }

  if ( $db_type != 'POSTGRES' and $db_type != 'REDSHIFT' ) {
    fail("Unknown value for DBTYPE '${db_type}'.")
  }

  # Set the defaults for the postgresql_psql resource
  Postgresql_psql {
    psql_user  => $user,
    psql_group => $group,
    psql_path  => $psql_path,
    connect_settings => $connect_settings,
  }

  if ($ensure == 'present') {

    # Strip option from unsupported versions
    if ( versioncmp($version, '8.4') >= 0 ) {
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

    $template_option = $db_type ? {
      'REDSHIFT' => '',
      default    => 'TEMPLATE=template0',
    }

    postgresql_psql { "${server_id} - Create db '${dbname}'":
      command => "CREATE DATABASE ${dbname} WITH OWNER=${owner} ${template_option} ${encoding_option} ${locale_option} ${tablespace_option}",
      unless  => "SELECT datname FROM pg_database WHERE datname='${dbname}'",
      require => Class['postgresql::server']
    }~>
  
    # This will prevent users from connecting to the database unless they've been
    #  granted privileges.
    postgresql_psql { "${server_id} - Revoke public privilege '${dbname}'":
      command     => "REVOKE ${public_revoke_privilege} ON DATABASE \"${dbname}\" FROM public",
      refreshonly => true,
    }->
  
    postgresql_psql {"${server_id} - UPDATE pg_database SET datistemplate = ${istemplate} WHERE datname = '${dbname}'":
      command => "UPDATE pg_database SET datistemplate = ${istemplate} WHERE datname = '${dbname}'",
      unless  => "SELECT datname FROM pg_database WHERE datname = '${dbname}' AND datistemplate = ${istemplate}",
    }
  
    # Build up dependencies on tablespace
    if($tablespace != undef and defined(Postgresql::Server::Tablespace[$tablespace])) {
      Postgresql::Server::Tablespace[$tablespace]->Postgresql_psql["${server_id} - Create db '${dbname}'"]
    }

  } elsif ($ensure == 'absent') {

    postgresql_psql { "${server_id} - Drop db '${dbname}'":
      command => "DROP DATABASE ${dbname}",
      onlyif  => "SELECT datname FROM pg_database WHERE datname='${dbname}'",
      require => Class['postgresql::server']
    }

    # Build up dependencies on tablespace
    if($tablespace != undef and defined(Postgresql::Server::Tablespace[$tablespace])) {
      Postgresql::Server::Tablespace[$tablespace]<-Postgresql_psql["${server_id} - Drop db '${dbname}'"]
    }


  } else {

     fail("Unknown value for ensure '${ensure}'.")

  }

}
