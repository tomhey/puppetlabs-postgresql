# Define for creating a database role. See README.md for more information
define postgresql::server::user(
  $ensure           = 'present',
  $password_hash    = false,
  $createdb         = false,
  $db               = $postgresql::server::user,
  $superuser        = false,
  $connection_limit = '-1',
  $username         = $title,
  $connect_settings = $postgresql::server::default_connect_settings,
  $server_id,
) {

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

  # From 8.1 or later create user is an alias for create role
  if ( versioncmp($version, '8.1') >= 0 ) {

    postgresql::server::role{ "${title}":
      ensure           => $ensure,
      password_hash    => $password_hash,
      createdb         => $createdb,
      createrole       => $createrole,
      db               => $db,
      superuser        => $superuser,
      connection_limit => $connection_limit,
      username         => $username,
      connect_settings => $connect_settings,
      server_id        => $server_id,
    }

  } else {

    $psql_user  = $postgresql::server::user
    $psql_group = $postgresql::server::group
    $psql_path  = $postgresql::server::psql_path

    $createdb_sql    = $createdb    ? { true => 'CREATEDB',    default => 'NOCREATEDB' }
    $superuser_sql   = $superuser   ? { true => 'CREATEUSER',  default => 'NOCREATEUSER' }
  
    if ($password_hash != false) {
      $password_sql = "PASSWORD '${password_hash}'"
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
  
      postgresql_psql { "Create user ${title}":
        command => "CREATE USER \"${username}\" ${password_sql} ${createdb_sql} ${superuser_sql}",
        unless  => "SELECT usename FROM pg_user WHERE usename='${username}'",
        require => Class['Postgresql::Server'],
      }->
    
      postgresql_psql {"ALTER USER \"${username}\" ${superuser_sql}":
        unless => "SELECT usename FROM pg_user WHERE usename='${username}' and usesuper=${superuser}",
      }->
    
      postgresql_psql {"ALTER USER \"${username}\" ${createdb_sql}":
        unless => "SELECT usename FROM pg_user WHERE usename='${username}' and usecreatedb=${createdb}",
      }

      # For Postgres, use pg_shadow checking for a matching password hash
      # For Redshift, pg_shadow is not accessable, so test the password by
      #  attempting to login
      if ( $db_type == 'POSTGRES' ) { 

        if $password_hash {
          if($password_hash =~ /^md5.+/) {
            $pwd_hash_sql = $password_hash
          } else {
            $pwd_md5 = md5("${password_hash}${username}")
            $pwd_hash_sql = "md5${pwd_md5}"
          }
          postgresql_psql {"ALTER USER \"${username}\" ${password_sql}":
            unless => "SELECT usename FROM pg_shadow WHERE usename='${username}' and passwd='${pwd_hash_sql}'",
            require => Postgresql_psql["Create user ${title}"],
          }

        }

      } else {

        exec { "test-password-${title}":
   
            # Use the normal connect_settings, overwriting user name and password
            #  with the value that we want to test. 
            environment => join_keys_to_values( merge($connect_settings, { "PGUSER"     => "$username",
                                                                           "PGPASSWORD" => "$password_hash" } ), "="),
            command     => "/bin/true",
            unless      => "${psql_path} -t -c 'select 1;'",
    
            require => Postgresql_psql["Create user ${title}"],
            
        }~>
    
        postgresql_psql {"ALTER USER \"${username}\" ${password_sql}":
            refreshonly => true,
          
            require => [
                         Postgresql_psql["Create user ${title}"],
                         Exec["test-password-${title}"],
                       ],
        }

      }
  
    } elsif ($ensure == 'absent') {
  
      postgresql_psql {"DROP USER \"${username}\"":
        onlyif  => "SELECT usename FROM pg_user WHERE usename='${username}'",
        require => Class['Postgresql::Server'],
      }
  
    } else {
  
       fail("Unknown value for ensure '${ensure}'.")
  
    }

  }

}
