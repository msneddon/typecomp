package Bio::KBase::KIDL::AnnotationParser;

=head1 NAME

JSONSchema

=head1 DESCRIPTION

Module that wraps methods which take a parsed set of KIDL types and processes the embedded
comments to extract annotations.  Annotations are then appended to the parsed type information so
that they can be accessed downstream by modules like JSONSchema that may use some
annotations to set constraints on fields.

Annotations are embedded in comments (so that raw annotations are always included in generated
documentation), and can therefore be parsed here independent of the lexer.

      
=head1 AUTHORS

Michael Sneddon (LBL, mwsneddon@lbl.gov)

=cut


use strict;
use warnings;
use Data::Dumper;
use File::Path 'make_path';
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(assemble_annotations);



# assemble_annotations($parsed_data, $available_type_table, $options)
#
#   $parsed_data is a ref to a hash containing the parsed data built from running compile_typespec; this structure
#     is used to parse annotations at the module and function level.  These annotations only need to be parsed
#     when 
#   $available_type is a ref to the full cached type table of all modules required to build the specified scripts,
#     e.g. when there are includes of other modules.
#   $options is a key/value hash of options.  supported options:
#        ignore_warnings => 1 (if defined, warning messages are not displayed)
#
#   Given the input parameters, this method assembles and saves annotations to every typed object definition in the
#   available_type_table, and every DefineModule and Funcdef object in the $parsed_data.  This method returns nothing
#   as it updates everything in-place.
#
#   You should call this function once you have parsed every module necessary and assembled the $parsed_data construct, but
#   before any methods for generating Json Schema if you need.  You should only
#   call this method once per compilation.
#
#
sub assemble_annotations
{
    my($parsed_data, $available_type_table, $options) = @_;
    
    my $n_total_warnings = 0;
    my $total_warning_mssg = '';
    
    # reassemble the data into custom lists that we can more easily work with
    my ($type_list,$func_list,$mod_list) = assemble_components($parsed_data, $available_type_table, $options);
    
    # process annotations of modules first
    foreach my $mod (@{$mod_list}) {
        # parse to retrieve the annotations, taking note of warnings that get passed back up
        my ($annotations, $n_warnings, $warning_mssg) = parse_comment_for_annotations($mod, $options);
        $n_total_warnings+=$n_warnings;
        $total_warning_mssg .= $warning_mssg;
        $mod->{annotations} = $annotations;
        #print "module: ".$mod->{module_name}.":\n";
        #print Dumper($annotations)."\n";
    }
    
    # then process annotations of type definitions
    foreach my $type (@{$type_list}) {
        # parse to retrieve the annotations, taking note of warnings that get passed back up
        my ($annotations, $n_warnings, $warning_mssg) = parse_comment_for_annotations($type, $options);
        $n_total_warnings+=$n_warnings;
        $total_warning_mssg .= $warning_mssg;
        $type->{annotations} = $annotations;
        #print "type: ".$type->{name}.":\n";
        #print Dumper($annotations)."\n";
    }
    
    # finally process annotations of function defs
    foreach my $func (@{$func_list}) {
        # parse to retrieve the annotations, taking note of warnings that get passed back up
        my ($annotations, $n_warnings, $warning_mssg) = parse_comment_for_annotations($func, $options);
        $n_total_warnings+=$n_warnings;
        $total_warning_mssg .= $warning_mssg;
        $func->{annotations} = $annotations;
        #print "funcdef: ".$func->{name}.":\n";
        #print Dumper($annotations)."\n";
    }
    
    # print warnings if some were found
    if($n_total_warnings > 0 && !$options->{ignore_warnings}) {
        print STDERR "total annotation warnings: ".$n_total_warnings."\n";
        print STDERR $total_warning_mssg."\n";
    }
    return;
}







# ($annotations,$n_total_warnings,$total_warning_mssg) = parse_comment_for_annotations($component, $options);
#
# internal method, accepts a KIDL component (either Bio::KBase::KIDL::KBT::Typedef,
# Bio::KBase::KIDL::KBT::Funcdef, Bio::KBase::KIDL::KBT::DefineModule) and an options
# hash, and returns the annotation object and warning information
#
sub parse_comment_for_annotations
{
    my($component, $options) = @_;
    
    # extract out the comment, and set it to an empty string if it is not defined
    my $raw_comment = $component->{"comment"};
    if(!defined($raw_comment)) { $raw_comment=""; }
    
    
    my $annotations = {}; #place to save annotations that we recognize
    $annotations->{"unknown_annotations"} = {}; #place to save declared annotations which we don't specifically parse
    my $n_total_warnings = 0;
    my $total_warning_mssg = '';
    
    # handle the comment just like we would if we were reading from file
    for (split /^/, $raw_comment) {
        my $line = $_;
        chomp($line);
        
        #trim whitespace
        $line =~ s/^\s+//;
        $line =~ s/\s+$//;
        #print "[1]'".$line."'\n";
                
        #detect if we think this is an annotation (if it start with '@')
        if($line=~/^@/) {
            $line =~ s/^@//; #drop the leading '@' symbol
            my @tokens = split(/\s+/,$line);
            my $n_tokens = scalar(@tokens);
            
            #make sure we've got some tokens parsed
            if($n_tokens>0) {
                # extract out the annotation name, and strip it from the line
                my $flag = shift(@tokens);
                $line =~ s/^\S+\s*//;
                
                # parse annotations differently based on whether it is a function/typedef/module
                my $n_warnings=0; my $warning_mssg="";
                if ($component->isa("Bio::KBase::KIDL::KBT::Typedef")) {
                    ($n_warnings, $warning_mssg) = process_typedef_annotation($annotations,$flag,\@tokens,$line,$component,$options);
                } elsif ($component->isa("Bio::KBase::KIDL::KBT::Funcdef")) {
                    ($n_warnings, $warning_mssg) = process_function_annotation($annotations,$flag,\@tokens,$component,$options);
                } elsif ($component->isa("Bio::KBase::KIDL::KBT::DefineModule")) {
                    
                }
                
                $n_total_warnings+=$n_warnings;
                $total_warning_mssg .= $warning_mssg;
            }
            #print Dumper(@tokens)."\n";
        }
    }
    #give back what we hath found
    return ($annotations,$n_total_warnings,$total_warning_mssg);
}


