# == Class: cluster::rabbitmq_ocf
#
# Overrides rabbitmq service provider as a pacemaker
#
# TODO(bogdando) that one just an example of Pacemaker service
#   provider wrapper implementation and should be moved to openstack_extra
#   and params should be described
#
# === Parameters
#
# [*primitive_type*]
#   String. Corosync resource primitive_type
#   Defaults to 'rabbitmq-server'
#
# [*service_name*]
#   String. The service name of rabbitmq.
#   Defaults to $::rabbitmq::service_name
#
# [*port*]
#   Integer. The port for rabbitmq to listen on.
#   Defaults to $::rabbitmq::port
#
# [*host_ip*]
#   String. A string used for OCF script to collect
#   RabbitMQ statistics
#   Defaults to '127.0.0.1'
#
# [*debug*]
#   Boolean. Flag to enable or disable debug logging.
#   Defaults to false;
# [*ocf_script_file*]
#   String. The script filename for use with pacemaker.
#   Defaults to 'cluster/ocf/rabbitmq'
#
# [*command_timeout*]
#   String.
#
# [*erlang_cookie*]
#   String. A string used as a cookie for rabbitmq instances to
#   communicate with eachother.
#   Defaults to 'EOKOWXQREETZSHFNTPEY'
#
# [*admin_user*]
#   String. An admin username that is used to import the rabbitmq
#   definitions from a backup as part of a recovery action.
#   Defaults to undef
#
# [*admin_pass*]
#   String. An admin password that is used to import the rabbitmq
#   definitions from a backup as part of a recovery action.
#   Defaults to undef
#
# [*enable_rpc_ha*]
#   Boolean. Set ha-mode=all policy for RPC queues. Note that
#   Ceilometer queues are not affected by this flag.
#
# [*enable_notifications_ha*]
#   Boolean. Set ha-mode=all policy for Ceilometer queues. Note
#   that RPC queues are not affected by this flag.
#
# [*fqdn_prefix*]
#   String. Optional FQDN prefix for node names.
#   Defaults to empty string
#
# [*policy_file*]
#   String. Optional path to the policy file for HA queues.
#   Defaults to undef
#

class cluster::rabbitmq_ocf (
  $primitive_type          = 'rabbitmq-server',
  $service_name            = $::rabbitmq::service_name,
  $port                    = $::rabbitmq::port,
  $host_ip                 = '127.0.0.1',
  $debug                   = false,
  $ocf_script_file         = 'cluster/ocf/rabbitmq',
  $command_timeout         = '',
  $erlang_cookie           = 'EOKOWXQREETZSHFNTPEY',
  $admin_user              = undef,
  $admin_pass              = undef,
  $enable_rpc_ha           = false,
  $enable_notifications_ha = true,
  $fqdn_prefix             = '',
  $pid_file                = undef,
  $policy_file             = undef,
) inherits ::rabbitmq::service {

  if $host_ip == 'UNSET' or $host_ip == '0.0.0.0' {
    $real_host_ip = '127.0.0.1'
  } else {
    $real_host_ip = $host_ip
  }

  $parameters      = {
    'host_ip'                 => $real_host_ip,
    'node_port'               => $port,
    'debug'                   => $debug,
    'command_timeout'         => $command_timeout,
    'erlang_cookie'           => $erlang_cookie,
    'admin_user'              => $admin_user,
    'admin_password'          => $admin_pass,
    'enable_rpc_ha'           => $enable_rpc_ha,
    'enable_notifications_ha' => $enable_notifications_ha,
    'fqdn_prefix'             => $fqdn_prefix,
    'pid_file'                => $pid_file,
    'policy_file'             => $policy_file,
  }

  $metadata        = {
    'migration-threshold' => '10',
    'failure-timeout'     => '30s',
    'resource-stickiness' => '100',
  }

  $complex_metadata     = {
    'notify'      => 'true',
    # We shouldn't enable ordered start for parallel start of RA.
    'ordered'     => 'false',
    'interleave'  => 'true',
    'master-max'  => '1',
    'master-node-max' => '1',
    'target-role' => 'Master'
  }

  $operations      = {
    'monitor' => {
      'interval' => '30',
      'timeout'  => '180'
    },
    'monitor:Master' => { # name:role
      'role' => 'Master',
      # should be non-intercectable with interval from ordinary monitor
      'interval' => '27',
      'timeout'  => '180'
    },
    'monitor:Slave'  => {
      'role'            => 'Slave',
      'interval'        => '103',
      'timeout'         => '180',
      'OCF_CHECK_LEVEL' => '30'
    },
    'start'     => {
      'interval' => '0',
      'timeout'  => '360'
    },
    'stop' => {
      'interval' => '0',
      'timeout'  => '120'
    },
    'promote' => {
      'interval' => '0',
      'timeout'  => '120'
    },
    'demote' => {
      'interval' => '0',
      'timeout'  => '120'
    },
    'notify' => {
      'interval' => '0',
      'timeout'  => '180'
    },
  }

  pacemaker::service { $service_name :
    primitive_type      => $primitive_type,
    complex_type        => 'master',
    complex_metadata    => $complex_metadata,
    metadata            => $metadata,
    operations          => $operations,
    parameters          => $parameters,
    #    ocf_script_file     => $ocf_script_file,
  }
  Service[$service_name] -> Rabbitmq_user <||>
}