package Camp::User;

use strict;
use warnings;
use Camp::Master;

sub add {
	my ($username, %conf) = @_;
	my $name = $conf{name};
	die 'Name must be provided (with --name="...")' unless $name;
	my $email = $conf{email};
	die 'Email must be provided (with --email="...")' unless $email;
	if ($conf{all}) {
		# Only create a new user if the --all flag is given
		create_user($username, $name);
	}
	else {
		# Check if user exists first
		if (system("id $username > /dev/null 2>&1") == 0) {
			# The user already exists so add it to the camp group
			add_to_camp_group($username);
		}
		else {
			# The user doesn't exist so throw an error
			die 'System user doesn\'t exist, use --all to create a new system user';
		}
	}
	register_user($username, $name, $email);
	create_git_config($username, $name, $email);
}

sub rm {
	my ($username, %conf) = @_;
	if ($conf{all}) {
		# Completely remove the user from the system if the --all flag is
		# given
		remove_from_camp_group($username);
		remove_user($username);
	}
	else {
		# Remove the user from the camp group otherwise
		remove_from_camp_group($username);
	}
	unregister_user($username, $conf{all});
}

sub create_user {
	my ($username, $name) = @_;
	# This funtion can create a new user only if the script is ran as a root
	# user
	die 'Cannot create user unless ran as root' unless $< == 0;
	system("useradd -G camp -c \"$name\" $username") == 0 
		or die "Failed to create new user";
	print "Created new system user $username\n";
}

sub remove_user {
	my ($username) = @_;
	# This function can only remove the user if ran as a root user
	die 'Cannot remove the user unless ran as root' unless $< == 0;
	system("userdel -r $username") == 0
		or die 'Failed to remove user';
	print "Removed system user $username\n";
}

sub add_to_camp_group {
	my ($username) = @_;
	# This function can only modify the user's group if ran as a root user
	die 'Cannot modify the user\'s group unless ran as root' unless $< == 0;
	system("gpasswd -a $username camp") == 0
		or 'Failed to add the user to the camp group';
}

sub remove_from_camp_group {
	my ($username) = @_;
	die 'Cannot modify the user\'s group unless ran as root' unless $< == 0;
	system("gpasswd -d $username camp") == 0
		or 'Failed to remove the user from the camp group';
}

sub register_user {
	my ($username, $name, $email) = @_;
	my $dbh = Camp::Master::dbh();
	my $sth = $dbh->prepare("INSERT INTO camp_users (username, name, email) VALUES (?, ?, ?)");
	$sth->execute($username, $name, $email)
		or die "Failed to register new camp user";
	$sth->finish();
	print "Registered $username as a camp admin\n";
}

sub unregister_user {
	my ($username, $all) = @_;
	my $dbh = Camp::Master::dbh();
	my $sth = $dbh->prepare("DELETE FROM camp_users WHERE username = ?");
	$sth->execute($username)
		or die 'Failed to unregister user';
	$sth->finish();
	print "Removed $username as a camp admin\n";

	if ($all) {
		# If the --all flag is passed the user is completely removed from the
		# system so clean up all of the entries in the camps table
		$sth = $dbh->prepare("DELETE FROM camps WHERE username = ?");
		$sth->execute($username)
			or die "Failed to delete camp records from the database";
		$sth->finish();
		print "Removed all camps for $username from the database\n";
	}
}

sub create_git_config {
	my ($username, $name, $email) = @_;
	my $gitconfig_file = "/home/$username/.gitconfig";
	if (-e $gitconfig_file) {
		print ".gitconfig unmodified since it already exists\n";
	}
	else {
		my $file;
		# Print contents to file
		open($file, '>', $gitconfig_file)
			or die "Failed to open .gitconfig file";
		print $file <<EOF;
[user]
	name = $name
	email = $email
EOF
	    close($file)
			or die "Failed to close .gitconfig file";

		# Change the owner of the .gitconfig file to the correct user
		my ($login, $pass, $uid, $gid) = getpwnam($username);		
        chown($uid, $gid, $gitconfig_file)
			or die 'Failed to change ownder of .gitconfig file';
		print ".gitconfig created for user $username\n";
	}
}
1;