sub process_module_annotation {
    my($annotations, $flag, $values, $function, $options) = @_;
    
    my $n_warnings = 0;
    my $warning_mssg = '';
    
    return ($n_warnings, $warning_mssg);
}

sub process_function_annotation {
    my($annotations, $flag, $values, $function, $options) = @_;
    
    my $n_warnings = 0;
    my $warning_mssg = '';
    
    # deprecated [$replacement_type1] [$replacement_type2] ...
    #    this flag indicates that the tagged function is deprecated, and optionally allows a list of replacement functions
    #    which should be used instead
    if($flag eq 'deprecated') {
        if(!defined($annotations->{$flag})) { $annotations->{$flag} = []; }
        foreach my $replacement_func (@{$values}) {
            if(scalar(split(/\./,$replacement_func)) == 2) {
                push(@{$annotations->{$flag}},$replacement_func);
            } else {
                $warning_mssg .= "ANNOTATION WARNING: annotation '\@$flag' must have a fully qualified function name (ie ModuleName.function_name)\n";
                $warning_mssg .= "  in order to be later retrieved.  \@$flag annotation was defined for funcdef '".$function->{name}."'\n";
                $warning_mssg .= "  The invalid replacement function name given was '$replacement_func'.\n";
                $n_warnings++;
            }
        }
    }
    
    # catch all other annotations and place them on the heap
    else {
        # make sure we have a list defined, then push the annotation to the list and let someone else deal with it downstream
        if(!defined($annotations->{unknown_annotations}->{$flag})) {
            $annotations->{unknown_annotations}->{$flag} = [];
        }
        push(@{$annotations->{unknown_annotations}->{$flag}},join(' ',@{$values}));
    }
    
    return ($n_warnings, $warning_mssg);
}


#
# 
#
#  returns ($n_warnings, $warning_mssg)
sub process_typedef_annotation {
    my($annotations, $flag, $parameters, $raw_line, $type, $options) = @_;
    
    my $n_warnings = 0;
    my $warning_mssg = '';
    
    # @optional [field_name] [field_name] ...
    #    this flag indicates that the specified field name or names are optional, used primarily to allow
    #    optional fields during json schema based validation
    if($flag eq 'optional') {
        my ($n,$mssg) = process_typedef_annotation_optional($annotations, $parameters, $raw_line, $type, $options);
        $n_warnings += $n;
        $warning_mssg .= $mssg;
    }
    
    # @deprecated [$replacement_type1] [$replacement_type2] ...
    #    this flag indicates that the tagged type is deprecated, and optionally allows a list of typed objects
    #    which should be used instead.  only used currently by the KIDL LINT
    elsif($flag eq 'deprecated') {
        my ($n,$mssg) = process_typedef_annotation_deprecated($annotations, $parameters, $raw_line, $type, $options);
        $n_warnings += $n;
        $warning_mssg .= $mssg;
    }
    
    
    # @id [ID_TYPE] [INFO] ....
    #    this annotation, if set, indicates that a typedef which resolves to a string is not just any string, but
    #    an ID that references another typed object or entity.  Valid [ID_TYPES] are ws, kb, shock, external
    #    see the annotation documentation for more details.
    elsif($flag eq 'id') {
        #we generate a warning if the id has been used before
        if(exists($annotations->{$flag})) {
            $warning_mssg .= "ANNOTATION WARNING: annotation '\@$flag' can only be declared once per typedef, only the first declaration is processed.\n";
            $warning_mssg .= "  typedef '".$type->{module}.".".$type->{name}."' had multiple declarations of \@$flag\n";
            $n_warnings++;
        } else {
            my ($n,$mssg) = process_typedef_annotation_id($annotations, $parameters, $raw_line, $type, $options);
            $n_warnings += $n;
            $warning_mssg .= $mssg;
        }
    }
    
    # @searchable [SEARCH_CONTEXT] [INFO]
    #    this annotation, if set, indicates that part of this object is searchable within some context.  The only supported context
    #    is withing the workspace service, indicated as 'ws_subset'
    #    see the annotation documentation for more details.
    elsif($flag eq 'searchable') {
        my ($n,$mssg) = process_typedef_annotation_searchable($annotations, $parameters, $raw_line, $type, $options);
        $n_warnings += $n;
        $warning_mssg .= $mssg;
    }
    
    # @metadata [CONTEXT] [EXPRESSION] as [METADATA_NAME]
    #    this annotation, if set, indicates that part of this object should be extracted under some context.  The only
    #    supported context is the workspace service, indicated as 'ws'
    elsif($flag eq 'metadata') {
        my ($n,$mssg) = process_typedef_annotation_metadata($annotations, $parameters, $raw_line, $type, $options);
        $n_warnings += $n;
        $warning_mssg .= $mssg;
    }
    
    elsif($flag eq 'range') {
        my ($n,$mssg) = process_typedef_annotation_range($annotations, $parameters, $raw_line, $type, $options);
        $n_warnings += $n;
        $warning_mssg .= $mssg;
    }
    
    # catch all other annotations and place them on the heap
    else {
        # make sure we have a list defined, then push the annotation to the list and let someone else deal with it downstream
        if(!defined($annotations->{unknown_annotations}->{$flag})) {
            $annotations->{unknown_annotations}->{$flag} = [];
        }
        push(@{$annotations->{unknown_annotations}->{$flag}},$raw_line);
        $warning_mssg .= "ANNOTATION WARNING: annotation '\@$flag' was not recognized, so it likely has no effect.\n";
        $warning_mssg .= "  \@$flag annotation was defined for type '".$type->{module}.".".$type->{name}."'.\n";
        $n_warnings++;
    }
    
    return ($n_warnings, $warning_mssg);
}



