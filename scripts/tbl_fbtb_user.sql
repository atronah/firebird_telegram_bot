create table fbtb_user(
   user_id bigint
    , username varchar(255)
    , updated timestamp
    , constraint pk_fbtb_user primary key (user_id)
);

comment on table fbtb_user is 'Stores information about telegram users';
comment on column fbtb_user.user_id is 'todo:';

