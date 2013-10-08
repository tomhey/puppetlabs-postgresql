# Manage a database grant. See README.md for more details.
define postgresql::server::database_grant(
  $privilege,
  $db,
  $role,
  $psql_db   = undef,
  $psql_user = undef,
  $connect_user = undef,
  $connect_password = undef,
  $connect_host = undef,
  $connect_port = undef,
) {
  postgresql::server::grant { "database:${name}":
    role        => $role,
    db          => $db,
    privilege   => $privilege,
    object_type => 'DATABASE',
    object_name => $db,
    psql_db     => $psql_db,
    psql_user   => $psql_user,
    connect_user => $connect_user,
    connect_password => $connect_password,
    connect_host => $connect_host,
    connect_port => $connect_port,
  }
}
