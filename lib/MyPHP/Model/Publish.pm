package MyPHP::Model::Publish;

use strict;
use warnings;
use parent 'Catalyst::Model';

use Carp;
use Config::General;
use Net::FTP;
use Tree::Simple::Visitor::LoadDirectoryTree;
use Tree::Simple::Visitor::PathToRoot;
use Net::Ftp::RecursivePut;
use Path::Class;
use File::Finder;
use File::Remove 'remove';


__PACKAGE__->mk_ro_accessors(qw/user pass host dest_root assets storage/);

sub ACCEPT_CONTEXT {
    my ($self, $c ) = @_;
    $self = bless({ %$self,
                    host      => $c->config->{'Model::Publish'}->{host},
                    user      => $c->stash->{site_config}->{username},
                    pass      => $c->stash->{site_config}->{pass},
                    dest_root => $c->config->{'Model::Publish'}->{dest} . "/" . $c->stash->{site_config}->{root},
                    assets    =>
                        Path::Class::Dir->new($c->config->{'View::Publish'}->{INCLUDE_PATH}->[0], 'static'),
                },
                  ref($self));
    return $self;
}

sub check_ftp {
    my ($self, $user, $pass) = @_;
    $DB::single=1;
    $user ||= $self->user;
    $pass ||= $self->pass;
    my $f = Net::FTP->new($self->host);
    $f->login($user, $pass);
    return $f->pwd ? 1 : 0;
}

sub rtf2html {
    my ($self, $file) = @_;
    use XML::DOM;
    use RTF::HTMLConverter;

    open my $in, "<", $file;

    # convert rtf
    my $html;
    my $parser = RTF::HTMLConverter->new(
        in  => \$in,
        out => \$html,
        discard_images => 1,
        DOMImplementation => 'XML::DOM',
        codepage => 'iso-8859-1',
    );
    $parser->parse();
    close $in;
    # trim and output
    $html =~ s/.*?<body>(.*?)<\/body>.*?/$1/ms;
    return $html;
}

sub save {
    my ($self, $upload, $title, $path) = @_;
    my $html = $self->rtf2html($upload);
    if ($path) {
        # work out subdir stuff later
    }
    my $dir = Path::Class::Dir->new($self->storage)->subdir($title);
    $dir = $dir->parent if $title eq 'Home' && ! $path;
    mkdir $dir if !-e $dir;
    my $outfile = $dir->file('raw.html');
    open my $FH, ">", $outfile;
    print $FH $html;
    close $FH;
    return 1;
}

sub save_from_form {
    my ($self, $dir, $content) = @_;
    my $outfile = $dir->file('raw.html');
    open my $FH, ">", $outfile or return undef;
    print $FH $content;
    close $FH;
    return 1;
}

sub get_content {
    my ($self, @page) = @_;
    my $dir = Path::Class::Dir->new($self->storage);
    $dir = $dir->subdir(@page) if @page;
    return $self->read_file($dir->file('raw.html'));
}

sub read_file {
    my ($self, $file) = @_;
    local $/;
    my $FH;
    eval {
        open  $FH, "<", $file or die "unable to read file";
    };
    return undef if $@;
    my $content = <$FH>;
    $content = " " if ! $content; # hack to allow existence of empty pages!
    close $FH;
    return $content;
}

sub write_file {
    my ($self, $file, $content) = @_;
    local $/;
    eval {
        open my $FH, ">", $file;
        print $FH $content;
        close $FH;
    };
    if ($@) {
        carp $@;
        return 0;
    }
    else {
        return 1;
    }
}

sub write_page {
    my ($self, $txt, @path) = @_;
    my $file = Path::Class::Dir->new($self->storage)->subdir(@path)->file('index.html');
    return $self->write_file("$file", $txt);
}

sub menu {
    my ($self) = @_;
    my $storage = Path::Class::Dir->new($self->storage);

    my $tree = Tree::Simple->new($storage);
    my $visitor = Tree::Simple::Visitor::LoadDirectoryTree->new();
    $visitor->setSortStyle( \&sort_by_mtime);
    $visitor->setNodeFilter( sub {
                                 my ($item) = @_;
                                 return 0 if $item =~ /^\.$|\.html$|^Home|\.xml$/;
                                 return 1;
                             });
    $tree->accept($visitor);
    my $pathfinder = Tree::Simple::Visitor::PathToRoot->new();
    return [$tree, $pathfinder];
}

