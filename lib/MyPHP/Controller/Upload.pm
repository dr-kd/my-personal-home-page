package MyPHP::Controller::Upload;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Net::FTP;

sub default :Private {
    my ($self, $c) = @_;
    $c->stash(template => 'upload.tt',
              files    => $c->model('Publish')->get_uploaded_files,
          );
}

sub do_upload :Local {
    my ($self, $c) = @_;
    $c->model('Publish')->put_uploaded_file($c->req->upload('file'));
    $c->res->redirect($c->uri_for('/upload'));
}

1;
