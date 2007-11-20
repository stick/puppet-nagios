class nagios {
    package { "nagios-plugins":
        ensure  => installed,
        require => Package["nagios-plugins-setuid"],
    }
    package { "nagios-plugins-setuid":
        ensure  => installed,
    }
}

class nagios::client inherits nagios {

    # defs for nagios_client
    # any of these can be overridden at the host level

    $users_warning = $users_warning ? { '' => '15', default => $users_warning }
    $users_critical = $users_critical ? { '' => '30', default => $users_critical }
    $load_warning = $load_warning ? { '' => '15,15,15', default => $load_warning }
    $load_critical = $load_critical ? { '' => '30,25,20', default => $load_critical }

    # disks
    # % of available space
    # defining as a number will make that a hard limit of K
    $slash_warning = $slash_warning ? { '' => '10%', default => $slash_warning }
    $slash_critical = $slash_critical ? { '' => '5%', default => $slash_critical }
    $boot_warning = $boot_warning ? { '' => '10%', default => $boot_warning }
    $boot_critical = $boot_critical ? { '' => '5%', default => $boot_critical }
    $md0_warning = $md0_warning ? { '' => '10%', default => $md0_warning }
    $md0_critical = $md0_critical ? { '' => '5%', default => $md0_critical }
    $md1_warning = $md1_warning ? { '' => '10%', default => $md1_warning }
    $md1_critical = $md1_critical ? { '' => '5%', default => $md1_critical }
    $md2_warning = $md2_warning ? { '' => '10%', default => $md2_warning }
    $md2_critical = $md2_critical ? { '' => '5%', default => $md2_critical }
    $md3_warning = $md3_warning ? { '' => '10%', default => $md3_warning }
    $md3_critical = $md3_critical ? { '' => '5%', default => $md3_critical }
    $md4_warning = $md4_warning ? { '' => '10%', default => $md4_warning }
    $md4_critical = $md4_critical ? { '' => '5%', default => $md4_critical }
    $md5_warning = $md5_warning ? { '' => '10%', default => $md5_warning }
    $md5_critical = $md5_critical ? { '' => '5%', default => $md5_critical }

    # procs
    # this is the number of procs in state Z or D (for iowait) to generate an alert
    $zprocs_warning = $zprocs_warning ? { '' => '5', default => $zprocs_warning }
    $zprocs_critical = $zprocs_critical ? { '' => '10', default => $zprocs_critical }
    $iowaitprocs_warning = $iowaitprocs_warning ? { '' => '5', default => $iowaitprocs_warning }
    $iowaitprocs_critical = $iowaitprocs_critical ? { '' => '10', default => $iowaitprocs_critical }
    $total_procs_warning = $total_procs_warning ? { '' => '700', default => $total_procs_warning }
    $total_procs_critical = $total_procs_critical ? { '' => '1000', default => $total_procs_critical }

    # memory
    # all 4 of these are %'s the free mem check defaults to %'s
    $free_mem_warning = $free_mem_warning ? { '' => '5', default => $free_mem_warning }
    $free_mem_critical  = $free_mem_critical ? { '' => '3', default => $free_mem_critical }
    $swap_warning = $swap_warning ? { '' => '5%', default => $swap_warning }
    $swap_critical = $swap_critical ? { '' => '2%', default => $swap_critical }

    package { "nrpe":
        ensure  => installed,
        require => Package["net-snmp"],
    }
    service { "nrpe":
        ensure          => running,
        enable          => true,
        hasrestart      => true,
        hasstatus       => true,
    }
    file { "/etc/nagios/nrpe.cfg":
        owner   => root,
        group   => root,
        mode    => 0644,
        notify  => Service["nrpe"],
        content => template("nagios/nrpe-cfg.erb"),
    }

    
}

define nagios::service (
    $template = 'service-tempate',
    $description = '',
    $host_name = $fqdn,
    $service_groups = '',
    $contact_groups = $default_contact_group,
    $check_command = ''
) {
    @@file { $name:
        name            => "/etc/nagios/conf.d/services/${name}.cfg",
        mode            => 0644,
        owner           => nagios,
        group           => nagios,
        content         => template("nagios/service.erb"),
    }
}

define nagios::host (
    $template = 'host-template',
    $host_name = $fqdn,
    $host_groups = '',
    $alias = $fqdn,
    $parents = '',
    $contact_groups = $default_contact_group,
    $check_command = 'check-host-alive'
) {
    @@file { $name:
        name            => "/etc/nagios/conf.d/hosts/${name}.cfg",
        mode            => 0644,
        owner           => nagios,
        group           => nagios,
        content         => template("nagios/host.erb"),
    }
}

class nagios::server inherits nagios {
    #package { "nagios":
        #ensure  => installed,
        #require => Package["nagios-plugins"],
    #}
    #package { "nrpe-plugin":
        #ensure  => installed,
    #}

    group { nagios:
        gid = 251,
    }
    user { nagios:
        uid = 250,
        gid = 251,
    }

    # import the nagios host declarations
    File <<|nagios::host|>>

    # import the nagios host declarations
    File <<|nagios::service|>>

}
