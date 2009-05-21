package Net::Ftp::RecursivePut;

use Any::Moose;
use Net::FTP;
use Tree::Simple;
use Tree::Simple::Visitor::LoadDirectoryTree;
use Tree::Simple::Visitor::PathToRoot;

# required

has 'host' =>  (isa => 'Str', is => 'ro', required => 1);
has 'remove_first' => (isa => 'Bool', is => 'ro', default => 0);
has 'login' => (isa => 'Str', is => 'ro', required => 1);
has 'passwd' => (isa => 'Str', is => 'ro', required => 1);
has 'base_home' => (isa => 'Str', is => 'ro', required => 1);

has 'base_dest' => (isa => 'Str', is => 'ro', default => './');
has 'check_mtime' => (isa => 'Bool', is => 'ro', default => 0); # unimplemented
has 'tree' => ( isa => 'Tree::Simple', is => 'ro', lazy_build => 1);


sub get_ftp_connection  {
    my ($self) = @_;
    my $ftp = Net::FTP->new($self->host);
    $ftp->login($self->login, $self->passwd);
    return $ftp->pwd ? $ftp : undef;
}

sub _build_tree {
    my ($self) = @_;
    my $tree = Tree::Simple->new($self->base_home);
    my $visitor = Tree::Simple::Visitor::LoadDirectoryTree->new();
    $visitor->setNodeFilter( sub {
                                 my ($item) = @_;
                                 return 1; # get everything
                             });
    $tree->accept($visitor);
    return $tree;
}

sub put_tree {
    my ($self) = @_;
    my @flat_tree;
    my $local = Path::Class::Dir->new($self->base_home);
    my $remote = Path::Class::Dir->new_foreign( 'Unix', $self->base_dest);
    my @remote_dir_list = $remote->dir_list;

    my $ftp = $self->get_ftp_connection;
    $ftp->rmdir("$remote", 1) if $self->remove_first;
    $ftp->binary;

    # setup dirs
    my $remote_base;
    for (@remote_dir_list) {
        $ftp->mkdir($_);
        $ftp->site("CHMOD 755 $_");
        $ftp->site("CHMOD g+s $_");
        $ftp->cwd($_);
        $remote_base = Path::Class::Dir->new_foreign('Unix', $ftp->pwd());
    }

    
    my $visitor = Tree::Simple::Visitor::PathToRoot->new;
    $self->tree->traverse ( sub {
                                my ($node) = @_;
                                $node->accept($visitor);
                                my @path = $visitor->getPath;
                                push @flat_tree, \@path;
                            });
    for my $aref (@flat_tree) {
        my $dir = $local->subdir(@$aref);
        if (-d $dir) {
            $ftp->mkdir($remote_base->subdir(@$aref), 1);
            $ftp->site("CHMOD 755 $dir");
            $ftp->site("CHMOD g+s $dir");
            $ftp->cwd("$remote_base");
        }
        else {
            my $file = $local->file(@$aref);
            my $dest_dir = $remote_base->file(@$aref)->dir;
            $ftp->mkdir($dest_dir,1);
            $ftp->site("CHMOD 755 $dest_dir");
            $ftp->cwd($dest_dir);
            my $remote_file = $remote_base->file(@$aref)->basename;
            $ftp->put("$file", "$remote_file");
            $ftp->site("CHMOD 644 $remote_file");
            $ftp->cwd("$remote_base");
        }
    }
}

1;
__END__
=head1 NAME

Net::Ftp::RecursivePut

Recursively mirrors directories of files to a ftp server.

=head1 SYNOPSIS;

 my $ftp = Net::Ftp::RecursivePut->new( %config );

Please read the source for optional and required configuration.
options/requirements.

=head1 VERSION

Version 0.01

=cut

=head1 METHODS


=head2 get_ftp_connection

Returns the Net::FTP object if the host, username and password are ok, undef
otherwise.

=head2 _build_tree

Returns the Tree::Simple nodes for the base_home dir hierarchy


=head2 put_tree

Puts the dir tree onto the ftp server.  Doesn't do any error checking, it just
tries to blat the whole directory tree onto the remote server.  The theory is
that if there's a problem it will be resolved on the next upload.
