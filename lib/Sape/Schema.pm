package Sape::Schema;
use strict;
use warnings;

#use base 'DBIx::Class::Schema';

use DBI;
use Data::Dumper;

sub connect {
  my $self = shift;
  my $dbh = DBI->connect("dbi:mysql:sape", 'lavan', 'Gh2mooK6C');
  $self->{dbh} = $dbh;
}


sub disconnect {
  my $self = shift;
  $self->{dbh}->disconnect;
}


sub db_create_user {
  my $self = shift;
  my ($id, $login, $password) = 
    ($self->{user}{id}, $self->{user}{login}, $self->{user}{password});
  
  $self->connect;
  $self->{dbh}->do("
    INSERT INTO users (id, login, password) VALUES (?, ?, ?)
  ", {}, $id, $login, $password);
  my $user_id = $self->{dbh}->{mysql_insertid};
  $self->disconnect;  
  
  return $user_id;
}


sub clear { 
  my $self = shift;

  $self->connect;

  # записываем номера проектов пользователя, чтобы по ним удалить ссылки
  my $pr_ids = $self->{dbh}->selectcol_arrayref("
    SELECT id FROM projects WHERE user_id = ?
  ", {}, $self->{user}->{id});

  # удаляем проекты пользователя
  $self->{dbh}->do("
    DELETE FROM projects WHERE user_id = ?
  ", {}, $self->{user}->{id});

  # удаляем ссылки по номерам проектов
  foreach my $pr_id (@$pr_ids){
    $self->{dbh}->do("
      DELETE FROM links WHERE project_id = ?
    ", {}, $pr_id);
  }

  $self->disconnect;
} # удаление из базы всех записей по пользователю


sub save {
  my $self = shift;
  my $projects = $self->{projects};

  $self->connect;

  # записываем проекты из памяти
  my $sql_pr_insert = $self->{dbh}->prepare("
    INSERT INTO projects (id, user_id, name) VALUES (?, ?, ?)
  ");
  # ... и ссылки по проекту
  my $sql_link_insert = $self->{dbh}->prepare("
    INSERT INTO links (id, project_id, site_url, page_uri, is_indexed)
    VALUES (?, ?, ?, ?, ?)
  ");
  # цикл записи в БД
  foreach my $pr (@$projects){
    $sql_pr_insert->execute($pr->{id}, $self->{user}->{id}, $pr->{name});
    foreach my $link (@{$pr->{links}}){
      $sql_link_insert->execute(
        $link->{id}, 
        $pr->{id}, 
        $link->{'site_url'}, 
        $link->{'page_uri'}, 
        $link->{'is_indexed'},
      );
    }
  }

  $self->disconnect;
} # сохранение данных пользователя в БД


sub load {
  my $self_or_class = shift;
  my ($login, $password) = @_;
  my $self = {};

  if(ref $self_or_class){
    $self = $self_or_class;
    $self->{user} = {login => $login, password => $password} if defined $password;
  } else {
    die "enter login and password to create sape_user_object using 'load'" 
      unless defined $password;
    bless $self, $self_or_class;
    $self->{user} = {login => $login, password => $password};
  } 

  $self->connect;

  my $user = $self->{dbh}->selectrow_hashref("
    SELECT id FROM users WHERE login = ? AND password = ?
  ", {}, $self->{user}{login}, $self->{user}{password});

  unless($user){
    $self->disconnect;
#    $self = { user => {login => $login, password => $password}};
#    $self->{projects} = {};
    return $self;
  }

  $self->{user}{id} = $user->{id};

  # все проекты
  $self->{projects} = $self->{dbh}->selectall_arrayref("
    SELECT * FROM projects WHERE user_id = ?
  ", {Slice => {}}, $self->{user}{id});

  # выгружаем ссылки по каждому проекту
  my $sql_links_select = $self->{dbh}->prepare("
    SELECT * FROM links WHERE project_id = ?
  ");
  foreach my $pr (@{$self->{projects}}){
    $sql_links_select->execute($pr->{id});
    my $links = $sql_links_select->fetchall_arrayref({});
    $pr->{links} = $links;
  }

  $self->disconnect;
  return $self;
} # извлечение данных из базы в память


sub no_indexed_projects {
  my $self = shift;
  my $pr_arr = [];
  foreach my $pr (@{$self->{projects}}){
    my $pr_to_return = $pr;
    $pr_to_return->{links} = [];
    push @{$pr_to_return->{links}}, grep {$_->{is_indexed} != 1} @{$pr->{links}};
    push @$pr_arr, $pr_to_return;
  }
  return $pr_arr;
}

1;