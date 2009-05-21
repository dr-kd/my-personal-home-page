package MyPHP::Controller::Root;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Config::General;
use CGI::Simple;
use XML::Atom::SimpleFeed;
use POSIX qw( strftime );
use HTTP::Date;
use LWP::UserAgent;

__PACKAGE__->config->{namespace} = '';

sub begin :Private {
    my ($self, $c) = @_;
    my $conf_file = $c->config->{site_conf};

    my $net_error;

    eval {
        $c->stash( site_config => { Config::General->new("$conf_file")->getall },
                   host        => $c->model('Publish')->host,
               );
    };
    if (! -e $conf_file) {
        $net_error = "You need to configure your personal site.  Please follow the  <a href=\"" . $c->uri_for('/setup/edit') . "\">Edit Setup</a> link and enter the required information";

    }
    else {
        # ping remote host to check if it's alive
        my $ping  = LWP::UserAgent->new;
        my $response = $ping->get("http://".$c->model('Publish')->host);
        if (! $response->is_success)  {
            $net_error = "FTP server is unreachable.  Please check your network connection and reload the page when the problem is resolved";
        }
        if (! $net_error ) {
            # check ftp connection for good username / passwd
            eval { $c->model('Publish')->check_ftp() };
            if ( $@ || $@ ne '' ) {
                $net_error = "FTP username or password is incorrect, please visit the <a href=\"" . $c->uri_for('/setup/edit') . "\">Edit Setup</a> link and update your password and/or username";
            }
        }
    }
    $c->stash->{error} = $net_error if $net_error;
}



sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
    my $uploads;
    unless ( $c->stash->{site_config}) {
        $c->log->info('running setup');
        $c->detach('Controller::Setup', 'firstrun');
    }
    my $content = $c->model('Publish')->get_content();
    $c->forward('MyPHP::Controller::Publish', 'menu_tree');
    $c->stash(template => 'index.tt',
              page_content => $content,
          );
}

sub help : Local {
    my ($self, $c) = @_;
    $c->stash->{template} = 'help.tt';
}

sub blog :Local {
    my ($self, $page, $entry);
    # List single entry
    # Page entries
}

sub xml :Local {
    my ($self, $c) = @_;
    my @data = $c->model('Publish')->get_pages;

    # A purist will tell you this should be in it's own view.  But seing as
    # this is a single controller method that doesn't need to set the stash,
    # we're going to short cut by putting it in the controller.

    my $feed = XML::Atom::SimpleFeed->new(
        title   => $c->stash->{site_config}->{title},
        link    => $c->uri_for('/'),
        updated => time2str($data[0]->{updated}),
        author  => $c->stash->{site_config}->{fn} . " " . $c->stash->{site_config}->{sn},
    );

    for my $item (@data) {
        shift @{$item->{link}} if $item->{link}->[0] eq '.';
        $feed->add_entry(
            title => $item->{title},
            link => $c->uri_for(@{$item->{link}}),
            id => $c->uri_for(@{$item->{link}}),
            summary => $item->{summary},
            updated => time2str ($item->{updated}),
        );
    }
    my $outfile = Path::Class::File->new($c->config->{'Model::Publish'}->{storage}, 'atom.xml');
    $c->model('Publish')->write_file($outfile, $feed->as_string);
    if ($c->stash->{current_view} eq 'Edit') {
        $c->res->header('Content-type' => 'text/xml');
        $c->serve_static_file("$outfile");
    }
}

sub default :Path { $_[1]->forward('root') }

sub root : Chained('/') PathPart('') Args(0) {
    my ($self, $c, @path) = @_;
    my $cgi = CGI::Simple->new;
     $_ = $cgi->url_decode($_) for @path;
    my $content;
        $content = $c->model('Publish')->get_content(@path);
    if (! $content) {
        $c->detach('do_404');
        return 0;
    }
    my $terminal_page = $c->model('Publish')->is_terminal(@path);
    $c->forward('MyPHP::Controller::Publish', 'menu_tree'); # get menu
    $c->stash(
        template => 'index.tt',
        request_path => \@path,
        page_content => $content,
        is_terminal => $terminal_page,
    );
}

sub do_404 :Private {
    my ( $self, $c ) = @_;
    $c->response->body( 'Page not found' );
    $c->response->status(404);
    
}

=head2 end

Attempt to render a view, if needed.

=cut 

sub end : ActionClass('RenderView') {
    my ($self, $c) = @_;
}

=head1 AUTHOR

Kieren Diment

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
