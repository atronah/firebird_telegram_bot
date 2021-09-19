create sequence fbtb_command_seq;

create table fbtb_command(
    command_id bigint
    , bot_id bigint
    , command_name varchar(32)
    , command_description varchar(1024)
    , result_statement blob sub_type text
    , allowed_chat_id_list varchar(1024)
    , allowed_user_id_list varchar(1024)
    , constraint pk_fbtb_command primary key (command_id)
);

comment on table fbtb_command is 'Stores information about all supported user commands for each bot in that database.';
comment on column fbtb_command.command_id is 'todo:';

