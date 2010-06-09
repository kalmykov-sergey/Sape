#!/usr/bin/env perl
use Sape;
use Sape::RPC;
use Data::Dumper;

#my $sape = Sape::RPC->login('kalmykov', 'kalmykov1A');
#print Dumper ($sape->get_project_links('top.masterstar.ru', 'OK'));

#my @ids = (1379993107);
#print Dumper($sape->get_placement_status($ids[0]));
#print Dumper($sape->delete_links(@ids));

my $sape = Sape->new('kalmykov', 'kalmykov1A');
my $links = $sape->links_list;
print Dumper ($links->[11]);

#print Dumper($sape->links), "\n";
#my $projects = $sape->get_projects;
#print Dumper ($projects), "\n";
#my $links = $sape->get_project_links('top.masterstar.ru');
#print Dumper ($links), "\n";
#my $all_links = $sape->get_all_links();
#print Dumper ($sape->links_list), "\n";
#$sape->save;

#my $sape = Sape->load;
#$sape->dump;