# Handler for  "@optional" annotation of structures
#
sub process_typedef_annotation_optional {
    my($annotations, $parameters, $raw_line, $type, $options) = @_;
    my $n_warnings = 0; my $warning_mssg = '';
    
    # make sure we are a typedef that points to a structure
    my ($base_type,$depth) = resolve_typedef($type);
    if(!$base_type->isa('Bio::KBase::KIDL::KBT::Struct')) {
        $warning_mssg .= "ANNOTATION WARNING: annotation '\@optional' does nothing for non-structure types.\n";
        $warning_mssg .= "  annotation was defined for type '".$type->{module}.".".$type->{name}."', which is not a structure.\n";
        $n_warnings++;
    } else {
        
        # for now, we allow each typedef to add additional optional fields...
        # If we do not want to allow the addition of more optional fields in subsequent typedefs, then do the check on $depth
        if ($depth > 1) {
            $warning_mssg .= "ANNOTATION WARNING: annotation '\@optional' can only be declared where a structure is originally defined, not in a subsequent typedef.\n";
            $warning_mssg .= "  \@optional annotation defined for type '".$type->{module}.".".$type->{name}."' does nothing.\n";
            $n_warnings++;
        } else {
            # we are sure that we have a structure, so get a list of field names
           my @items = @{$base_type->items};
           my @subtypes = map { $_->item_type } @items;
           my @field_names = map { $_->name } @items;
           my %field_lookup_table = map { $_ => 1 } @field_names;
           
           # create the annotation object   
           if(!defined($annotations->{optional})) { $annotations->{optional} = []; }
           foreach my $field (@{$parameters}) {
               # do simple checking to see if the field exists
               if(!exists($field_lookup_table{$field})) {
                   $warning_mssg .= "ANNOTATION WARNING: annotation '\@optional' for structure '".$type->{module}.".".$type->{name}."' indicated\n";
                   $warning_mssg .= "  a field named '$field', but no such field exists in the structure, so this constraint was ignored.\n";
                   $n_warnings++;
                   next;
               }
               # don't add it twice, and report that we found it already
               foreach my $marked_optional_field (@{$annotations->{optional}}) {
                   if($marked_optional_field eq $field) {
                       $warning_mssg .= "ANNOTATION WARNING: annotation '\@optional' for structure '".$type->{module}.".".$type->{name}."' has\n";
                       $warning_mssg .= "  marked a field named '$field' multiple times.\n";
                       $n_warnings++;
                       next;
                   }
               }
               # if we got here, we are good. push it to the list
               push(@{$annotations->{optional}},$field);
           }
        }
    }
    
    return ($n_warnings, $warning_mssg);
}


