#!/usr/local/cpanel/3rdparty/bin/perl

package test::cpev::blockers;

use FindBin;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;

use Test::MockFile 0.032;
use Test::MockModule qw/strict/;

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

use cPstrict;

my $cpev_mock    = Test::MockModule->new('cpev');
my $distros_mock = Test::MockModule->new('Elevate::Blockers::Distros');

my $cpev    = cpev->new;
my $distros = $cpev->get_blocker('Distros');

{
    note "Distro supported checks.";
    Cpanel::OS::clear_cache_after_cloudlinux_update();
    my $f   = Test::MockFile->symlink( 'linux|centos|6|9|2009', '/var/cpanel/caches/Cpanel-OS' );
    my $osr = Test::MockFile->file( '/etc/os-release',     '', { mtime => time - 100000 } );
    my $rhr = Test::MockFile->file( '/etc/redhat-release', '', { mtime => time - 100000 } );

    my $m_custom = Test::MockFile->file(q[/var/cpanel/caches/Cpanel-OS.custom]);

    my $mock_cpos = Test::MockModule->new('Cpanel::OS');
    $mock_cpos->define( can_be_elevated => 0 );
    $mock_cpos->define( is_cloudlinux => 0 );

    is(
        $distros->check(),
        {
            id  => q[Elevate::Blockers::Distros::_blocker_is_non_centos7],
            msg => 'This script is only designed to upgrade CentOS/CloudLinux 7 to AlmaLinux 8.',
        },
        'C6 is not supported.'
    );

    undef $f;
    Cpanel::OS::clear_cache_after_cloudlinux_update();
    $f = Test::MockFile->symlink( 'linux|centos|8|9|2009', '/var/cpanel/caches/Cpanel-OS' );
    is(
        $distros->check(),
        {
            id  => q[Elevate::Blockers::Distros::_blocker_is_non_centos7],
            msg => 'This script is only designed to upgrade CentOS/CloudLinux 7 to AlmaLinux 8.',
        },
        'C8 is not supported.'
    );

    undef $f;
    Cpanel::OS::clear_cache_after_cloudlinux_update();
    $mock_cpos->redefine( can_be_elevated => 1 );
    $f = Test::MockFile->symlink( 'linux|centos|7|4|2009', '/var/cpanel/caches/Cpanel-OS' );
    like(
        $distros->check(),
        {
            id  => q[Elevate::Blockers::Distros::_blocker_is_old_centos7],
            msg => qr{You need to run CentOS/CloudLinux 7.9 and later to upgrade to AlmaLinux 8. You are currently using},
        },
        'Need at least CentOS 7.9.'
    );

    undef $f;
    Cpanel::OS::clear_cache_after_cloudlinux_update();
    $f = Test::MockFile->symlink( 'linux|centos|7|9|2009', '/var/cpanel/caches/Cpanel-OS' );
    $m_custom->contents('');
    is(
        $distros->check(),
        {
            id  => q[Elevate::Blockers::Distros::_blocker_is_experimental_os],
            msg => 'Experimental OS detected. This script only supports CentOS 7 upgrades',
        },
        'Custom OS is not supported.'
    );
    $m_custom->unlink;
    is( $distros->_blocker_is_experimental_os(), 0, "if not experimental, we're ok" );
    is( $distros->_blocker_is_non_centos7(),     0, "now on a valid C7" );
    is( $distros->_blocker_is_old_centos7(),     0, "now on a up to date C7" );

    undef $f;
    Cpanel::OS::clear_cache_after_cloudlinux_update();
    $f = Test::MockFile->symlink( 'linux|cloudlinux|7|9|2009', '/var/cpanel/caches/Cpanel-OS' );
    $mock_cpos->redefine( is_cloudlinux => 1 );

    is( $distros->_blocker_is_experimental_os(), 0, "if not experimental, we're ok" );
    is( $distros->_blocker_is_non_centos7(),     0, "now on a valid C7" );
    is( $distros->_blocker_is_old_centos7(),     0, "now on a up to date C7" );

    #no_messages_seen();
}

done_testing();
