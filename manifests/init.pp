class nagios {
    case $operatingsystemrelease {
        4: {
            package { "nagios-plugins":
                ensure  => installed,
            }
        }
        default: {
            package { "nagios-plugins":
                ensure  => installed,
                require => Package["nagios-plugins-setuid"],
            }
            package { "nagios-plugins-setuid":
                ensure  => installed,
            }
        }
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

    # case this if you need it
    $nagios_muninhost = $nagios_muninhost ? { "" => "munin.util.${site}", default => $nagios_munin_host }

    package { "nrpe":
        name    => $operatingsystemrelease ? {
            '4'         => 'nrpe',
            default     => 'nagios-nrpe',
        },
        ensure  => installed,
        require => Package["net-snmp"],
    }
    service { "nrpe":
        ensure          => running,
        enable          => true,
        hasrestart      => true,
        hasstatus       => true,
        require         => Package["nrpe"],
    }
    file { "/etc/nagios/nrpe.cfg":
        owner   => root,
        group   => root,
        mode    => 0644,
        notify  => Service["nrpe"],
        content => template("nagios/nrpe-cfg.erb"),
    }

    $plugin_dir = $architecture ? { 
            'x86_64'    => "/usr/lib64/nagios/plugins/extra",
            default     => "/usr/lib/nagios/plugins/extra",
    }
    file { $plugin_dir:
        recurse         => true,
        purge           => true,
        source          => [ "puppet:///nagios/plugins/", "puppet:///nagios/empty" ],
        require         => Package["nagios-plugins"],
    }


    # open firewall for nrpe
    firewall::rule { NRPE:
        comment                 => "inbound access for nrpe/5666",
        destination_port        => 5666,
    }

    # defaults
    $default_contact_group = "prodops" # make this a fact
    # this 'should' be a fact, but you can't have a fact as an array
    # TODO figure something out later
    $default_escalation = [ "prodops_247", "managers" ] 
    #$nagios_parent = $nagios_parent ? { '' => "corerouter.${site}", default => $nagios_parent }

    # we add ourself (the host) first
    nagios::host { $fqdn:
        parents                 => $nagios_parent,
        escalation_groups       => $default_escalation,
    }
    # things we monitor for everything with this class
    if $raid {
        $mdstatus_dep = ",MDSTATUS"
    }
    nagios::service { "${fqdn}-NRPE":
        check_command           => "check_nrpe",
        dependency              => true,
        dependent_services      => "slash,boot${mdstatus_dep}",
        max_check_attempts      => 2,
        escalation_groups       => $default_escalation,
    }
    nagios::service { "${fqdn}-slash":
        check_command           => "check_slash",
        max_check_attempts      => 5,
        escalation_groups       => $default_escalation,
    }
    nagios::service { "${fqdn}-boot":
        check_command           => "check_boot",
        max_check_attempts      => 5,
        escalation_groups       => $default_escalation,
    }

    # only create this service is we determine (via the raid fact)
    # that the node has raid
    if $raid {
        nagios::service { "${fqdn}-MDSTATUS":
            check_command           => "check_mdstatus",
            max_check_attempts      => 5,
            escalation_groups       => $default_escalation,
        }
    }
}

define nagios::service (
    $nagios_template = 'generic-service',
    $host_name = $fqdn,
    $service_groups = '',
    $contact_groups = $default_contact_group,
    $max_check_attempts = 3,
    $dependency = false,
    $dependent_host = $fqdn,
    $dependent_services = '',
    $escalation_groups = [],
    $escalation_stages = [ 7, 10 ],
    $check_command = ''
) {

    $contacts = [] # leave this blank
    @@file { "service:${name}":
        name            => "/etc/nagios/conf.d/services/${name}.cfg",
        mode            => 0644,
        owner           => nagios,
        group           => nagios,
        tag             => nagios,
        notify          => Service["nagios"],
        content         => template("nagios/service.erb"),
    }
}

define nagios::host (
    $nagios_template = 'generic-host',
    $host_name = $fqdn,
    $host_groups = '',
    $nagios_alias = $fqdn,
    $parents = '',
    $contact_groups = $default_contact_group,
    $dependency = false,
    $dependent_host = '',
    $escalation_groups = [],
    $escalation_stages = [ 7, 10 ],
    $dummy_service = false,
    $check_command = 'check-host-alive'
) {

    $contacts = [] # leave this blank
    @@file { "host:${name}":
        name            => "/etc/nagios/conf.d/hosts/${name}.cfg",
        mode            => 0644,
        owner           => nagios,
        group           => nagios,
        tag             => nagios,
        notify          => Service["nagios"],
        content         => template("nagios/host.erb"),
    }
}

class nagios::server inherits nagios {

    package { "nagios":
        ensure  => installed,
        require => Package["nagios-plugins"],
    }
    package { "nagios-www":
        ensure  => installed,
        require => Package["nagios"],
    }
    package { "nagios-plugins-nrpe":
        ensure  => installed,
    }

    service { "nagios":
        ensure          => running,
        enable          => true,
        hasrestart      => true,
        hasstatus       => true,
        require         => Package["nagios"],
    }

    group { nagios:
        gid => 251,
    }
    user { nagios:
        uid => 250,
        gid => 251,
    }

    $nagios_dir = '/etc/nagios'

    # defaults for file objects
    File {
        owner   => nagios,
        group   => nagios,
        notify  => Service["nagios"],
    }

    file { "${nagios_dir}/conf.d/":
        ensure          => directory,
        purge           => true,
        recurse         => true,
        require         => Package["nagios"],
    }

    file { [ "${nagios_dir}/conf.d/hosts/", "${nagios_dir}/conf.d/services/" ]:
        ensure          => directory,
        purge           => true,
        recurse         => true,
        require         => File["${nagios_dir}/conf.d"],
    }

    file { "${nagios_dir}/private":
        ensure          => directory,
        require         => Package["nagios"],
    }
    file { "/var/log/nagios/rw":
        ensure          => directory,
        owner           => nagios,
        group           => nagios,
        mode            => 0775,
    }
    file { "/var/log/nagios":
        owner           => nagios,
        group           => nagios,
        recurse         => true,
    }

    file { "/var/log/nagios/spool":
        owner           => nagios,
        group           => nagios,
        ensure          => directory,
        mode            => 0755,
        require         => File["/var/log/nagios"],
    }

    file { "/var/log/nagios/spool/checkresults":
        owner           => nagios,
        group           => nagios,
        ensure          => directory,
        mode            => 0755,
        require         => File["/var/log/nagios/spool"],
    }

    file { "${nagios_dir}/nagios.cfg":
        source          => "puppet:///nagios/nagios.cfg",
        require         => Package["nagios"],
    }
    file { "${nagios_dir}/cgi.cfg":
        source          => "puppet:///nagios/cgi.cfg",
        require         => Package["nagios"],
    }
    file { "${nagios_dir}/private/resource.cfg":
        content         => template("nagios/resource-cfg.erb"),
        mode            => 0600,
        require         => File["${nagios_dir}/private"],
    }
    file { "${nagios_dir}/conf.d/contacts.cfg":
        source          => "puppet:///nagios/contacts.cfg",
        require         => File["${nagios_dir}/conf.d"],
    }
    file { "${nagios_dir}/conf.d/contactgroups.cfg":
        source          => "puppet:///nagios/contactgroups.cfg",
        require         => File["${nagios_dir}/conf.d"],
    }
    file { "${nagios_dir}/conf.d/checkcommands.cfg":
        source          => "puppet:///nagios/checkcommands.cfg",
        require         => File["${nagios_dir}/conf.d"],
    }
    file { "${nagios_dir}/conf.d/escalations.cfg":
        source          => "puppet:///nagios/escalations.cfg",
        require         => File["${nagios_dir}/conf.d"],
    }
    file { "${nagios_dir}/conf.d/hostgroups.cfg":
        source          => "puppet:///nagios/hostgroups.cfg",
        require         => File["${nagios_dir}/conf.d"],
    }
    file { "${nagios_dir}/conf.d/hostextinfo.cfg":
        source          => "puppet:///nagios/hostextinfo.cfg",
        require         => File["${nagios_dir}/conf.d"],
    }
    file { "${nagios_dir}/conf.d/serviceextinfo.cfg":
        source          => "puppet:///nagios/hostextinfo.cfg",
        require         => File["${nagios_dir}/conf.d"],
    }
    file { "${nagios_dir}/conf.d/notifcationcommands.cfg":
        source          => "puppet:///nagios/notificationcommands.cfg",
        require         => File["${nagios_dir}/conf.d"],
    }
    file { "${nagios_dir}/conf.d/servicegroups.cfg":
        source          => "puppet:///nagios/servicegroups.cfg",
        require         => File["${nagios_dir}/conf.d"],
    }
    file { "${nagios_dir}/conf.d/timeperios.cfg":
        source          => "puppet:///nagios/timeperiods.cfg",
        require         => File["${nagios_dir}/conf.d"],
    }
    file { "${nagios_dir}/conf.d/hosts.cfg":
        source          => "puppet:///nagios/hosts.cfg",
        require         => File["${nagios_dir}/conf.d"],
    }
    file { "${nagios_dir}/conf.d/services.cfg":
        source          => "puppet:///nagios/services.cfg",
        require         => File["${nagios_dir}/conf.d"],
    }

    # cleanup
    # these are manually set would be nice to wildcard somehow
    tidy { [
        "${nagios_dir}/localhost.cfg-sample",
        "${nagios_dir}/nagios.cfg-sample",
        "${nagios_dir}/cgi.cfg-sample",
        "${nagios_dir}/*.rpmnew",
        "${nagios_dir}/private/resource.cfg-sample",
        "${nagios_dir}/commands.cfg-sample",
        "${nagios_dir}/nrpe.cfg.rpmnew"
    ]:
        size            => "0k",
    }

    # for the server we create some hosts that are needed that aren't managed by puppet
#    nagios::host { "corerouter.${site}":
#        contact_groups          => "prodops",
#        dummy_service           => true,
#        escalation_groups       => [ "prodops" ],
#    }

    # import the nagios host/service declarations
    # TODO make this specific to nagios so we can export/collect in other place
    File <<| tag == nagios|>>

    # nagios needs apache
    include apache
    include apache::ssl
    include apache::auth_kerb

    # move this to something more common
    # short list for testing
    $nagios_auth_users = [
        "cmacleod",
        "csmith",
        "jeckersb",
        "jpickard",
	"trobert",
        "plundin",
        "batkisso",
        "jstrong",
        "madisonj",
        "ebrown"
    ]
    apache::auth_kerb::access { "nagios":
        allowed_users           => $nagios_auth_users,
    }

    apache::ssl::cert { "${fqdn}": }

    file { "/etc/httpd/conf.d/nagios.conf":
        source  => "puppet:///nagios/nagios-httpd.conf",
        notify  => Exec["graceful-apache"],
    }

}
