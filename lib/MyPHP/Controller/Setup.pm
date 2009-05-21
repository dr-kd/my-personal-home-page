package MyPHP::Controller::Setup;

use strict;
use warnings;
use parent 'Catalyst::Controller';

sub firstrun :Private {
    my ( $self, $c ) = @_;
    $c->stash(
        template => 'setup/firstrun.tt',
    );
}

sub edit :Local {
    my ( $self, $c ) = @_;
    $c->forward('firstrun');
}

sub do_setup :Local {
    my ($self, $c ) = @_;
    my $dest = $c->req->query_params->{dest} || '/';
    my $error = $c->model('Setup')->store_user_data($c->req->body_params);
    if ($error) {
        $c->stash(message => $error);
        $c->detach('firstrun');
        return 0;
    }
    else {
        $c->res->redirect($dest);
    }
}

sub ftp_pass_change :Private {
    my ($self, $c) = @_;
    $c->res->status(401);
    $c->res->content_type('text/plain');
    $c->res->body($c->config->{auth_string});
    $c->res->headers->header('WWW-Authenticate' => 'Basic realm="password required"');
    my ($new_user, $new_pass) = $c->req->headers->authorization_basic;
    if ($c->model('Publish')->check_ftp($new_user, $new_pass) ) {
        $c->model('Setup')->change_credentials($new_user, $new_pass);
    }
    else {
        # run the request again to get it right
    }
    $c->res->redirect('/');
}


1;