# Handler for  "@id" annotation of structures
#
sub process_typedef_annotation_id {
    my($annotations, $parameters, $raw_line, $type, $options) = @_;
    my $n_warnings = 0; my $warning_mssg = '';
   
    # first, we make sure that the type maps to a typedef which maps to a string, else generate a warning and return
    my ($base_type,$depth) = resolve_typedef($type);
    my $mapsToString;
    if($base_type->isa('Bio::KBase::KIDL::KBT::Scalar')) {
        if($base_type->{'scalar_type'} eq 'string') {
            $mapsToString = 1;
        }
    }
    if (!$mapsToString) {
        $warning_mssg .= "ANNOTATION WARNING: annotation '\@id' can only be applied to typedefs that resolve to a string.\n";
        $warning_mssg .= "  \@id annotation was defined for type '".$type->{module}.".".$type->{name}."', which is not a typedef\n";
        $warning_mssg .= "  that resolves to a 'string' base type.  This annotation therefore has no effect.\n";
        $n_warnings++;
        return ($n_warnings, $warning_mssg);
    }
        
    # second, we extract out the type of id; if no type is given, we abort with a warning
    my $id_type = shift(@$parameters);
    if (!defined $id_type) {
        $warning_mssg .= "ANNOTATION WARNING: annotation '\@id' must delcare a type of ID.  Valid ID types are 'ws', 'kb',\n";
        $warning_mssg .= "  'handle', 'external'.  Annotation was defined for type '".$type->{module}.".".$type->{name}."'.\n";
        $n_warnings++;
        return ($n_warnings, $warning_mssg);
    }
    
    # third, save this ID annotation
    $annotations->{id} = {type=>$id_type, attributes=>$parameters};
    
    # fourth, based on the type of id we may perform some additional checks
    if ($id_type eq 'kb') {
        #kbase id - for now we do nothing else; if additional parameters are given, we generate a warning
        if (scalar(@$parameters)>0) {
            $warning_mssg .= "ANNOTATION WARNING: annotation '\@id kb' does not accept additional parameters.\n";
            $warning_mssg .= "  annotation was defined for type '".$type->{module}.".".$type->{name}."', and parameters\n";
            $warning_mssg .= "  given (".join(' ',@$parameters).") likely do nothing.\n";
            $n_warnings++;
        }
    } elsif ($id_type eq 'handle') {
        #shock node handle id - for now we mark it and do nothing else; if additional parameters are given, we generate a warning
        if (scalar(@$parameters)>0) {
            $warning_mssg .= "ANNOTATION WARNING: annotation '\@id handle' does not accept additional parameters.\n";
            $warning_mssg .= "  annotation was defined for type '".$type->{module}.".".$type->{name}."', and parameters\n";
            $warning_mssg .= "  given (".join(' ',@$parameters).") likely do nothing.\n";
            $n_warnings++;
        }
    } elsif ($id_type eq 'external') {
        #external id - for now we don't yet validate source names
    } elsif ($id_type eq 'ws') {
        my $valid_typedef_names = {};
        foreach my $typename (@{$parameters}) {
            # generate warnings if there are duplicates or it doesn't look like the type name is well formed
            if(scalar(split(/\./,$typename)) == 2) {
                # don't add duplicates
                 if(!exists($valid_typedef_names->{$typename})) {
                    $valid_typedef_names->{$typename}=1;
                } else {
                    $warning_mssg .= "ANNOTATION WARNING: annotation '\@id ws' indicated valid type '$typename' multiple times.\n";
                $warning_mssg .= "  annotation was defined for typedef '".$type->{module}.".".$type->{name}."'\n";
                $n_warnings++;
                }
            } else {
                $warning_mssg .= "ANNOTATION WARNING: annotation '\@id ws' must have a fully qualified type name (ie ModuleName.TypeName).\n";
                $warning_mssg .= "  annotation was defined for typedef '".$type->{module}.".".$type->{name}."' and indicated a valid type\n";
                $warning_mssg .= "  for this ID is '$typename'.  This annotation therefore has no effect.\n";
                $n_warnings++;
            }
        }
        #my $valid_typedef_names_list = [];
        #push(@$valid_typedef_names_list, keys(%$valid_typedef_names));

    } else {
        $annotations->{id} = {type=>$id_type, attributes=>$parameters};
        $warning_mssg .= "ANNOTATION WARNING: annotation '\@id' indicated that id type is '$id_type', but that id type is\n";
        $warning_mssg .= "  not recognized.  Annotation was declared for type '".$type->{module}.".".$type->{name}."'\n";
        $n_warnings++;
    }
    
    return ($n_warnings, $warning_mssg);
}



sub process_typedef_annotation_range {
    my($annotations, $parameters, $raw_line, $type, $options) = @_;
    my $n_warnings = 0; my $warning_mssg = '';
   
    # first, we make sure that the type maps to a typedef which maps to a number, else generate a warning and return
    my ($base_type,$depth) = resolve_typedef($type);
    my $mapsToNumber;
    if($base_type->isa('Bio::KBase::KIDL::KBT::Scalar')) {
        if($base_type->{'scalar_type'} eq 'int' || $base_type->{'scalar_type'} eq 'float') {
            $mapsToNumber = 1;
        }
    }
    if (!$mapsToNumber) {
        $warning_mssg .= "ANNOTATION WARNING: annotation '\@range' can only be applied to typedefs that resolve to an int or float.\n";
        $warning_mssg .= "  \@range annotation was defined for type '".$type->{module}.".".$type->{name}."', which is not a typedef\n";
        $warning_mssg .= "  that resolves to an 'int' or 'float' base type.  This annotation therefore has no effect.\n";
        $n_warnings++;
        return ($n_warnings, $warning_mssg);
    }
    
    $annotations->{range}={};
    
    # second, we extract out and parse the range string
    my $rangeStr = join('',@$parameters);
    $rangeStr =~ s/^\s+|\s+$//g;
    
    my $isExclusiveMin = 0;
    my $isExclusiveMax = 0;
    
    my $minValue;
    my $maxValue;
    
    if ($rangeStr =~ m/^\[/) { #starts with [
        $rangeStr = substr($rangeStr,1);
    } elsif ($rangeStr =~ m/^[(\]]/) { #starts with ( or ]
        $rangeStr = substr($rangeStr,1);
        $isExclusiveMin = 1;
    }
    
    if ($rangeStr =~ m/\]$/) { #ends with ]
        chop($rangeStr);
    } elsif ($rangeStr =~ m/[)\[]$/) { #ends with ) or []
        chop($rangeStr);
        $isExclusiveMax = 1;
    }
    
    my @values = split(/,/,$rangeStr);
    if (scalar(@values)>=1) {
        $minValue = $values[0];        
    }
    if (scalar(@values)==2) {
        $maxValue = $values[1];     
    }
    if (scalar(@values)>2) {
        $warning_mssg .= "ANNOTATION WARNING: annotation '\@range' could not be parsed because there are too many commas.\n";
        $warning_mssg .= "  \@range annotation was defined for '".$type->{module}.".".$type->{name}."' and has no effect.\n";
        $n_warnings++;
        return ($n_warnings, $warning_mssg);
    }
    if (defined $minValue) {
        if ($minValue ne '') {
            $annotations->{range}->{minimum} = $minValue;
            $annotations->{range}->{exclusiveMinimum} = $isExclusiveMin;
        }
    }
    if (defined $maxValue) {
        if ($maxValue ne '') {
            $annotations->{range}->{maximum} = $maxValue;
            $annotations->{range}->{exclusiveMaximum} = $isExclusiveMax;
        }
    }
    return ($n_warnings, $warning_mssg);
}


