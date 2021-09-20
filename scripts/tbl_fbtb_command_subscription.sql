create sequence fbtb_command_subscription_seq;

create table fbtb_command_subscription(
    subscription_id bigint
    , command_id bigint
    , chat_id bigint
    , user_id bigint
    , repeat_after varchar(32)
    , start_date date
    , end_date date
    , from_time time
    , to_time time
    , no_sound smallint
    , constraint pk_fbtb_command_subscription primary key (subscription_id)
);

comment on table fbtb_command_subscription is 'Stores information about all subscriptions.';
comment on column fbtb_command_subscription.subscription_id is 'todo:';


