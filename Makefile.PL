# IMPORTANT: if you delete this file your app will not work as
# expected.  you have been warned
use inc::Module::Install;

name 'MyPHP';
all_from 'lib/MyPHP.pm';

requires 'Catalyst::Runtime' => '5.7015';
requires 'Catalyst::Plugin::ConfigLoader';
requires 'Catalyst::Plugin::Static::Simple';
requires 'Catalyst::Action::RenderView';
requires 'Catalyst::Plugin::Params::Demoronize';
requires 'parent';
requires 'Config::General';
requires 'Catalyst::View::TT';
requires 'RTF::HTMLConverter';
requires 'XML::DOM';
requires 'Net::FTP';
requires 'Path::Class';
requires 'Any::Moose';
requires 'CGI::Simple';
requires 'Tree::Simple';
requires 'Tree::Simple::Visitor::LoadDirectoryTree';
requires 'Tree::Simple::Visitor::PathToRoot';
requires 'File::Finder';
requires 'XML::Atom::SimpleFeed';
requires 'HTTP::Date';
requires 'HTML::Entities';
requires 'File::Remove';
catalyst;

install_script glob('script/*.pl');
auto_install;
WriteAll;
