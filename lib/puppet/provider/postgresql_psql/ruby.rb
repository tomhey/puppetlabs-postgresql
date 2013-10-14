Puppet::Type.type(:postgresql_psql).provide(:ruby) do

  def command()

    unless_check = false
    onlyif_check = true

    if ( resource[:unless] and !resource[:unless].empty? )

      output, status = run_check_sql_command(resource[:unless])

      if status != 0
        self.fail("Error evaluating 'unless' clause: '#{output}'")
      end
      result_count = output.strip.to_i

      # The 'unless' query indicates we should not execute
      #  the command by returning rows
      if result_count > 0
        unless_check = true
      end

    end

    if ( resource[:onlyif] and !resource[:onlyif].empty? )

      onlyif_conditions = resource[:onlyif].kind_of?(Array) ? resource[:onlyif] : [ resource[:onlyif] ]

      onlyif_conditions.each { |condition| 

        output, status = run_check_sql_command(condition)
    
        if status != 0
          self.fail("Error evaluating 'onlyif' clause: '#{output}'")
        end
        result_count = output.strip.to_i
    
        # The 'onlyif' query indicates we should execute
        #  the command by returning rows
        if result_count < 1
          onlyif_check = false
          break
        end

      }

    end

    if ( !unless_check and onlyif_check ) 

      if (resource.refreshonly?)
        # We're in "refreshonly" mode, we need to return the 
        #  target command here.  If we don't, then Puppet will 
        #  generate an event indicating that this property has 
        #  changed.
        return resource[:command]
      end

      # if we're not in refreshonly mode, then we return nil,
      #  which will cause Puppet to sync this property.  
      return nil

    else

      # Either the unless test returned true or the onlyif test
      #  returned false, return 'command' here will cause
      #  Puppet to treat this property as already being 'insync?',
      #  so it  won't call the setter to run the 'command' later.
      return resource[:command]

    end

  end

  def command=(val)
    output, status = run_sql_command(val)

    if status != 0
      self.fail("Error executing SQL; psql returned #{status}: '#{output}'")
    end
  end


  def run_check_sql_command(sql)
    # for the 'unless' or 'onlyif' queries, we wrap the user's query in a 'SELECT COUNT',
    # which makes it easier to parse and process the output.
    run_sql_command('SELECT COUNT(*) FROM (' <<  sql << ') count')
  end

  def run_sql_command(sql)
    environment = resource[:connect_settings] ? resource[:connect_settings] : Hash.new

    command = [resource[:psql_path]]
    command.push("-d", resource[:db]) if ( resource[:db] and !environment.key?('PGDATABASE') )
    command.push("-t", "-c", sql)

    if resource[:cwd]
      Dir.chdir resource[:cwd] do
        Puppet::Util::SUIDManager.run_and_capture(command, resource[:psql_user], resource[:psql_group], { :custom_environment => environment } )
      end
    else
      Puppet::Util::SUIDManager.run_and_capture(command, resource[:psql_user], resource[:psql_group], { :custom_environment => environment } )
    end
  end

end
