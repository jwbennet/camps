package Camp::Type;

use strict;
use warnings;
use File::Copy::Recursive qw(rcopy);
use File::Path;
use Camp::Master;

sub add {
    my ($type, %conf) = @_;
    print "Creating new camp type: $type\n";
    my $type_root = type_root($type);
	create_directory($type_root);
    setup_git_repository($type_root, $type);
    copy_skeleton_files($type_root);
    register_camp_type($type, $conf{description});
}

sub rm {
    my ($type) = @_;
    print "Removing camp type: $type\n";
    remove_directory($type);
    unregister_camp_type($type);
}

sub type_root {
    my ($type) = @_;
    return Camp::Master::base_path() . "/$type";
}

sub create_directory {
    my ($type_root) = @_;
    mkdir($type_root) 
		or die "Failed to create camp type directory: $!\n Try running as the camp user";
}

sub remove_directory {
    my ($type) = @_;
    rmtree(type_root($type));
}

sub setup_git_repository {
    my ($type_root, $type) = @_;
    my $project_git_path = "$type_root/$type.git";
    mkdir($project_git_path)
        or die "Failed to create default git directory: $!";
    system("git init --bare --shared=group $project_git_path") == 0
        or die "Failed to initialize default git repository";
}

sub copy_skeleton_files {
    my ($type_root) = @_;
    rcopy(Camp::Master::base_path() . "/skel", $type_root);
}

sub register_camp_type {
    my ($type, $description) = @_;
    $description = '' unless defined $description;
    my $dbh = Camp::Master::dbh();
    my $sth = $dbh->prepare("INSERT INTO camp_types (camp_type, description) VALUES (?, ?)");
    $sth->execute($type, $description)
		or die "Failed to register camp type in database";
	$sth->finish();
}

sub unregister_camp_type {
    my ($type) = @_;
    my $dbh = Camp::Master::dbh();
    my $sth = $dbh->prepare("DELETE FROM camp_types WHERE camp_type = ?");
    $sth->execute($type)
		or die "Failed to remove camp type from database";
	$sth->finish();
}
1;
