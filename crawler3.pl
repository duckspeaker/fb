
use DBI;
use LWP;
use HTML::TokeParser;
use HTTP::Cookies;
use Term::ReadKey;
use utf8;
use strict;

my $login;
my $password;
my $status_message;
my $post_form_id;
my $user_agent = "Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.9.0.9) Gecko/2009042113 Ubuntu/8.10 (intrepid) Firefox/3.0.9";
my @header = ( 'Referer' => 'http://www.facebook.com/', 
               'User-Agent' => $user_agent);
my $cookie_jar = HTTP::Cookies->new(
                        file => 'cookies.dat',
                        autosave => 1,
                        ignore_discard => 1);
my $browser = LWP::UserAgent->new;
$browser->cookie_jar($cookie_jar);

#====================================================
# Get login info from user. (temporarily hard-coded)
#====================================================
#print "Enter facebook login (email): ";
#$login = <>; chomp($login);
$login = 'XXXXXXXXXXXXXX';
 
#print "Enter facebook password: ";
ReadMode('noecho');
#$password = ReadLine(0); chomp($password); ReadMode 0;
$password = 'XXXXXXXXXXXXXXXXX';
 
#================================================
# Connect to facebook and get cookies.
#================================================
my $response = $browser->get('http://www.facebook.com', @header);
$cookie_jar->extract_cookies($response);
 
#================================================
# Log in.
#================================================
$response = $browser->post('https://login.facebook.com/login.php?login_attempt=1', 
                           ['charset_test' => '&euro;,&acute;,€,´,水,Д,Є',  #'&euro;,&acute;,‚Ç¨,¬¥,Ê∞¥,–î,–Ñ',
                            'locale' => 'en_US',
                            'persistent' => '1',
                            'email' => $login,
                            'pass' => $password,
                            'pass_placeholder' => 'Password'], @header);
                            # fb_dtsg?
$cookie_jar->extract_cookies($response);
 
#===================================================
# Get some proof that we've successfully logged in.
#===================================================
@header = ( 'Host' => 'facebook.com',
            'User-Agent' => $user_agent,
            'Connection' => 'keep-alive');

$response = getUrl('http://www.facebook.com/home.php');

#====================================================
# For each year, search for alumni of that class.
#
# For each profile result, make sure it's the alumni
# of the desired school for the desired class year.
#
# For each desired profile, grab the profile data,
# clean it, and store it in database.
#====================================================
my @years = reverse(1910 .. 2008);  #2009
my $school = 'Berkeley'; # NOTE: this is not even used
my ($url, $s) = ("", 0);
my $tp;

foreach (@years) {
    print("\n", "YEAR: $_", "\n\n");  
    $s = 0;
    print("PAGE: ", ($s/10 + 1), "\n\n");
    do {
        my @profileIds;
        
        $url = getSearchUrl($_, $s);
        print("search page url: $url", "\n");
        $response = getUrl($url);

        $tp = HTML::TokeParser->new(\$response);
        while (my $token = $tp->get_tag("div")) {
            if (defined $token->[1]{class} 
                    && $token->[1]{class} =~ /result clearfix/i) {
                $token = $tp->get_tag("dd");
                if (defined $token->[1]{class}
                        && $token->[1]{class} =~ /result_name fn/i) {
                    $token = $tp->get_tag("a");
                    if ($token->[1]{href} =~ /id=(.*?)&/i) {
                        push(@profileIds, $1);
                    }
                }
            }
        }
        
        foreach(@profileIds) {
            grab_profile_data($_);
        }
        
        $s += 10;
        print("PAGE: ", ($s/10 + 1), "\n\n");
    } while ($response =~ /Next<\/a>/);
}


