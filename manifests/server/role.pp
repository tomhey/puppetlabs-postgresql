# Define for creating a database role. See README.md for more information
define postgresql::server::role(
  $ensure           = 'present',
  $password_hash    = false,
  $createdb         = false,
  $createrole       = false,
  $db               = $postgresql::server::user,
  $login            = true,
  $superuser        = false,
  $replication      = false,
  $connection_limit = '-1',
  $username         = $title,
  $connect_settings = $postgresql::server::default_connect_settings,
  $server_id,
) {
  $psql_user  = $postgresql::server::user
  $psql_group = $postgresql::server::group
  $psql_path  = $postgresql::server::psql_path

  if has_key( $connect_settings, 'DBVERSION') {
    $version = $connect_settings['DBVERSION']
  } else {
    $version = $postgresql::server::version
  }

  $login_sql       = $login       ? { true => 'LOGIN',       default => 'NOLOGIN' }
  $createrole_sql  = $createrole  ? { true => 'CREATEROLE',  default => 'NOCREATEROLE' }
  $createdb_sql    = $createdb    ? { true => 'CREATEDB',    default => 'NOCREATEDB' }
  $superuser_sql   = $superuser   ? { true => 'SUPERUSER',   default => 'NOSUPERUSER' }

  if ( versioncmp($version, '9.1') >= 0 ) {
    $replication_sql = $replication ? { true => 'REPLICATION', default => 'NOREPLICATION' }
  } else {
    $replication_sql = ""
  }

  if ($password_hash != false) {
    $password_sql = "ENCRYPTED PASSWORD '${password_hash}'"
  } else {
    $password_sql = ''
  }

  Postgresql_psql {
    db         => $db,
    psql_user  => $psql_user,
    psql_group => $psql_group,
    psql_path  => $psql_path,
    connect_settings => $connect_settings,
  }

  if ($ensure == 'present') {

    postgresql_psql { "Create role ${title}":
      command => "CREATE ROLE \"${username}\" ${password_sql} ${login_sql} ${createrole_sql} ${createdb_sql} ${superuser_sql} ${replication_sql} CONNECTION LIMIT ${connection_limit}",
      unless  => "SELECT rolname FROM pg_roles WHERE rolname='${username}'",
      require => Class['Postgresql::Server'],
    }->
  
    postgresql_psql {"ALTER ROLE \"${username}\" ${superuser_sql}":
      unless => "SELECT rolname FROM pg_roles WHERE rolname='${username}' and rolsuper=${superuser}",
    }->
  
    postgresql_psql {"ALTER ROLE \"${username}\" ${createdb_sql}":
      unless => "SELECT rolname FROM pg_roles WHERE rolname='${username}' and rolcreatedb=${createdb}",
    }->
  
    postgresql_psql {"ALTER ROLE \"${username}\" ${createrole_sql}":
      unless => "SELECT rolname FROM pg_roles WHERE rolname='${username}' and rolcreaterole=${createrole}",
    }->
  
    postgresql_psql {"ALTER ROLE \"${username}\" ${login_sql}":
      unless => "SELECT rolname FROM pg_roles WHERE rolname='${username}' and rolcanlogin=${login}",
    }->
  
    postgresql_psql {"ALTER ROLE \"${username}\" CONNECTION LIMIT ${connection_limit}":
      unless => "SELECT rolname FROM pg_roles WHERE rolname='${username}' and rolconnlimit=${connection_limit}",
    }

    if(versioncmp($version, '9.1') >= 0) {
      postgresql_psql {"ALTER ROLE \"${username}\" ${replication_sql}":
        unless => "SELECT rolname FROM pg_roles WHERE rolname='${username}' and rolreplication=${replication}",
        require => Postgresql_psql["Create role ${title}"],
      }
    }
  
    if $password_hash {
      if($password_hash =~ /^md5.+/) {
        $pwd_hash_sql = $password_hash
      } else {
        $pwd_md5 = md5("${password_hash}${username}")
        $pwd_hash_sql = "md5${pwd_md5}"
      }
      postgresql_psql {"ALTER ROLE \"${username}\" ${password_sql}":
        unless => "SELECT usename FROM pg_shadow WHERE usename='${username}' and passwd='${pwd_hash_sql}'",
        require => Postgresql_psql["Create role ${title}"],
      }
    }

  } elsif ($ensure == 'absent') {

    postgresql_psql {"DROP ROLE \"${username}\"":
      onlyif  => "SELECT rolname FROM pg_roles WHERE rolname='${username}'",
      require => Class['Postgresql::Server'],
    }

  } else {

     fail("Unknown value for ensure '${ensure}'.")

  }

}
