#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use My::Brassica;

=pod

Given a provided contrast, e.g. EF-LF, produces a table of EnsEMBL gene IDs of genes that
occur within the QTL regions identified in the analysis of this contrast. The table has
the following columns:

- chromosome number
- gene's start coordinate
- end coordinate
- gene ID
- provided contrast

=cut

# process command line arguments
my $db = '/home/ubuntu/data/reference/sqlite/snps.db';
my $contrast;
GetOptions(
	'db=s'       => \$db,
	'contrast=s' => \$contrast,
);
die "Usage: $0 -c <contrast> [-d <db>]" if not $contrast;

# connect to database
my $schema = My::Brassica->connect("dbi:SQLite:$db");

# query regions
my $regions = $schema->resultset("QtlRegion")->search({ bsa_contrast => $contrast });
while( my $r = $regions->next ) {

	# get coordinates
	my $chr   = $r->chromosome->id;
	my $start = $r->start;
	my $end   = $r->end;

	# QTL:     |--------| 
	# FEAT:   ***
	my $straddle_begin = $schema->resultset("Feature")->search({
		'chromosome_id' => $chr,
		'feat_start'    => { '<' => $start },
		'feat_end'      => { '>' => $start },
		'feature_type'  => "gene"
	});

	# QTL:     |--------| 
	# FEAT:       ***
	my $inside = $schema->resultset("Feature")->search({
		'chromosome_id' => $chr,
		'feat_start'    => { '>=' => $start },
		'feat_end'      => { '<=' => $end },
		'feature_type'  => "gene"
	});
		
	# QTL:     |--------| 
	# FEAT:            ***		
	my $straddle_end = $schema->resultset("Feature")->search({
		'chromosome_id' => $chr,
		'feat_start'    => { '<' => $end },
		'feat_end'      => { '>' => $end },
		'feature_type'  => "gene"
	});
	
	for my $rs ( $inside, $straddle_begin, $straddle_end ) {
		while( my $f = $rs->next ) {
			my $att = $f->attributes;
			if ( $att =~ m/ID=gene:([^;]+)/ ) {
				my $id = $1;
				print join("\t", $chr, $start, $end, $id, $f->feat_start, $f->feat_end, $contrast), "\n";
			}
		}
	}
}
