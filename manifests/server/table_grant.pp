# This resource wraps the grant resource to manage table grants specifically.
# See README.md for more details.
define postgresql::server::table_grant(
  $ensure    = 'present',
  $privilege,
  $table,
  $db,
  $role,
  $psql_db   = undef,
  $psql_user = undef
  $connect_settings = undef,
) {
  postgresql::server::grant { "table:${name}":
    ensure      => $ensure,
    role        => $role,
    db          => $db,
    privilege   => $privilege,
    object_type => 'TABLE',
    object_name => $table,
    psql_db     => $psql_db,
    psql_user   => $psql_user,
    connect_settings => $connect_settings,
  }
}
