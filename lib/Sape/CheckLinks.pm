package Sape::CheckLinks;
use strict;
use warnings;

use URI;
use URI::Escape;
use HTML::Entities;
use LWP::UserAgent;

my $ua = LWP::UserAgent->new(
    agent => "Mozilla/5.0 (Windows; U; Windows NT 5.1; ru; rv:1.9.1.3) Gecko/20090624 Firefox/3.5 GTB5",
);

sub get {
  my $uri = shift;
  my $resp = $ua->get($uri);
  die $resp->status_line unless $resp->is_success;
  return $resp->content;
}

sub yandex_check_url {
  my $link = shift;
  $link =~ s{\s+$}{};
  $link =~ s{^https?://}{}i;
  $link =~ s{^www\.}{}i;
  $link =~ s{\/$}{}i;
  
  my $uri = URI->new("http://yandex.ru/yandsearch");
  $uri->query_form(
    text => "url:$link || url:www.$link",
    lr => 213,
  );
  return $uri->as_string;
}

sub check_qip {
    my $link = shift;

    # приводим ссылку к нужному формату: mysite.ru/index.php?text=hello
    $link =~ s{\s+$}{};
    $link =~ s{^https?://}{}i;
    $link =~ s{^www\.}{}i;
    $link =~ s{\/$}{}i;

    # в один запрос проверка не умещается, поэтому проверяем каждую ссылку 2 раза
    my $uri = URI->new("http://search.qip.ru/search");
    $uri->query_form(
        query => "url:$link",
    );
    my $uri1 = $uri->as_string; # 1-ый запрос
    $uri->query_form(
        query => "url:www.$link",
    );
    my $uri2 = $uri->as_string; # 2-ой запрос
    my $html1 = lc get($uri1);
    my $html2 = lc get($uri2);
    my $match = lc substr(uri_unescape(encode_entities($link)),0,50);
    $match =~ s{\s+$}{}g;
    return 1 if (
      (
        index($html1,'<ol class="searchresult"') > -1
        and
        (
        index($html1, '<p class="info">http://www.'.$match) > -1
        or index($html1, '<p class="info">http://'.$match) > -1
        )
      ) or
      (
        index($html2,'<ol class="searchresult"') > -1
        and
        (
        index($html2, '<p class="info">http://www.'.$match) > -1
        or index($html2, '<p class="info">http://'.$match) > -1
        )
      )
    );
    return 0;
}

sub check_yandex {
    my $link = shift;
    my $timeout = 600;

    my $uri = URI->new("http://yandex.ru/yandsearch");
    $uri->query_form(
        text => $link,
        lr => 1,
    );
    
    $link =~ s{^https?://}{}i;
    $link =~ s{^www\.}{}i;
    $link =~ s{\/$}{}i;

    my $html = get($uri->as_string, $timeout);
#    my $file_name = URI->new('http://'.$link)->host.'.html';
#    open my $w, ">$file_name";
#    print $w $html;
#    close $w;
    if ($html =~ m/captcha\.yandex\.net/i){
        return -1;
    }
    return 1 if (index($html,'div class="fe"') > -1 and index($html,'div class="hp"') == -1);
    return 0;
}

sub check_mail {
    my $link = shift;
    my $timeout = 1;

    $link =~ s{^https?://}{}i;
    $link =~ s{^www\.}{}i;
    $link =~ s{\/$}{}i;

    my $uri = URI->new("http://go.mail.ru/search");
    $uri->query_form(
        q => $link,
    );
    my $html = get($uri->as_string, $timeout);
    return 1 if index($html,'<div id="searchResultsWrap"') > -1;
    return 0;
}

sub check_livejournal {
# http://search.livejournal.ru/search?query=plarson.ru
}

1;