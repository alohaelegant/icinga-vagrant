# This class manages the Logstash package.
#
# It is usually used only by the top-level `logstash` class. It's unlikely
# that you will need to declare this class yourself.
#
# @param [String] package_name
#   The name of the Logstash package in the package manager.
#
# @param [String] version
#   Install precisely this version from the package manager.
#
# @param [String] package_url
#   Get the package from this URL, not from the package manager.
#
# @example Include this class to ensure its resources are available.
#   include logstash::package
#
# @author https://github.com/elastic/puppet-logstash/graphs/contributors
#
class logstash::package(
  $package_url = $logstash::package_url,
  $version = $logstash::version,
  $package_name = $logstash::package_name,
)
{
  if $logstash::ensure == 'present' {
    # Check if we want to install a specific version.
    if $version {
      $package_ensure = $version
    }
    else {
      $package_ensure = $logstash::auto_upgrade ? {
        true  => 'latest',
        false => 'present',
      }
    }

    if ($package_url) {
      $filename = basename($package_url)
      $extension = regsubst($filename, '.*\.', '')
      $protocol = regsubst($package_url, ':.*', '')
      $package_local_file = "/tmp/${filename}"

      case $protocol {
        'puppet': {
          file { $package_local_file:
            source => $package_url,
          }
        }
        'ftp', 'https', 'http': {
          exec { "download_package_logstash_${name}":
            command => "wget -O ${package_local_file} ${package_url} 2> /dev/null",
            path    => ['/usr/bin', '/bin'],
            creates => $package_local_file,
            timeout => $logstash::download_timeout,
          }
        }
        'file': {
          file { $package_local_file:
            source => $package_url,
          }
        }
        default: {
          fail("Protocol must be puppet, file, http, https, or ftp. Not '${protocol}'")
        }
      }

      case $extension {
        'deb':   { $package_provider = 'dpkg'  }
        'rpm':   { $package_provider = 'rpm'   }
        default: { fail("Unknown file extension '${extension}'.") }
      }
    }
    else {
      # Use the OS packaging system to locate the package.
      $package_local_file = undef
      $package_provider = undef
      if $::osfamily == 'Debian' {
        $package_require = Class['apt::update']
      }
    }
  }
  else { # Package removal
    $package_local_file = undef
    if ($::osfamily == 'Suse') {
      $package_provider = 'rpm'
      $package_ensure = 'absent' # "purged" not supported by provider
    }
    else {
      $package_provider = undef # ie. automatic
      $package_ensure = 'purged'
    }
  }

  package { 'logstash':
    ensure   => $package_ensure,
    name     => $package_name,
    source   => $package_local_file, # undef if using package manager.
    provider => $package_provider, # undef if using package manager.
    require  => $package_require,
  }

  Exec {
    path      => [ '/bin', '/usr/bin', '/usr/local/bin' ],
    cwd       => '/',
    tries     => 3,
    try_sleep => 10,
  }

  File {
    ensure => file,
    backup => false,
  }
}
