create sequence fbtb_bot_seq;

create table fbtb_bot(
    bot_id bigint
    , bot_name varchar(32)
    , bot_token varchar(64)
    , last_updates timestamp
    , update_delay_in_milliseconds bigint default 5000
    , message_prefix varchar(64)
    , messages_per_day_limit smallint default 100
    , enabled smallint
    , data_db varchar(1024)
    , data_user varchar(32)
    , data_password varchar(32)
    , constraint pk_fbtb_bot primary key (bot_id)
);

comment on table fbtb_bot is 'Stores information about each bot in that database.';

comment on column fbtb_bot.bot_id is 'todo:';