# Handler for  "@deprecated" annotation of typedefs
#
sub process_typedef_annotation_deprecated {
    my($annotations, $parameters, $raw_line, $type, $options) = @_;
    my $n_warnings = 0; my $warning_mssg = '';
    
    my $replacement_types = {};
    if(!defined($annotations->{deprecated})) {
        $annotations->{deprecated} = [];
    } else {
        foreach my $t (@$annotations->{deprecated}) {
            $replacement_types->{$t} = 1;
        }
    }
    foreach my $replacement_type (@{$parameters}) {
        if(scalar(split(/\./,$replacement_type)) == 2) {
            # don't add duplicates
            if(!exists($replacement_types->{$replacement_type})) {
                $replacement_types->{$replacement_type}=1;
                push(@{$annotations->{deprecated}},$replacement_type);
            } else {
                $warning_mssg .= "ANNOTATION WARNING: annotation '\@deprecated' indicated replacement type '$replacement_type' multiple times.\n";
                $warning_mssg .= "  annotation was defined for typedef '".$type->{module}.".".$type->{name}."'\n";
                $n_warnings++;
            }
        } else {
            $warning_mssg .= "ANNOTATION WARNING: annotation '\@deprecated' must have a fully qualified type name (ie ModuleName.TypeName) to\n";
            $warning_mssg .= "  indicate replacement type. Annotation was defined for typedef '".$type->{module}.".".$type->{name}."' and\n";
            $warning_mssg .= "  and indicated replacement type '$replacement_type'.  This annotation therefore has no effect.\n";
            $n_warnings++;
        }
    }
    return ($n_warnings, $warning_mssg);
}


# Handler for  "@searchable" annotation of structures
#
sub process_typedef_annotation_searchable {
    my($annotations, $parameters, $raw_line, $type, $options) = @_;
    my $n_warnings = 0; my $warning_mssg = '';
    
    # make sure we are a typedef that points to a structure
    my ($base_type,$depth) = resolve_typedef($type);
    if(!$base_type->isa('Bio::KBase::KIDL::KBT::Struct')) {
        $warning_mssg .= "ANNOTATION WARNING: annotation '\@searchable' does nothing for non-structure types.\n";
        $warning_mssg .= "  annotation was defined for type '".$type->{module}.".".$type->{name}."', which does not resolve to a structure.\n";
        $n_warnings++;
    } else {
        
        # ensure that we have declared the context for being searchable
        my $search_context = shift(@$parameters);
        if (!defined $search_context) {
             $warning_mssg .= "ANNOTATION WARNING: annotation '\@searchable' must delcare the context for being searchable.\n";
            $warning_mssg .= "  The only current valid context is 'ws_subset'.\n";
            $warning_mssg .= "  Annotation was defined for type '".$type->{module}.".".$type->{name}."'.\n";
            $n_warnings++;
            return ($n_warnings, $warning_mssg);
        }
        
        # the context is to define the searchable subset of the typed object when stored in the Workspace
        if ($search_context eq 'ws_subset') {
            
            # create the annotation if it does not exist
            if(!defined($annotations->{searchable_ws_subset})) { $annotations->{searchable_ws_subset} = {fields=>{},keys=>{}}; }
            
            # grab handles into the annotation object
            my $parsed_field_tree = $annotations->{searchable_ws_subset}->{fields};
            my $parsed_keys_of_tree = $annotations->{searchable_ws_subset}->{keys};
            
            # go through each path given and parse it
            foreach my $path (@$parameters) {
                
                # check if we want keys or fields
                my ($isKeysOf, $raw_path) = strip_keys_of_flag($path);
                
                # resolve the string into a path tree
                my $parse_error='';
                if ($isKeysOf) {
                    $parse_error = resolve_path($raw_path,$parsed_keys_of_tree);
                } else {
                    $parse_error = resolve_path($raw_path,$parsed_field_tree);
                }
                if ($parse_error ne '') {
                    $warning_mssg .= "ANNOTATION WARNING: annotation '\@searchable ws_subset' has indicated a set of fields that could not be parsed.\n";
                    $warning_mssg .= "  field specification was: '$path'\n";
                    $warning_mssg .= "  $parse_error\n";
                    $warning_mssg .= "  Annotation was defined for type '".$type->{module}.".".$type->{name}."'\n";
                    $n_warnings++;
                }
                
                # validation error occurs if searchable subset specified does not match typedef structure
                my $validation_error='';
                if ($isKeysOf) {
                    $validation_error = validate_path($parsed_keys_of_tree, $base_type, $isKeysOf);
                } else {
                    $validation_error = validate_path($parsed_field_tree, $base_type, $isKeysOf);
                }
                if ($validation_error ne '') {
                    $warning_mssg .= "ANNOTATION WARNING: annotation '\@searchable ws_subset' had an error in specifying fields.\n";
                    $warning_mssg .= "  field specification was: '$path'\n";
                    $warning_mssg .= "  $validation_error\n";
                    $warning_mssg .= "  Annotation was defined for type '".$type->{module}.".".$type->{name}."'\n";
                    $n_warnings++;
                }
            }
            
        } else {
            $warning_mssg .= "ANNOTATION WARNING: annotation '\@searchable' indicated that the search context is '$search_context', but that is\n";
            $warning_mssg .= "  not recognized as a valid search context.  This type has been marked as searchable, but this likely does nothing.\n";
            $warning_mssg .= "  Annotation was defined for type '".$type->{module}.".".$type->{name}."'\n";
            $n_warnings++;
        }
    }
    return ($n_warnings, $warning_mssg);
}


