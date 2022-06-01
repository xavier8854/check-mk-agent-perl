# check-mk-agent-perl

## Description
This package consists of several nagios plugins (cmk\_xxx.pl), and several check\_mk plugins (check\_mk\_agent/xxx\_plugin\_OS.yy)

Its purpose is to exploit the informations returned by the check\_mk agent.
You can download the latest agent(s) **[here](http://git.mathias-kettner.de/git/?p=check\_mk.git;a=tree;f=agents;hb=HEAD)**.

It is primarily developed to monitor FreeBSD servers from Icinga2 running on FreeBSD, but can be used as well with Nagios running on Linux to monitor any type of host.
The check\_mk plugins, however, are more tied to a particular OS, for example *zfs\_memory\_plugin-fb.sh*, is specifically designed for ZFS on FreeBSD (actually FreeBSD-12).

## Usage
Simply put the desired cmk\_xxx.pl files into your nagios plugins directory (usually */usr/local/libexec/nagios/* on FreeBSD, or */usr/lib64/nagios/plugins/* on Linux).

Then call it fom Icinga2 or Icinga1/Nagios with the appropriate options, usually
cmk_xxx.pl -H hostname [-c critical value -w warning value]

Example (Icinga1/Nagios) :
```
define command {
    command_name    cmk_load
    command_line    $USER1$/cmk_load.pl -H $HOSTADDRESS$ -w $ARG1$ -c $ARG2$
}
```
where $USER1$ is your plugins path as above.

Then call it with something like :
```
define service {
    service_description    Load as reported by Check_Mk agent
    use                    default_service
    host_name              myhostname
    check_command          cmk_load!5!10
}
```

In order to use the check\_mk plugins, follow the procedure adapted to your agent, by copying the plugin in the appropriate directory.
