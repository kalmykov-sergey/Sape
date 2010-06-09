package Sape::Template;
use strict;
use warnings;

#use HTML::Template;
use Template;

use Data::Dumper;

sub new {
  my $class = shift;

  my $tt = Template->new({
    INCLUDE_PATH => 'Sape/templates',
  });

  my $path = $0;
  $path =~ s{\/}{/}gs; # для windows
  $path =~ s{.*/cgi-bin}{/cgi-bin};

  my $self = {tt => $tt, path => $path};
  bless $self, $class;
} # конструктор

sub html { 
  my ($self, $auth, $query) = @_;
  
  $auth->{login} = $self->{user}{login};
  $auth->{password} = $self->{user}{password};

  my $stash = {
    projects => $self->{projects},
    auth => $auth,
    path => $path,
  };

  if($query eq 'noindex'){
    $stash->{projects} = $self->no_indexed_projects;
    $tt->process('noindex.html', $stash) or die $tt->error();
  } else {
    $tt->process('sape.html', $stash) or die $tt->error();
  }

}
=pod

  my $tt = HTML::Template->new(
    filename => 'dump.html',
    path => [ 'Sape/templates' ],
    die_on_bad_params => 0,
  );

  $tt->param(
    projects => $self->{projects},
  );

  return $tt->output;

=cut


sub auth_form {
  my $self = shift;

  my $stash = {
    login => $self->{user}{login},
    'defined_login' => defined $self->{user}{login},
    password => $self->{user}{password},
    'defined_password' => defined $self->{user}{password},
    connected => $self->{user}{id},
  };

  $tt->process('auth_form.html', $stash) or die $tt->error();
}

=pod

  my $tt = HTML::Template->new(
    filename => 'auth_form.html',
    path => [ 'Sape/templates' ],
    die_on_bad_params => 0,
  );

  $tt->param(
    login => $self->{user}{login},
    'defined_login' => defined $self->{user}{login},
    password => $self->{user}{password},
    'defined_password' => defined $self->{user}{password},
    connected => $self->{user}{id},
  );

  return $tt->output;

=cut

1;