#
#  metadata annotations defined as:
#
#    @metadata [DATASTORE] [EXPRESSION] as [METADATA NAME]
#
#      where the only supported data store is ws
#
#    the selector is used to select the fields and compute the value stored as the metadata in the WS
#    eventually this may support more complex expressions, but for now can only select top level fields by
#    name.  The fields must resolve to a string, float, int. Additionally, the "length()" operator is supported
#    by the WS which will compute the length of a list or mapping, as in length(my_list_field_name).
#
#
sub process_typedef_annotation_metadata {
    my($annotations, $parameters, $raw_line, $type, $options) = @_;
    my $n_warnings = 0; my $warning_mssg = '';
    
    # make sure we are a typedef that points to a structure
    my ($base_type,$depth) = resolve_typedef($type);
    if(!$base_type->isa('Bio::KBase::KIDL::KBT::Struct')) {
        $warning_mssg .= "ANNOTATION WARNING: annotation '\@metadata' does nothing for non-structure types.\n";
        $warning_mssg .= "  annotation was defined for type '".$type->{module}.".".$type->{name}."', which is not a structure.\n";
        $n_warnings++;
    } else {
        
        # ensure that we have declared the context for being searchable
        my $metadata_context = shift(@$parameters);
        if (!defined $metadata_context) {
            $warning_mssg .= "ANNOTATION WARNING: annotation '\@metadata' must delcare the the data store that should extract the data.\n";
            $warning_mssg .= "  The only current valid context is 'ws'.\n";
            $warning_mssg .= "  Annotation was defined for type '".$type->{module}.".".$type->{name}."'.\n";
            $n_warnings++;
            return ($n_warnings, $warning_mssg);
        }
        
        if ($metadata_context eq 'ws') {
            # we are sure that we have a structure, so get a list of field names
            my @items = @{$base_type->items};
            my @subtypes = map { $_->item_type } @items;
            my @field_names = map { $_->name } @items;
            my %field_lookup_table = map { $_ => 1 } @field_names;
               
            if (scalar(@$parameters) < 1) {
                $warning_mssg .= "ANNOTATION WARNING: annotation '\@metadata' is invalid, must define at least 2 tokens: \@metadata ws [expression]\n";
                $warning_mssg .= "  Annotation was defined for type '".$type->{module}.".".$type->{name}."'.\n";
                $n_warnings++;
                return ($n_warnings, $warning_mssg);
            }
            
            # parse out the expression and metadata name
            my $expression = ''; my $metadataName = '';
            my $seenAsKeyword = 0; my $isFirstWord = 1;
            foreach my $word (@{$parameters}) {
                if (!$isFirstWord && (lc($word) eq 'as')) {
                    $seenAsKeyword = 1; next;
                }
                if ($isFirstWord) { $isFirstWord = 0; }
                if ($seenAsKeyword) { $metadataName .= $word." " }
                else { $expression .= $word; }
            }
            if (!$seenAsKeyword) { $metadataName = $expression; }
            $metadataName =~ s/^\s+|\s+$//g;
            
            # validate that the expression is valid
            
            
            # add it as an annotation
            if(!defined($annotations->{metadata}->{ws})) { $annotations->{metadata}->{ws} = {}; }
            if (defined($annotations->{metadata}->{ws}->{$metadataName}) ) {
                $warning_mssg .= "ANNOTATION WARNING: annotation '\@metadata' is invalid, you cannot redefine a metadata name; attempted to redefine '$metadataName'\n";
                $warning_mssg .= "  Annotation was defined for type '".$type->{module}.".".$type->{name}."'.\n";
                $n_warnings++;
                return ($n_warnings, $warning_mssg);
            }
            $annotations->{metadata}->{ws}->{$metadataName} = $expression;

        } else {
            $warning_mssg .= "ANNOTATION WARNING: annotation '\@metadata' indicated that the data store to use is '$metadata_context', but that is\n";
            $warning_mssg .= "  not recognized as a valid data store.  Only the Workspace (specified as 'ws') is accepted.\n";
            $warning_mssg .= "  Annotation was defined for type '".$type->{module}.".".$type->{name}."'\n";
            $n_warnings++;
        }
        
      
        
        #foreach my $field (@{$parameters}) {
        #    # do simple checking to see if the field exists
        #    if(!exists($field_lookup_table{$field})) {
        #        $warning_mssg .= "ANNOTATION WARNING: annotation '\@optional' for structure '".$type->{module}.".".$type->{name}."' indicated\n";
        #           $warning_mssg .= "  a field named '$field', but no such field exists in the structure, so this constraint was ignored.\n";
        #           $n_warnings++;
        #           next;
        #       }
        #       # don't add it twice, and report that we found it already
        #       foreach my $marked_optional_field (@{$annotations->{optional}}) {
        #           if($marked_optional_field eq $field) {
        #               $warning_mssg .= "ANNOTATION WARNING: annotation '\@optional' for structure '".$type->{module}.".".$type->{name}."' has\n";
        #               $warning_mssg .= "  marked a field named '$field' multiple times.\n";
        #               $n_warnings++;
        #               next;
        #           }
        #       }
        #       # if we got here, we are good. push it to the list
        #       push(@{$annotations->{optional}},$field);
        #   }
    }
    
    return ($n_warnings, $warning_mssg);
}




