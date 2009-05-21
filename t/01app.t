#!/usr/bin/env perl
use strict;
use warnings;

use Test::More qw/no_plan/;
use File::Path;



BEGIN {
    use FindBin qw/$Bin/;
    mkdir "$Bin/lib/storage";
}

use Test::WWW::Mechanize::Catalyst;
my $agent = Test::WWW::Mechanize::Catalyst->new(catalyst_app => 'MyPHP');
$DB::single=1;
# do the setup
$agent->get('/');
$agent->form_name('setup');
$agent->field('confpass', 'higlepix');
$agent->field('pass', 'higlepix');
$agent->field('sn', 'Test');
$agent->field('title', 'Test Site');
$agent->field('root', 'site');
$agent->field('fn', 'MR');
$agent->field('username', 'kd');
$agent->click('submit');
$DB::single=1;
# $agent->content_contains("Add Standard Pages", "Configured app ok");


# add the standard pages
# $agent->form_name('default_content');
# $agent->field('Home', "$Bin/lib/sample/home.rtf");
# $agent->field('About', "$Bin/lib/sample/about.rtf");
# $agent->field('Who we are', "$Bin/lib/sample/who.rtf");
# $agent->field('Research areas', "$Bin/lib/sample/research.rtf");
# $agent->field('Collaboration', "$Bin/lib/sample/collaboration.rtf");
# $agent->click('submit');
cmp_ok($agent->uri, "eq", "http://localhost/", "redirect to right place");
$agent->content_contains('Home page baby!', 'correct content');

ok (!$agent->form_name('default_content'), "don't have any more default content to add");
$agent->content_lacks('/Users/kd/windows_exchange/strawberry_portable/MyPHP/t/lib/storage', "home page is NOT rendered as path string to storage!");

# check rendering of static pages.

use Tree::Simple;
use Tree::Simple::Visitor::LoadDirectoryTree;
my $tree = Tree::Simple->new("$Bin/lib/storage");
my $visitor = Tree::Simple::Visitor::LoadDirectoryTree->new();
$tree->accept($visitor);
ok( $tree->size == 16, "Locally rendered dir tree is correct size");

$tree = Tree::Simple->new("$Bin/lib/rendered");
$visitor = Tree::Simple::Visitor::LoadDirectoryTree->new();
$tree->accept($visitor);
ok( $tree->size == 47, "Remotely pushed dir tree is correct size (with static content");
$agent->get('/publish/_add_page');
$agent->form_name('content');
$agent->field('title', "new top page");
$agent->field('copy', "some misc content");
$agent->click('submit');

diag "DEST: " . $agent->uri;
is ($agent->uri, "http://localhost//new%20top%20page", "redirected to new page");
$agent->content_contains('some misc content', 'expected content for new page');

ok (-e "$Bin/lib/storage/new top page/raw.html", "new raw html locally rendered");
ok (-e "$Bin/lib/storage/new top page/index.html", "new page locally rendered");
ok (-e "$Bin/lib/rendered/site/new top page/index.html", "new page remotely rendered");

$agent->get('/publish/_add_page/new%20top%20page?below=1');

$agent->form_name('content');
$agent->field('title', "new lower pagepage");
$agent->field('copy', "some frobnicious content");
$agent->click('submit');


is ($agent->uri, "http://localhost//new%20top%20page/new%20lower%20pagepage", "redirected to lower page");
$agent->content_contains('frobnicious', 'expected content for new lowerpage');
ok (-e "$Bin/lib/storage/new top page/new lower pagepage/raw.html", "new lower raw html locally rendered");
ok (-e "$Bin/lib/storage/new top page/new lower pagepage/index.html", "new lower page locally rendered");
ok (-e "$Bin/lib/rendered/site/new top page/new lower pagepage/index.html", "newlower  page remotely rendered");

# Test editing page
$agent->form_name('content');
$agent->field('copy', "some new frobnicious content");
$agent->click('submit');
$agent->content_contains("some new frobnicious content", "edited page ok");

# atom feed test
$agent->get_ok('/xml', "got atom feed");
ok (-e "$Bin/lib/storage/atom.xml", "atom feed locally rendered");
ok (-e "$Bin/lib/rendered/site/atom.xml", "atom feed remotely rendered");

$agent->get_ok('/upload', "got uploads page");
$agent->form_number(1);
$agent->field('file', "$Bin/../root/static/images/feed.png");
$agent->submit;
ok (-e "$Bin/lib/rendered/site/uploads/feed.png", "upload transfered to ftp server");
$DB::single=1;
$agent->content_contains("feed.pn", "feed listed on uploads page");

# clean up
END {
    unlink("$Bin/lib/site.conf");
    rmtree("$Bin/lib/rendered");
    rmtree("$Bin/lib/storage");
}