sub grab_profile_data {
    my ($id) = @_;
    my $url = getProfileUrl($id);
    print("profile url: $url", "\n");

    my $profile_html = getUrl($url);
    my %profile;
    
    print("****\n");
    
    $profile{'id'} = $id;
    print("id: $id", "\n");
    
    ($profile{'first_name'}, $profile{'last_name'}) = getName($profile_html);
    if (defined $profile{'first_name'} and defined $profile{'last_name'}) {
        print("name: $profile{'first_name'} $profile{'last_name'}", "\n");
    }
    
    $profile{'sex'} = getSex($profile_html);
    print("sex: ");
    if (defined $profile{'sex'}) {
        print("$profile{'sex'}");
    }
    print("\n");
    
    $profile{'birthday'} = getBirthday($profile_html);
    print("birthday: ");
    if (defined $profile{'birthday'}) {
        print("$profile{'birthday'}");
    }
    print("\n");
    
    ($profile{'hometown_city'}, $profile{'hometown_state'}) = getHometown($profile_html);
    print("hometown: ");
    if (defined $profile{'hometown_city'}) {
        print("$profile{'hometown_city'}, $profile{'hometown_state'}");
    }
    print("\n");
    
    my @interests = getInterests($profile_html);
    $profile{'interests'} = \@interests;
    print("interests: ");
    if (scalar($profile{'interests'}) > 0) {
        print("$profile{'interests'}");
    }
    print("\n");
    
    my @email = getEmail($profile_html);
    $profile{'email'} = \@email;
    print("email: ");
    if (scalar($profile{'email'}) > 0) {
        print("@email");
    }
    print("\n");
    
    ($profile{'current_town_city'}, $profile{'current_town_state'}) = getCurrentTown($profile_html);
    print("current town: ");
    if (defined $profile{'current_town_city'}) {
        print("$profile{'current_town_city'}, $profile{'current_town_state'}");
    }
    print("\n");
    
    my @college_entries = getCollege($profile_html);
    $profile{'college'} = \@college_entries;
    print("college: ");
    if (scalar($profile{'college'}) > 0) {
        print("$profile{'college'}");
    }
    print("\n");
    
    my @gradschool_entries = getGradSchool($profile_html);
    $profile{'grad'} = \@gradschool_entries;
    print("grad school: ");
    if (scalar($profile{'grad'}) > 0) {
        print("$profile{'grad'}");
    }
    print("\n");
    
    my %hs = getHighSchool($profile_html);
    $profile{'hs'} = \%hs;
    print("high school: ");
    if (defined $profile{'hs'}->{'school'}) {
        print("$profile{'hs'}");
    }
    print("\n");
    
    my @employments = getEmployerInfo($profile_html);
    $profile{'employment'} = \@employments;
    print("employer: ");
    if (scalar($profile{'employment'}) > 0) {
        print("$profile{'employment'}");
    }
    print("\n");
    
    print("\n\n");
    
    store_profile(\%profile);
}


sub getUrl {
    my ($url) = @_;
    my $response = $browser->get($url, @header);
    $cookie_jar->extract_cookies($response);
    $cookie_jar->save;
    
    my $content = $response->content;
    $content =~ s/\n//g;
    
    return $content;
}

sub getImage {
    my ($url) = @_;
    my $response = $browser->get($url, @header);
    $cookie_jar->extract_cookies($response);
    $cookie_jar->save;
    
    my $content = $response->content;
    return $content;
}

sub getSearchUrl {
    my ($year, $s) = @_;
    my $url = "http://www.facebook.com/srch.php?init=s%3Aclassmate&sf=p&sid=XXXXXXXXXXX.NOQ..2&ed=16777229&n=16777229&yr=$year&k=100008000&nm&em&wk&o=4&s=$s&hash=4993d522b41643abb0e48e93c73c1146";
    return $url;
}

