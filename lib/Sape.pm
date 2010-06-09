package Sape;
use warnings;
use strict;

use Sape::RPC;
use Sape::DB;
use Sape::CheckLinks;
use Sape::HTML;

#use DBI;
use Data::Dumper;

my $debug = 0;

=pod
  �������� ������� �������� ������ (���� �� �������������� ��)
=cut


# ������ ���� ������������������ �������
# TODO: ��������� � ���� � ��������� ��������� ����������
my %pwds = (
  kalmykov => 'kalmykov1A',
);


# ����� ������������ ������������� ���� � ����������, ������ ���:
my $new_base_file = __FILE__;
my $dir = $1 if ($new_base_file =~ /(.*)(\/|\\)(\w+)\.(\w+)$/);
if($dir){
  chdir $dir or die "Cannot initialize Sape.pm";
}



sub cron_check {
  foreach(keys %pwds){
    my $user = Sape->new($_, $pwds{$_});
    $user->check_links();
    $user->save_to_db();
  }
} # �������� ������, ����������� ������ n ����� 
  # (n ������� �� ����� ������ �� ���� �������)


sub cron_sync {
  foreach(keys %pwds){
    my $local_user = Sape->new($_, $pwds{$_});
    my $actions_todo = $local_user->actions;

    my $remote_user;
    eval{
      $remote_user = Sape::RPC->login($_, $pwds{$_});
      $remote_user->send_actions($actions_todo);
    };
    die $@ if $@;

    print "refreshing ...\n" if $debug;
    $remote_user->refresh();
    $local_user->update_with($remote_user);
    $local_user->save_to_db();
  }
} # ������������� � Sape.ru, ����������� ������ ���


sub register_new_user {
  my ($class, $login, $password) = @_;
  eval{
    my $user = Sape->new($login, $password);
  };
  unless($@){
    die "such user is already registered";
  }
  my $user = Sape->new('kalmykov', 'kalmykov1A');
  # TODO: ���� ����� ������� ������ ������������ ����� ������ (���������?)
  $user->{db}->create_user($login, $password);
}


sub new_html {
  my $class = shift;
  my $self = Sape::HTML->new();
  return $self;
}


=pod
    ������ Sape �������� � ���� ��������� {projects} � {db}
=cut


sub new {
  my $class = shift;
  my $self = {};
  my ($login, $password) = @_;
  bless $self, $class;
  $self->{user} = {login => $login, password => $password};
  eval{
    $self->{db} = Sape::DB->connect($login, $password);
  };
  die "�������� ����� ��� ������: $@" if $@;
  
  $self->load_from_db; 

  return $self;
} # ����������� 


sub delete {
  my $self = shift;
  eval{ 
    $self->{db}->disconnect(); 
  };
  die "DataBase error: $@" if $@;
} # ����������


sub load_from_db {
  my $self = shift;
  eval{
    $self->{projects} = $self->{db}->load;
  };

  die "DataBase error: $@" if $@;

  # ��������� � ��������� ����������� ������
  foreach my $pr (@{$self->{projects}}){
    foreach my $link (@{$pr->{links}}){
      $link->{'check_link'} = Sape::CheckLinks::yandex_check_url(
        $link->{'site_url'}.$link->{'page_uri'}
      );
    }
  }

} # �������� ������ �� ������ �� ��������� ����   


sub save_to_db {
  my $self = shift;
  eval{
    $self->{db}->clear;
    # TODO: ��� ������ �����, ���� ������ ����� UPDATE ������ ������
    $self->{db}->save( $self->{projects} );
  };
  die "DataBase error: $@" if $@;
} # ���������� ������ �� ������ � ��������� ����  
  # ��������� �������, ��������� ������� ��������� ��� ������
  # �� ������������, � ����� ������������ ����������� �� ������


sub set_actions {
  my $self = shift;
  my $opts = shift;
  my @to_delete = @{$opts->{'delete'}};

  foreach my $pr (@{$self->{projects}}){
    foreach my $link (@{$pr->{links}}){
      $link->{'action'} = undef;
      foreach(@to_delete){
        $link->{'action'} = 'delete' if $link->{id} eq $_;
      }
    }
  }
  $self->save_to_db;
}


sub actions {
  my $self = shift;
  my @to_delete = 
    map{$_->{id}} 
    grep{$_->{action} eq 'delete'} 
    grep{defined $_->{action}}
    @{$self->links_list};
  return { 
    'delete' => \@to_delete,
    'accept' => [],
  };
} # ������ �������� ��� ���������� ����� RPC ���������


sub update_with {
  my $self = shift;
  my $remote_user = shift;
  my $links_list = $self->links_list;
  foreach my $pr (@{$remote_user->{projects}}){
    foreach my $link (@{$pr->{links}}){
      my @old_links_with_same_id = 
          grep{$_->{id} == $link->{id}}
            @$links_list;

      # ������� �� ��� (������ �������� � ��������� ������ - ���������� ������ ����)
      if(scalar @old_links_with_same_id == 1){
        my $old_link = $old_links_with_same_id[0];
        $link->{'is_indexed'} = $old_link->{'is_indexed'} if defined $old_link->{'is_indexed'};
        $link->{'site_url'} = $old_link->{'site_url'} unless $link->{'site_url'};
        $link->{'page_uri'} = $old_link->{'page_uri'} unless $link->{'page_uri'};
      }

      
    }
  }
  $self->{projects} = $remote_user->{projects};
} # ���������� ��������� ���� ������ �� Sape.ru


sub check_links {
  my $self = shift;

  foreach my $pr (@{$self->{projects}}){
    foreach my $link (@{$pr->{links}}){
      my $uri = $link->{'site_url'} . $link->{'page_uri'};
      if(defined $link->{'is_indexed'}) {
        print "skipping $uri (", 
          ($link->{'is_indexed'})?'OK':'FAIL', ")\n" if $debug;
        next;
      }
      eval{
      $link->{'is_indexed'} = Sape::CheckLinks::check_qip($uri);
      };
      warn @$,"\n" if @$;
      print "$uri ... ", ($link->{'is_indexed'})?'OK':'FAIL', "\n" if $debug;
    }
  }
} # �������� ���� ������ ������

sub no_indexed_projects {
  my $self = shift;
  my $pr_arr = [];
  foreach my $pr (@{$self->{projects}}){
    my $pr_to_return = $pr;
    my @not_indexed_links = grep {not $_->{'is_indexed'}} @{$pr->{links}};
    $pr_to_return->{links} = \@not_indexed_links;
    push @$pr_arr, $pr_to_return;
  }
  return $pr_arr;
}



sub links_list {
  my $self = shift;
  my $links = [];

  foreach my $pr (@{$self->{projects}}){
    my @links_copy = @{$pr->{links}};
    push @$links, @links_copy;
  }
  return $links;
}


1;