#  recursive loop to get the base type of a typedef
sub resolve_typedef {
    my($type) = @_;
    my $depth = 0;
    my $base_type = $type;
    while($base_type->isa('Bio::KBase::KIDL::KBT::Typedef')) {
        $base_type = $base_type->{alias_type};
        $depth++;
    }
    return ($base_type, $depth);
}


sub initAnnotationStructure {
    my($type) = @_;
    $type->{annotations}={};
    if($type->isa('Bio::KBase::KIDL::KBT::Typedef')) {
        initAnnotationStructure($type->{alias_type});
    } elsif ($type->isa('Bio::KBase::KIDL::KBT::Mapping')) {
        initAnnotationStructure($type->{key_type});
        initAnnotationStructure($type->{value_type});
    } elsif ($type->isa('Bio::KBase::KIDL::KBT::List')) {
        initAnnotationStructure($type->{element_type});
    } elsif ($type->isa('Bio::KBase::KIDL::KBT::Tuple')) {
        foreach my $element (@{$type->{element_types}}) {
            initAnnotationStructure($element);
        }
    }
    return;
}


# This method packages up a list of types, functions, and modules so that annotation parsing is simplified
# 
#
sub assemble_components
{
    my($parsed_data, $available_type_table, $options) = @_;

    my $type_list = [];
    my $func_list = [];
    my $mod_list  = [];
    
    # assemble the list of types (NOTE: we CANNOT do this from the parsed_data hash because the parsed_data
    # hash will only have the relevant info for the modules that we are compiling, not included specs; but
    # we need to process included specs otherwise annotations will not be complete if they are inherited )
    while (my($module_name, $types) = each %{$available_type_table}) {
        foreach my $type (values(%{$types})) {
            # we do not parse annotations for built-in scalars or UnspecifiedObjects, so we skip
            #$type->{annotations}={}; # for consistency in parsed structure, we always add annotations
            initAnnotationStructure($type);
            
            next if ($type->isa("Bio::KBase::KIDL::KBT::Scalar"));
            next if ($type->isa("Bio::KBase::KIDL::KBT::UnspecifiedObject"));
            push(@$type_list, $type);
        }
    }
    
    # top level is a hash of service_name -> list of modules in the service
    while (my($service_name, $service_module_info_list) = each %{$parsed_data}) {
        # the list of modules is itself a list of items that provide information on the module
        # (ok, this is getting crazy!)
        foreach my $module_data_list (@$service_module_info_list) {
            # of which only the first element in that list is the proper Bio::KBase::KIDL::KBT::DefineModule
            my $module_def = $module_data_list->[0];
            my $module_components = $module_def->module_components;
            
            #save the module def...
            push(@$mod_list,$module_def);
            
            #loop through the module components and find our functions
            foreach my $component (@$module_components) {
                if ($component->isa("Bio::KBase::KIDL::KBT::Funcdef")) {
                    # add empty annotation block so that parsed data structure is consistant
                    foreach my $rt (@{$component->{return_type}}) {
                        initAnnotationStructure($rt->{type});
                    }
                    foreach my $rt (@{$component->{parameters}}) {
                        initAnnotationStructure($rt->{type});
                    }
                    
                    push(@$func_list,$component);
                }
            }
        }
    }
    
    return ($type_list, $func_list, $mod_list);
}




