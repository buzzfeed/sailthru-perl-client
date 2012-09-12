use strict;
use warnings;
use Test::More;
use lib 'lib';

use_ok('Sailthru::Client');


my ( $api_key, $secret ) = ( $ENV{SAILTHRU_KEY}, $ENV{SAILTHRU_SECRET} );

#resources to use for the test.  These will be automatically created/deleted on Sailthru
use constant LIST     => 'CPAN test list';
use constant EMAIL    => 'sc-cpan@example.com';
use constant TEMPLATE => 'CPAN Test';

SKIP: {
    skip 'Requires an API key and secret.', 1 if not defined $api_key and not defined $secret;
    my $sc = Sailthru::Client->new( $api_key, $secret );

	############################################################
	# Grab template source/preview
	############################################################

	#create template (or overwrite if already exists)
	my @lines = <DATA>; close DATA;
	my $create_template = $sc->call_api('POST', 'template', {template=>TEMPLATE, content_html=>"@lines"});
	is($create_template->{error}, undef, "no error creating template");

	#valid source
	my $source = $sc->call_api('POST', 'blast', {copy_template=>TEMPLATE});
	like($source->{content_html}, qr/Hey/, "got right result");
	like($source->{content_html}, qr/\Q{email}/, "has variable");
	unlike ($source->{content_html}, qr/\Q@{[EMAIL]}/, "didn't find email");

	#valid preview
	my $preview =  $sc->call_api('POST', 'preview', {
		template=>TEMPLATE,
		email=>EMAIL,
	});
	ok (not($preview->{error}), "No error in preview");
	like ($preview->{content_html}, qr/Hey/, "found text");
	unlike($preview->{content_html}, qr/\Q{email}/, "doesn't have variable");
	like ($preview->{content_html}, qr/\Q@{[EMAIL]}/, "found email");

	#delete template, rerun preview, look for error.
	$sc->call_api('DELETE', 'template', {template=>TEMPLATE});

	my $no_template = $sc->call_api('POST', 'preview', {
		template=>TEMPLATE(),
		email=>EMAIL(),
	});

	ok($no_template->{error}, "got error from deleted template");
	like($no_template->{errormsg}, qr/template/, "got expected error message from deleted template");

	############################################################
	#test email subscriptions
	############################################################
	my $email;
	
	#try to create list, in case it doesn't exist (will delete at end, anyway) and verify it's there
	$email = $sc->call_api('POST', 'list', {list=>LIST});
	is($email->{errormsg}, undef, "No error creating list");
	$email = $sc->call_api('GET', 'list', {list=>LIST});
	is($email->{list}, LIST, "email list exists");
	is($email->{errormsg}, undef, "No error getting list");

	# add via call_api
	$sc->call_api( 'POST', 'email', {email=>EMAIL(), lists=>{LIST()=>1}} );
	$email = $sc->call_api( 'GET', 'email', {email=>EMAIL()} );
	is ($email->{lists}{LIST()}, 1, 'is on list');

	#rm via call_api
	$sc->call_api('POST', 'email', {email=>EMAIL(), lists=>{LIST()=>0}});
	$email = $sc->call_api( 'GET', 'email', {email=>EMAIL()});
	is ($email->{lists}{LIST()}, undef, 'is not on list');

	#add via setEmail/getEmail
	$sc->setEmail(EMAIL(), {}, {LIST()=>1});
	$email = $sc->getEmail( EMAIL );
	is ($email->{lists}{LIST()}, 1, 'is on list');

	#rm via setEmail/getEmail
	$sc->setEmail(EMAIL(), {}, {LIST()=>0});
	$email = $sc->getEmail( EMAIL );
	is ($email->{lists}{LIST()}, undef, 'is not on list');

	$sc->call_api('DELETE', 'list', {list=>LIST});
	$email = $sc->call_api('GET', 'list', {list=>LIST});
	is($email->{name}, undef, "email list doesn't exist");
	
	############################################################
}

done_testing;

__DATA__
<html>
<body>
<h1>Hey!!!</h1>

This is a big important message

Not really, we just use this template to test the CPAN module.

bye, {email}

<p><small>If you believe this has been sent to you in error, please safely <a href="{optout_confirm_url}">unsubscribe</a>.</small></p>
</body>
</html>
