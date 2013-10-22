# Define for granting permissions to roles. See README.md for more details.
define postgresql::server::grant (
  $ensure      = 'present',
  $role,
  $db,
  $privilege   = undef,
  $object_type = 'database',
  $object_name = $db,
  $psql_db     = $postgresql::server::user,
  $psql_user   = $postgresql::server::user,
  $connect_settings = $postgresql::server::default_connect_settings,
) {
  $group     = $postgresql::server::group
  $psql_path = $postgresql::server::psql_path

  ## Munge the input values
  $_object_type = upcase($object_type)
  $_privilege   = upcase($privilege)

  ## Validate that the object type is known
  validate_string($_object_type,
    #'COLUMN',
    'DATABASE',
    #'FOREIGN SERVER',
    #'FOREIGN DATA WRAPPER',
    #'FUNCTION',
    #'PROCEDURAL LANGUAGE',
    #'SCHEMA',
    #'SEQUENCE',
    'TABLE',
    #'TABLESPACE',
    #'VIEW',
  )

  ## Validate that the object type's privilege is acceptable
  case $_object_type {
    'DATABASE': {
      validate_string($_privilege,'CREATE','CONNECT','TEMPORARY','TEMP','ALL',
        'ALL PRIVILEGES')
      $unless_function = 'has_database_privilege'
      $unless_object_drop_test = "SELECT datname FROM pg_database WHERE datname='${object_name}'"
      $on_db = $psql_db
    }
    'TABLE': {
      validate_string($_privilege,'SELECT','INSERT','UPDATE','REFERENCES',
        'ALL','ALL PRIVILEGES')
      $unless_function = 'has_table_privilege'
      $unless_object_drop_test = "SELECT tablename FROM pg_tables WHERE tablename='${object_name}'"
      $on_db = $db
    }
    default: {
      fail("Missing privilege validation for object type ${_object_type}")
    }
  }

  if has_key( $connect_settings, 'DBVERSION') {
    $version = $connect_settings['DBVERSION']
  } else {
    $version = $postgresql::server::version
  }

  # From 8.1 or later create user is an alias for create role
  if ( versioncmp($version, '8.1') >= 0 ) {
    $unless_role_drop_test = "SELECT rolname FROM pg_roles WHERE rolname='${role}'"
  } else {
    $unless_role_drop_test = "SELECT usename FROM pg_user WHERE usename='${role}'"
  }

  # TODO: this is a terrible hack; if they pass "ALL" as the desired privilege,
  #  we need a way to test for it--and has_database_privilege does not
  #  recognize 'ALL' as a valid privilege name. So we probably need to
  #  hard-code a mapping between 'ALL' and the list of actual privileges that
  #  it entails, and loop over them to check them.  That sort of thing will
  #  probably need to wait until we port this over to ruby, so, for now, we're
  #  just going to assume that if they have "CREATE" privileges on a database,
  #  then they have "ALL".  (I told you that it was terrible!)
  $unless_privilege = $_privilege ? {
    'ALL'   => 'CREATE',
    default => $_privilege,
  }

  if ($ensure == 'present') {

    $grant_cmd = "GRANT ${_privilege} ON ${_object_type} \"${object_name}\" TO \"${role}\""
    postgresql_psql { "${title} - ${grant_cmd}":
      command    => $grant_cmd,
      db         => $on_db,
      psql_user  => $psql_user,
      psql_group => $group,
      psql_path  => $psql_path,
      connect_settings => $connect_settings,
      unless     => "SELECT 1 WHERE ${unless_function}('${role}', '${object_name}', '${unless_privilege}')",
      require    => Class['postgresql::server']
    }
  
    if($role != undef and defined(Postgresql::Server::Role[$role])) {
      Postgresql::Server::Role[$role]->Postgresql_psql["${title} - ${grant_cmd}"]
    }
  
    if($role != undef and defined(Postgresql::Server::User[$role])) {
      Postgresql::Server::User[$role]->Postgresql_psql["${title} - ${grant_cmd}"]
    }

    if($db != undef and defined(Postgresql::Server::Database[$db])) {
      Postgresql::Server::Database[$db]->Postgresql_psql["${title} - ${grant_cmd}"]
    }

  } elsif ($ensure == 'absent') {

    $revoke_cmd = "REVOKE ${_privilege} ON ${_object_type} \"${object_name}\" FROM \"${role}\""
    postgresql_psql { "${title} - ${revoke_cmd}":
      command    => $revoke_cmd,
      db         => $on_db,
      psql_user  => $psql_user,
      psql_group => $group,
      psql_path  => $psql_path,
      connect_settings => $connect_settings,

      # Check the role and object exist before has_X_privilege function call
      #  as it returns an error if the role or object does not exists
      onlyif     => [
                      $unless_role_drop_test,
                      $unless_object_drop_test,
                      "SELECT 1 WHERE ${unless_function}('${role}', '${object_name}', '${unless_privilege}')",
                    ],
      require    => Class['postgresql::server']
    }
  
    if($role != undef and defined(Postgresql::Server::Role[$role])) {
      Postgresql::Server::Role[$role]<-Postgresql_psql["${title} - ${revoke_cmd}"]
    }
  
    if($role != undef and defined(Postgresql::Server::User[$role])) {
      Postgresql::Server::User[$role]<-Postgresql_psql["${title} - ${revoke_cmd}"]
    }

    if($db != undef and defined(Postgresql::Server::Database[$db])) {
      Postgresql::Server::Database[$db]<-Postgresql_psql["${title} - ${revoke_cmd}"]
    }

  } else {

     fail("Unknown value for ensure '${ensure}'.")

  }

}
