#!/usr/bin/env perl
use lib '/home/sergey/projects';

use CGI qw(:standard);
use CGI::Carp qw(fatalsToBrowser);

use Sape;
use Data::Dumper;

# authorization
my ($login, $password) = ('', '');
my ($cookie, $auth) = (undef, {});

my $path = '/cgi-bin/sape_dump.cgi';

my $sape = Sape->new;
$auth = {connected => undef, path => $path};

# если уже есть куки..
if(my %sape = cookie('sape')){
  $login = $sape{login};
  $password = $sape{password};
  $sape->load($login, $password);
} # все, если есть только куки

# ... но если есть еще и пост-запрос на вход в систему ...
if(param('login') and param('action') eq '«айти'){
  $login = param('login');
  $password = param('password');
  $sape->load($login, $password);
  $auth->{connected} = $sape->connected;
  if($auth->{connected}){    # установим куки
    my %hash = (login => $login, password => $password);
    $cookie = cookie(
      -name=>'sape',
      -value=> \%hash,
      -expires=>'+1y'
    );
  } else {
    $auth->{msg} = 'неверный логин или пароль';
  }
}
# ... или пост-запрос на выход ...
if(param('action') eq '¬ыйти'){
  $auth->{msg} = "ƒо свидани€, $login";
  ($login, $password) = (undef, undef);
  $sape->load(undef,undef);
  $cookie = cookie(
    -name=>'sape',
    -value=> '',
    -expires=>'+1d',
  );
}


print header( 
    -type => 'text/html', 
    -charset => 'windows-1251', 
    -cookie => $cookie,
);

$sape->auth($auth);