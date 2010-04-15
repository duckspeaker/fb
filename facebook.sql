
drop table if exists employment;
drop table if exists employers;
drop table if exists user_interests;
drop table if exists interests;
drop table if exists alumni_studies;
drop table if exists concentrations;
drop table if exists alumni;
drop table if exists institutes;
drop table if exists email;
drop table if exists users;


create table if not exists users (
    id bigint,
    first_name varchar(50),
    last_name varchar(50),
    sex varchar(1),
    birthday date,
    hometown_city varchar(100),
    hometown_state varchar(25),
    current_town_city varchar(100),
    current_town_state varchar(25),
    primary key(id)
) type=innodb;


create table if not exists email (
    user_id bigint,
    email varchar(40),
    foreign key (user_id) references users (id)
) type=innodb;


create table if not exists institutes (
    id bigint auto_increment,
    fb_id bigint,
    name varchar(150),
    primary key(id, name)
) type=innodb;


create table if not exists alumni (
    id bigint auto_increment,
    user_id bigint,
    institute_id bigint,
    education_type varchar(10),
    year int,
    degree_type varchar(30),
    foreign key (user_id) references users (id),
    foreign key (institute_id) references institutes (id),
    primary key(id)
) type=innodb;


create table if not exists concentrations (
    id bigint auto_increment,
    name varchar(80),
    primary key(id, name)
) type=innodb;


create table if not exists alumni_studies (
    alumni_id bigint,
    concentration_id bigint,
    foreign key (alumni_id) references alumni (id),
    foreign key (concentration_id) references concentrations (id)
) type=innodb;


create table if not exists interests (
    id bigint auto_increment,
    name varchar(250),
    primary key(id, name)
) type=innodb;


create table if not exists user_interests (
    user_id bigint,
    interest_id bigint,
    foreign key (user_id) references users (id),
    foreign key (interest_id) references interests (id),
    primary key(user_id, interest_id)
) type=innodb;


create table if not exists employers (
    id bigint auto_increment,
    fb_id bigint,
    name varchar(200),
    primary key(id, name)
) type=innodb;


create table if not exists employment (
    id bigint not null auto_increment,
    employee_id bigint,
    employer_id bigint,
    position varchar(100),
    startDate varchar(30),
    endDate varchar(30),
    location_city varchar(100),
    location_state varchar(20),
    description varchar(250),
    foreign key (employee_id) references users (id),
    foreign key (employer_id) references employers (id),
    primary key(id)
) type=innodb;
