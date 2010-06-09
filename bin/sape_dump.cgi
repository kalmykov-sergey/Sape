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

# ���� ��� ���� ����..
if(my %sape = cookie('sape')){
  $login = $sape{login};
  $password = $sape{password};
  $sape->load($login, $password);
} # ���, ���� ���� ������ ����

# ... �� ���� ���� ��� � ����-������ �� ���� � ������� ...
if(param('login') and param('action') eq '�����'){
  $login = param('login');
  $password = param('password');
  $sape->load($login, $password);
  $auth->{connected} = $sape->connected;
  if($auth->{connected}){    # ��������� ����
    my %hash = (login => $login, password => $password);
    $cookie = cookie(
      -name=>'sape',
      -value=> \%hash,
      -expires=>'+1y'
    );
  } else {
    $auth->{msg} = '�������� ����� ��� ������';
  }
}
# ... ��� ����-������ �� ����� ...
if(param('action') eq '�����'){
  $auth->{msg} = "�� ��������, $login";
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