sub getProfileUrl {
    my ($id) = @_;
    my $url = "http://www.facebook.com/profile.php?id=$id&ref=search";
    # redirect for case in which user has human-friendly id
    if (getUrl($url) =~ /window\.location\.replace\(.*?facebook\.com\\\/(.*?)\?ref=search"\)/i) {
        $url = "http://www.facebook.com/$1"; #&ref=search";
    }

    return $url;
}

sub getName {
    my ($profile) = @_;
    my (@name, $first_name, $last_name);
    if ($profile =~ /<h1 id="profile_name">(.*?)<\/h1>/i) {
        @name = split(/\s/, $1);
        $first_name = $name[0];
        $last_name = $name[-1];
    }
    return ($first_name, $last_name);
}

sub getSex {
    my ($profile) = @_;
    my ($sex, $sex_initial);
    if ($profile =~ /Sex:<\\*\/dt><dd>(.*?)<\\*\/dd>/i) {
        $sex = $1;
        if ($sex eq 'Male') {
            $sex_initial = 'M';
        } elsif ($sex eq 'Female') {
            $sex_initial = 'F';
        }
    }
    return $sex_initial;
}

sub getBirthday {
    my ($profile) = @_;
    my ($birthday);
    if ($profile =~ /Birthday:<\\*\/dt><dd>(.*?)<\\*\/dd>/i) {
        $birthday = $1;
    }
    return $birthday;
}

sub getHometown {
    my ($profile) = @_;
    my ($hometown, $hometown_city, $hometown_state);
    if ($profile =~ /Hometown:<\\*\/dt><dd>(.*?)<\\*\/dd>/i) {
        $hometown = $1;
        ($hometown_city, $hometown_state) = trim(split(/,/, $hometown));
    }
    return ($hometown_city, $hometown_state);
}

sub getInterests {
    my ($profile) = @_;
    my (@interests);
    if ($profile =~ /Interests:<\\*\/dt><dd>(.*?)<\\*\/dd>/i) {
        @interests = $1 =~ /<a href=.*?>(.*?)<\\*\/a>/ig;
    }
    return @interests;
}

sub getEmail {
    my ($profile) = @_;
    my (@email_url, @email_txt);
    if ($profile =~ /Email:<\\*\/dt><dd>(.*?)<\\*\/dd>/i) {
        @email_url = $1 =~ /src="(.*?)"/ig;
        foreach(@email_url) {
            $_ =~ s/^/http:\/\/www\.facebook\.com/;
            $_ =~ s/fp=.*&/fp=90&/;
            
            my $file = getImage($_);
            open(FILE, ">email.png");
            print(FILE $file);
            close(FILE);
            
            my $text = `gocr email.png`;
            $text =~ s/\s//g;
            $text =~ s/\.cOm/\.com/;
            push(@email_txt, $text);
        }
    }
    return @email_txt;
}

sub getCurrentTown {
    my ($profile) = @_;
    my ($current_town, $current_town_city, $current_town_state);
    if ($profile =~ /Current Town:<\\*\/dt><dd>(.*?)<\\*\/dd>/i) {
        $current_town = $1;
        if ($current_town =~ /<a href=.*?>(.*?)<\\*\/a>/i) {
            $current_town = $1;
            ($current_town_city, $current_town_state) = trim(split(/,/, $current_town));
        }
    }
    return ($current_town_city, $current_town_state);
}

sub getCollege {
    my ($profile) = @_;
    my @college_entries;
    if ($profile =~ /Colleges*:<\\*\/dt><dd>(.*?)<\\*\/span/mi) {
        my $region = $1;
        my @subregions = $region =~ /(<a href="\/srch\.php\?n=.*?)<\\*\/ul>/mig;
        foreach(@subregions) {
            my $subregion = $1;
            my %college;
            $college{'school'} = $1 if $subregion =~ /yr=\d+">(.*?)\s'/mi;
            $college{'school_fb_id'} = $1 if $subregion =~ /\?n=(\d+)/mi;
            $college{'year'} = $1 if $subregion =~ /yr=(\d+)/mi;
            
            my $degree;
            if ($subregion =~ /<a href=".*?cn=/mi) {
                $degree = $1 if $subregion =~ /<li>(.+?), <a href=".*?cn=/mi;
                $degree = undef if defined $degree  and $degree =~ /<a href=".*?cn=/mi;
            } else {
                $degree = $1 if $subregion =~ /<li>(.+?)<\\*\/li>/mi;
            }
            $college{'degree'} = $degree;
            
            my @concentrations = $subregion =~ /cn=.*?>(.*?)<\\*\/a>/mig;
            $college{'concentrations'} = \@concentrations;
            
            push(@college_entries, \%college);
        }
    }
    return @college_entries;
}

sub getGradSchool {
    my ($profile) = @_;
    my @gradschool_entries;
    if ($profile =~ /Grad Schools*:<\\*\/dt><dd>(.*?)<\\*\/span>/mi) {
        my $region = $1;
        my @subregions = $region =~ /(<a href="\/srch\.php\?n=.*?)<\\*\/ul>/mig;
        foreach(@subregions) {
            my $subregion = $_;
            my %gradschool;
            $gradschool{'school'} = $1 if $subregion =~ /yr=\d+">(.*?)\s'/mi;
            $gradschool{'school_fb_id'} = $1 if $subregion =~ /\?n=(\d+)/mi;
            $gradschool{'year'} = $1 if $subregion =~ /yr=(\d+)/mi;
            
            my $degree;
            if ($subregion =~ /<a href=".*?cn=/mi) {
                $degree = $1 if $subregion =~ /<li>(.+?), <a href=".*?cn=/mi;
                $degree = undef if defined $degree and $degree =~ /<a href=".*?cn=/mi;
            } else {
                $degree = $1 if $subregion =~ /<li>(.+?)<\\*\/li>/mi;
            }
            $gradschool{'degree'} = $degree;
            
            my @concentrations = $subregion =~ /cn=.*?>(.*?)<\\*\/a>/mig;
            $gradschool{'concentrations'} = \@concentrations;
            
            push(@gradschool_entries, \%gradschool);
        }
    }
    return @gradschool_entries;
}

sub getHighSchool {
    my ($profile) = @_;
    my %hs;
    if ($profile =~ /High School:<\\*\/dt><dd><ul><li>(.*?)<\\*\/li>/i) {
        my $region = $1;
        $hs{'school'} = $1 if $region =~ /hr=\d+">(.*?)\s'/mi;
        $hs{'school_fb_id'} = $1 if $region =~ /\?hs=(\d+)/mi;
        $hs{'year'} = $1 if $region =~ /hr=(\d+)/mi;
    }
    return %hs;
}

sub getEmployerInfo {
    my ($profile) = @_;
    my (@employments);
    if ($profile =~ /Employer:<\\*\/dt><dd>(.*?)<\\*\/dl>/i) {
        my $region = $1;
        my @subregions = split('<dt class="line_break">&nbsp</dt><dd class="line_break">&nbsp</dd><dt>Employer:</dt><dd>', $region);
        foreach(@subregions) {
            my $subregion = $_;
            my %employment;
            $employment{'employer_fb_id'} = $1 if $subregion =~ /srch\.php\?n=(\d+?)">/i;
            $employment{'employer_name'} = $1 if $subregion =~ /<a href=".*?">(.*?)<\\*\/a>/i;
            $employment{'position'} = $1 if $subregion =~ /Position:.*?<a href=".*?">(.*?)<\\*\/a>/i;
            ($employment{'startDate'}, $employment{'endDate'}) = ($1, $2) if $subregion =~ /Time Period:<\\*\/dt><dd>(.*?) - (.*?)<\\*\/dd>/i;
            ($employment{'location_city'}, $employment{'location_state'}) = ($1, $2) if $subregion =~ /Location:<\\*\/dt><dd>(.*?), (.*?)<\\*\/dd>/i;
            $employment{'description'} = $1 if $subregion =~ /Description:<\\*\/dt><dd>(.*?)<\\*\/dd>/i;
            
            push(@employments, \%employment)
        }
    }
    return @employments;
}

sub trim {
    my (@str) = @_;
    foreach(@str) {
        $_ =~ s/^\s+//;
        $_ =~ s/\s+$//;
    }
    return @str;
}

sub store_profile {
    my ($profile) = @_;
    my $dbh = DBI->connect('DBI:mysql:facebook', 'root', 'XXXXXXXXXXXXX')
                || die "Unable to connect to db: $DBI::errstr";
    my ($sth, @result, $rc);
    
    $sth = $dbh->prepare('SELECT count(id) FROM users WHERE id=?');
    $sth->execute($profile->{id});
    @result = $sth->fetchrow_array();
    
    # TODO: if user is already in db, do an update

    if (1 == 0) { #$result[0] > 0) {
        return;
    } else {
        # insert user
        $sth = $dbh->prepare(
            ' INSERT INTO users'
          . '   (id, first_name, last_name, sex, birthday,'
          . '    hometown_city, hometown_state,'
          . '    current_town_city, current_town_state)'
          . ' VALUES'
          . '   (?, ?, ?, ?, ?,'
          . '    ?, ?,'
          . '    ?, ?)');
        $sth->execute(
            $profile->{id}, $profile->{first_name}, $profile->{last_name}, $profile->{sex}, $profile->{birthday},
            $profile->{hometown_city}, $profile->{hometown_state},
            $profile->{current_town_city}, $profile->{current_town_state});
        
        # insert email
        foreach(@{$profile->{email}}) {
            $sth = $dbh->prepare(
                'INSERT INTO email (user_id, email) VALUES (?, ?)');
            $sth->execute($profile->{id}, $_);
        }
        
        # insert college
        foreach(@{$profile->{college}}) {
            my $college = $_;
            
            $sth = $dbh->prepare('SELECT count(id) FROM institutes WHERE fb_id=?');
            $sth->execute($college->{school_fb_id});
            @result = $sth->fetchrow_array();
            if ($result[0] < 1) {
                # insert the institute
                $sth = $dbh->prepare(
                    'INSERT INTO institutes (fb_id, name) VALUES (?, ?)');
                $sth->execute($college->{school_fb_id}, $college->{school});
            }
            
            # get id of inserted institute
            $sth = $dbh->prepare('SELECT id FROM institutes WHERE name=?');
            $sth->execute($college->{school});
            @result = $sth->fetchrow_array();
            my $institute_id = $result[0];
            
            # insert alumni
            $sth = $dbh->prepare(
                ' INSERT INTO alumni'
              . '   (user_id, institute_id, education_type, year, degree_type)'
              . ' VALUES'
              . '   (?, ?, ?, ?, ?)');
            $sth->execute(
                $profile->{id}, $institute_id, 'ugrad', $college->{year}, $college->{degree});

            # get id of inserted alumni
            $sth = $dbh->prepare('SELECT LAST_INSERT_ID()');
            $sth->execute();
            @result = $sth->fetchrow_array();
            my $alumni_id = $result[0];
            
            # insert concentrations
            foreach(@{$college->{concentrations}}) {
                
                $sth = $dbh->prepare('INSERT INTO concentrations (name) VALUES (?)');
                $sth->execute($_);
                
                # get id of inserted concentration
                $sth = $dbh->prepare('SELECT id FROM concentrations WHERE name=?');
                $sth->execute($_);
                @result = $sth->fetchrow_array();
                my $concentration_id = $result[0];
                
                # alumni studies (using concentration id and alumni id)
                $sth = $dbh->prepare('INSERT INTO alumni_studies (alumni_id, concentration_id) VALUES (?, ?)');
                $sth->execute($alumni_id, $concentration_id);
            }
        }

        # insert grad
        foreach(@{$profile->{grad}}) {
            my $grad = $_;
            
            $sth = $dbh->prepare('SELECT count(id) FROM institutes WHERE fb_id=?');
            $sth->execute($grad->{school_fb_id});
            @result = $sth->fetchrow_array();
            if ($result[0] < 1) {
                # insert the institute
                $sth = $dbh->prepare(
                    'INSERT INTO institutes (fb_id, name) VALUES (?, ?)');
                $sth->execute($grad->{school_fb_id}, $grad->{school});
            }
            
            # get id of inserted institute
            $sth = $dbh->prepare('SELECT id FROM institutes WHERE name=?');
            $sth->execute($grad->{school});
            @result = $sth->fetchrow_array();
            my $institute_id = $result[0];
            
            # insert alumni
            $sth = $dbh->prepare(
                ' INSERT INTO alumni'
              . '   (user_id, institute_id, education_type, year, degree_type)'
              . ' VALUES'
              . '   (?, ?, ?, ?, ?)');
            $sth->execute(
                $profile->{id}, $institute_id, 'grad', $grad->{year}, $grad->{degree});

            # get id of inserted alumni
            $sth = $dbh->prepare('SELECT LAST_INSERT_ID()');
            $sth->execute();
            @result = $sth->fetchrow_array();
            my $alumni_id = $result[0];
            
            # insert concentrations
            foreach(@{$grad->{concentrations}}) {
                
                $sth = $dbh->prepare('INSERT INTO concentrations (name) VALUES (?)');
                $sth->execute($_);
                
                # get id of inserted concentration
                $sth = $dbh->prepare('SELECT id FROM concentrations WHERE name=?');
                $sth->execute($_);
                @result = $sth->fetchrow_array();
                my $concentration_id = $result[0];
                
                # alumni studies (using concentration id and alumni id)
                $sth = $dbh->prepare('INSERT INTO alumni_studies (alumni_id, concentration_id) VALUES (?, ?)');
                $sth->execute($alumni_id, $concentration_id);
            }
        }

        # insert hs
        my $hs = $profile->{hs};
        if (scalar(keys(%$hs)) > 0) {
            $sth = $dbh->prepare('SELECT count(id) FROM institutes WHERE fb_id=?');
            $sth->execute($hs->{school_fb_id});
            @result = $sth->fetchrow_array();
            if ($result[0] < 1) {
                $sth = $dbh->prepare(
                    'INSERT INTO institutes (fb_id, name) VALUES (?, ?)');
                $sth->execute($hs->{school_fb_id}, $hs->{school});
            }
            
            # get id of inserted institute
            $sth = $dbh->prepare('SELECT id FROM institutes WHERE name=?');
            $sth->execute($hs->{school});
            @result = $sth->fetchrow_array();
            my $institute_id = $result[0];
    
            # insert alumni
            $sth = $dbh->prepare(
                ' INSERT INTO alumni'
              . '   (user_id, institute_id, education_type, year)'
              . ' VALUES'
              . '   (?, ?, ?, ?)');
            $sth->execute(
                $profile->{id}, $institute_id, 'hs', $hs->{year});
        }
        
        # insert employer
        foreach(@{$profile->{employment}}) {
            my $employment = $_;
            
            $sth = $dbh->prepare(
                'INSERT INTO employers (fb_id, name) VALUES (?, ?)');
            $sth->execute($employment->{employer_fb_id}, $employment->{employer_name});
            
            # get id of inserted employer
            $sth = $dbh->prepare('SELECT id FROM employers WHERE name=?');
            $sth->execute($employment->{employer_name});
            @result = $sth->fetchrow_array();
            my $employer_id = $result[0];
            
            # insert employment
            $sth = $dbh->prepare(
                ' INSERT INTO employment'
              . '   (employee_id, employer_id, position, startDate, endDate,'
              . '    location_city, location_state, description)'
              . ' VALUES'
              . '   (?, ?, ?, ?, ?,'
              . '    ?, ?, ?)');
            $sth->execute(
                $profile->{id}, $employer_id, $employment->{position}, $employment->{startDate}, $employment->{endDate},
                $employment->{location_city}, $employment->{location_state}, $employment->{description});
        }
        
        # insert interests
        foreach(@{$profile->{interests}}) {
                $sth = $dbh->prepare('INSERT INTO interests (name) VALUES (?)');
                $sth->execute($_);
                
                # get id of inserted concentration
                $sth = $dbh->prepare('SELECT id FROM interests WHERE name=?');
                $sth->execute($_);
                @result = $sth->fetchrow_array();
                my $interest_id = $result[0];
                
                # user_interests (using concentration id and alumni id)
                $sth = $dbh->prepare('INSERT INTO user_interests (user_id, interest_id) VALUES (?, ?)');
                $sth->execute($profile->{id}, $interest_id);
        }
    }
    
    $rc = $dbh->disconnect;
    my $place_holder = 1;
}

# delete cookies and any other downloaded resources
exec('rm cookies.dat email.png');
