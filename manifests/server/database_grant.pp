# Manage a database grant. See README.md for more details.
define postgresql::server::database_grant(
  $ensure    = 'present',
  $privilege,
  $db,
  $role,
  $psql_db   = undef,
  $psql_user = undef,
  $connect_settings = undef,
  $server_id,
) {
  postgresql::server::grant { "database:${name}":
    ensure      => $ensure,
    role        => $role,
    db          => $db,
    privilege   => $privilege,
    object_type => 'DATABASE',
    object_name => $db,
    psql_db     => $psql_db,
    psql_user   => $psql_user,
    connect_settings => $connect_settings,
    server_id   => $server_id,
  }
}