sub sort_by_mtime {
    my ($path, $left, $right) = @_;
    $left  = File::Spec->catdir($path, $left);
    $right = File::Spec->catdir($path, $right);
    my $left_t = (stat($left))[9];
    my $right_t = (stat($right))[9];
    return (($left_t >  $right_t) ? 1 :       # file beats directory
                ( $right_t > $left_t) ? -1 :    # file beats directory
                    (lc($left) cmp lc($right)))     # otherwise just sort 'em
}

sub is_terminal {
    my ($self, @path) = @_;
    my $dir = Path::Class::Dir->new($self->storage)->subdir(@path);
    opendir my ($DH), $dir;
    my @subdirs;
    while (my $file = readdir($DH)) {
        next if ! -d $dir->subdir($file);
        next if $file =~ /^\.+$/;
        push @subdirs, $file;
    }
    closedir $DH;
    return 1 if ! @subdirs;
    return undef;
}

sub delete_page {
    my ($self, @path) = @_;
    my $dir = Path::Class::Dir->new($self->storage)->subdir(@path);

    # return undef if we shouldnt be here
    return undef unless -e $dir;
    return undef if ! $self->is_terminal(@path);
    warn "DIR to delete:  $dir";
    remove (\1, $dir);
    return @path;
}

sub add_page {
    my ($self, $title, $copy, @path) = @_;
    my $dest_dir = Path::Class::Dir->new($self->storage)->subdir(@path)->subdir("$title");

    eval {mkdir $dest_dir};
    return { error => "Failed to make directory: $@"} if $@;
    my $ok = $self->save_from_form($dest_dir, $copy);
    return $ok;
}

sub publish_assets {
    my ($self) = @_;
    my $base_home = $self->assets;
    my $base_dest = $self->dest_root . "/static";
    my $ftp = Net::Ftp::RecursivePut->new(
        host         => $self->host,
        login        => $self->user,
        passwd       => $self->pass,
        remove_first => 0,
        base_home    => "$base_home",
        base_dest    => "$base_dest",
    );
    $ftp->put_tree;
}

sub publish_site {
    my ($self) = @_;
    my $base_home = $self->storage;
    my $base_dest = $self->dest_root;
    my $ftp = Net::Ftp::RecursivePut->new(
        host         => $self->host,
        login        => $self->user,
        passwd       => $self->pass,
        remove_first => 1,
        base_home    => "$base_home",
        base_dest    => "$base_dest",
    );
    $ftp->put_tree;
    $self->publish_assets;
}

sub get_pages {
    my ($self) = @_;
    my $root = $self->storage;
    my @files = map { $_->[1] }
        sort { $a->[0] <=> $b->[0] }
            map  { [ -M $_, $_ ] }
                grep { /\w/ }
                    File::Finder->type('f')->in("$root");
    @files = grep { /raw.html/ } @files;
    map {$_ = Path::Class::File->new($_)} @files;

    my @data;

    foreach my $f (@files) {
        my %item;
        my @link = $f->relative( $self->storage )->dir->dir_list;
        my $title = $link[$#link];
        %item = ( title   => $title,
                  link    => \@link,
                  summary => $self->read_file($f),
                  updated => (stat($f))[9],
              );
        push @data, \%item;
    }
    return @data;
}

sub get_uploaded_files {
    my ($self) = @_;
    my $f = Net::FTP->new($self->host);
    $f->login($self->user, $self->pass);
    my @dest = Path::Class::Dir->new($self->dest_root)->dir_list;
    $f->cwd($_) for @dest;
    $f->cwd('uploads') or return undef;
    return [$f->ls];

}

sub put_uploaded_file {
    my ($self, $upload) = @_;
    my $f = Net::FTP->new($self->host);
    $f->binary;
    $f->login($self->user, $self->pass);
    my @dest = Path::Class::Dir->new($self->dest_root)->dir_list;
    $f->cwd($_) for @dest;
    $f->mkdir('uploads');
    $f->site("CHMOD 755 uploads");
    $f->cwd('uploads');
    my $remote = $upload->basename;
    $f->put($upload->tempname, $remote);
    $f->site("CHMOD 644 $remote");
}
1;

