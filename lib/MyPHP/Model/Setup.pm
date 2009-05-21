package MyPHP::Model::Setup;

use strict;
use warnings;
use parent 'Catalyst::Model';

use Config::General;
use Net::FTP;
use WWW::Mechanize;
use Path::Class;
use HTML::Entities;

__PACKAGE__->mk_accessors(qw/path_to storage publish user_pages site_conf email_root/);

sub ACCEPT_CONTEXT {
    my ($self, $c ) = @_;
    $self = bless({ %$self,
                    path_to => $c->path_to(''),
                    storage => Path::Class::Dir->new($c->config->{'Model::Publish'}->{storage}),
                    publish => $c->model('Publish'),
                    user_pages => $c->config->{pages}->{user},
                    site_conf => $c->config->{site_conf},
                    email_root => $c->config->{email_root},
                }, ref($self));
    return $self;
}

sub store_user_data {
    my ($self, $data) = @_;
    my $name =  $data->{'fn'} . " " . $data->{sn};
    my $default_title;
    $name =~ /s$/ ?
        $default_title = $name . "' Personal Website" :
            $default_title = $name . "'s Personal Website";
    my $fn = $data->{fn};
    my $sn = $data->{sn};
    my $user_conf = {
        title => $data->{'title'} || $default_title,
        fn => $fn,
        sn => $sn,
        username => $data->{'username'},
        office   => $data->{'office'},
        tel      => $data->{'tel'},
        email    => encode_entities($data->{username} . $self->email_root, 'abcdefghijklmnopqrstuvwxyz@.ABCEFGHIJKLMNOPQRSTUVWXYZ1234567890.'),
        pass => $data->{'pass'},
        root => $data->{'root'},
        other_homepage => $self->get_school_page($name),
        ro_uri => $self->get_ro_uri($fn, $sn),
    };

    if ($data->{pass} ne $data->{confpass}) {
        return "Passwords must match";
    }

    unless (  $user_conf->{fn} &&   $user_conf->{sn} && $user_conf->{username} && $user_conf ->{pass} ) {
        return 'Required fields are First name, Surname, Username and Password.  Please ensure these are completed'
    }

    if ( ! $self->publish->check_ftp($user_conf->{username}, $user_conf->{pass}) ) {
        return "Username and or password incorrect" ;
    }
    my $file = $self->site_conf;
    my $config = Config::General->new($user_conf);
    eval {
        $config->save_file($file, $user_conf);
    };
}

sub get_ro_uri {
    my ($self, $fn, $sn) = @_;
    my ($initial) = $fn =~ /^(\w)/;
    my $url;
    # do evil web scraping or munging GET params here to get a url :)
    return $url;
}

sub get_school_page {
    my ($self, $name) = @_;
    my $url;
    # do evil web scraping or munging GET params here to get a url :)
    return $url;
}

sub change_credentials {
    my ($self, $nu, $np);
    my $config = Config::General->new($self->site_conf)->getall;
    $config->{username} = $nu;
    $config->{pass} = $np;
    Config::General->new($config)->save_file($self->site_conf);
    return;
}



1;

