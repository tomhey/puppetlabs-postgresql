Puppet::Type.type(:postgresql_psql).provide(:ruby) do

  def run_unless_sql_command(sql)
    # for the 'unless' queries, we wrap the user's query in a 'SELECT COUNT',
    # which makes it easier to parse and process the output.
    run_sql_command('SELECT COUNT(*) FROM (' <<  sql << ') count')
  end

  def run_sql_command(sql)
    if resource[:search_path]
      sql = "set search_path to #{Array(resource[:search_path]).join(',')}; #{sql}"
    end

    environment = resource[:connect_settings] ? resource[:connect_settings] : Hash.new

    command = [resource[:psql_path]]
    command.push("-d", resource[:db]) if ( resource[:db] and !environment.key?('PGDATABASE') )
    command.push("-t", "-c", sql)

    if resource[:cwd]
      Dir.chdir resource[:cwd] do
        run_command(command, resource[:psql_user], resource[:psql_group], environment)
      end
    else
      run_command(command, resource[:psql_user], resource[:psql_group], environment)
    end
  end

  private

  def run_command(command, user, group, environment)
    if Puppet::PUPPETVERSION.to_f < 3.4
      Puppet::Util::SUIDManager.run_and_capture(command, user, group, { :custom_environment => environment })
    else
      output = Puppet::Util::Execution.execute(command, {
        :uid                => user,
        :gid                => group,
        :failonfail         => false,
        :combine            => true,
        :override_locale    => true,
	:custom_environment => environment,
      })
      [output, $CHILD_STATUS.dup]
    end
  end

end
