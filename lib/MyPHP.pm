package MyPHP;

use strict;
use warnings;

use Catalyst::Runtime '5.70';

use parent qw/Catalyst/;
use Catalyst qw/
                   ConfigLoader
                   Static::Simple
                   Params::Demoronize
               /;
our $VERSION = '0.01';

__PACKAGE__->config->{static}->{dirs} = [
    'static',
    qr/^(images|css)/,
];

if (exists $ENV{TESTING_APP}) {
    my $file = __PACKAGE__->path_to('t/lib/myphp_test.conf');
    __PACKAGE__->config( 'Plugin::ConfigLoader' => { file => $file } );

}

__PACKAGE__->setup();


use Class::C3;
use URI ();

sub uri_for {
    my $self = shift;
    my $uri = $self->next::method(@_);
    $self->stash->{current_view} = 'Edit'
        unless $self->stash->{current_view}; # eliminate ugly undef warnings
    if ($self->stash->{current_view} eq 'Publish') {
        my $login = $self->stash->{site_config}->{username};
        my $path = "~$login".$uri->path;
        my $new_base;
        if ($self->stash->{site_config}->{root} ) {
            $new_base = $self->config->{publish_base} . "/" . $self->stash->{site_config}->{root};
        }
        else {
            $new_base = $self->config->{publish_base}
        }
        $DB::single=1;
        $uri = URI->new_abs( $path, $new_base);
        $uri =~ s/\/\//\//g;
        $uri=~ s/http:\//http:\/\//g;
    }
    
    return URI->new($uri)
}


1;

__END__

=head1 NAME

My Personal Home Page - MyPHP

=head2 SYNOPSIS

My Personal Home Page is a small website to be deployed as a single user
application on a memory stick (or other mobile storage), or "installed" on a
single user machine.  The idea is to be able to deploy a modern full-featured
personal web site onto a server with nothing but FTP access.  It should be easy
enough to use that people with basic computer literacy (i.e. no technical
knowledge of web publishing, ftp servers etc) should be abl to use it once
configured.

On a Unix system, use your distribution's package manager to install perl
(5.8.6 or greater) and install the required modules with the following code:

 $ perl Makefile.PL
 $ make
  # answer yes to the question here
 $ make installdeps

B<IMPOTANT NOTE:> Do B<not> C< make instal > this application.  It is not
designed to do so.  If I could figure out an easy way to prevent
Module::Install from making a valid C< make install > entry in the Makefile, I
would.

On a Windows system grab Strawberry Perl from http://www.strawberryperl.com and
install it using the same process as above.  If you are using the portable
version, you will want a C< startperl.bat > file as follows in the strawberry
perl root folder:

 echo off
 set bindir=%~dp0
 set perlpath=%bindir%perl\bin
 set buildpath=%bindir%\bin
 set PATH=%PATH%;%perlpath%;%buildpath%
 start cmd

If you have any trouble with C< make installdeps > you may need to install some
modules through the cpan shell eith by C< force > or with the C< notest >
pragma.  The quickest way to get help with problems you are unable resolve
yourslef is on IRC at #perl-help on irc.perl.org, #perl on irc.freenode.net or
#catalyst on irc.perl.org.  If you are using Windows, it may be advisable to
work out what the module dependencies are by reading the Makefile.PL and
installing them in the cpan shell under notest first (windows is annyoying - I
have successful deployments of this software on windows, but had to resort to
C< notest > for much of the install).

=head2 Deployment

On a unix system, there are many ways to deploy.  You could just add the
following to your ~/.bash_profile or equivalent (assuming MyPHP is copied into
your home directory):

    MYPHP_BIN=$HOME/MyPHP/script/myphp_server.pl
    if [ ! -f /tmp/my_php_is_running ]
    do MYPHP_BIN -p 35900 2>&1 >/tmp/myphp.log & && touch /tmp/myphp_is_running
    fi

On Windows, it's a whole extra level of fun.  Fortunately, I've pre-prepared
the fun for you.  Here I'll assume that you have strawberry perl portable in a
directory with the required catalyst modules installed.  First, copy MyPHP into
this directory.  Second add the following batch script into the strawberry perl
root directory.  Call it start_myphp.bat

 echo off
 set bindir=%~dp0
 set perlpath=%bindir%perl\bin
 set buildpath=%bindir%\bin
 set PATH=%PATH%;%perlpath%;%buildpath%
 "%perlpath%\wperl.exe" "%bindir%MyPhp\script\myphp_server.pl" -p 35900