sub validate_path {
    my ($parsed_path,$base_type,$isKeysOf) = @_;
    
    # if the hash is empty, then we want the full object.  If isKeysOf is on, then the base_type must be a mapping
    if(scalar(keys(%$parsed_path)) == 0) {
        if ($isKeysOf) {
            if ($base_type->isa("Bio::KBase::KIDL::KBT::Mapping")) { return ""; }
            else { return "keys_of(..) can only be applied to fields that resolve to a 'mapping'"; }
        }
        return "";
    }
    
    # if it is a struct, we need to validate the StructItems (ie the fields) that were specified
    if ($base_type->isa("Bio::KBase::KIDL::KBT::Struct")) {
        my $item_list = $base_type->items;
        my $item_lookup_table = {};
        foreach my $item (@$item_list) {
            my ($base_item_type, $d) = resolve_typedef($item->item_type);
            $item_lookup_table->{$item->name} = $base_item_type;
        }
        foreach my $field_name (keys(%$parsed_path)) {
            # we mark mappings (and potentially other things) with a dot appended before the field name, so we strip that
            my @toks = split(/\./,$field_name);
            if (scalar(@toks)==2) {
                $field_name = $toks[1];
            }
            if (!exists($item_lookup_table->{$field_name})) {
                return "field name given: '$field_name' is not a valid field of '".$base_type->module.".".$base_type->name."'";
            } else {
                my $err_mssg = validate_path($parsed_path->{$field_name},$item_lookup_table->{$field_name},$isKeysOf);
                if ($err_mssg ne "") { return $err_mssg; }
                
                #if it is a mapping, we need to mark it so that during subset extraction we know
                #to interpret the json object as a mapping and not a usual object
                #if ($item_lookup_table->{$field_name}->isa("Bio::KBase::KIDL::KBT::Mapping")) {
                #    my $temp = $parsed_path->{$field_name};
                #    delete $parsed_path->{$field_name};
                #    $parsed_path->{"mapping.".$field_name}=$temp;
                #}
            }
        }
    }
    
    # if it is the fields of a List we want, then we validate against the items that can be stored in the list
    elsif ($base_type->isa("Bio::KBase::KIDL::KBT::List")) {
        my ($base_element_type, $d) = resolve_typedef($base_type->element_type);
        if (exists $parsed_path->{"[*]"}) {
            my $err_mssg = validate_path($parsed_path->{"[*]"},$base_element_type,$isKeysOf);
            if ($err_mssg ne "") { return $err_mssg; }
        } else {
            return "must use an '[*]' to select subfields of objects stored in a list";
        }
    }
    
    # if it is the fields of a Mapping we want, then we validate against the values that can be stored in the list
    elsif ($base_type->isa("Bio::KBase::KIDL::KBT::Mapping")) {
        my ($base_value_type, $d) = resolve_typedef($base_type->value_type);
        if (exists $parsed_path->{"*"}) {
            my $err_mssg = validate_path($parsed_path->{"*"},$base_value_type,$isKeysOf);
            if ($err_mssg ne "") { return $err_mssg; }
        } else {
            return "must use an '*' to select subfields of objects stored in a mapping";
        }
        
        
    }
    
    #if it is an unsupported type and we got here, then we cannot recurse down and we must abort
    else {
        return "cannot specify fields (".join(",",keys(%$parsed_path)).") of type '".$base_type->as_string()."'";
    }
    
    #if we get here, then we are good.
    return "";
}


sub strip_keys_of_flag {
    my ($path_str) = @_;
    if($path_str =~ m/^keys_of\(/ && $path_str =~ m/\)$/) {
        $path_str =~ s/^keys_of\(//;
        $path_str =~ s/\)$//;
        return (1,$path_str); 
    }
    return (0,$path_str);
}

# given a string (and previously parsed path tree hash), this method parses and constructs
# a path through nested structures/lists/mappings to generate a listing of what was selected
# NOTE: this method does not validate the parsed path tree, see method 'validate_path'
# NOTE: if we want the language to become more complex, we should prob break down and write
# an actual grammer...  but for now this simple parser works fairly well.
sub resolve_path {
    my ($path_str,$parsed_path) = @_;
    
    my $pointer = $parsed_path;
    
    my @pos_stack;
    my $err_mssg = '';
    my $curfield = '';
    my @chars = split(//,$path_str);
    my $acceptingChars = '1'; my $acceptingOpen = '1';
    foreach my $c (@chars) {
        #print Dumper($parsed_path)."\n";
        #print "$c\n";
        # decend if we get to a '.'
        if ($c eq '.') {
            if($curfield eq '') {
                $err_mssg = "illegal use of '.'; it can only be used directly after a valid field name is given";
                last;
            }
            if (!exists($pointer->{$curfield})) {
                $pointer->{$curfield} = {};
            }
            $pointer = $pointer->{$curfield};
            $curfield = '';
            $acceptingChars = 1; $acceptingOpen=1;
            next;
        }
        if ($c eq '(') {
            if (!$acceptingOpen) {
                $err_mssg = "illegal use of '('; a grouping can only be declared directly following '.'";
                last;
            }
            push(@pos_stack,$pointer);
            $acceptingChars = 1;  $acceptingOpen=0;
            next;
        }
        if ($c eq ')') {
            if(scalar(@pos_stack)==0) {
                $err_mssg = "unbalanced parentheses, ')' found without earlier matching '('";
                last;
            }
            if ($curfield ne '' && !exists($pointer->{$curfield})) {
                $pointer->{$curfield} = {};
            }
            $pointer = pop(@pos_stack);
            $curfield = '';
            $acceptingChars = 0;  $acceptingOpen=0;
            next;
        }
        if ($c eq ',') {
            if ($curfield ne '' && !exists($pointer->{$curfield})) {
                $pointer->{$curfield} = {};
            }
            # we either reset the pointer to the end of the stack (to add a sibling field) or we reset to root
            if (scalar(@pos_stack)!=0) { $pointer = $pos_stack[-1]; }
            else { $pointer = $parsed_path; }
            $curfield = '';
            $acceptingChars = 1;  $acceptingOpen=0;
            next;
        }
        if (!$acceptingChars) {
            $err_mssg = "illegal definition of field name path; field names can only follow '.', '(', or ','";
            last;
        }
        $curfield .= $c;
        $acceptingOpen=0;
    }
    if ($curfield ne '') {
        $pointer->{$curfield} = {};
    }
    
    if (scalar(@pos_stack)!=0 && $err_mssg eq '') {
        $err_mssg = "unbalanced parentheses, '(' found without a later matching ')'";
        print Dumper(scalar @pos_stack)."\n";
    }
    
    if ($err_mssg ne '') { $parsed_path = {}; }
    
    return ($err_mssg);
}


