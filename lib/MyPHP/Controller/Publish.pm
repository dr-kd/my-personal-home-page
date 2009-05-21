package MyPHP::Controller::Publish;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Path::Class;
use Tree::Simple::View::HTML;


sub menu_tree :Private {
    my ($self, $c) = @_;
    my $menu_tree = $c->model('Publish')->menu();
    $c->stash( menu => $menu_tree->[0],
               pathfinder => $menu_tree->[1],
           );
}

sub visit_node {
    my ($node) = @_;
    return 0 if $node eq 'root';
    return 0 if ref($node->getNodeValue) eq 'Path::Class::Dir';
    return 1;
}

sub publish :Path('edit') {
    my ($self, $c, @path) = @_;
    $c->stash->{render_path} = \@path;
    my $html = $c->req->params->{copy};
    my $dir = Path::Class::Dir->new($c->model('Publish')->{storage});
    $dir = $dir->subdir(@path) if @path;
    my $outfile = $dir->file('raw.html');
    $c->model('Publish')->write_file($outfile, $html);
    $c->forward('render_site');


    # change password logic here
    $c->model('Publish')->publish_site;
    $c->res->redirect($c->uri_for('/', @path));
    
}

sub render_site :Private {
    my ($self, $c) = @_;
    my $start_dir = $c->model('Publish')->{storage};
    $c->stash->{render_path} = [];
    $c->forward('render'); # render root dir

    my $tree = Tree::Simple->new($start_dir);
    my $dir_visitor = Tree::Simple::Visitor::LoadDirectoryTree->new();
    $tree->accept($dir_visitor);
    my $visitor = Tree::Simple::Visitor::PathToRoot->new;
    $tree->traverse( sub {
                         my ($node) = @_;
                         $node->accept($visitor);
                         my $dir = Path::Class::Dir->new($start_dir)->subdir($visitor->getPath);
                         if (-d $dir) {
                             $c->stash->{render_path} = [ $visitor->getPath ];
                             $c->forward('render');
                         }
                     }
                 );

    # Render local and remote versions of rss feed
    $c->stash( current_view => 'Publish');
    $c->forward('/xml');
    $c->stash( current_view => 'Edit');
    $c->forward('/xml');
}

sub render :Private {
    my ($self, $c) = @_;
    my @path = @{ $c->stash->{render_path} };
    shift @path if ( $path[0] eq 'Home' && scalar(@path) ==1 );
    $c->stash( current_view => 'Publish'); # makes my uri_for code work
    my $content = $c->model('Publish')->get_content(@path);
    $c->stash->{content} = $content;
    $c->forward('menu_tree') ;
    my $txt = $c->view('Publish')->render($c, 'index.tt');
    $c->model('Publish')->write_page($txt, @path);
    $c->stash( current_view => 'Edit');
}

sub standard :Local {
    my ($self, $c) = @_;
    my @files  = @ {$c->config->{pages}->{user} };
    my $no_files = 0;

    foreach my $f (@files) {
        if ( $c->req->params->{$f} ) {
            my $upload = $c->req->upload($f)->tempname;
            $no_files++ if $c->model('Publish')->save($upload, $f);
            $c->stash->{render_path} = [$f];
        }
    }
    $c->forward('render_site');
    $c->model('Publish')->publish_site;
    $c->res->redirect($c->uri_for('/'));
}

sub _add_page :Local {
    my ($self, $c, @path) = @_;
    # TODO  work out what needs to be done to make this bit work!
    $c->stash(
        template => 'add.tt',
        below => $c->req->query_params->{below},
        dest => $c->uri_for('_do_add_page', @path),
        path => scalar @path ? \@path : undef,
    );
}

sub _do_add_page :Local {
    my ($self, $c, @path) = @_;
    my $params = $c->req->params;
    my ($title, $below, $copy) = ($params->{title}, $params->{below}, $params->{copy});
    pop @path if !$below && @path;
    my $ok = $c->model('Publish')->add_page($title, $copy, @path);
    push @path, $title;
    $c->forward('render_site');
    $c->model('Publish')->publish_site;
    if (ref($ok) ) {
        $c->res->body("Error writing page with error $ok->{error}");
    }
    else {
        $c->res->redirect($c->uri_for($c->controller('Root')->action_for('root'), @path));
        return 0;
    }
}



sub _delete_page : Local {
    my ($self, $c) = @_;
    my $root_controller = $c->controller('Root');
    $c->stash(template => 'confirm_del.tt',
              delete => $c->uri_for('_do_delete', @{$c->req->args}),
              cancel => $c->uri_for($root_controller->action_for('root'), @{$c->req->args}),
          );
}

sub _do_delete : Local{
    my ($self, $c) = @_;
    my @path = @{$c->req->args};
    my @dest_path = $c->model('Publish')->delete_page(@path);
    my $error;
    if (! @dest_path) {
        $error = "There was an error deleting " . join ("/", @path) if ! @dest_path;
        @dest_path = @path;
    }
    else {
        pop @dest_path;
        $error = join ('/', @path) . " deleted OK";
    }
    my $root_controller = $c->controller('Root');
    $c->stash(error => $error,
              orig_path  => $c->uri_for( $root_controller->action_for('root') , @path),
              dest_path  => $c->uri_for($root_controller->action_for('root') , @dest_path),
              orig_page  => join ("/", @path),
              template   => 'deleted.tt',
          );
}


1;
