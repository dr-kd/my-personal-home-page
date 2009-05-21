use strict;
use warnings;
use Test::More tests => 3;

BEGIN { use_ok 'Catalyst::Test', 'MyPHP' }
BEGIN { use_ok 'MyPHP::Controller::Setup' }

ok( request('/setup')->is_success, 'Request should succeed' );


