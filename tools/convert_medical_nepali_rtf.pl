#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

use Encode qw(decode);
use File::Path qw(make_path);
use File::Spec;
use Getopt::Long qw(GetOptions);
use HTML::TreeBuilder;

binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';

my $output_dir = '.';
GetOptions('output-dir=s' => \$output_dir) or die "Usage: $0 INPUT.rtf [--output-dir DIR]\n";

my $input_path = shift @ARGV or die "Usage: $0 INPUT.rtf [--output-dir DIR]\n";

my $html = run_textutil($input_path);
my $tree = HTML::TreeBuilder->new;
$tree->parse_content($html);
$tree->eof;

my @blocks = extract_blocks($tree);
die "No content was extracted from the RTF file.\n" unless @blocks;

my $title = strip_md($blocks[0]{text});
my @group_order = (
    'foundations',
    'body_systems',
    'special_populations',
    'diseases_and_conditions',
    'clinical_workflow_and_care',
    'context_lifestyle_and_end_of_life',
);
my %group_meta = (
    foundations => {
        label => '01 Foundations',
        dir => '01-foundations',
        blurb => 'These files introduce the communication strategy and shared clinical vocabulary that the rest of the guide builds on.',
        notes => [
            'Register and sensitive-language guidance comes first because it affects how the rest of the vocabulary should be used.',
            q{General illness, vitals, and symptom trajectories are shared clinical building blocks rather than organ-specific terms.},
            q{Life-stage vocabulary sits here because it supports later chapters on pediatrics, women's health, and end-of-life communication.},
        ],
    },
    body_systems => {
        label => '02 Body Systems',
        dir => '02-body-systems',
        blurb => 'These chapters group anatomy, symptoms, and exam-style vocabulary by body system so the guide can be read in a head-to-toe flow.',
        notes => [
            q{The body-system cluster keeps anatomy-centered chapters together so readers do not have to jump between organ systems and disease classes.},
            q{Neurology stays in this group because the section functions as a system-focused symptom vocabulary rather than a population or workflow chapter.},
        ],
    },
    special_populations => {
        label => '03 Special Populations',
        dir => '03-special-populations',
        blurb => 'These sections collect age-specific and sex-specific vocabulary that cuts across multiple body systems.',
        notes => [
            q{Women's health and pediatrics are grouped separately from organ systems because each chapter mixes anatomy, symptoms, life-stage language, and culture-specific phrasing.},
            q{The original content is preserved in place; this grouping simply keeps special-population terminology easier to locate.},
        ],
    },
    diseases_and_conditions => {
        label => '04 Diseases and Conditions',
        dir => '04-diseases-and-conditions',
        blurb => 'These sections group diagnosis-oriented vocabulary separately from anatomy-oriented chapters.',
        notes => [
            q{This group is meant for condition-based lookup after the reader already understands general vocabulary and body-system language.},
            q{Mental health stays here because it behaves more like a condition cluster than a purely anatomic chapter.},
        ],
    },
    clinical_workflow_and_care => {
        label => '05 Clinical Workflow and Care',
        dir => '05-clinical-workflow-and-care',
        blurb => 'These files cover urgent events, treatment language, procedures, rehabilitation, and the hospital system itself.',
        notes => [
            q{These chapters describe how care is delivered, documented, and navigated rather than how symptoms are localized in the body.},
            q{Keeping them together makes it easier to use the guide during treatment planning, referrals, admissions, and follow-up instructions.},
        ],
    },
    context_lifestyle_and_end_of_life => {
        label => '06 Context, Lifestyle, and End of Life',
        dir => '06-context-lifestyle-and-end-of-life',
        blurb => 'These sections gather longer-horizon counseling language, cultural context, and end-of-life communication.',
        notes => [
            q{Lifestyle counseling, cultural beliefs, and end-of-life language all depend heavily on context, tone, and longitudinal trust.},
            q{Traditional healing is placed here intentionally so it can frame interpretation and counseling rather than interrupt the core anatomy and disease sections.},
        ],
    },
);
my $part_one_title = '';
my @section_titles;
my %section_contents;
my @part_one_blocks;
my $current_section_key;

for my $block (@blocks[1 .. $#blocks]) {
    my $text = strip_md($block->{text});

    if (($block->{class_name} eq 'p2' || $block->{class_name} eq 'li2') && $text =~ /^Part 1:/) {
        $part_one_title = $text;
        next;
    }

    if (($block->{class_name} eq 'p2' || $block->{class_name} eq 'li2') && $text =~ /^Part 2:/) {
        $current_section_key = undef;
        next;
    }

    if ($block->{class_name} eq 'li4' && $text =~ /^Section (\d+):/) {
        my $number = $1;
        my $filename = sprintf('%02d-%s.md', $number, slugify($text));
        $current_section_key = $filename;
        push @section_titles, {
            number => $number,
            title => $text,
            filename => $filename,
        };
        $section_contents{$filename} = [];
        next;
    }

    if (defined $current_section_key) {
        push @{ $section_contents{$current_section_key} }, $block;
    } else {
        push @part_one_blocks, $block;
    }
}

my $docs_dir = File::Spec->catdir($output_dir, 'medical-nepali-guide');
my %sections_by_group;

write_file(
    File::Spec->catfile($docs_dir, $group_meta{foundations}{dir}, 'part-1-sensitive-language-and-registers.md'),
    build_markdown(\@part_one_blocks, $part_one_title || 'Part 1'),
);

for my $section (@section_titles) {
    my $group_key = section_group_key($section->{number});
    push @{ $sections_by_group{$group_key} }, $section;
    write_file(
        File::Spec->catfile($docs_dir, $group_meta{$group_key}{dir}, $section->{filename}),
        build_markdown($section_contents{$section->{filename}}, $section->{title}),
    );
}

write_file(
    File::Spec->catfile($docs_dir, 'README.md'),
    build_root_readme($title, $input_path, \@group_order, \%group_meta, \%sections_by_group),
);

for my $group_key (@group_order) {
    write_file(
        File::Spec->catfile($docs_dir, $group_meta{$group_key}{dir}, 'README.md'),
        build_group_readme($group_key, \%group_meta, \%sections_by_group),
    );
}

$tree->delete;

sub run_textutil {
    my ($path) = @_;
    open my $fh, '-|:raw', 'textutil', '-convert', 'html', '-stdout', $path
        or die "Failed to run textutil: $!\n";
    local $/;
    my $data = <$fh>;
    close $fh;
    return decode('UTF-8', $data);
}

sub extract_blocks {
    my ($root) = @_;
    my @blocks;
    for my $node ($root->look_down(sub {
        return 0 unless ref $_[0];
        return 0 unless $_[0]->tag =~ /^(p|li)$/;
        return 1;
    })) {
        my $text = clean_text(render_children($node));
        next unless length $text;
        push @blocks, {
            tag => $node->tag,
            class_name => ($node->attr('class') // ''),
            text => $text,
            list_depth => list_depth($node),
        };
    }
    return @blocks;
}

sub render_children {
    my ($node) = @_;
    my @parts;
    for my $child ($node->content_list) {
        push @parts, render_node($child);
    }
    return join('', @parts);
}

sub render_node {
    my ($node) = @_;

    if (!ref $node) {
        return $node;
    }

    my $tag = $node->tag;
    my $content = render_children($node);

    return "**$content**" if $tag eq 'b';
    return "*$content*" if $tag eq 'i';
    return "\n" if $tag eq 'br';
    return $content;
}

sub clean_text {
    my ($text) = @_;
    $text =~ s/\x{A0}/ /g;
    $text =~ s/[ \t]+/ /g;
    $text =~ s/ *\n */\n/g;
    $text =~ s/\* \*\*/**/g;
    $text =~ s/^\s+|\s+$//g;
    return $text;
}

sub list_depth {
    my ($node) = @_;
    my $depth = 0;
    my $parent = $node->parent;
    while ($parent) {
        $depth++ if $parent->tag =~ /^(ul|ol)$/;
        $parent = $parent->parent;
    }
    return $depth;
}

sub build_markdown {
    my ($blocks, $title) = @_;
    my @lines = ("# $title", "");

    for my $block (@$blocks) {
        my $text = $block->{text};

        if ($block->{class_name} eq 'li5') {
            push @lines, '## ' . strip_md($text), '';
            next;
        }

        if ($block->{class_name} eq 'p3') {
            push @lines, $text, '';
            next;
        }

        if ($block->{tag} eq 'li') {
            my @pieces = split_inline_bullets($text);
            for my $piece (@pieces) {
                if ($piece =~ /^\*\*.+\*\*$/ && $block->{list_depth} <= 1) {
                    push @lines, $piece, '';
                } else {
                    my $indent = '  ' x (($block->{list_depth} > 0 ? $block->{list_depth} : 1) - 1);
                    push @lines, $indent . '- ' . $piece;
                }
            }
            push @lines, '' unless $lines[-1] eq '';
            next;
        }

        push @lines, $text, '';
    }

    return join("\n", compact_blank_lines(@lines)) . "\n";
}

sub split_inline_bullets {
    my ($text) = @_;
    if ($text =~ /^\*\*(.+?):\*\*\s+\*\s+(.+)$/) {
        my ($head, $tail) = ($1, $2);
        my @items = ("**$head**");
        push @items, grep { length $_ } map { s/^\s+|\s+$//gr } split(/ \* /, $tail);
        return @items;
    }

    return ($text) unless $text =~ /: \* /;

    my ($head, $tail) = split(/: \* /, $text, 2);
    my @items = ("**" . $head . "**");
    push @items, grep { length $_ } map { s/^\s+|\s+$//gr } split(/ \* /, $tail);
    return @items;
}

sub section_group_key {
    my ($number) = @_;
    return 'foundations' if $number == 1 || $number == 2;
    return 'body_systems' if grep { $_ == $number } (3, 4, 5, 6, 7, 8, 11);
    return 'special_populations' if $number == 9 || $number == 10;
    return 'diseases_and_conditions' if $number == 12 || $number == 13 || $number == 14;
    return 'clinical_workflow_and_care' if grep { $_ == $number } (15, 16, 17, 18, 19);
    return 'context_lifestyle_and_end_of_life' if grep { $_ == $number } (20, 21, 22);
    die "No group mapping found for section $number\n";
}

sub build_root_readme {
    my ($title, $input_path, $group_order, $group_meta, $sections_by_group) = @_;
    my @lines = (
        "# $title",
        "",
        "Converted from `$input_path`.",
        "",
        "## Organization Principles",
        "",
        "- All original section content is preserved; this reorganization changes grouping and navigation, not substance.",
        "- Original section titles and numbering remain inside the files for traceability back to the source document.",
        "- The guide is now grouped by how a clinician is most likely to use it: foundations, body systems, special populations, diseases, workflow, and context.",
        "",
        "## Guide Map",
        "",
    );

    for my $group_key (@$group_order) {
        my $meta = $group_meta->{$group_key};
        push @lines, "### $meta->{label}", "";
        push @lines, "- [Overview](./$meta->{dir}/README.md)";
        if ($group_key eq 'foundations') {
            push @lines, "- [Part 1: Sensitive Language and Clinical Registers](./$meta->{dir}/part-1-sensitive-language-and-registers.md)";
        }
        for my $section (@{ $sections_by_group->{$group_key} // [] }) {
            push @lines, "- [$section->{title}](./$meta->{dir}/$section->{filename})";
        }
        push @lines, "";
    }

    push @lines,
        "## Notes",
        "",
        "- Source formatting was converted from RTF via `textutil` and normalized into Markdown.",
        "- The content is split into smaller files so we can revise terminology section by section without collapsing distinct topics into summaries.";

    return join("\n", @lines) . "\n";
}

sub build_group_readme {
    my ($group_key, $group_meta, $sections_by_group) = @_;
    my $meta = $group_meta->{$group_key};
    my @lines = (
        "# $meta->{label}",
        "",
        $meta->{blurb},
        "",
        "## Files",
        "",
    );

    if ($group_key eq 'foundations') {
        push @lines, "- [Part 1: Sensitive Language and Clinical Registers](./part-1-sensitive-language-and-registers.md)";
    }

    for my $section (@{ $sections_by_group->{$group_key} // [] }) {
        push @lines, "- [$section->{title}](./$section->{filename})";
    }

    push @lines, "", "## Organization Notes", "";
    for my $note (@{ $meta->{notes} }) {
        push @lines, "- $note";
    }

    return join("\n", @lines) . "\n";
}

sub compact_blank_lines {
    my @lines = @_;
    my @compacted;
    my $blank = 0;

    for my $line (@lines) {
        if ($line eq '') {
            next if $blank;
            push @compacted, $line;
            $blank = 1;
        } else {
            $line =~ s/\s+$//;
            push @compacted, $line;
            $blank = 0;
        }
    }

    return @compacted;
}

sub strip_md {
    my ($text) = @_;
    $text =~ s/\*\*//g;
    $text =~ s/\*//g;
    $text =~ s/^\s+|\s+$//g;
    return $text;
}

sub slugify {
    my ($text) = @_;
    $text = lc $text;
    $text =~ s/^\s*section\s+\d+:\s*//i;
    $text =~ s/[^\p{Word}\s-]//g;
    $text =~ s/\s+/-/g;
    $text =~ s/^-+|-+$//g;
    return $text;
}

sub write_file {
    my ($path, $content) = @_;
    my (undef, $dir) = File::Spec->splitpath($path);
    make_path($dir) if length $dir;
    open my $fh, '>:encoding(UTF-8)', $path or die "Failed to write $path: $!\n";
    print {$fh} $content;
    close $fh;
}