Next you want a visual basic script to start the server without spawning a
pesky dos window.  Call this one startmyphp.vbs:

 Set fso = CreateObject("Scripting.FileSystemObject")
 Set WshShell = CreateObject("WScript.Shell")
 WshShell.Run chr(34) &  fso.GetParentFolderName(wscript.ScriptFullName) & "\perlshell.bat"& Chr(34), 0
 Set WshShell = Nothing

Next obtain a copy of Shortcut.exe (http://www.optimumx.com/download/#Shortcut)
and put it in the root directory of strawberry perl as well.  Finally you want
an installer, so that you can install it onto users computers.  This script
below (call it install.bat) works well in a locked down environemnt.  It puts a
shortcut to the vbs script in the user's startup folder and opens the web
browser on the web server page.  The port 35900 is arbitrary (apart from that
359 is the funniest three digit number).

 @echo off
 set bindir=%~dp0
 set bindir=%bindir:~0,-1%
 mkdir "%APPDATA%\MyPersonalHomePage"
 echo ...
 echo Copying application to hard drive, please be patient ....
 xcopy /E /C /Y /Q  "%bindir%" "%APPDATA%\MyPersonalHomePage"
 echo ...
 echo Creating link in  startup folder
 echo ...
 mkdir "%APPDATA%\..\Start Menu\Programs\Startup"
 Shortcut.exe /R:7 /A:C /T:"%APPDATA%\MyPersonalHomePage\startmyphp.vbs"  /F:"%APPDATA%\..\Start Menu\Programs\Startup\Start Personal Home Page Server.lnk"
 "%APPDATA%\MyPersonalHomePage\startmyphp.vbs"
 echo Starting server, please be patient
 ping 127.0.0.1 -n 10 -w 1000 > nul
 start http://127.0.0.1:35900

=head2 CONFIGURATION

Site config is from the myphp.conf file (see myphp_sample.conf for a commented
version of this).  User config is generated at first run, or any other time the
user uses the "Edit Setup" link in the admin menu.

=head2 MODIFICATION and EXTENSION

If you want to change the end user templates, they're in the web_publish folder
below the root directory of MyPHP.  They are written using the Template Toolkit
(http://template-toolkit.org/) templating language.  This should be reasonably
self explanatory if you understand the concept of templating, and have a basic
knowledge of HTML.

=head2 RUNNING A BLOG

The easy way to run a blog is to put a folder at the top level of the directory
tree; add some introductory content here, and then keep using the "Add another
page at current level" to add new blog entries.  Limitations of this approach
at present are:

=over

=item *

The RSS feed will be for the entire site, not the blog.

=item *

The timestamp is not shown on the blog page (but is in the RSS feed)

=item *

The only way to get a list of all entries in the page is to use the RSS feed,
which also grabs every other page in the site.

=back

=head2 TODO

=over

=item *

Clean up the design of the setup form to be a little more user-friendly.

=item *

Improve the blog function

=item *

At present the code only supports publishing to remote hosts by ftp where the
eventual base url of the site is of the form http://remotehost/~username or
http://remote/~username/remote_base

=item *

Work out how to get TinyMCE to EMBED items (e.g. youtube videos).

=item *

Refactor the over-ridden uri_for sub in MyPHP.pm to use a remote_uri_for sub,
and possibly update the templates in the web_templates directory to use this
directly.  (You also want to use a remote_uri_for method in the index.tt
template in the editing interface to get the "published link for this page"
link in a saner way than it is currently implemented.

=item *

Make the push to ftp code slightly more inteligent.  At this stage, it simply
pushes the entire site, static content and all over to the web space.  This
should only be necessary on addition of a new page (and we could be more
intelligent about pushing the static content too).  The important technical
limitation here is that the local host is not guaranteed to have time
synchronised with the remote host, and that if you wanted to use md5 hashes or
similar to check if the remote host had changed, you can't do that without
transferring the remote file back over to the local host (assuming ftp
transport which is all that is supported at this stage).

=back

=head2 ACKNOWLEDGEMENTS

Thanks to Rafael Kitover for help with the uri_for code in MyPHP.pm

This application was funded by the People and Organisations Research Centre
(http://www.uow.edu.au/commerce/smm/mgmt/porc/index.html） at the University of
Wollongong in Australia to provide a webspace with modern features deployed on
a server with nothing but the ability to serve static pages.

=head2 AUTHOR and COPYRIGHT

Copyright Kieren Diment <zarquon@cpan.org> 2009.

=head2 LICENCE

This library is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.


